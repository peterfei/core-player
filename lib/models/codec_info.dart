/// 编解码器信息模型
/// 包含视频和音频编解码器的详细技术信息
class CodecInfo {
  /// 编解码器ID（如h264, hevc, vp9, av1, aac, mp3等）
  final String codec;

  /// 编码规格（如Main, High, Main 10, Baseline等）
  final String profile;

  /// 编码级别（如4.1, 5.1, 6.0等）
  final String level;

  /// 位深度（8, 10, 12等）
  final int bitDepth;

  /// 像素格式（如YUV420P, YUV422P, YUV444P, RGB等）
  final String? pixelFormat;

  /// 色彩空间（如BT.601, BT.709, BT.2020等）
  final String? colorSpace;

  /// 是否为硬件加速解码
  final bool isHardwareAccelerated;

  /// 硬件加速类型（videotoolbox, dxva2, vaapi等）
  final String? hardwareAccelerationType;

  /// 编解码器类型（video或audio）
  final CodecType type;

  /// 声道配置（仅音频编解码器）
  final int? channels;

  /// 采样率（仅音频编解码器）
  final int? sampleRate;

  /// 音频码率（仅音频编解码器）
  final int? audioBitrate;

  const CodecInfo({
    required this.codec,
    required this.profile,
    required this.level,
    required this.bitDepth,
    this.pixelFormat,
    this.colorSpace,
    this.isHardwareAccelerated = false,
    this.hardwareAccelerationType,
    required this.type,
    this.channels,
    this.sampleRate,
    this.audioBitrate,
  });

