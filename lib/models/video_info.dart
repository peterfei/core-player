import 'codec_info.dart';

/// 视频信息模型
/// 包含视频文件的所有技术信息和元数据
class VideoInfo {
  /// 视频文件路径
  final String videoPath;

  /// 文件名（含扩展名）
  final String fileName;

  /// 视频时长
  final Duration duration;

  /// 视频宽度（像素）
  final int width;

  /// 视频高度（像素）
  final int height;

  /// 帧率
  final double fps;

  /// 视频码率（bps）
  final int bitrate;

  /// 文件大小（字节）
  final int fileSize;

  /// 容器格式（mkv, mp4, avi等）
  final String container;

  /// 视频编解码器信息
  final CodecInfo videoCodec;

  /// 音频编解码器信息
  final List<CodecInfo> audioCodecs;

  /// 所有音频轨道
  final List<Track> audioTracks;

  /// 所有字幕轨道
  final List<Track> subtitleTracks;

  /// 色彩空间
  final String? colorSpace;

  /// 像素格式
  final String? pixelFormat;

  /// 位深度
  final int? bitDepth;

  /// 是否为HDR视频
  final bool isHDR;

  /// HDR类型（HDR10, Dolby Vision, HLG等）
  final String? hdrType;

  /// 最后播放时间
  final DateTime lastPlayedAt;

  /// 分析时间戳
  final DateTime analyzedAt;

  const VideoInfo({
    required this.videoPath,
    required this.fileName,
    required this.duration,
    required this.width,
    required this.height,
    required this.fps,
    required this.bitrate,
    required this.fileSize,
    required this.container,
    required this.videoCodec,
    required this.audioCodecs,
    required this.audioTracks,
    required this.subtitleTracks,
    this.colorSpace,
    this.pixelFormat,
    this.bitDepth,
    required this.isHDR,
    this.hdrType,
    required this.lastPlayedAt,
    required this.analyzedAt,
  });

  /// 从JSON创建VideoInfo对象
  factory VideoInfo.fromJson(Map<String, dynamic> json) {
    return VideoInfo(
      videoPath: json['videoPath'] as String,
      fileName: json['fileName'] as String,
      duration: Duration(seconds: json['duration'] as int),
      width: json['width'] as int,
      height: json['height'] as int,
      fps: (json['fps'] as num).toDouble(),
      bitrate: json['bitrate'] as int,
      fileSize: json['fileSize'] as int,
      container: json['container'] as String,
      videoCodec:
          CodecInfo.fromJson(json['videoCodec'] as Map<String, dynamic>),
      audioCodecs: (json['audioCodecs'] as List)
          .map((e) => CodecInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      audioTracks: (json['audioTracks'] as List)
          .map((e) => Track.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtitleTracks: (json['subtitleTracks'] as List)
          .map((e) => Track.fromJson(e as Map<String, dynamic>))
          .toList(),
      colorSpace: json['colorSpace'] as String?,
      pixelFormat: json['pixelFormat'] as String?,
      bitDepth: json['bitDepth'] as int?,
      isHDR: json['isHDR'] as bool,
      hdrType: json['hdrType'] as String?,
      lastPlayedAt: DateTime.parse(json['lastPlayedAt'] as String),
      analyzedAt: DateTime.parse(json['analyzedAt'] as String),
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'videoPath': videoPath,
      'fileName': fileName,
      'duration': duration.inSeconds,
      'width': width,
      'height': height,
      'fps': fps,
      'bitrate': bitrate,
      'fileSize': fileSize,
      'container': container,
      'videoCodec': videoCodec.toJson(),
      'audioCodecs': audioCodecs.map((e) => e.toJson()).toList(),
      'audioTracks': audioTracks.map((e) => e.toJson()).toList(),
      'subtitleTracks': subtitleTracks.map((e) => e.toJson()).toList(),
      'colorSpace': colorSpace,
      'pixelFormat': pixelFormat,
      'bitDepth': bitDepth,
      'isHDR': isHDR,
      'hdrType': hdrType,
      'lastPlayedAt': lastPlayedAt.toIso8601String(),
      'analyzedAt': analyzedAt.toIso8601String(),
    };
  }

  /// 获取分辨率标签
  String get resolutionLabel => '${width}x$height';

  /// 获取画质标签
  String get qualityLabel {
    if (height >= 4320) return '8K';
    if (height >= 2160) return '4K';
    if (height >= 1440) return '2K';
    if (height >= 1080) return 'Full HD';
    if (height >= 720) return 'HD';
    if (height >= 480) return 'SD';
    return 'Low';
  }

  /// 获取画质评级
  String get qualityRating {
    if (height >= 2160 && fps >= 60) return '🌟🌟🌟🌟🌟 旗舰画质';
    if (height >= 2160) return '🌟🌟🌟🌟 超高清';
    if (height >= 1440 || (height >= 1080 && fps >= 60)) return '🌟🌟🌟 高品质';
    if (height >= 1080) return '🌟🌟 高清';
    if (height >= 720) return '🌟 标清';
    return '⭐ 基础画质';
  }

  /// 获取格式化的文件大小
  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024)
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024)
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 获取格式化的时长
  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// 获取格式化的码率
  String get formattedBitrate {
    if (bitrate < 1000) return '${bitrate} bps';
    if (bitrate < 1000 * 1000)
      return '${(bitrate / 1000).toStringAsFixed(1)} kbps';
    return '${(bitrate / (1000 * 1000)).toStringAsFixed(1)} Mbps';
  }

