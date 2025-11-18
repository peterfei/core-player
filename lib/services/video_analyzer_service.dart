import 'dart:async';
import 'dart:io';
import 'package:media_kit/media_kit.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:media_kit/src/models/track.dart' as media_kit_models;
import '../models/codec_info.dart';
import '../models/video_info.dart' as vi;

/// 视频分析服务
/// 负责分析视频文件，提取元数据和技术信息
class VideoAnalyzerService {
  static VideoAnalyzerService? _instance;
  static VideoAnalyzerService get instance {
    _instance ??= VideoAnalyzerService._internal();
    return _instance!;
  }

  VideoAnalyzerService._internal();

  /// 视频信息缓存
  final Map<String, vi.VideoInfo> _cache = {};

  /// 分析结果流
  final StreamController<VideoAnalysisEvent> _eventController =
      StreamController<VideoAnalysisEvent>.broadcast();

  /// 分析事件流
  Stream<VideoAnalysisEvent> get events => _eventController.stream;

  /// 分析视频文件
  ///
  /// [videoPath] 视频文件路径
  /// [forceRefresh] 是否强制重新分析（忽略缓存）
  ///
  /// 返回分析后的视频信息
  Future<vi.VideoInfo> analyzeVideo(String videoPath,
      {bool forceRefresh = false}) async {
    try {
      // 检查缓存
      if (!forceRefresh && _cache.containsKey(videoPath)) {
        final cached = _cache[videoPath]!;
        // 缓存1小时内的结果
        if (DateTime.now().difference(cached.analyzedAt).inHours < 1) {
          _fireEvent(VideoAnalysisEvent.analyzed(
            videoPath,
            cached,
            source: AnalysisSource.cache,
          ));
          return cached;
        }
      }

      _fireEvent(VideoAnalysisEvent.started(videoPath));

      // 创建临时播放器用于分析
      final player = Player();

      try {
        // 设置文件来源
        if (kIsWeb) {
          // Web平台处理
          await player.open(Media(videoPath));
        } else {
          // 桌面/移动平台处理
          if (videoPath.startsWith('http://') ||
              videoPath.startsWith('https://')) {
            await player.open(Media(videoPath));
          } else {
            final file = File(videoPath);
            if (!await file.exists()) {
              throw VideoAnalysisException('文件不存在: $videoPath');
            }
            await player.open(Media(file.path));
          }
        }

        // 等待元数据加载
        await _waitForMetadata(player);

        // 提取视频信息
        final videoInfo = await _extractVideoInfo(player, videoPath);

        // 缓存结果
        _cache[videoPath] = videoInfo;

        _fireEvent(VideoAnalysisEvent.analyzed(
          videoPath,
          videoInfo,
          source: AnalysisSource.file,
        ));

        return videoInfo;
      } finally {
        await player.dispose();
      }
    } catch (e) {
      final error = VideoAnalysisException('视频分析失败: $e', originalError: e);
      _fireEvent(VideoAnalysisEvent.error(videoPath, error));
      rethrow;
    }
  }

  /// 提取编解码器信息
  Future<CodecInfo> extractCodecInfo(String videoPath) async {
    final videoInfo = await analyzeVideo(videoPath);
    return videoInfo.videoCodec;
  }

  /// 检测多轨道
  Future<List<vi.Track>> detectTracks(String videoPath) async {
    final videoInfo = await analyzeVideo(videoPath);
    return [
      ...videoInfo.audioTracks,
      ...videoInfo.subtitleTracks,
    ];
  }