  /// 从JSON创建CodecInfo对象
  factory CodecInfo.fromJson(Map<String, dynamic> json) {
    return CodecInfo(
      codec: json['codec'] as String,
      profile: json['profile'] as String,
      level: json['level'] as String,
      bitDepth: json['bitDepth'] as int,
      pixelFormat: json['pixelFormat'] as String?,
      colorSpace: json['colorSpace'] as String?,
      isHardwareAccelerated: json['isHardwareAccelerated'] as bool? ?? false,
      hardwareAccelerationType: json['hardwareAccelerationType'] as String?,
      type: CodecType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CodecType.video,
      ),
      channels: json['channels'] as int?,
      sampleRate: json['sampleRate'] as int?,
      audioBitrate: json['audioBitrate'] as int?,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'codec': codec,
      'profile': profile,
      'level': level,
      'bitDepth': bitDepth,
      'pixelFormat': pixelFormat,
      'colorSpace': colorSpace,
      'isHardwareAccelerated': isHardwareAccelerated,
      'hardwareAccelerationType': hardwareAccelerationType,
      'type': type.name,
      'channels': channels,
      'sampleRate': sampleRate,
      'audioBitrate': audioBitrate,
    };
  }

  /// 获取编解码器显示名称
  String get displayName => _getCodecDisplayName(codec);

  /// 获取完整的编解码器描述
  String get fullDescription {
    final parts = <String>[displayName];

    if (profile.isNotEmpty) parts.add(profile);
    if (level.isNotEmpty) parts.add('Level $level');
    if (bitDepth > 8) parts.add('${bitDepth}-bit');
    if (isHardwareAccelerated && hardwareAccelerationType != null) {
      parts.add('硬件加速($hardwareAccelerationType)');
    }

    return parts.join(' ');
  }

  /// 是否为高质量编解码器
  bool get isHighQuality {
    // 高质量特征
    return bitDepth >= 10 ||
           profile.toLowerCase().contains('high') ||
           codec == 'hevc' ||
           codec == 'vp9' ||
           codec == 'av1' ||
           codec == 'prores';
  }

  /// 是否为现代编解码器（近年推出的）
  bool get isModern {
    final modernCodecs = ['hevc', 'vp9', 'av1', 'opus', 'aac'];
    return modernCodecs.contains(codec.toLowerCase());
  }

  /// 是否为专业级编解码器
  bool get isProfessional {
    final professionalCodecs = ['prores', 'dnxhr', 'cinemadng', 'lossless'];
    return professionalCodecs.contains(codec.toLowerCase()) ||
           profile.toLowerCase().contains('professional');
  }

  /// 获取视频码率等级
  String get videoBitrateTier {
    if (type != CodecType.video) return 'N/A';

    if (isHighQuality) return '高码率';
    if (isModern) return '标准码率';
    return '基础码率';
  }

  /// 获取音频码率等级
  String get audioBitrateTier {
    if (type != CodecType.audio || audioBitrate == null) return 'N/A';

    final bitrate = audioBitrate!;
    if (bitrate >= 320) return '高品质';
    if (bitrate >= 192) return '标准品质';
    if (bitrate >= 128) return '基础品质';
    return '低品质';
  }

  /// 获取声道配置描述
  String get channelDescription {
    if (type != CodecType.audio || channels == null) return 'N/A';

    switch (channels!) {
      case 1:
        return '单声道';
      case 2:
        return '立体声';
      case 4:
        return '四声道';
      case 6:
        return '5.1环绕声';
      case 8:
        return '7.1环绕声';
      default:
        return '${channels}声道';
    }
  }

  /// 获取采样率描述
  String get sampleRateDescription {
    if (type != CodecType.audio || sampleRate == null) return 'N/A';

    final rate = sampleRate!;
    if (rate >= 96000) return '${rate ~/ 1000}kHz (高保真)';
    if (rate >= 48000) return '${rate ~/ 1000}kHz (标准)';
    if (rate >= 44100) return '${rate ~/ 1000}kHz (CD品质)';
    return '${rate}Hz';
  }

  /// 获取编解码器支持状态
  CodecSupportStatus get supportStatus => _getCodecSupportStatus(codec);

  /// 获取硬件加速能力
  HardwareAccelerationCapability get hardwareCapability {
    if (!isHardwareAccelerated) return HardwareAccelerationCapability.unsupported;

    switch (hardwareAccelerationType?.toLowerCase()) {
      case 'videotoolbox':
        return HardwareAccelerationCapability.full;
      case 'd3d11va':
      case 'dxva2':
        return HardwareAccelerationCapability.full;
      case 'vaapi':
      case 'vdpau':
        return HardwareAccelerationCapability.full;
      case 'mediacodec':
        return HardwareAccelerationCapability.full;
      default:
        return HardwareAccelerationCapability.partial;
    }
  }

  /// 获取解码器性能评级
  String get decoderPerformanceRating {
    if (isHardwareAccelerated) {
      return '🚀 硬件解码（高性能）';
    } else if (isProfessional) {
      return '⚡ 软件解码（专业级）';
    } else if (isHighQuality) {
      return '✨ 软件解码（高质量）';
    } else {
      return '📽️ 软件解码（标准）';
    }
  }

  /// 获取编解码器标签
  List<String> get codecTags {
    final tags = <String>[];

    if (isHighQuality) tags.add('高质量');
    if (isModern) tags.add('现代');
    if (isProfessional) tags.add('专业级');
    if (isHardwareAccelerated) tags.add('硬件加速');
    if (bitDepth > 8) tags.add('${bitDepth}-bit');
    if (codec == 'hevc' || codec == 'h265') tags.add('H.265');
    if (codec == 'av1') tags.add('下一代');

    return tags;
  }

  /// 创建副本
  CodecInfo copyWith({
    String? codec,
    String? profile,
    String? level,
    int? bitDepth,
    String? pixelFormat,
    String? colorSpace,
    bool? isHardwareAccelerated,
    String? hardwareAccelerationType,
    CodecType? type,
    int? channels,
    int? sampleRate,
    int? audioBitrate,
  }) {
    return CodecInfo(
      codec: codec ?? this.codec,
      profile: profile ?? this.profile,
      level: level ?? this.level,
      bitDepth: bitDepth ?? this.bitDepth,
      pixelFormat: pixelFormat ?? this.pixelFormat,
      colorSpace: colorSpace ?? this.colorSpace,
      isHardwareAccelerated: isHardwareAccelerated ?? this.isHardwareAccelerated,
      hardwareAccelerationType: hardwareAccelerationType ?? this.hardwareAccelerationType,
      type: type ?? this.type,
      channels: channels ?? this.channels,
      sampleRate: sampleRate ?? this.sampleRate,
      audioBitrate: audioBitrate ?? this.audioBitrate,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CodecInfo &&
           other.codec == codec &&
           other.profile == profile &&
           other.level == level &&
           other.bitDepth == bitDepth &&
           other.type == type;
  }

  @override
  int get hashCode {
    return Object.hash(codec, profile, level, bitDepth, type);
  }

  @override
  String toString() {
    return 'CodecInfo('
        'codec: $codec, '
        'profile: $profile, '
        'level: $level, '
        'bitDepth: $bitDepth, '
        'type: $type, '
        'hw: $isHardwareAccelerated'
        ')';
  }

  /// 获取编解码器显示名称
  static String _getCodecDisplayName(String codec) {
    final codecMap = {
      // 视频编解码器
      'h264': 'H.264/AVC',
      'hevc': 'HEVC/H.265',
      'vp8': 'VP8',
      'vp9': 'VP9',
      'av1': 'AV1',
      'mpeg2video': 'MPEG-2',
      'mpeg4': 'MPEG-4',
      'prores': 'Apple ProRes',
      'dnxhr': 'Avid DNxHR',
      'cinemadng': 'Cinema DNG',
      'libx264': 'H.264 (libx264)',
      'libx265': 'H.265 (libx265)',

      // 音频编解码器
      'aac': 'AAC',
      'mp3': 'MP3',
      'ac3': 'AC3',
      'dts': 'DTS',
      'flac': 'FLAC',
      'opus': 'Opus',
      'vorbis': 'Vorbis',
      'pcm': 'PCM',
      'pcm_s16le': 'PCM 16-bit',
      'pcm_s24le': 'PCM 24-bit',
      'pcm_f32le': 'PCM 32-bit float',
    };

    return codecMap[codec.toLowerCase()] ?? codec.toUpperCase();
  }

  /// 获取编解码器支持状态
  static CodecSupportStatus _getCodecSupportStatus(String codec) {
    final supportedCodecs = [
      'h264', 'hevc', 'vp8', 'vp9', 'av1',
      'aac', 'mp3', 'ac3', 'dts', 'flac', 'opus'
    ];

    if (supportedCodecs.contains(codec.toLowerCase())) {
      return CodecSupportStatus.fullySupported;
    } else if (['mpeg2video', 'mpeg4', 'vorbis'].contains(codec.toLowerCase())) {
      return CodecSupportStatus.limited;
    } else {
      return CodecSupportStatus.unsupported;
    }
  }

  /// 从media_kit track创建CodecInfo
  static CodecInfo? fromMediaKitTrack(dynamic track, bool isHardwareAccelerated, String? hwType) {
    try {
      // 尝试解析track信息
      final type = track.type.toString().toLowerCase();
      final codecType = type.contains('video') ? CodecType.video : CodecType.audio;

      // 获取编解码器名称
      String codec = '';
      String profile = '';
      String level = '';
      int bitDepth = 8;

      // 假设track有codec属性
      if (track.codec != null) {
        codec = track.codec.toString();
      }

      // 根据编解码器推断其他信息
      if (codec.toLowerCase() == 'hevc') {
        profile = 'Main';
        if (track.profile != null) profile = track.profile.toString();
        if (track.level != null) level = track.level.toString();
        if (track.pixelformat != null && track.pixelformat.toString().contains('10')) {
          bitDepth = 10;
        }
      } else if (codec.toLowerCase() == 'h264') {
        if (track.profile != null) profile = track.profile.toString();
        if (track.level != null) level = track.level.toString();
      }

      return CodecInfo(
        codec: codec,
        profile: profile,
        level: level,
        bitDepth: bitDepth,
        type: codecType,
        isHardwareAccelerated: isHardwareAccelerated,
        hardwareAccelerationType: hwType,
      );
    } catch (e) {
      print('Error creating CodecInfo from media_kit track: $e');
      return null;
    }
  }
}

