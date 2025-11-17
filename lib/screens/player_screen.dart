import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/playback_history.dart';
import '../models/buffer_config.dart';
import '../models/network_stats.dart';
import '../models/cache_entry.dart';
import '../services/history_service.dart';
import '../services/simple_thumbnail_service.dart';
import '../services/network_stream_service.dart';
import '../services/bandwidth_monitor_service.dart';
import '../services/video_cache_service.dart';
import '../services/cache_download_service.dart';
import '../services/local_proxy_server.dart';
import '../widgets/enhanced_buffering_indicator.dart';
import '../widgets/cache_indicator.dart';

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
  late final Player player = Player();
  // Create a [VideoController] instance from `media_kit_video`.
  late final VideoController controller = VideoController(player);

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

  @override
  void initState() {
    super.initState();

    // 初始化缓冲配置
    _initializeBufferConfig();

    // 设置播放器监听
    _setupPlayerListeners();

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
    player.stream.playing.listen((playing) {
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
    player.stream.position.listen((position) {
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
    player.stream.duration.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
        });
        // 获取总时长后开始记录播放历史
        _initializeHistory();

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
    player.stream.volume.listen((volume) {
      if (mounted) {
        setState(() {
          _volume = volume;
        });
      }
    });
  }

  /// 设置缓冲监控（仅对网络视频）
  void _setupBufferMonitoring() {
    try {
      // 监听缓冲状态
      player.stream.buffering.listen((isBuffering) {
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
      player.stream.buffer.listen((buffer) {
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
        final updatedHistory = existingHistory.copyWith(
          lastPlayedAt: DateTime.now(),
          currentPosition: widget.seekTo ?? 0,
          totalDuration: _totalDuration.inSeconds,
        );
        await HistoryService.saveHistory(updatedHistory);
      } else if (!existingHistory.isCompleted) {
        // 如果有未看完的记录，询问用户是否从上次位置继续
        _showResumeDialog(existingHistory);
        _startHistoryTimer();
        return;
      } else {
        // 已看完的视频，重置到开头
        final resetHistory = existingHistory.copyWith(
          lastPlayedAt: DateTime.now(),
          currentPosition: 0,
          totalDuration: _totalDuration.inSeconds,
        );
        await HistoryService.saveHistory(resetHistory);
      }
    } else {
      // 创建新的历史记录
      final newHistory = await HistoryService.createHistory(
        videoPath: _videoPath!,
        videoName: _videoName!,
        currentPosition: widget.seekTo ?? 0,
        totalDuration: _totalDuration.inSeconds,
        sourceType: _isNetworkVideo ? 'network' : 'local',
        streamUrl: _isNetworkVideo ? _videoPath : null,
        streamProtocol: _isNetworkVideo ? _getStreamProtocol(_videoPath!) : null,
      );
      await HistoryService.saveHistory(newHistory);
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

  // 保存播放进度
  void _saveProgress() async {
    if (_videoPath == null || _videoName == null || _currentPosition.inSeconds <= 0) {
      return;
    }

    await HistoryService.updateProgress(
      videoPath: _videoPath!,
      currentPosition: _currentPosition.inSeconds,
      totalDuration: _totalDuration.inSeconds,
    );
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
                  Video(
                    controller: controller,
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

      // 打开视频并开始播放
      player.open(Media(playbackUrl), play: true);

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

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _historyTimer?.cancel();
    _connectivitySubscription?.cancel();
    _networkStatsSubscription?.cancel();
    _bufferProgressTimer?.cancel();
    _globalBufferMonitor?.cancel();
    _downloadProgressSubscription?.cancel();

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

    // Make sure to dispose the player and controller.
    player.dispose();
    super.dispose();
  }
}