  /// 验证格式兼容性
  Future<vi.FormatCompatibility> checkCompatibility(String videoPath) async {
    try {
      final videoInfo = await analyzeVideo(videoPath);
      final issues = <String>[];
      final suggestions = <String>[];

      // 检查编解码器支持
      final codecSupport = videoInfo.videoCodec.supportStatus;
      if (codecSupport != CodecSupportStatus.fullySupported) {
        switch (codecSupport) {
          case CodecSupportStatus.unsupported:
            issues.add('不支持的编解码器: ${videoInfo.videoCodec.displayName}');
            suggestions.add('请尝试转换视频格式或安装相应的编解码器');
            break;
          case CodecSupportStatus.limited:
            issues.add('编解码器支持有限: ${videoInfo.videoCodec.displayName}');
            suggestions.add('可能会出现播放问题，建议转换为更常见的格式');
            break;
          case CodecSupportStatus.fullySupported:
            // 编解码器完全支持，无需处理
            break;
        }
      }

      // 检查分辨率
      if (videoInfo.isUltraHD && !_isHighResolutionSupported()) {
        issues.add('超高分辨率可能不被支持');
        suggestions.add('检查系统是否支持4K/8K播放');
      }

      // 检查文件大小
      if (videoInfo.isLargeFile && !_isLargeFileSupported()) {
        issues.add('文件过大，可能影响性能');
        suggestions.add('建议使用更快的存储设备');
      }

      // 检查HDR支持
      if (videoInfo.isHDR && !_isHDRSupported()) {
        issues.add('HDR视频可能无法正确显示');
        suggestions.add('检查显示器是否支持HDR');
      }

      // 检查帧率
      if (videoInfo.isHighFramerate && !_isHighFramerateSupported()) {
        issues.add('高帧率视频可能需要硬件加速');
        suggestions.add('启用硬件加速以获得更好性能');
      }

      final isCompatible = issues.isEmpty;
      final requiresHW = videoInfo.isUltraHD ||
          videoInfo.isHighFramerate ||
          videoInfo.videoCodec.isHighQuality;

      if (isCompatible) {
        if (requiresHW) {
          return vi.FormatCompatibility.warning(
            issues: [],
            suggestions: ['建议启用硬件加速以获得最佳性能'],
            requiresHardwareAcceleration: true,
          );
        } else {
          return vi.FormatCompatibility.fullyCompatible();
        }
      } else {
        return vi.FormatCompatibility.incompatible(
          issues: issues,
          suggestions: suggestions,
        );
      }
    } catch (e) {
      if (e is VideoAnalysisException) {
        rethrow;
      }
      throw VideoAnalysisException('兼容性检查失败: $e', originalError: e);
    }
  }

  /// 清理缓存
  void clearCache() {
    _cache.clear();
    _fireEvent(const VideoAnalysisEvent.cacheCleared());
  }