/// 编解码器类型
enum CodecType {
  video,
  audio,
}

/// 编解码器支持状态
enum CodecSupportStatus {
  /// 完全支持
  fullySupported,
  /// 有限支持（部分功能）
  limited,
  /// 不支持
  unsupported,
}

/// 硬件加速能力
enum HardwareAccelerationCapability {
  /// 完全支持硬件加速
  full,
  /// 部分支持硬件加速
  partial,
  /// 不支持硬件加速
  unsupported,
}

/// 编解码器映射表
class CodecMapper {
  /// 媒体类型映射
  static const Map<String, String> mimeTypeMap = {
    'video/x-matroska': 'MKV',
    'video/mp4': 'MP4',
    'video/avi': 'AVI',
    'video/webm': 'WebM',
    'video/quicktime': 'MOV',
    'video/x-msvideo': 'WMV',
    'audio/mp3': 'MP3',
    'audio/aac': 'AAC',
    'audio/flac': 'FLAC',
    'audio/ogg': 'OGG',
  };

  /// 获取MIME类型对应的后缀
  static String getExtensionFromMimeType(String mimeType) {
    final extensions = {
      'video/x-matroska': '.mkv',
      'video/mp4': '.mp4',
      'video/avi': '.avi',
      'video/webm': '.webm',
      'video/quicktime': '.mov',
      'video/x-msvideo': '.wmv',
      'audio/mp3': '.mp3',
      'audio/aac': '.aac',
      'audio/flac': '.flac',
      'audio/ogg': '.ogg',
    };

    return extensions[mimeType.toLowerCase()] ?? '';
  }

  /// 从文件路径推测MIME类型
  static String guessMimeTypeFromPath(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;

    final mimeTypes = {
      'mkv': 'video/x-matroska',
      'mp4': 'video/mp4',
      'avi': 'video/avi',
      'webm': 'video/webm',
      'mov': 'video/quicktime',
      'wmv': 'video/x-msvideo',
      'flv': 'video/x-flv',
      'mp3': 'audio/mp3',
      'aac': 'audio/aac',
      'flac': 'audio/flac',
      'ogg': 'audio/ogg',
      'wav': 'audio/wav',
    };

    return mimeTypes[extension] ?? 'application/octet-stream';
  }
}