  /// 获取帧率标签
  String get fpsLabel => '${fps.toStringAsFixed(1)} fps';

  /// 获取画质特征标签
  List<String> get qualityTags {
    final tags = <String>[];

    if (isHDR) {
      tags.add('HDR');
      if (hdrType != null) tags.add(hdrType!);
    }

    if (bitDepth != null && bitDepth! > 8) {
      tags.add('${bitDepth}-bit');
    }

    if (fps >= 60) {
      tags.add('高帧率');
    } else if (fps >= 30) {
      tags.add('标准帧率');
    }

    if (qualityLabel.contains('4K') || qualityLabel.contains('8K')) {
      tags.add('超高清');
    }

    return tags;
  }

  /// 是否为大型文件（>10GB）
  bool get isLargeFile => fileSize > 10 * 1024 * 1024 * 1024;

  /// 是否为超高清视频（≥4K）
  bool get isUltraHD => height >= 2160;

  /// 是否为高帧率视频（≥60fps）
  bool get isHighFramerate => fps >= 60;

  /// 是否为高码率视频（>20Mbps）
  bool get isHighBitrate => bitrate > 20 * 1000 * 1000;

  /// 是否为多音轨视频
  bool get hasMultipleAudioTracks => audioTracks.length > 1;

  /// 是否有字幕
  bool get hasSubtitles => subtitleTracks.isNotEmpty;

  /// 是否为网络视频
  bool get isNetworkVideo =>
      videoPath.startsWith('http://') || videoPath.startsWith('https://');

  /// 创建副本并更新最后播放时间
  VideoInfo copyWithLastPlayed() {
    return VideoInfo(
      videoPath: videoPath,
      fileName: fileName,
      duration: duration,
      width: width,
      height: height,
      fps: fps,
      bitrate: bitrate,
      fileSize: fileSize,
      container: container,
      videoCodec: videoCodec,
      audioCodecs: audioCodecs,
      audioTracks: audioTracks,
      subtitleTracks: subtitleTracks,
      colorSpace: colorSpace,
      pixelFormat: pixelFormat,
      bitDepth: bitDepth,
      isHDR: isHDR,
      hdrType: hdrType,
      lastPlayedAt: DateTime.now(),
      analyzedAt: analyzedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoInfo &&
        other.videoPath == videoPath &&
        other.fileName == fileName &&
        other.duration == duration &&
        other.width == width &&
        other.height == height &&
        other.fps == fps &&
        other.bitrate == bitrate &&
        other.fileSize == fileSize &&
        other.container == container;
  }

  @override
  int get hashCode {
    return Object.hash(
      videoPath,
      fileName,
      duration,
      width,
      height,
      fps,
      bitrate,
      fileSize,
      container,
    );
  }

  @override
  String toString() {
    return 'VideoInfo('
        'fileName: $fileName, '
        'resolution: $resolutionLabel, '
        'quality: $qualityLabel, '
        'codec: ${videoCodec.displayName}, '
        'duration: $formattedDuration, '
        'fileSize: $formattedFileSize'
        ')';
  }
}

/// 轨道信息
class Track {
  /// 轨道ID
  final String id;