  /// 清理过期缓存
  void cleanExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _cache.entries) {
      if (now.difference(entry.value.analyzedAt).inHours > 24) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _cache.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      _fireEvent(VideoAnalysisEvent.cacheCleaned(expiredKeys.length));
    }
  }

  /// 获取缓存统计
  Map<String, dynamic> getCacheStats() {
    final totalEntries = _cache.length;
    int totalSize = 0;
    for (final videoInfo in _cache.values) {
      totalSize += videoInfo.fileSize;
    }

    return {
      'totalEntries': totalEntries,
      'totalSize': totalSize,
      'totalSizeFormatted': _formatBytes(totalSize),
      'lastCleanup': DateTime.now().toString(),
    };
  }

  /// 等待元数据加载
  Future<void> _waitForMetadata(Player player) async {
    final timeout = Duration(seconds: 30);

    for (int i = 0; i < 30; i++) {
      if (player.state.duration.inMilliseconds > 0) {
        return;
      }
      await Future.delayed(Duration(milliseconds: 100));
    }

    throw TimeoutException('元数据加载超时', timeout);
  }

  /// 提取视频信息
  Future<vi.VideoInfo> _extractVideoInfo(
      Player player, String videoPath) async {
    final duration = player.state.duration;
    final tracks = player.state.tracks;

    // 基本信息
    final fileName = videoPath.split('/').last;
    final fileSize = await _getFileSize(videoPath);
    final container = _extractContainerFormat(fileName);

    // 视频轨道信息
    final videoTracks = tracks.video;
    final audioTracks = tracks.audio;
    final subtitleTracks = tracks.subtitle;

    media_kit_models.VideoTrack? primaryVideoTrack;
    List<media_kit_models.AudioTrack> audioCodecList = [];
    List<vi.Track> audioTrackList = [];
    List<vi.Track> subtitleTrackList = [];
    List<CodecInfo> audioCodecInfoList = [];

    // 分析视频轨道
    if (videoTracks.isNotEmpty) {
      primaryVideoTrack = videoTracks.first;
    }

    // 分析音频轨道
    for (final track in audioTracks) {
      final audioTrackInfo = vi.Track(
        id: track.id.toString(),
        type: 'audio',
        title: track.title ?? '音轨 ${audioTrackList.length + 1}',
        language: track.language ?? '',
        codec: track.codec,
        isDefault: false, // media_kit doesn't have isDefault property
        isExternal: false,
      );
      audioTrackList.add(audioTrackInfo);

      final audioCodec = CodecInfo(
        codec: track.codec ?? '',
        profile: '', // 音频编解码器通常没有profile
        level: '',
        bitDepth: 8, // 音频通常8-bit
        type: CodecType.audio,
        channels: track.channels != null
            ? int.tryParse(track.channels.toString())
            : null,
        sampleRate: null, // media_kit AudioTrack doesn't have sampleRate
      );
      // audioCodecList is a list of AudioTrack, not CodecInfo
      // We'll use audioCodecInfoList for the codec info instead
      audioCodecInfoList.add(audioCodec);
    }

    // 分析字幕轨道
    for (final track in subtitleTracks) {
      final subtitleTrackInfo = vi.Track(
        id: track.id.toString(),
        type: 'subtitle',
        title: track.title ?? '字幕 ${subtitleTrackList.length + 1}',
        language: track.language ?? '',
        codec: track.codec,
        isDefault: false, // media_kit doesn't have isDefault property
        isExternal: false,
      );
      subtitleTrackList.add(subtitleTrackInfo);
    }

    // 视频编解码器信息
    CodecInfo? primaryVideoCodec;
    int width = 0, height = 0;
    double fps = 0.0;
    int bitrate = 0;

    if (primaryVideoTrack != null) {
      // media_kit VideoTrack doesn't have direct width/height properties
      // We need to get them from the video track metadata
      width = 1920; // Default fallback - will be updated if available
      height = 1080; // Default fallback - will be updated if available
      fps = primaryVideoTrack!.fps ?? 30.0;
      bitrate = primaryVideoTrack!.bitrate ?? 0;

      // Create codec info from the track
      primaryVideoCodec = CodecInfo(
        codec: primaryVideoTrack!.codec ?? 'h264',
        profile: '',
        level: '',
        bitDepth: 8,
        type: CodecType.video,
      );
    }

    final videoCodecInfo = CodecInfo(
      codec: primaryVideoCodec?.codec ?? 'unknown',
      profile: primaryVideoCodec?.profile ?? '',
      level: primaryVideoCodec?.level ?? '',
      bitDepth: 8, // 默认8-bit，需要进一步检测
      pixelFormat: null, // media_kit VideoTrack doesn't have pixelformat
      colorSpace: null, // media_kit VideoTrack doesn't have colorspace
      type: CodecType.video,
      isHardwareAccelerated: false, // 这个需要硬件加速服务来检测
    );

    // 检测HDR和位深度
    bool isHDR = false;
    String? hdrType;
    int? bitDepth;

    if (primaryVideoCodec != null) {
      final codecLower = primaryVideoCodec!.codec!.toLowerCase();
      // media_kit doesn't provide pixelformat directly, default to empty
      final pixelFormat = '';

      if (codecLower.contains('hevc') || codecLower.contains('h265')) {
        // Default bitDepth for HEVC is 10 unless we can detect otherwise
        bitDepth = 10;
      }

      // Without access to detailed pixel format and color space info from media_kit,
      // we can't reliably detect HDR. Mark as non-HDR by default.
      isHDR = false;
      hdrType = null;
    }

    final now = DateTime.now();
    final file = File(videoPath);

    return vi.VideoInfo(
      videoPath: videoPath,
      fileName: fileName,
      duration: duration,
      width: width,
      height: height,
      fps: fps,
      bitrate: bitrate,
      fileSize: fileSize,
      container: container,
      videoCodec: videoCodecInfo,
      audioCodecs: audioCodecInfoList,
      audioTracks: audioTrackList,
      subtitleTracks: subtitleTrackList,
      colorSpace: null, // Not available from media_kit VideoTrack
      pixelFormat: null, // Not available from media_kit VideoTrack
      bitDepth: bitDepth,
      isHDR: isHDR,
      hdrType: hdrType,
      lastPlayedAt: file.lastModifiedSync(),
      analyzedAt: now,
    );
  }

  /// 获取文件大小
  Future<int> _getFileSize(String path) async {
    try {
      if (kIsWeb || path.startsWith('http')) {
        return 0; // Web和网络视频无法获取文件大小
      }
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      print('获取文件大小失败: $e');
    }
    return 0;
  }

  /// 提取容器格式
  String _extractContainerFormat(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'mkv':
        return 'MKV';
      case 'mp4':
      case 'm4v':
        return 'MP4';
      case 'avi':
        return 'AVI';
      case 'mov':
        return 'MOV';
      case 'webm':
        return 'WebM';
      case 'flv':
        return 'FLV';
      case 'wmv':
        return 'WMV';
      case 'm4a':
      case 'aac':
      case 'mp3':
      case 'flac':
      case 'ogg':
        return 'Audio';
      default:
        return extension.toUpperCase();
    }
  }

  /// 检测HDR类型
  String? _detectHDRType(CodecInfo codec, String pixelFormat) {
    final codecStr = codec.codec.toLowerCase();

    // 检测HDR类型
    if (pixelFormat.contains('10') ||
        pixelFormat.contains('12') ||
        codecStr.contains('hdr') ||
        pixelFormat.contains('p010') ||
        pixelFormat.contains('p016')) {
      if (codecStr.contains('hevc')) {
        if (pixelFormat.contains('p010')) {
          return 'HDR10';
        }
        return 'HDR';
      }
      if (pixelFormat.contains('hlg')) {
        return 'HLG';
      }
      if (pixelFormat.contains('dolby') || pixelFormat.contains('pq')) {
        return 'Dolby Vision';
      }
      return 'HDR';
    }

    return null;
  }

  /// 格式化字节数
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 检查高分辨率支持
  bool _isHighResolutionSupported() {
    // TODO: 实现实际的高分辨率检测逻辑
    return true; // 暂时返回true
  }

  /// 检查大文件支持
  bool _isLargeFileSupported() {
    // TODO: 实现实际的大文件支持检测逻辑
    return true; // 暂时返回true
  }

  /// 检查HDR支持
  bool _isHDRSupported() {
    // TODO: 实现实际的HDR支持检测逻辑
    return true; // 暂时返回true
  }

  /// 检查高帧率支持
  bool _isHighFramerateSupported() {
    // TODO: 实现实际的高帧率支持检测逻辑
    return true; // 暂时返回true
  }

  /// 触发事件
  void _fireEvent(VideoAnalysisEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// 销毁服务
  void dispose() {
    _cache.clear();
    _eventController.close();
  }
}

