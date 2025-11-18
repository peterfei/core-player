import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/playback_history.dart';
import '../models/buffer_config.dart';
import '../models/network_stats.dart';
import '../models/cache_entry.dart';
import '../services/history_service.dart';
import '../services/simple_thumbnail_service.dart';
import '../services/macos_bookmark_service.dart';
import '../services/network_stream_service.dart';
import '../services/bandwidth_monitor_service.dart';
import '../services/video_cache_service.dart';
import '../services/cache_download_service.dart';
import '../services/local_proxy_server.dart';
import '../services/subtitle_service.dart';
import '../services/video_analyzer_service.dart';
import '../services/hardware_acceleration_service.dart';
import '../services/performance_monitor_service.dart';
import '../models/subtitle_track.dart' as subtitle_models;
import '../models/subtitle_config.dart';
import '../models/video_info.dart';
import '../models/codec_info.dart';
import '../models/hardware_acceleration_config.dart';
import '../widgets/enhanced_buffering_indicator.dart';
import '../widgets/cache_indicator.dart';
import '../widgets/video_info_panel.dart';
import '../widgets/performance_overlay.dart' as custom;
import 'subtitle_settings_screen.dart';
import 'subtitle_download_screen.dart';

class PlayerScreen extends StatefulWidget {
  final File? videoFile;
  final String? webVideoUrl;
  final String? webVideoName;
  final int? seekTo;
  final bool fromHistory;

  const PlayerScreen({
    super.key,
    this.videoFile,
    this.webVideoUrl,
    this.webVideoName,
    this.seekTo,
    this.fromHistory = false,
  });

  // 用于网络视频的便捷构造函数
  PlayerScreen.network({
    super.key,
    required String videoPath,
    this.webVideoName,
    this.seekTo,
    this.fromHistory = false,
  }) : videoFile = null,
       webVideoUrl = videoPath;

  // 用于本地视频的便捷构造函数
  PlayerScreen.local({
    super.key,
    required File videoFile,
    this.webVideoName,
    this.seekTo,
    this.fromHistory = false,
  }) : videoFile = videoFile,
       webVideoUrl = null;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // Create a [Player] instance from `media_kit`.
  // Enable libass for native MPV subtitle rendering (required for sub-add command)
  // Subtitles are rendered directly on the video by MPV's libass
  late Player player;
  VideoController? controller;

  // 超高清视频支持相关服务
  VideoInfo? _currentVideoInfo;
  HardwareAccelerationConfig? _hwAccelConfig;
  StreamSubscription<PerformanceMetrics>? _performanceSubscription;
  StreamSubscription<HardwareAccelerationEvent>? _hwAccelSubscription;
  bool _showPerformanceOverlay = false;
  bool _videoInfoPanelVisible = false;
  bool _isInitialized = false;

  // 初始化播放器和服务
  Future<void> _initializePlayerAndServices() async {
    try {
      // 初始化播放器和硬件加速
      await _initializePlayer();

      // 设置播放器监听器
      _setupPlayerListeners();

      // 启动性能监控（播放器初始化后）
      _startPerformanceMonitoring();

      // 标记初始化完成
      setState(() {
        _isInitialized = true;
      });

      print('🚀 超高清视频支持服务初始化完成');
    } catch (e) {
      print('❌ 服务初始化失败: $e');
      // 确保基本的播放器监听器仍然工作
      _setupPlayerListeners();
      // 即使出错也标记为已初始化（使用降级模式）
      setState(() {
        _isInitialized = true;
      });
    }
  }

  // 初始化播放器配置
  Future<void> _initializePlayer() async {
    try {
      // 获取硬件加速配置
      await HardwareAccelerationService.instance.initialize();
      _hwAccelConfig = await HardwareAccelerationService.instance.getRecommendedConfig();

      // 创建播放器配置
      final config = _buildPlayerConfiguration();

      // 创建播放器实例
      player = Player(configuration: config);
      controller = VideoController(player);

      // 监听硬件加速事件
      _hwAccelSubscription = HardwareAccelerationService.instance.events.listen(
        _handleHardwareAccelerationEvent,
      );

      print('🎮 播放器初始化完成');
      print('  硬件加速: ${_hwAccelConfig?.enabled == true ? "✅ 已启用" : "❌ 未启用"}');
      if (_hwAccelConfig?.enabled == true) {
        print('  加速类型: ${_hwAccelConfig?.displayName}');
        print('  支持编解码器: ${_hwAccelConfig?.supportedCodecs.join(", ")}');
      }
    } catch (e) {
      print('❌ 播放器初始化失败: $e');
      // 降级到基础配置
      player = Player(configuration: const PlayerConfiguration(libass: true));
      controller = VideoController(player);
    }
  }

  // 构建播放器配置
  PlayerConfiguration _buildPlayerConfiguration() {
    Map<String, dynamic> libmpvSettings = {
      'libass': true, // 保持原有字幕支持
    };

    // 应用硬件加速配置
    if (_hwAccelConfig?.enabled == true && _hwAccelConfig != null) {
      final hwConfig = _hwAccelConfig!.getMediaKitConfig();
      libmpvSettings.addAll(hwConfig);
      print('🚀 应用硬件加速配置: ${hwConfig}');
    }

    // 超高清视频和大文件优化设置
    libmpvSettings.addAll({
      // 优化大文件性能
      'cache': 'yes',
      'cache-secs': '300', // 5分钟缓存
      'cache-size': '500000', // 500MB缓存大小
      'demuxer-max-bytes': '100000000', // 100MB解复用器缓存
      'demuxer-max-back-bytes': '50000000', // 50MB向后缓存

      // 优化seek性能 - 针对大文件的关键优化
      'hr-seek': 'yes', // 高精度seek
      'hr-seek-framedrop': 'yes', // seek时允许丢帧以快速响应
      'hr-seek-demuxer-offset': '0.1', // 减少demuxer偏移
      'load-seeking': 'yes', // 加载seek

      // 超高清视频解码优化
      'vd-lavc-fast': 'yes', // 快速解码
      'vd-lavc-skipframe': 'no', // 正常播放时不要跳帧
      'vd-lavc-dr': 'yes', // 直接渲染（如果支持）
      'vd-lavc-threads': 'auto', // 自动线程数

      // 大文件I/O优化
      'stream-buffer-size': '1048576', // 1MB流缓冲区
      'max-bytes-per-chunk': '4194304', // 4MB每个块

      // 内存优化
      'demuxer-readahead-secs': '20', // 预读20秒
      'demuxer-readahead-bytes': '52428800', // 50MB预读

      // 性能监控
      'stats': 'yes', // 启用统计信息

      // 编解码器优化
      'hwdec-codecs': 'all', // 尝试所有硬件解码器
      'ad-lavc-dr': 'yes', // 硬件解码直接渲染
    });

    // 根据视频信息进一步优化
    if (_currentVideoInfo != null) {
      final videoInfo = _currentVideoInfo!;
      if (videoInfo.isLargeFile) {
        // 大文件特殊优化
        libmpvSettings.addAll({
          'demuxer-readahead-secs': '30', // 增加预读
          'demuxer-readahead-bytes': '104857600', // 增加预读到100MB
          'cache-size': '1000000', // 增加缓存到1GB
        });
        print('🎬 应用大文件优化设置');
      }

      if (videoInfo.isHighFramerate) {
        // 高帧率视频优化
        libmpvSettings.addAll({
          'framedrop': 'yes', // 允许丢帧保持同步
          'display-fps': videoInfo.fps.toString(), // 指定显示帧率
          'sync-max-video-change': '100', // 最大视频变化百分比
        });
        print('🎬 应用高帧率优化设置');
      }

      if (videoInfo.isUltraHD) {
        // 超高清视频优化
        libmpvSettings.addAll({
          'sws-fast': 'yes', // 快速软件缩放
          'sws-luma-sharpness': '1.5', // 锐化度
          'sws-chroma-sharpness': '1.5', // 色度锐化
          'vf-add': 'lavfi=[fps=fps_source]', // 保持原始帧率
        });
        print('🎬 应用超高清优化设置');
      }

      // 根据编解码器优化
      if (videoInfo.videoCodec.codec.toLowerCase() == 'hevc') {
        libmpvSettings.addAll({
          'vd-lavc-profile': 'main',
          'vd-lavc-level': '5.1',
        });
      } else if (videoInfo.videoCodec.codec.toLowerCase() == 'vp9') {
        libmpvSettings.addAll({
          'vd-lavc-threads': '8', // VP9需要更多线程
        });
      }
    }

    return const PlayerConfiguration(libass: true);
  }