  /// 轨道类型（video, audio, subtitle）
  final String type;

  /// 轨道标题
  final String title;

  /// 语言代码（如zh, en）
  final String? language;

  /// 编解码器
  final String? codec;

  /// 是否为默认轨道
  final bool isDefault;

  /// 是否为外部轨道
  final bool isExternal;

  const Track({
    required this.id,
    required this.type,
    required this.title,
    this.language,
    this.codec,
    this.isDefault = false,
    this.isExternal = false,
  });

  /// 从JSON创建Track对象
  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      language: json['language'] as String?,
      codec: json['codec'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      isExternal: json['isExternal'] as bool? ?? false,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'language': language,
      'codec': codec,
      'isDefault': isDefault,
      'isExternal': isExternal,
    };
  }

  /// 获取语言显示名称
  String get languageDisplayName {
    if (language == null || language!.isEmpty) return '未知';

    const languageMap = {
      'zh': '中文',
      'zh-cn': '简体中文',
      'zh-tw': '繁体中文',
      'en': 'English',
      'ja': '日语',
      'ko': '韩语',
      'fr': 'Français',
      'de': 'Deutsch',
      'es': 'Español',
      'ru': 'Русский',
    };

    return languageMap[language!.toLowerCase()] ?? language!.toUpperCase();
  }

  @override
  String toString() {
    return 'Track(id: $id, type: $type, title: $title, language: $language)';
  }
}

/// 格式兼容性结果
class FormatCompatibility {
  /// 是否完全兼容
  final bool isCompatible;

  /// 兼容性问题列表
  final List<String> issues;

  /// 建议的解决方案
  final List<String> suggestions;

  /// 是否需要硬件加速
  final bool requiresHardwareAcceleration;

  /// 推荐的硬件加速类型
  final String? recommendedAcceleration;

  const FormatCompatibility({
    required this.isCompatible,
    required this.issues,
    required this.suggestions,
    this.requiresHardwareAcceleration = false,
    this.recommendedAcceleration,
  });

  /// 完全兼容
  factory FormatCompatibility.fullyCompatible() {
    return const FormatCompatibility(
      isCompatible: true,
      issues: [],
      suggestions: [],
      requiresHardwareAcceleration: false,
    );
  }

  /// 部分兼容，有警告
  factory FormatCompatibility.warning({
    required List<String> issues,
    required List<String> suggestions,
    bool requiresHardwareAcceleration = false,
    String? recommendedAcceleration,
  }) {
    return FormatCompatibility(
      isCompatible: true,
      issues: issues,
      suggestions: suggestions,
      requiresHardwareAcceleration: requiresHardwareAcceleration,
      recommendedAcceleration: recommendedAcceleration,
    );
  }

  /// 不兼容
  factory FormatCompatibility.incompatible({
    required List<String> issues,
    required List<String> suggestions,
  }) {
    return FormatCompatibility(
      isCompatible: false,
      issues: issues,
      suggestions: suggestions,
      requiresHardwareAcceleration: false,
    );
  }

  @override
  String toString() {
    return 'FormatCompatibility('
        'compatible: $isCompatible, '
        'issues: $issues, '
        'suggestions: $suggestions'
        ')';
  }
}