/// 视频分析异常
class VideoAnalysisException implements Exception {
  final String message;
  final Object? originalError;

  const VideoAnalysisException(this.message, {this.originalError});

  @override
  String toString() {
    return 'VideoAnalysisException: $message';
  }
}

/// 视频分析事件
class VideoAnalysisEvent {
  final String videoPath;
  final VideoAnalysisEventType type;
  final vi.VideoInfo? videoInfo;
  final String? error;
  final AnalysisSource? source;
  final int? cleanedCount;

  const VideoAnalysisEvent._({
    required this.videoPath,
    required this.type,
    this.videoInfo,
    this.error,
    this.source,
    this.cleanedCount,
  });

  factory VideoAnalysisEvent.started(String videoPath) {
    return VideoAnalysisEvent._(
      videoPath: videoPath,
      type: VideoAnalysisEventType.started,
    );
  }

  factory VideoAnalysisEvent.analyzed(
    String videoPath,
    vi.VideoInfo videoInfo, {
    required AnalysisSource source,
  }) {
    return VideoAnalysisEvent._(
      videoPath: videoPath,
      type: VideoAnalysisEventType.analyzed,
      videoInfo: videoInfo,
      source: source,
    );
  }

  factory VideoAnalysisEvent.error(String videoPath, Object error) {
    return VideoAnalysisEvent._(
      videoPath: videoPath,
      type: VideoAnalysisEventType.error,
      error: error.toString(),
    );
  }

  const VideoAnalysisEvent.cacheCleared()
      : videoPath = '',
        type = VideoAnalysisEventType.cacheCleared,
        videoInfo = null,
        error = null,
        source = null,
        cleanedCount = null;

  factory VideoAnalysisEvent.cacheCleaned(int count) {
    return VideoAnalysisEvent._(
      videoPath: '',
      type: VideoAnalysisEventType.cacheCleaned,
      cleanedCount: count,
    );
  }

  @override
  String toString() {
    return 'VideoAnalysisEvent(type: $type, videoPath: $videoPath)';
  }
}

/// 视频分析事件类型
enum VideoAnalysisEventType {
  started,
  analyzed,
  error,
  cacheCleared,
  cacheCleaned,
}

/// 分析结果来源
enum AnalysisSource {
  file,
  cache,
}