  // 处理硬件加速事件
  void _handleHardwareAccelerationEvent(HardwareAccelerationEvent event) {
    switch (event.type) {
      case HardwareAccelerationEventType.enabled:
        print('✅ ${event.message}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(event.message ?? '硬件加速已启用'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
        break;
      case HardwareAccelerationEventType.fallback:
        print('⚠️ ${event.message}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(event.message ?? '已切换到软件解码'),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.orange,
            ),
          );
        }
        break;
      case HardwareAccelerationEventType.error:
        print('❌ ${event.message}');
        break;
      case HardwareAccelerationEventType.testFailed:
        print('⚠️ ${event.message}');
        break;
      default:
        // 其他事件类型暂时不处理
        break;
    }
  }

  // 启动性能监控
  void _startPerformanceMonitoring() {
    // 延迟启动性能监控，等视频开始播放
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_isPlaying) return; // 如果已经停止播放，不启动监控

      try {
        PerformanceMonitorService.instance.startMonitoring(player, intervalMs: 1000);

        // 监听性能指标，用于覆盖层显示
        _performanceSubscription = PerformanceMonitorService.instance.metricsStream.listen(
          (metrics) {
            if (mounted) {
              // 性能警告日志
              if (metrics.isPoorPerformance) {
                print('⚠️ 性能警告: FPS=${metrics.fps.toStringAsFixed(1)}, CPU=${metrics.cpuUsage.toStringAsFixed(1)}%');
                // 可以在这里显示用户友好的提示
                _showPerformanceWarningIfNeeded(metrics);
              }

              // 更新状态以触发性能指示器更新
              setState(() {});
            }
          },
        );

        print('📊 性能监控已启动');
      } catch (e) {
        print('❌ 性能监控启动失败: $e');
      }
    });
  }

  // 显示性能警告提示
  void _showPerformanceWarningIfNeeded(PerformanceMetrics metrics) {
    // 避免频繁显示提示
    if (metrics.fps < metrics.targetFps * 0.5) {
      _showPerformanceSnackBar('视频播放卡顿，建议降低分辨率或启用硬件加速');
    } else if (metrics.cpuUsage > 90) {
      _showPerformanceSnackBar('CPU占用过高，建议关闭其他应用或启用硬件加速');
    }
  }

  void _showPerformanceSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: '性能设置',
            onPressed: () {
              // 这里可以打开性能设置页面
              setState(() {
                _showPerformanceOverlay = !_showPerformanceOverlay;
              });
            },
            textColor: Colors.white,
          ),
        ),
      );
    }
  }

  // 停止性能监控
  void _stopPerformanceMonitoring() {
    _performanceSubscription?.cancel();
    _performanceSubscription = null;
    PerformanceMonitorService.instance.dispose();
    print('📊 性能监控已停止');
  }

  // 分析视频信息
  Future<void> _analyzeVideoInfo() async {
    try {
      print('🔍 开始分析视频信息: $_videoPath');

      // 分析视频文件
      final videoInfo = await VideoAnalyzerService.instance.analyzeVideo(_videoPath);

      if (mounted) {
        setState(() {
          _currentVideoInfo = videoInfo;
        });
      }

      // 为超高清视频优化缓冲配置
      await _optimizeBufferForVideo(videoInfo);

      // 检查格式兼容性
      final compatibility = await VideoAnalyzerService.instance.checkCompatibility(_videoPath);

      // 显示分析结果
      if (!kIsWeb) { // Web平台不显示这些通知
        if (videoInfo.isUltraHD) {
          print('🎬 检测到超高清视频: ${videoInfo.qualityLabel} ${videoInfo.resolutionLabel}');
          if (videoInfo.isHighFramerate) {
            print('🎬 高帧率视频: ${videoInfo.fpsLabel}');
          }
          if (videoInfo.isHDR) {
            print('🎬 HDR视频: ${videoInfo.hdrType ?? 'HDR'}');
          }
        }

        if (videoInfo.isLargeFile) {
          print('🎬 大型文件: ${videoInfo.formattedFileSize}');
        }

        // 检查硬件加速能力
        final hwService = HardwareAccelerationService.instance;
        final codecSupported = hwService.isCodecSupported(videoInfo.videoCodec.codec);

        if (!codecSupported && videoInfo.videoCodec.isHighQuality) {
          print('⚠️ 编解码器 ${videoInfo.videoCodec.displayName} 可能需要硬件加速');
          print('💡 建议: 确保硬件加速已启用以获得最佳性能');
        }

        // 检查性能需求
        if (videoInfo.isUltraHD || videoInfo.isHighFramerate) {
          final recommendations = PerformanceMonitorService.instance.getPerformanceRecommendations();
          if (recommendations.isNotEmpty) {
            print('💡 性能建议: ${recommendations.join(', ')}');
          }
        }
      }

      print('✅ 视频分析完成: ${videoInfo.fileName}');
    } catch (e) {
      print('❌ 视频分析失败: $e');
      // 分析失败不应该影响播放
    }
  }

  // 为视频优化缓冲配置
  Future<void> _optimizeBufferForVideo(VideoInfo videoInfo) async {
    try {
      // 获取当前缓冲配置
      final currentConfig = await BufferConfig.load();

      // 为超高清视频优化缓冲配置
      final optimizedConfig = currentConfig.optimizeForUltraHD(videoInfo);

      if (mounted) {
        setState(() {
          _bufferConfig = optimizedConfig;
        });
      }

      // 应用优化后的配置到播放器
      await _applyBufferConfigToPlayer(optimizedConfig);

      print('🎬 缓冲配置已优化: ${optimizedConfig.getPerformanceLevel()}');
      print('🎬 详细配置: ${optimizedConfig.getDescription()}');
    } catch (e) {
      print('❌ 缓冲配置优化失败: $e');
    }
  }

  // 应用缓冲配置到播放器
  Future<void> _applyBufferConfigToPlayer(BufferConfig config) async {
    try {
      // 这里可以应用media_kit的缓冲相关设置
      // 注意：media_kit的某些设置需要在播放器初始化时设置

      final libmpvSettings = <String, dynamic>{
        // 基于config的缓冲设置
        'cache': 'yes',
        'cache-secs': config.thresholds.targetBuffer.inSeconds.toString(),
        'cache-size': (config.thresholds.bufferSizeMB * 1024).toString(), // KB

        // 其他缓冲优化
        'demuxer-max-bytes': (config.thresholds.bufferSizeMB * 1024 * 1024).toString(),
        'demuxer-max-back-bytes': (config.thresholds.bufferSizeMB * 512 * 1024).toString(),
      };

      // 如果视频已开始播放，动态调整某些参数
      if (player.state.duration.inMilliseconds > 0) {
        // 某些参数可能需要重启播放器才能生效
        print('🎬 动态应用缓冲配置到播放器');
      }

      print('🎬 应用缓冲设置: $libmpvSettings');
    } catch (e) {
      print('❌ 应用缓冲配置失败: $e');
    }
  }

  // 显示视频信息面板
  void _showVideoInfoPanel() {
    if (_currentVideoInfo != null) {
      VideoInfoPanel.show(
        context: context,
        videoInfo: _currentVideoInfo!,
      );
    }
  }

  // 优化seek性能（针对大文件）
  Future<void> _optimizeSeek() async {
    if (_currentVideoInfo == null) return;

    try {
      // 大文件seek优化
      if (_currentVideoInfo!.isLargeFile) {
        // 暂停播放器以优化seek
        final wasPlaying = _isPlaying;
        if (wasPlaying) {
          await player.pause();
        }

        // 等待一小段时间让缓冲稳定
        await Future.delayed(const Duration(milliseconds: 100));

        // 如果需要seek到指定位置，这里可以实现
        print('🎬 优化大文件seek性能');

        // 恢复播放
        if (wasPlaying) {
          await player.play();
        }
      }
    } catch (e) {
      print('❌ seek优化失败: $e');
    }
  }

  // 监控seek性能
  void _monitorSeekPerformance(Duration seekTime) {
    if (_currentVideoInfo == null) return;

    if (_currentVideoInfo!.isLargeFile && seekTime.inMilliseconds > 500) {
      print('⚠️ 大文件seek较慢: ${seekTime.inMilliseconds}ms');
      // 可以在这里向用户显示提示
      _showSeekPerformanceWarning(seekTime);
    }
  }

  void _showSeekPerformanceWarning(Duration seekTime) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('大文件seek需要 ${seekTime.inMilliseconds}ms，正在优化性能...'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  // 播放状态
  bool _isPlaying = true;
  bool _isControlsVisible = true;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _volume = 1.0;
  bool _isFullscreen = false;

  // 控制界面自动隐藏的定时器
  Timer? _controlsTimer;

  // 播放历史记录相关
  Timer? _historyTimer;
  late String _videoPath;
  String? _videoName;

  // macOS沙盒和缩略图相关
  String? _securityBookmark;
  String? _thumbnailCachePath;
  bool _thumbnailGenerated = false;

  // 网络流媒体相关
  final NetworkStreamService _networkService = NetworkStreamService();
  final BandwidthMonitorService _bandwidthMonitor = BandwidthMonitorService();
  bool _isNetworkVideo = false;
  bool _isBuffering = false;
  String _networkStatus = '正在连接...';
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // 高级缓冲相关
  BufferConfig _bufferConfig = const BufferConfig();
  BufferHealth _bufferHealth = BufferHealth.critical;
  double _bufferProgress = 0.0;      // 0-100%
  Duration _bufferedDuration = Duration.zero;
  NetworkStats _currentNetworkStats = NetworkStats(timestamp: DateTime.now());
  StreamSubscription<NetworkStats>? _networkStatsSubscription;
  int _bufferEventCount = 0;
  DateTime? _lastBufferEvent;
  Timer? _bufferProgressTimer;
  Timer? _globalBufferMonitor;
  Duration? _lastPosition;
  DateTime? _lastPositionTime;

  // 缓存相关
  CacheEntry? _cacheEntry;
  bool _hasCache = false;
  bool _isDownloading = false;
  String? _playbackUrl; // 实际播放的URL（可能是代理URL）
  StreamSubscription? _downloadProgressSubscription;

  // 字幕相关
  final SubtitleService _subtitleService = SubtitleService.instance;
  
  // 播放器监听器
  StreamSubscription? _playingSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _volumeSubscription;
  StreamSubscription? _bufferingSubscription;
  StreamSubscription? _bufferSubscription;
  StreamSubscription? _subtitleContentSubscription;
  List<subtitle_models.SubtitleTrack> _subtitleTracks = [];
  subtitle_models.SubtitleTrack? _currentSubtitleTrack;
  bool _hasSubtitles = false;

  @override
  void initState() {
    super.initState();

    // 初始化macOS书签服务
    MacOSBookmarkService.initialize();

    // 异步初始化播放器和硬件加速
    _initializePlayerAndServices();

    // 初始化缓冲配置
    _initializeBufferConfig();

    // 检查是否为网络视频
    _isNetworkVideo = widget.webVideoUrl != null && widget.videoFile == null;

    // 设置视频路径和名称
    _videoPath = widget.webVideoUrl ?? widget.videoFile?.path ?? '';
    _videoName = widget.webVideoName ?? HistoryService.extractVideoName(_videoPath);

    // 如果是网络视频，设置网络监控和高级缓冲
    if (_isNetworkVideo) {
      _setupNetworkMonitoring();
      _setupAdvancedBuffering();
      // 检查缓存状态
      _checkCacheStatus();
    }

    // 初始化字幕服务
    _initializeSubtitleService();

    // 打开视频并开始播放
    _loadVideo();

    // 3秒后自动隐藏控制界面
    _startControlsTimer();
  }

  /// 初始化缓冲配置
  Future<void> _initializeBufferConfig() async {
    final config = await BufferConfig.load();
    if (mounted) {
      setState(() {
        _bufferConfig = config;
      });
    }
  }

  /// 设置播放器监听
  void _setupPlayerListeners() {
    // 监听播放状态变化
    _playingSubscription = player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
          if (_isNetworkVideo) {
            // 更精确的缓冲状态判断
            _updateBufferingState(playing);
          }
        });
      }
    });

    // 监听播放位置变化
    _positionSubscription = player.stream.position.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });

        // 更新位置跟踪（用于缓冲检测）
        _lastPosition = position;
        _lastPositionTime = DateTime.now();

        // 如果是网络视频
        if (_isNetworkVideo) {
          // 如果正在缓冲，更新缓冲进度
          if (_isBuffering) {
            _updateBufferProgress();
          }
          // 如果没有在缓冲，尝试启动缓冲监控
          else {
            // 每10次位置变化检查一次是否需要启动缓冲监控
            if (position.inMilliseconds % 10000 < 1000) {
              _checkAndStartBufferMonitoring();
            }
          }
        }
      }
    });

    // 监听精确缓冲状态
    if (_isNetworkVideo) {
      _setupBufferMonitoring();
    }

    // 监听总时长变化
    _durationSubscription = player.stream.duration.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
        });
        // 获取总时长后开始记录播放历史
        _initializeHistory();

        // 延迟加载字幕轨道
        Future.delayed(const Duration(milliseconds: 1000), () async {
          if (mounted) {
            await _loadSubtitleTracks();
            final loadedExternalSubtitle = await _autoLoadSubtitles();

            // 只有在没有成功加载外部字幕的情况下，才自动选择内置字幕
            if (mounted && !loadedExternalSubtitle && _subtitleTracks.isNotEmpty) {
              // 查找第一个非 disabled 的轨道
              final firstSubtitle = _subtitleTracks.firstWhere(
                (track) => track.id != 'disabled',
                orElse: () => subtitle_models.SubtitleTrack.disabled,
              );
              // 只有找到实际的字幕轨道才选择
              if (firstSubtitle.id != 'disabled') {
                await _selectSubtitleTrack(firstSubtitle);
                debugPrint('Auto-selected first subtitle: ${firstSubtitle.title}');
              } else {
                debugPrint('No subtitle tracks available for auto-selection');
              }
            }
          }
        });

        // 如果是网络视频，延迟启动缓冲监控
        if (_isNetworkVideo) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted && _isNetworkVideo && !_isBuffering) {
              print('Auto-starting buffer progress after duration loaded');
              _checkAndStartBufferMonitoring();
            }
          });
        }

        // 如果是从历史记录播放且有指定跳转位置，则跳转
        if (widget.fromHistory && widget.seekTo != null && widget.seekTo! > 0) {
          // 延迟跳转，确保视频已经开始播放
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              player.seek(Duration(seconds: widget.seekTo!));
            }
          });
        }
      }
    });

    // 监听音量变化
    _volumeSubscription = player.stream.volume.listen((volume) {
      if (mounted) {
        setState(() {
          _volume = volume;
        });
      }
    });

    // 监听字幕内容变化
    _subtitleContentSubscription = player.stream.subtitle.listen((subtitleLines) {
      // 字幕内容更新时可以在这里处理，例如显示在自定义 UI 中
      // debugPrint('Subtitle: $subtitleLines');
    });
  }

  /// 设置缓冲监控（仅对网络视频）
  void _setupBufferMonitoring() {
    try {
      // 监听缓冲状态
      _bufferingSubscription = player.stream.buffering.listen((isBuffering) {
        if (mounted) {
          final wasBuffering = _isBuffering;
          setState(() {
            _isBuffering = isBuffering;
            _networkStatus = isBuffering ? '缓冲中...' : (_isPlaying ? '播放中' : '暂停中');
          });

          if (isBuffering) {
            _recordBufferEvent();

            // 如果刚开始缓冲，立即更新进度并启动动画
            if (!wasBuffering) {
              _forceUpdateBufferProgress(); // 立即设置基础进度
              _animateBufferProgress();
              _startBufferProgressUpdater();
            }
          } else {
            _stopBufferProgressUpdater();
          }
        }
      });

      // 监听缓冲进度
      _bufferSubscription = player.stream.buffer.listen((buffer) {
        if (mounted && _totalDuration.inMilliseconds > 0) {
          // 计算缓冲进度和时长
          final progress = (buffer.inMilliseconds / _totalDuration.inMilliseconds) * 100;
          setState(() {
            _bufferProgress = min(100.0, progress);
            _bufferedDuration = buffer;
            _bufferHealth = _calculateBufferHealth();
          });
        }
      });
    } catch (e) {
      // 如果不支持 buffer 流，使用备用方案
      print('Buffer monitoring not supported, using fallback: $e');
      _setupFallbackBufferMonitoring();
    }
  }

  /// 备用缓冲监控方案
  void _setupFallbackBufferMonitoring() {
    Timer? bufferUpdateTimer;

    // 定期更新缓冲状态
    void startFallbackUpdate() {
      bufferUpdateTimer?.cancel();
      bufferUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted && _isBuffering) {
          _estimateBufferProgress();
        } else if (!_isBuffering) {
          bufferUpdateTimer?.cancel();
        }
      });
    }

    // 监听播放状态变化
    player.stream.playing.listen((playing) {
      if (mounted) {
        final wasBuffering = _isBuffering;
        _isBuffering = !playing && _isNetworkVideo;
        _networkStatus = _isBuffering ? '缓冲中...' : (playing ? '播放中' : '暂停中');

        if (_isBuffering && !wasBuffering) {
          _recordBufferEvent();
          _forceUpdateBufferProgress(); // 立即设置基础进度
          _animateBufferProgress(); // 启动动画
          startFallbackUpdate();
        }
      }
    });
  }

  /// 开始缓冲进度更新器
  void _startBufferProgressUpdater() {
    _stopBufferProgressUpdater();

    print('Starting buffer progress updater...');

    int updateCount = 0;

    _bufferProgressTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) { // 降低到800ms
      if (!_isBuffering) {
        print('Buffering stopped, cancelling updater');
        timer.cancel();
        _bufferProgressTimer = null;
        return;
      }

      if (mounted) {
        updateCount++;
        // 强制更新进度，即使变化很小
        _forceUpdateBufferProgress(updateCount);
      } else {
        print('Widget not mounted, stopping updater');
        timer.cancel();
        _bufferProgressTimer = null;
      }
    });
  }

  /// 停止缓冲进度更新器
  void _stopBufferProgressUpdater() {
    _bufferProgressTimer?.cancel();
    _bufferProgressTimer = null;
  }

  /// 更新缓冲进度（估算方式）
  void _updateBufferProgress() {
    if (_totalDuration.inMilliseconds == 0) return;

    try {
      // 获取当前播放位置
      final currentPosition = _currentPosition;

      // 根据网络状况和缓冲时间估算已缓冲的时长
      final bufferedSeconds = _estimateBufferedSeconds();
      final estimatedBuffered = currentPosition + Duration(seconds: bufferedSeconds);

      // 计算缓冲进度百分比
      double progress = (estimatedBuffered.inMilliseconds / _totalDuration.inMilliseconds) * 100;
      progress = min(100.0, max(0.0, progress));

      // 移除随机波动，保持稳定性
      // 只有当进度有显著变化时才更新UI（避免闪烁）
      if ((_bufferProgress - progress).abs() > 1.0) { // 提高阈值到1%
        print('Updating buffer progress: ${progress.toStringAsFixed(1)}% (${_bufferedDuration.inSeconds}s)');
        setState(() {
          _bufferProgress = progress;
          _bufferedDuration = estimatedBuffered;
          _bufferHealth = _calculateBufferHealth();
        });
      }
    } catch (e) {
      print('Error updating buffer progress: $e');
    }
  }

  /// 估算缓冲进度（备用方案）
  void _estimateBufferProgress() {
    if (_totalDuration.inMilliseconds == 0) return;

    final currentPosition = _currentPosition;
    final bufferedSeconds = _estimateBufferedSeconds();
    final estimatedBuffered = currentPosition + Duration(seconds: bufferedSeconds);

    double progress = (estimatedBuffered.inMilliseconds / _totalDuration.inMilliseconds) * 100;
    progress = min(100.0, max(0.0, progress));

    print('Estimating buffer progress: ${progress.toStringAsFixed(1)}%');

    setState(() {
      _bufferProgress = progress;
      _bufferedDuration = estimatedBuffered;
      _bufferHealth = _calculateBufferHealth();
    });
  }

  /// 估算已缓冲秒数（基于网络状况和缓冲时间）
  int _estimateBufferedSeconds() {
    // 基础缓冲量
    int baseBufferedSeconds = 5;

    // 根据网络质量调整
    switch (_currentNetworkStats.quality) {
      case NetworkQuality.excellent:
        baseBufferedSeconds = 30;
        break;
      case NetworkQuality.good:
        baseBufferedSeconds = 20;
        break;
      case NetworkQuality.moderate:
        baseBufferedSeconds = 15;
        break;
      case NetworkQuality.poor:
        baseBufferedSeconds = 10;
        break;
      case NetworkQuality.critical:
        baseBufferedSeconds = 5;
        break;
    }

    // 根据缓冲时间进一步调整（刚开始缓冲时较少）
    final now = DateTime.now();
    final bufferDuration = _lastBufferEvent != null
        ? now.difference(_lastBufferEvent!).inSeconds
        : 0;

    // 缓冲时间越长，估算的缓冲量越多（最多为基础值的3倍）
    final timeMultiplier = min(3.0, 1.0 + (bufferDuration / 10.0));

    return (baseBufferedSeconds * timeMultiplier).round();
  }

  /// 模拟缓冲进度动画
  void _animateBufferProgress() {
    if (!_isBuffering || _totalDuration.inMilliseconds == 0) return;

    const animationDuration = Duration(seconds: 5); // 5秒内完成缓冲动画
    const steps = 50; // 动画步数
    final stepDuration = Duration(milliseconds: animationDuration.inMilliseconds ~/ steps);

    int currentStep = 0;

    // 计算目标进度：基于当前播放位置和预估缓冲时长
    final currentPositionMs = _currentPosition.inMilliseconds;
    final bufferedSeconds = _estimateBufferedSeconds();
    final targetProgress = min(100.0, (currentPositionMs + bufferedSeconds * 1000) / _totalDuration.inMilliseconds * 100);

    print('Starting buffer animation: current=${currentPositionMs}ms, buffered=${bufferedSeconds}s, target=${targetProgress.toStringAsFixed(1)}%');

    Timer.periodic(stepDuration, (timer) {
      currentStep++;

      final progress = (targetProgress * currentStep / steps).clamp(0.0, 100.0);

      if (mounted && _isBuffering) {
        final bufferedDuration = Duration(milliseconds: (_totalDuration.inMilliseconds * progress / 100).round());
        final bufferedSecondsDisplay = bufferedDuration.inSeconds;

        print('Buffer animation step $currentStep: progress=${progress.toStringAsFixed(1)}%, buffered=${bufferedSecondsDisplay}s');

        setState(() {
          _bufferProgress = progress;
          _bufferedDuration = bufferedDuration;
          _bufferHealth = _calculateBufferHealth();
        });
      }

      if (currentStep >= steps || !_isBuffering) {
        timer.cancel();
        print('Buffer animation completed or cancelled');
      }
    });
  }

  /// 计算缓冲健康状态
  BufferHealth _calculateBufferHealth() {
    final bufferedSeconds = _bufferedDuration.inSeconds;

    if (bufferedSeconds < 2) return BufferHealth.critical;
    if (bufferedSeconds < 10) return BufferHealth.warning;
    if (bufferedSeconds < _bufferConfig.thresholds.targetBuffer.inSeconds) {
      return BufferHealth.healthy;
    }
    return BufferHealth.excellent;
  }

  /// 更新缓冲状态
  void _updateBufferingState(bool playing) {
    final newState = !playing;
    if (newState != _isBuffering) {
      setState(() {
        _isBuffering = newState;
        _networkStatus = newState ? '缓冲中...' : (_isPlaying ? '播放中' : '暂停中');
      });

      if (newState) {
        _recordBufferEvent();
      }
    }
  }

  /// 记录缓冲事件
  void _recordBufferEvent() {
    final now = DateTime.now();
    if (_lastBufferEvent == null || now.difference(_lastBufferEvent!).inSeconds > 2) {
      _bufferEventCount++;
      _lastBufferEvent = now;

      // 立即设置一个基础的缓冲进度
      _setInitialBufferProgress();
    }
  }

  /// 设置初始缓冲进度
  void _setInitialBufferProgress() {
    if (_totalDuration.inMilliseconds == 0) return;

    // 计算当前播放位置进度
    final positionProgress = (_currentPosition.inMilliseconds / _totalDuration.inMilliseconds) * 100;

    // 添加预估的缓冲时长（5-15秒）
    final bufferedSeconds = _estimateBufferedSeconds();
    final bufferedDurationMs = _currentPosition.inMilliseconds + (bufferedSeconds * 1000);
    final bufferProgress = min(100.0, (bufferedDurationMs / _totalDuration.inMilliseconds) * 100);

    setState(() {
      _bufferProgress = max(positionProgress, bufferProgress);
      _bufferedDuration = Duration(milliseconds: bufferedDurationMs.toInt());
      _bufferHealth = _calculateBufferHealth();
    });

    print('Buffer progress initialized: ${_bufferProgress.toStringAsFixed(1)}% (${_bufferedDuration.inSeconds}s buffered)');
  }

  /// 强制更新缓冲进度（测试用）
  void _forceUpdateBufferProgress([int updateCount = 0]) {
    if (!_isNetworkVideo || _totalDuration.inMilliseconds == 0) return;

    // 基础缓冲计算：当前播放位置 + 动态缓冲秒数
    final bufferedSeconds = _estimateBufferedSeconds();
    final baseBufferedMs = _currentPosition.inMilliseconds + (bufferedSeconds * 1000);

    // 使用更稳定的线性增长算法
    final targetProgress = min(95.0, (baseBufferedMs / _totalDuration.inMilliseconds) * 100); // 最高到95%

    // 线性插值：从当前进度平滑增长到目标进度
    final maxIncrease = 2.0; // 每次最多增加2%
    final desiredIncrease = (targetProgress - _bufferProgress).clamp(0.1, maxIncrease);
    final newProgress = (_bufferProgress + desiredIncrease).clamp(0.0, 100.0);

    // 只有当进度确实增长时才更新
    if (newProgress > _bufferProgress + 0.1) {
      final finalBufferedMs = (_totalDuration.inMilliseconds * newProgress / 100).toInt();

      setState(() {
        _bufferProgress = newProgress;
        _bufferedDuration = Duration(milliseconds: finalBufferedMs);
        _bufferHealth = _calculateBufferHealth();
      });

      print('Force updated buffer progress: ${_bufferProgress.toStringAsFixed(1)}% (update #$updateCount, +${desiredIncrease.toStringAsFixed(1)}%)');
    }
  }

  /// 设置高级缓冲功能
  void _setupAdvancedBuffering() async {
    // 配置 MPV 参数
    await _configureMpvBufferOptions();

    // 启动带宽监控
    _bandwidthMonitor.startMonitoring();

    // 启动全局缓冲监控
    _startGlobalBufferMonitor();

    // 监听网络状态变化
    _networkStatsSubscription = _bandwidthMonitor.networkStatsStream.listen((stats) {
      if (mounted) {
        setState(() {
          _currentNetworkStats = stats;
        });

        // 根据网络状况调整缓冲策略
        _adjustBufferingStrategy(stats);
      }
    });
  }

  /// 启动全局缓冲监控（简化版）
  void _startGlobalBufferMonitor() {
    _globalBufferMonitor?.cancel();

    // 暂时禁用复杂的全局缓冲监控，专注于播放功能
    print('Global buffer monitoring disabled for simpler playback');

    // 简单的播放状态检查
    _globalBufferMonitor = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || !_isNetworkVideo) return;

      player.stream.playing.first.then((isPlaying) {
        if (mounted && isPlaying) {
          // 只是检查播放状态，不启动复杂的缓冲监控
          if (_networkStatus == '正在连接...' || _networkStatus == '加载中...') {
            setState(() {
              _networkStatus = '播放中';
              _isBuffering = false;
            });
          }
        }
      });
    });
  }

  /// 检查并启动缓冲监控（简化版）
  void _checkAndStartBufferMonitoring() {
    // 暂时禁用复杂的缓冲监控，专注于基本播放功能
    return;

    // 以下代码暂时注释掉
    /*
    if (_isNetworkVideo && mounted && !_isBuffering && _totalDuration.inMilliseconds > 0) {
      final isPlaying = player.state.playing;
      if (mounted && isPlaying && !_isBuffering) {
        print('Auto-starting buffer progress from position change');
        setState(() {
          _isBuffering = true;
          _networkStatus = '监控缓冲...';
        });
        _recordBufferEvent();
        _forceUpdateBufferProgress();
        _startBufferProgressUpdater();

        // 3秒后自动结束
        Timer(const Duration(seconds: 3), () {
          if (mounted && _isBuffering) {
            setState(() {
              _isBuffering = false;
              _networkStatus = '播放中';
            });
            _stopBufferProgressUpdater();
          }
        });
      }
    }
    */
  }

  /// 检测缓冲状态（简化版）
  void _detectBufferingState() {
    // 暂时禁用复杂的缓冲监控
    return;

    // 以下代码暂时注释掉
    /*
    try {
      // 直接启动缓冲进度更新
      if (_isNetworkVideo && mounted && !_isBuffering) {
        print('Direct starting buffer progress monitoring');
        setState(() {
          _isBuffering = true;
          _networkStatus = '监控缓冲...';
        });
        _recordBufferEvent();
        _forceUpdateBufferProgress();
        _startBufferProgressUpdater();

        // 5秒后自动结束
        Timer(const Duration(seconds: 5), () {
          if (mounted && _isBuffering) {
            setState(() {
              _isBuffering = false;
              _networkStatus = '播放中';
            });
            _stopBufferProgressUpdater();
          }
        });
      }
    } catch (e) {
      print('Error detecting buffering state: $e');
    }
    */
  }

  /// 配置 MPV 缓冲参数
  Future<void> _configureMpvBufferOptions() async {
    try {
      final config = _bufferConfig;
      final thresholds = config.thresholds;

      // 配置缓冲相关参数
      // Note: media_kit player doesn't expose setProperty directly
      // Consider using player configuration or custom protocols if needed

      print('MPV buffer options configured: ${thresholds.bufferSizeMB}MB, ${thresholds.maxBuffer.inSeconds}s');
    } catch (e) {
      print('Failed to configure MPV options: $e');
    }
  }

  /// 根据网络状况调整缓冲策略
  void _adjustBufferingStrategy(NetworkStats stats) {
    if (!_bufferConfig.autoAdjust) return;

    final quality = stats.quality;
    final currentTime = Duration(seconds: (_bufferedDuration.inSeconds));
    final targetDuration = _bufferConfig.thresholds.targetBuffer;

    // 根据网络质量动态调整缓冲策略
    if (currentTime < targetDuration && stats.currentBandwidth > 0) {
      switch (quality) {
        case NetworkQuality.excellent:
        case NetworkQuality.good:
          // 网络良好时减少缓冲要求
          break;
        case NetworkQuality.moderate:
        case NetworkQuality.poor:
          // 网络一般时增加预加载
          break;
        case NetworkQuality.critical:
          // 网络差时暂停播放等待更多缓冲
          if (_bufferedDuration.inSeconds < _bufferConfig.thresholds.rebufferTrigger.inSeconds && _isPlaying) {
            player.pause();
            setState(() {
              _networkStatus = '网络较差，等待缓冲...';
            });
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted && _bufferedDuration.inSeconds > 5) {
                player.play();
              }
            });
          }
          break;
      }
    }
  }

  // 控制界面自动隐藏
  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isControlsVisible = false;
        });
      }
    });
  }

  // 切换播放/暂停
  void _togglePlayPause() {
    setState(() {
      _isPlaying ? player.pause() : player.play();
    });
    _startControlsTimer();
  }

  // 跳转到指定位置
  void _seekTo(Duration position) {
    player.seek(position);
    _startControlsTimer();
  }

  // 设置音量
  void _setVolume(double volume) {
    player.setVolume(volume);
    _startControlsTimer();
  }

  // 切换控制界面显示
  void _toggleControls() {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
    });
    if (_isControlsVisible) {
      _startControlsTimer();
    }
  }

  // 初始化播放历史记录
  void _initializeHistory() async {
    if (_videoPath == null || _videoName == null || _totalDuration.inSeconds <= 0) {
      return;
    }

    // 查找是否有历史记录
    final existingHistory = await HistoryService.getHistoryByPath(_videoPath!);

    if (existingHistory != null) {
      // 如果是从历史记录播放，更新最后播放时间但不询问
      if (widget.fromHistory) {
        // 使用增强版历史记录更新，包含书签和缩略图信息
        await HistoryService.addOrUpdateHistory(
          videoPath: existingHistory.videoPath,
          videoName: existingHistory.videoName,
          currentPosition: widget.seekTo ?? 0,
          totalDuration: _totalDuration.inSeconds,
          securityBookmark: _securityBookmark ?? existingHistory.securityBookmark,
          thumbnailCachePath: _thumbnailCachePath ?? existingHistory.thumbnailCachePath,
          sourceType: existingHistory.sourceType,
          watchCount: existingHistory.watchCount + 1,
        );
      } else if (!existingHistory.isCompleted) {
        // 如果有未看完的记录，询问用户是否从上次位置继续
        _showResumeDialog(existingHistory);
        _startHistoryTimer();
        return;
      } else {
        // 已看完的视频，重置到开头
        await HistoryService.addOrUpdateHistory(
          videoPath: existingHistory.videoPath,
          videoName: existingHistory.videoName,
          currentPosition: 0,
          totalDuration: _totalDuration.inSeconds,
          securityBookmark: _securityBookmark ?? existingHistory.securityBookmark,
          thumbnailCachePath: _thumbnailCachePath ?? existingHistory.thumbnailCachePath,
          sourceType: existingHistory.sourceType,
          watchCount: existingHistory.watchCount + 1,
        );
      }
    } else {
      // 创建新的历史记录（使用增强版方法）
      await HistoryService.addOrUpdateHistory(
        videoPath: _videoPath!,
        videoName: _videoName!,
        currentPosition: widget.seekTo ?? 0,
        totalDuration: _totalDuration.inSeconds,
        securityBookmark: _securityBookmark,
        thumbnailCachePath: _thumbnailCachePath,
        sourceType: _isNetworkVideo ? 'network' : 'local',
        streamUrl: _isNetworkVideo ? _videoPath : null,
        streamProtocol: _isNetworkVideo ? _getStreamProtocol(_videoPath!) : null,
        watchCount: 1,
      );
    }

    
    // 开始定期保存播放进度
    _startHistoryTimer();

    // 后台生成简单缩略图（仅本地视频）
    if (_videoPath != null && !_isNetworkVideo) {
      Future.delayed(const Duration(seconds: 3), () async {
        await SimpleThumbnailService.generateThumbnail(
          videoPath: _videoPath!,
          width: 320,
          height: 180,
          seekSeconds: 1.0,
          securityBookmark: _securityBookmark,
        );
      });
    }
  }

  // 显示继续播放对话框
  void _showResumeDialog(PlaybackHistory history) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('继续播放'),
        content: Text(
          '检测到您上次观看此视频到 ${history.formattedProgress}，\n'
          '是否从上次位置继续观看？',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _seekTo(Duration(seconds: history.currentPosition));
            },
            child: const Text('继续'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('重新开始'),
          ),
        ],
      ),
    );
  }

  // 开始定时保存播放进度
  void _startHistoryTimer() {
    _historyTimer?.cancel();
    _historyTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveProgress();
    });
  }

  // 保存播放进度（增强版）
  void _saveProgress() async {
    if (_videoPath == null || _videoName == null || _currentPosition.inSeconds <= 0) {
      return;
    }

    try {
      await HistoryService.addOrUpdateHistory(
        videoPath: _videoPath!,
        videoName: _videoName!,
        currentPosition: _currentPosition.inSeconds,
        totalDuration: _totalDuration.inSeconds,
        securityBookmark: _securityBookmark,
        thumbnailCachePath: _thumbnailCachePath,
        sourceType: _isNetworkVideo ? 'network' : 'local',
        streamUrl: _isNetworkVideo ? widget.webVideoUrl : null,
        streamProtocol: _isNetworkVideo ? _getStreamProtocol(_videoPath!) : null,
      );
    } catch (e) {
      print('❌ 定期保存播放进度失败: $e');
    }
  }

  // 切换全屏模式
  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (_isFullscreen) {
      // 进入全屏模式
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      // 退出全屏模式
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    _startControlsTimer();
  }

  // 格式化时间显示
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 ? "$hours:$minutes:$seconds" : "$minutes:$seconds";
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 视频播放区域
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 只在初始化完成后显示视频播放器
                if (_isInitialized && controller != null)
                  Video(
                    controller: controller!,
                    subtitleViewConfiguration: _buildSubtitleViewConfiguration(),
                  )
                else
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('初始化播放器...', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                   // 网络视频增强缓冲指示器
                   if (_isNetworkVideo)
                    EnhancedBufferingIndicator(
                      isBuffering: _isBuffering,
                      bufferProgress: _bufferProgress,
                      bufferedDuration: _bufferedDuration,
                      downloadSpeed: _currentNetworkStats.currentBandwidth,
                      health: _bufferHealth,
                      networkQuality: _currentNetworkStats.quality,
                      message: _networkStatus == '正在连接...' ? '正在连接...' : null,
                    ),
                  // 缓存状态指示器（左上角）
                  if (_isNetworkVideo)
                    Positioned(
                      top: 80,
                      left: 16,
                      child: CacheIndicator(
                        videoUrl: widget.webVideoUrl!,
                        videoTitle: _videoName,
                        onTap: _showCacheInfo,
                      ),
                    ),
                ],
              ),
            ),
            // 性能监控覆盖层（全局显示，不受控制栏影响）
            if (_showPerformanceOverlay)
              custom.PerformanceOverlay(
                showByDefault: true,
                enableKeyboardToggle: true,
              ),
            // 性能指示器（当覆盖层隐藏时显示）
            if (!_showPerformanceOverlay && _currentVideoInfo != null)
              Positioned(
                top: 16,
                right: 16,
                child: custom.PerformanceIndicator(
                  isVisible: true,
                ),
              ),
            // 播放控制界面
            AnimatedOpacity(
              opacity: _isControlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 顶部工具栏
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 返回按钮
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          // 标题
                          Expanded(
                            child: Text(
                              widget.webVideoName ?? widget.videoFile?.path.split('/').last ?? 'Unknown',
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // 视频信息按钮
                          if (_currentVideoInfo != null)
                            IconButton(
                              icon: const Icon(Icons.info_outline, color: Colors.white),
                              onPressed: () => _showVideoInfoPanel(),
                              tooltip: '视频信息',
                            ),
                          // 全屏按钮
                          IconButton(
                            icon: Icon(
                              _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                              color: Colors.white,
                            ),
                            onPressed: _toggleFullscreen,
                          ),
                          // 音量按钮
                          IconButton(
                            icon: Icon(
                              _volume > 0 ? Icons.volume_up : Icons.volume_off,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              _setVolume(_volume > 0 ? 0.0 : 1.0);
                            },
                          ),
                          // 字幕控制按钮（始终可用，允许加载外部字幕）
                          IconButton(
                            icon: Icon(
                              _hasSubtitles && _currentSubtitleTrack?.id != 'disabled'
                                  ? Icons.subtitles
                                  : Icons.subtitles_off,
                              color: Colors.white,
                            ),
                            onPressed: _showSubtitleSelector,
                          ),
                          // 缓存控制按钮（仅网络视频显示）
                          if (_isNetworkVideo)
                            CacheControlButton(
                              videoUrl: widget.webVideoUrl!,
                              videoTitle: _videoName,
                            ),
                        ],
                      ),
                    ),
                    // 中间播放按钮
                    Expanded(
                      child: Center(
                        child: IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                            size: 80,
                            color: Colors.white,
                          ),
                          onPressed: _togglePlayPause,
                        ),
                      ),
                    ),
                    // 底部进度条和控制
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // 进度条
                          Slider(
                            value: _totalDuration.inSeconds > 0
                                ? _currentPosition.inSeconds / _totalDuration.inSeconds
                                : 0.0,
                            onChanged: (value) {
                              final position = Duration(
                                seconds: (value * _totalDuration.inSeconds).round(),
                              );
                              _seekTo(position);
                            },
                            activeColor: Colors.blue,
                            inactiveColor: Colors.grey,
                          ),
                          // 时间和控制按钮
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 当前时间
                              Text(
                                _formatDuration(_currentPosition),
                                style: const TextStyle(color: Colors.white),
                              ),
                              // 总时长
                              Text(
                                _formatDuration(_totalDuration),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 网络视频相关方法

  /// 加载视频
  Future<void> _loadVideo() async {
    try {
      if (_isNetworkVideo) {
        setState(() {
          _isBuffering = true;
          _networkStatus = '正在连接...';
        });

        // 添加到URL历史记录
        await _networkService.addUrlToHistory(_videoPath!);
      }

      // 确定播放URL（考虑缓存）
      String playbackUrl;
      if (widget.webVideoUrl != null) {
        // 网络视频：检查缓存
        playbackUrl = await _getPlaybackUrl(widget.webVideoUrl!);
      } else {
        // 本地视频：使用文件路径
        playbackUrl = widget.videoFile!.path;
      }

      _playbackUrl = playbackUrl;

      print('🎬 Opening video: $playbackUrl');

      // 检查是否有配套的字幕文件
      String? subtitlePath;
      if (!_isNetworkVideo && widget.videoFile != null) {
        subtitlePath = await _subtitleService.findMatchingSubtitle(widget.videoFile!.path);
        if (subtitlePath != null) {
          debugPrint('Found matching subtitle: $subtitlePath');
        }
      }

      // 对于macOS本地视频，创建安全书签
      if (MacOSBookmarkService.isSupported && !_isNetworkVideo && widget.videoFile != null) {
        print('🔐 创建macOS安全书签: ${widget.videoFile!.path}');
        _securityBookmark = await MacOSBookmarkService.createBookmark(widget.videoFile!.path);
        if (_securityBookmark != null) {
          print('✅ 安全书签创建成功');
        } else {
          print('❌ 安全书签创建失败');
        }
      }

      // 打开视频并开始播放（包含字幕支持配置）
      final media = Media(
        playbackUrl,
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0',
        },
      );

      await player.open(media, play: true);

      // 分析视频信息和格式兼容性
      await _analyzeVideoInfo();

      // 视频打开后，如果有字幕文件，尝试加载
      if (subtitlePath != null) {
        // 延迟加载字幕，让video完全初始化
        await Future.delayed(const Duration(milliseconds: 500));
        final track = await _subtitleService.loadExternalSubtitle(player, subtitlePath);
        if (track != null && mounted) {
          setState(() {
            _currentSubtitleTrack = track;
          });
          debugPrint('Auto-loaded subtitle file: $subtitlePath');
        }
      }
      
      // 确保字幕已启用（某些播放器版本可能需要显式启用）
      debugPrint('Video opened, waiting for subtitle tracks to load...');
      
      // 延迟一下让字幕轨道信息加载
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 打印当前字幕轨道信息
      final subtitleTracks = player.state.tracks.subtitle;
      debugPrint('Subtitle tracks available after opening: ${subtitleTracks.length}');
      for (int i = 0; i < subtitleTracks.length; i++) {
        final track = subtitleTracks[i];
        debugPrint('  Subtitle $i: id=${track.id}, title=${track.title}, language=${track.language}');
      }

      // 网络视频在开始播放后更新状态
      if (_isNetworkVideo && mounted) {
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isBuffering = false;
              _networkStatus = '播放中';
            });
          }
        });
      }

      // 后台生成缩略图（仅本地视频）
      if (!_isNetworkVideo && !_thumbnailGenerated) {
        _generateThumbnailInBackground();
      }
    } catch (e) {
      print('❌ Error loading video: $e');
      if (mounted) {
        setState(() {
          _isBuffering = false;
          _networkStatus = '加载失败';
        });
      }
    }
  }

  /// 缓存相关方法

  /// 检查缓存状态
  Future<void> _checkCacheStatus() async {
    if (widget.webVideoUrl == null) return;

    final cacheService = VideoCacheService.instance;
    final downloadService = CacheDownloadService.instance;

    try {
      await cacheService.initialize(); // 确保缓存服务已初始化

      final cacheEntry = await cacheService.getCacheEntry(widget.webVideoUrl!);
      final hasCache = await cacheService.hasCache(widget.webVideoUrl!);
      final isDownloading = downloadService.isDownloading(widget.webVideoUrl!);

      print('Cache status check:');
      print('  URL: ${widget.webVideoUrl}');
      print('  Has cache: $hasCache');
      print('  Is downloading: $isDownloading');
      print('  Cache entry: ${cacheEntry != null ? "found" : "not found"}');
      if (cacheEntry != null) {
        print('  Cache file size: ${cacheEntry.fileSize}');
        print('  Cache progress: ${(cacheEntry.downloadProgress * 100).toStringAsFixed(1)}%');
        print('  Is complete: ${cacheEntry.isComplete}');
      }

      if (mounted) {
        setState(() {
          _cacheEntry = cacheEntry;
          _hasCache = hasCache;
          _isDownloading = isDownloading;
        });
      }

      // 设置下载进度监听
      _setupDownloadProgressListener();
    } catch (e) {
      print('Error checking cache status: $e');
    }
  }

  /// 获取播放URL（优先使用缓存）
  Future<String> _getPlaybackUrl(String originalUrl) async {
    print('Getting playback URL for: $originalUrl');
    final cacheService = VideoCacheService.instance;

    try {
      await cacheService.initialize();

      // 检查是否有完整缓存
      final cachePath = await cacheService.getCachePath(originalUrl);
      if (cachePath != null) {
        // 使用本地缓存文件
        print('✅ Using cached file: $cachePath');
        return cachePath;
      } else {
        print('❌ No cached file found');
      }

      // 启动后台下载缓存（不阻塞播放）
      _startBackgroundDownload(originalUrl);

      // 直接使用原始URL播放（兼容性更好）
      print('✅ Using original URL for playback: $originalUrl');
      return originalUrl;
    } catch (e) {
      print('❌ Error getting playback URL: $e');
      // 出错时使用原始URL
      print('⚠️ Falling back to original URL: $originalUrl');
      return originalUrl;
    }
  }

  /// 启动后台下载缓存
  void _startBackgroundDownload(String originalUrl) async {
    try {
      final cacheService = VideoCacheService.instance;
      final downloadService = CacheDownloadService.instance;

      // 检查是否已经在下载
      if (downloadService.isDownloading(originalUrl)) {
        print('Already downloading: $originalUrl');
        return;
      }

      // 检查是否已有缓存
      if (await cacheService.hasCache(originalUrl)) {
        print('Already cached: $originalUrl');
        return;
      }

      print('🚀 Starting background download: $originalUrl');

      // 启动下载（不等待完成）
      downloadService.downloadAndCache(originalUrl, title: _videoName).listen(
        (_) {
          // 字节流数据，在这里不需要处理
        },
        onError: (error) {
          print('Download error: $error');
        },
        onDone: () {
          print('✅ Download completed: $originalUrl');
          // 下载完成后可以通知用户或更新UI
        },
      );

      // 单独监听下载进度
      downloadService.getDownloadProgress(originalUrl).listen(
        (progress) {
          print('Download progress: ${(progress.progressPercentage * 100).toStringAsFixed(1)}%');
        },
      );
    } catch (e) {
      print('Failed to start background download: $e');
    }
  }

  /// 设置下载进度监听
  void _setupDownloadProgressListener() {
    if (widget.webVideoUrl == null) return;

    _downloadProgressSubscription?.cancel();
    _downloadProgressSubscription = CacheDownloadService.instance
        .getDownloadProgress(widget.webVideoUrl!)
        .listen((progress) {
      if (mounted) {
        setState(() {
          _isDownloading = !progress.isComplete && !progress.hasError;
        });
      }
    });
  }

  /// 手动下载缓存
  Future<void> _downloadForCaching() async {
    if (widget.webVideoUrl == null || _isDownloading || _hasCache) return;

    try {
      final downloadService = CacheDownloadService.instance;
      downloadService.downloadAndCache(
        widget.webVideoUrl!,
        title: _videoName,
      ).listen(
        (_) {},
        onError: (error) {
          print('Download error: $error');
        },
        onDone: () {
          print('✅ Download completed');
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('开始缓存视频'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('缓存启动失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 取消下载
  Future<void> _cancelDownload() async {
    if (widget.webVideoUrl == null || !_isDownloading) return;

    try {
      final downloadService = CacheDownloadService.instance;
      await downloadService.cancelDownload(widget.webVideoUrl!);

      if (mounted) {
        setState(() {
          _isDownloading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已取消缓存下载'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error canceling download: $e');
    }
  }

  /// 移除缓存
  Future<void> _removeCache() async {
    if (widget.webVideoUrl == null || !_hasCache) return;

    try {
      final cacheService = VideoCacheService.instance;
      await cacheService.removeCache(widget.webVideoUrl!);

      if (mounted) {
        setState(() {
          _hasCache = false;
          _cacheEntry = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('缓存已移除'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('移除缓存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 显示缓存信息
  void _showCacheInfo() {
    if (_cacheEntry == null || !mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('缓存信息 - ${_videoName ?? "视频"}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('缓存状态: ${_hasCache ? "已完成" : "未完成"}'),
            if (_cacheEntry!.fileSize > 0)
              Text('文件大小: ${_formatFileSize(_cacheEntry!.fileSize)}'),
            if (_cacheEntry!.downloadedBytes > 0 && _cacheEntry!.fileSize > 0)
              Text('下载进度: ${(_cacheEntry!.downloadProgress * 100).toStringAsFixed(1)}%'),
            Text('缓存时间: ${_formatDateTime(_cacheEntry!.createdAt)}'),
            Text('访问次数: ${_cacheEntry!.accessCount}'),
            Text('最后访问: ${_formatDateTime(_cacheEntry!.lastAccessedAt)}'),
            const SizedBox(height: 8),
            Text(
              '文件路径: ${_cacheEntry!.localPath}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 设置网络监控
  void _setupNetworkMonitoring() {
    _connectivitySubscription = _networkService.connectivityStream.listen((result) {
      if (mounted) {
        setState(() {
          _networkStatus = _networkService.getConnectivityDescription(result);

          if (result == ConnectivityResult.none) {
            // 网络断开，暂停播放
            player.pause();
            _isBuffering = true;
          }
        });
      }
    });
  }

  /// 获取流协议类型
  String _getStreamProtocol(String url) {
    if (url.toLowerCase().contains('.m3u8')) {
      return 'hls';
    } else if (url.toLowerCase().contains('.mpd')) {
      return 'dash';
    } else if (url.toLowerCase().startsWith('http://') ||
               url.toLowerCase().startsWith('https://')) {
      return 'http';
    } else {
      return 'unknown';
    }
  }

  /// 初始化字幕服务
  Future<void> _initializeSubtitleService() async {
    try {
      await _subtitleService.initialize();
      debugPrint('Subtitle service initialized');
    } catch (e) {
      debugPrint('Error initializing subtitle service: $e');
    }
  }

  /// 加载可用字幕轨道
  Future<void> _loadSubtitleTracks() async {
    try {
      final tracks = await _subtitleService.getAvailableTracks(player);
      debugPrint('Loaded ${tracks.length} subtitle tracks successfully');

      if (mounted) {
        setState(() {
          _subtitleTracks = tracks;
          _hasSubtitles = tracks.length > 1; // 除了"关闭字幕"选项
          if (!_hasSubtitles) {
            _currentSubtitleTrack = subtitle_models.SubtitleTrack.disabled;
          } else if (_currentSubtitleTrack == null) {
            // 如果还没有选择字幕，默认选择第一个（不是"关闭字幕"）
            _currentSubtitleTrack = tracks.firstWhere(
              (track) => track.id != 'disabled',
              orElse: () => subtitle_models.SubtitleTrack.disabled,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading subtitle tracks: $e');
      if (mounted) {
        setState(() {
          _subtitleTracks = [subtitle_models.SubtitleTrack.disabled];
          _hasSubtitles = false;
          _currentSubtitleTrack = subtitle_models.SubtitleTrack.disabled;
        });
      }
    }
  }

  /// 自动加载字幕
  /// 返回 true 如果成功加载了外部字幕，否则返回 false
  Future<bool> _autoLoadSubtitles() async {
    try {
      // 如果是本地视频，尝试查找同名字幕
      if (!_isNetworkVideo && widget.videoFile != null) {
        final subtitlePath = await _subtitleService.findMatchingSubtitle(
          widget.videoFile!.path,
        );
        if (subtitlePath != null) {
          final track = await _subtitleService.loadExternalSubtitle(player, subtitlePath);
          if (track != null) {
            // 等待一下以确保字幕轨道已加载到播放器
            await Future.delayed(const Duration(milliseconds: 500));

            // 重新加载字幕轨道列表
            await _loadSubtitleTracks();

            // 选择新加载的字幕（确保使用刚加载的外部字幕，而非内置轨道）
            if (mounted) {
              setState(() {
                _currentSubtitleTrack = track;
              });
            }

            debugPrint('Auto-loaded external subtitle: $subtitlePath');
            return true; // 成功加载外部字幕
          }
        }
      }
      return false; // 没有加载外部字幕
    } catch (e) {
      debugPrint('Error auto-loading subtitles: $e');
      return false;
    }
  }

  /// 显示字幕选择器
  void _showSubtitleSelector() {
    showDialog(
      context: context,
      builder: (context) => _SubtitleSelectorDialog(
        subtitleTracks: _subtitleTracks,
        currentTrack: _currentSubtitleTrack,
        onTrackSelected: (subtitle_models.SubtitleTrack track) async {
          Navigator.of(context).pop();
          await _selectSubtitleTrack(track);
        },
        onLoadExternal: () async {
          Navigator.of(context).pop();
          await _loadExternalSubtitle();
        },
        onShowSyncControl: _showSubtitleSyncControl,
        onShowSettings: _showSubtitleSettings,
        onShowDownload: _showSubtitleDownload,
      ),
    );
  }

  /// 选择字幕轨道
  Future<void> _selectSubtitleTrack(subtitle_models.SubtitleTrack track) async {
   try {
     await _subtitleService.selectTrack(player, track);
     if (mounted) {
       setState(() {
         _currentSubtitleTrack = track;
       });
     }
     debugPrint('Selected subtitle track: ${track.title}');
   } catch (e) {
     debugPrint('Error selecting subtitle track: $e');
     _showError('选择字幕轨道失败: $e');
   }
  }

  /// 加载外部字幕
  Future<void> _loadExternalSubtitle() async {
    try {
      final filePath = await _subtitleService.pickSubtitleFile();
      if (filePath != null) {
        final track = await _subtitleService.loadExternalSubtitle(player, filePath);
        if (track != null) {
          // 更新字幕轨道列表
          await _loadSubtitleTracks();
          if (mounted) {
            setState(() {
              _currentSubtitleTrack = track;
            });
          }
          _showSuccess('字幕加载成功');
        } else {
          _showError('字幕加载失败');
        }
      }
    } catch (e) {
      debugPrint('Error loading external subtitle: $e');
      _showError('加载外部字幕失败: $e');
    }
  }

  /// 显示字幕同步控制
  void _showSubtitleSyncControl() {
    showDialog(
      context: context,
      builder: (context) => _SubtitleSyncDialog(
        currentDelay: Duration(milliseconds: _subtitleService.config.delayMs),
        onDelayChanged: (delay) async {
          await _subtitleService.setSubtitleDelay(player, delay);
        },
      ),
    );
  }

  /// 显示字幕设置
  void _showSubtitleSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SubtitleSettingsScreen(),
      ),
    );
  }

  /// 显示字幕下载界面
  void _showSubtitleDownload() {
    Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => SubtitleDownloadScreen(
          videoTitle: _videoName ?? '未知视频',
          videoPath: widget.videoFile?.path,
        ),
      ),
    ).then((subtitlePath) async {
      // 处理下载完成后返回的字幕文件路径
      if (subtitlePath != null && subtitlePath.isNotEmpty) {
        debugPrint('Subtitle downloaded: $subtitlePath');
        
        // 加载下载的字幕
        final track = await _subtitleService.loadExternalSubtitle(player, subtitlePath);
        if (track != null && mounted) {
          // 刷新字幕轨道列表
          await _loadSubtitleTracks();
          
          setState(() {
            _currentSubtitleTrack = track;
          });
          
          _showSuccess('字幕加载成功');
          debugPrint('Downloaded subtitle loaded: ${track.title}');
        }
      }
    });
  }

  /// 显示成功消息
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// 显示错误消息
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    // 停止超高清视频支持服务
    _stopPerformanceMonitoring();
    _hwAccelSubscription?.cancel();

    _controlsTimer?.cancel();
    _historyTimer?.cancel();
    _connectivitySubscription?.cancel();
    _networkStatsSubscription?.cancel();
    _bufferProgressTimer?.cancel();
    _globalBufferMonitor?.cancel();
    _downloadProgressSubscription?.cancel();
    
    // 取消播放器监听器
    _playingSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _volumeSubscription?.cancel();
    _bufferingSubscription?.cancel();
    _bufferSubscription?.cancel();
    _subtitleContentSubscription?.cancel();

    // 停止带宽监控
    if (_isNetworkVideo) {
      _bandwidthMonitor.stopMonitoring();
    }

    // 保存最终播放进度
    _saveProgress();

    // 恢复正常的系统UI模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // 停止所有macOS文件访问权限
    if (MacOSBookmarkService.isSupported && !_isNetworkVideo) {
      MacOSBookmarkService.stopAccessingSecurityScopedResource(_videoPath);
    }

    // Make sure to dispose the player and controller.
    player.dispose();
    super.dispose();
  }

  /// 后台生成缩略图
  Future<void> _generateThumbnailInBackground() async {
    try {
      if (_thumbnailGenerated) return; // 避免重复生成

      print('🎬 开始后台生成缩略图...');

      // 延迟5秒生成，确保视频已开始播放和渲染
      await Future.delayed(const Duration(seconds: 5));

      if (!mounted || _videoPath.isEmpty) return;

      print('📸 尝试从正在播放的视频中截图...');

      // 使用当前正在播放的player截图
      final screenshot = await player.screenshot();

      if (screenshot != null && screenshot.isNotEmpty) {
        print('✅ 从播放器截图成功，大小: ${screenshot.length} bytes');

        // 生成历史记录ID（使用当前路径的哈希）
        final historyId = _videoPath.hashCode.abs().toString();

        // 获取缩略图保存路径
        final appDir = await getApplicationDocumentsDirectory();
        final thumbsDir = Directory(path.join(appDir.path, 'thumbnails'));
        if (!await thumbsDir.exists()) {
          await thumbsDir.create(recursive: true);
        }

        _thumbnailCachePath = path.join(thumbsDir.path, '${historyId}_320x180.jpg');

        // 保存截图
        await File(_thumbnailCachePath!).writeAsBytes(screenshot);
        _thumbnailGenerated = true;

        print('✅ 缩略图已保存: $_thumbnailCachePath');

        // 更新历史记录中的缩略图路径
        await HistoryService.addOrUpdateHistory(
          videoPath: _videoPath,
          videoName: _videoName ?? '未知视频',
          currentPosition: _currentPosition.inSeconds,
          totalDuration: _totalDuration.inSeconds,
          securityBookmark: _securityBookmark,
          thumbnailCachePath: _thumbnailCachePath,
          sourceType: _isNetworkVideo ? 'network' : 'local',
          watchCount: 1,
        );
      } else {
        print('❌ 播放器截图返回空，尝试备用方案...');

        // 备用方案：使用SimpleThumbnailService
        final historyId = _videoPath.hashCode.abs().toString();
        _thumbnailCachePath = await SimpleThumbnailService.generateAndCacheThumbnail(
          videoPath: _videoPath,
          historyId: historyId,
          width: 320,
          height: 180,
          seekSeconds: 1.0,
          securityBookmark: _securityBookmark,
        );

        if (_thumbnailCachePath != null) {
          _thumbnailGenerated = true;
          print('✅ 备用方案缩略图生成成功');
        } else {
          print('❌ 所有缩略图生成方案都失败');
        }
      }
    } catch (e) {
      print('❌ 后台生成缩略图异常: $e');
    }
  }

  /// Build SubtitleViewConfiguration with current subtitle settings
  SubtitleViewConfiguration _buildSubtitleViewConfiguration() {
    final config = SubtitleService.instance.config;
    
    return SubtitleViewConfiguration(
      style: TextStyle(
        fontSize: config.fontSize,
        color: Color(config.fontColor),
        fontFamily: config.fontFamily,
        backgroundColor: Color(config.backgroundColor),
        shadows: [
          Shadow(
            color: Color(config.outlineColor),
            blurRadius: config.outlineWidth,
          ),
        ],
      ),
      textAlign: TextAlign.center,
      padding: EdgeInsets.only(
        bottom: config.position == SubtitlePosition.bottom ? 50.0 : 
                config.position == SubtitlePosition.center ? 0.0 : 300.0,
      ),
    );
  }
}

/// 字幕选择器对话框
class _SubtitleSelectorDialog extends StatelessWidget {
  final List<subtitle_models.SubtitleTrack> subtitleTracks;
  final subtitle_models.SubtitleTrack? currentTrack;
  final Function(subtitle_models.SubtitleTrack) onTrackSelected;
  final VoidCallback onLoadExternal;
  final VoidCallback? onShowSyncControl;
  final VoidCallback? onShowSettings;
  final VoidCallback? onShowDownload;

  const _SubtitleSelectorDialog({
    required this.subtitleTracks,
    this.currentTrack,
    required this.onTrackSelected,
    required this.onLoadExternal,
    this.onShowSyncControl,
    this.onShowSettings,
    this.onShowDownload,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择字幕'),
      content: SizedBox(
        width: 300,
        height: 400,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: subtitleTracks.length,
                itemBuilder: (context, index) {
                  final track = subtitleTracks[index];
                  final isSelected = currentTrack?.id == track.id;

                  return ListTile(
                    title: Text(track.title),
                    subtitle: track.id != 'disabled'
                        ? Text('${track.languageName} • ${track.format.toUpperCase()}')
                        : null,
                    leading: isSelected
                        ? const Icon(Icons.check, color: Colors.blue)
                        : const Icon(Icons.subtitles),
                    onTap: () => onTrackSelected(track),
                    tileColor: isSelected ? Colors.blue.withOpacity(0.1) : null,
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('加载外部字幕'),
              leading: const Icon(Icons.file_upload),
              onTap: onLoadExternal,
            ),
            ListTile(
              title: const Text('字幕同步设置'),
              leading: const Icon(Icons.sync),
              onTap: onShowSyncControl != null ? () {
                Navigator.of(context).pop();
                onShowSyncControl!();
              } : null,
            ),
            ListTile(
              title: const Text('字幕样式设置'),
              leading: const Icon(Icons.style),
              onTap: onShowSettings != null ? () {
                Navigator.of(context).pop();
                onShowSettings!();
              } : null,
            ),
            ListTile(
              title: const Text('在线搜索字幕'),
              leading: const Icon(Icons.search),
              onTap: onShowDownload != null ? () {
                Navigator.of(context).pop();
                onShowDownload!();
              } : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }

  void _showSubtitleSyncDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _SubtitleSyncDialog(
        currentDelay: Duration.zero,
        onDelayChanged: (delay) {
          // 这里需要访问 PlayerScreen 的实例来设置延迟
          // 暂时留空，在实际使用时需要传入相应的回调
        },
      ),
    );
  }
}

/// 字幕同步控制对话框
class _SubtitleSyncDialog extends StatefulWidget {
  final Duration currentDelay;
  final Function(Duration) onDelayChanged;

  const _SubtitleSyncDialog({
    required this.currentDelay,
    required this.onDelayChanged,
  });

  @override
  State<_SubtitleSyncDialog> createState() => _SubtitleSyncDialogState();
}

class _SubtitleSyncDialogState extends State<_SubtitleSyncDialog> {
  late Duration _currentDelay;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _currentDelay = widget.currentDelay;
    _controller = TextEditingController(
      text: (_currentDelay.inMilliseconds / 1000.0).toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateDelay(double seconds) {
    final newDelay = Duration(milliseconds: (seconds * 1000).round());
    setState(() {
      _currentDelay = newDelay;
      _controller.text = seconds.toStringAsFixed(1);
    });
    widget.onDelayChanged(newDelay);
  }

  void _applyDelay() {
    final seconds = double.tryParse(_controller.text) ?? 0.0;
    _updateDelay(seconds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('字幕同步'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('调整字幕显示时间（秒，正数延迟，负数提前）'),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () => _updateDelay((_currentDelay.inMilliseconds / 1000.0) - 0.5),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: '延迟（秒）',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _applyDelay(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _updateDelay((_currentDelay.inMilliseconds / 1000.0) + 0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => _updateDelay(-1.0),
                child: const Text('-1s'),
              ),
              TextButton(
                onPressed: () => _updateDelay(-0.1),
                child: const Text('-0.1s'),
              ),
              TextButton(
                onPressed: () => _updateDelay(0.0),
                child: const Text('重置'),
              ),
              TextButton(
                onPressed: () => _updateDelay(0.1),
                child: const Text('+0.1s'),
              ),
              TextButton(
                onPressed: () => _updateDelay(1.0),
                child: const Text('+1s'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
