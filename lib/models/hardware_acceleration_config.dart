import 'dart:io';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// 硬件加速配置模型
/// 管理各平台的硬件加速设置和状态
class HardwareAccelerationConfig {
  /// 硬件加速类型
  final HwAccelType type;

  /// 是否启用硬件加速
  final bool enabled;

  /// 支持的编解码器列表
  final List<String> supportedCodecs;

  /// 平台特定设置
  final Map<String, dynamic> platformSpecificSettings;

  /// 检测时间戳
  final DateTime detectedAt;

  /// 硬件加速状态
  final HwAccelStatus status;

  /// GPU信息
  final GPUInfo? gpuInfo;

  /// 硬件加速驱动信息
  final String? driverInfo;

  /// 硬件加速版本
  final String? version;

  const HardwareAccelerationConfig({
    required this.type,
    required this.enabled,
    required this.supportedCodecs,
    required this.platformSpecificSettings,
    required this.detectedAt,
    required this.status,
    this.gpuInfo,
    this.driverInfo,
    this.version,
  });

  /// 从JSON创建HardwareAccelerationConfig对象
  factory HardwareAccelerationConfig.fromJson(Map<String, dynamic> json) {
    return HardwareAccelerationConfig(
      type: HwAccelType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => HwAccelType.none,
      ),
      enabled: json['enabled'] as bool,
      supportedCodecs:
          (json['supportedCodecs'] as List).map((e) => e as String).toList(),
      platformSpecificSettings: Map<String, dynamic>.from(
        json['platformSpecificSettings'] as Map,
      ),
      detectedAt: DateTime.parse(json['detectedAt'] as String),
      status: HwAccelStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => HwAccelStatus.unknown,
      ),
      gpuInfo: json['gpuInfo'] != null
          ? GPUInfo.fromJson(json['gpuInfo'] as Map<String, dynamic>)
          : null,
      driverInfo: json['driverInfo'] as String?,
      version: json['version'] as String?,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'enabled': enabled,
      'supportedCodecs': supportedCodecs,
      'platformSpecificSettings': platformSpecificSettings,
      'detectedAt': detectedAt.toIso8601String(),
      'status': status.name,
      'gpuInfo': gpuInfo?.toJson(),
      'driverInfo': driverInfo,
      'version': version,
    };
  }

  /// 创建禁用硬件加速的配置
  factory HardwareAccelerationConfig.disabled() {
    return HardwareAccelerationConfig(
      type: HwAccelType.none,
      enabled: false,
      supportedCodecs: [],
      platformSpecificSettings: {},
      detectedAt: DateTime.now(),
      status: HwAccelStatus.disabled,
    );
  }

  /// 创建检测失败的配置
  factory HardwareAccelerationConfig.detectionFailed(String error) {
    return HardwareAccelerationConfig(
      type: HwAccelType.none,
      enabled: false,
      supportedCodecs: [],
      platformSpecificSettings: {},
      detectedAt: DateTime.now(),
      status: HwAccelStatus.error,
      driverInfo: error,
    );
  }

  /// 获取硬件加速显示名称
  String get displayName => _getTypeDisplayName(type);

  /// 获取状态描述
  String get statusDescription => _getStatusDescription(status);

  /// 是否为硬件加速模式
  bool get isHardwareAccelerationEnabled => enabled && type != HwAccelType.none;

  /// 是否支持特定编解码器的硬件加速
  bool supportsCodec(String codec) {
    return supportedCodecs.contains(codec.toLowerCase()) ||
        supportedCodecs.contains(codec.toUpperCase());
  }

  /// 获取media_kit配置参数
  Map<String, dynamic> getMediaKitConfig() {
    if (!enabled || type == HwAccelType.none) {
      return {'hwdec': 'no'};
    }

    final config = <String, dynamic>{
      'hwdec': _getHwdecType(type),
      'hwdec-codecs': 'all',
    };

    // 添加平台特定配置
    config.addAll(platformSpecificSettings);

    return config;
  }

  /// 获取编解码器特定配置
  Map<String, dynamic> getCodecConfig(String codec) {
    if (!supportsCodec(codec)) {
      return {'hwdec': 'no'};
    }

    final config = getMediaKitConfig();

    // 特定编解码器配置
    if (codec.toLowerCase() == 'hevc' && type == HwAccelType.videotoolbox) {
      config['videotoolbox-allow-decoding-hevc'] = true;
    }

    if (codec.toLowerCase() == 'av1') {
      // AV1可能需要额外配置
      config['av1-allow-decoding'] = true;
    }

    return config;
  }

  /// 创建副本
  HardwareAccelerationConfig copyWith({
    HwAccelType? type,
    bool? enabled,
    List<String>? supportedCodecs,
    Map<String, dynamic>? platformSpecificSettings,
    DateTime? detectedAt,
    HwAccelStatus? status,
    GPUInfo? gpuInfo,
    String? driverInfo,
    String? version,
  }) {
    return HardwareAccelerationConfig(
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      supportedCodecs: supportedCodecs ?? this.supportedCodecs,
      platformSpecificSettings:
          platformSpecificSettings ?? this.platformSpecificSettings,
      detectedAt: detectedAt ?? this.detectedAt,
      status: status ?? this.status,
      gpuInfo: gpuInfo ?? this.gpuInfo,
      driverInfo: driverInfo ?? this.driverInfo,
      version: version ?? this.version,
    );
  }

  @override
  String toString() {
    return 'HardwareAccelerationConfig('
        'type: $type, '
        'enabled: $enabled, '
        'status: $status, '
        'codecs: ${supportedCodecs.length}'
        ')';
  }

  /// 获取硬件加速类型显示名称
  static String _getTypeDisplayName(HwAccelType type) {
    const typeMap = {
      HwAccelType.videotoolbox: 'VideoToolbox (macOS)',
      HwAccelType.dxva2: 'DXVA2 (Windows)',
      HwAccelType.d3d11va: 'D3D11VA (Windows)',
      HwAccelType.vaapi: 'VAAPI (Linux)',
      HwAccelType.vdpau: 'VDPAU (Linux)',
      HwAccelType.mediacodec: 'MediaCodec (Android)',
      HwAccelType.auto: '自动检测',
      HwAccelType.none: '软件解码',
    };

    return typeMap[type] ?? type.name;
  }

  /// 获取状态描述
  static String _getStatusDescription(HwAccelStatus status) {
    const statusMap = {
      HwAccelStatus.active: '已启用',
      HwAccelStatus.available: '可用',
      HwAccelStatus.unavailable: '不可用',
      HwAccelStatus.disabled: '已禁用',
      HwAccelStatus.error: '错误',
      HwAccelStatus.unknown: '未知',
    };

    return statusMap[status] ?? status.name;
  }

  /// 获取media_kit硬件解码器类型
  static String _getHwdecType(HwAccelType type) {
    const hwdecMap = {
      HwAccelType.videotoolbox: 'videotoolbox',
      HwAccelType.dxva2: 'dxva2',
      HwAccelType.d3d11va: 'd3d11va',
      HwAccelType.vaapi: 'vaapi',
      HwAccelType.vdpau: 'vdpau',
      HwAccelType.mediacodec: 'mediacodec',
      HwAccelType.auto: 'auto',
      HwAccelType.none: 'no',
    };

    return hwdecMap[type] ?? 'auto-safe';
  }

  /// 为特定平台创建推荐配置
  static HardwareAccelerationConfig forPlatform({
    TargetPlatform? platform,
    bool enabled = true,
  }) {
    final targetPlatform = platform ?? defaultTargetPlatform;
    final now = DateTime.now();

    switch (targetPlatform) {
      case TargetPlatform.macOS:
        return HardwareAccelerationConfig(
          type: HwAccelType.videotoolbox,
          enabled: enabled,
          supportedCodecs: ['h264', 'hevc', 'vp9', 'av1'],
          platformSpecificSettings: {
            'videotoolbox-allow-decoding-hevc': true,
            'videotoolbox-allow-decoding-prores': true,
          },
          detectedAt: now,
          status: enabled ? HwAccelStatus.available : HwAccelStatus.disabled,
          driverInfo: 'macOS VideoToolbox',
        );

      case TargetPlatform.windows:
        return HardwareAccelerationConfig(
          type: HwAccelType.d3d11va, // 优先使用D3D11VA
          enabled: enabled,
          supportedCodecs: ['h264', 'hevc', 'vp9'],
          platformSpecificSettings: {
            'd3d11va-zero-copy': true,
          },
          detectedAt: now,
          status: enabled ? HwAccelStatus.available : HwAccelStatus.disabled,
          driverInfo: 'Windows D3D11VA',
        );

      case TargetPlatform.linux:
        return HardwareAccelerationConfig(
          type: HwAccelType.vaapi, // 优先使用VAAPI
          enabled: enabled,
          supportedCodecs: ['h264', 'hevc', 'vp9', 'av1'],
          platformSpecificSettings: {
            'vaapi-device': '/dev/dri/renderD128',
          },
          detectedAt: now,
          status: enabled ? HwAccelStatus.available : HwAccelStatus.disabled,
          driverInfo: 'Linux VAAPI',
        );

      case TargetPlatform.android:
        return HardwareAccelerationConfig(
          type: HwAccelType.mediacodec,
          enabled: enabled,
          supportedCodecs: ['h264', 'hevc', 'vp9', 'av1'],
          platformSpecificSettings: {
            'mediacodec-decoder': 'hardware',
          },
          detectedAt: now,
          status: enabled ? HwAccelStatus.available : HwAccelStatus.disabled,
          driverInfo: 'Android MediaCodec',
        );

      case TargetPlatform.iOS:
        return HardwareAccelerationConfig(
          type: HwAccelType.videotoolbox,
          enabled: enabled,
          supportedCodecs: ['h264', 'hevc'],
          platformSpecificSettings: {
            'videotoolbox-allow-decoding-hevc': true,
          },
          detectedAt: now,
          status: enabled ? HwAccelStatus.available : HwAccelStatus.disabled,
          driverInfo: 'iOS VideoToolbox',
        );

      default:
        if (kIsWeb) {
          return HardwareAccelerationConfig(
            type: HwAccelType.none,
            enabled: false,
            supportedCodecs: [],
            platformSpecificSettings: {},
            detectedAt: now,
            status: HwAccelStatus.unavailable,
            driverInfo: 'Web平台不支持硬件加速控制',
          );
        }

        return HardwareAccelerationConfig(
          type: HwAccelType.auto,
          enabled: enabled,
          supportedCodecs: ['h264', 'hevc'],
          platformSpecificSettings: {},
          detectedAt: now,
          status: enabled ? HwAccelStatus.unknown : HwAccelStatus.disabled,
        );
    }
  }

  /// 检测平台特定的硬件加速能力
  static Future<HardwareAccelerationConfig> detectHardwareAcceleration() async {
    final targetPlatform = defaultTargetPlatform;

    try {
      if (kIsWeb) {
        return forPlatform(platform: targetPlatform, enabled: false);
      }

      switch (targetPlatform) {
        case TargetPlatform.macOS:
          return await _detectVideoToolbox();
        case TargetPlatform.windows:
          return await _detectWindowsHwAccel();
        case TargetPlatform.linux:
          return await _detectLinuxHwAccel();
        case TargetPlatform.android:
          return await _detectAndroidHwAccel();
        case TargetPlatform.iOS:
          return await _detectVideoToolbox(); // iOS也使用VideoToolbox
        default:
          return forPlatform(platform: targetPlatform);
      }
    } catch (e) {
      print('Error detecting hardware acceleration: $e');
      return HardwareAccelerationConfig.detectionFailed(e.toString());
    }
  }

  /// 检测VideoToolbox (macOS/iOS)
  static Future<HardwareAccelerationConfig> _detectVideoToolbox() async {
    // TODO: 实现VideoToolbox检测
    // 这里需要调用平台特定的代码来检测VideoToolbox支持
    return forPlatform(platform: defaultTargetPlatform);
  }

  /// 检测Windows硬件加速
  static Future<HardwareAccelerationConfig> _detectWindowsHwAccel() async {
    // TODO: 实现Windows硬件加速检测
    // 检测D3D11VA和DXVA2支持
    return forPlatform(platform: defaultTargetPlatform);
  }

  /// 检测Linux硬件加速
  static Future<HardwareAccelerationConfig> _detectLinuxHwAccel() async {
    // TODO: 实现Linux硬件加速检测
    // 检测VAAPI和VDPAU支持
    return forPlatform(platform: defaultTargetPlatform);
  }

  /// 检测Android硬件加速
  static Future<HardwareAccelerationConfig> _detectAndroidHwAccel() async {
    // TODO: 实现Android MediaCodec检测
    return forPlatform(platform: defaultTargetPlatform);
  }
}

/// 硬件加速类型
enum HwAccelType {
  /// VideoToolbox (macOS/iOS)
  videotoolbox,

  /// Direct3D Video Acceleration (Windows)
  dxva2,

  /// Direct3D 11 Video Acceleration (Windows)
  d3d11va,

  /// Video Acceleration API (Linux)
  vaapi,

  /// Video Decode and Presentation API for Unix (Linux)
  vdpau,

  /// MediaCodec (Android)
  mediacodec,

  /// 自动检测
  auto,

  /// 无硬件加速（软件解码）
  none,
}

/// 硬件加速状态
enum HwAccelStatus {
  /// 正在使用
  active,

  /// 可用但未使用
  available,

  /// 不可用
  unavailable,

  /// 用户禁用
  disabled,

  /// 错误
  error,

  /// 未知
  unknown,
}

/// GPU信息
class GPUInfo {
  /// GPU名称
  final String name;

  /// GPU厂商
  final String vendor;

  /// GPU型号
  final String model;

  /// GPU内存（MB）
  final int? memoryMB;

  /// 驱动版本
  final String? driverVersion;

  /// OpenGL/Vulkan版本
  final String? apiVersion;

  /// 支持的硬件加速特性
  final List<String> features;

  const GPUInfo({
    required this.name,
    required this.vendor,
    required this.model,
    this.memoryMB,
    this.driverVersion,
    this.apiVersion,
    this.features = const [],
  });

  /// 从JSON创建GPUInfo对象
  factory GPUInfo.fromJson(Map<String, dynamic> json) {
    return GPUInfo(
      name: json['name'] as String,
      vendor: json['vendor'] as String,
      model: json['model'] as String,
      memoryMB: json['memoryMB'] as int?,
      driverVersion: json['driverVersion'] as String?,
      apiVersion: json['apiVersion'] as String?,
      features: (json['features'] as List).map((e) => e as String).toList(),
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'vendor': vendor,
      'model': model,
      'memoryMB': memoryMB,
      'driverVersion': driverVersion,
      'apiVersion': apiVersion,
      'features': features,
    };
  }

  /// 是否为集成显卡
  bool get isIntegrated {
    final integratedKeywords = ['intel', 'amd', 'radeon', 'nvidia'];
    return !integratedKeywords.any((keyword) =>
        vendor.toLowerCase().contains(keyword) ||
        name.toLowerCase().contains(keyword));
  }

  /// 获取GPU级别
  String get performanceLevel {
    if (memoryMB != null) {
      if (memoryMB! >= 8192) return '高端';
      if (memoryMB! >= 4096) return '中高端';
      if (memoryMB! >= 2048) return '中端';
      if (memoryMB! >= 1024) return '入门';
      return '低端';
    }

    // 根据厂商和型号判断
    if (vendor.toLowerCase().contains('nvidia')) {
      if (name.toLowerCase().contains('rtx 40') ||
          name.toLowerCase().contains('rtx 30')) {
        return '高端';
      }
      if (name.toLowerCase().contains('gtx 16') ||
          name.toLowerCase().contains('gtx 10')) {
        return '中端';
      }
    }

    if (vendor.toLowerCase().contains('amd')) {
      if (name.toLowerCase().contains('rx 6') ||
          name.toLowerCase().contains('rx 7')) {
        return '高端';
      }
    }

    if (vendor.toLowerCase().contains('intel')) {
      if (name.toLowerCase().contains('iris')) {
        return '中端';
      }
      return '入门';
    }

    return '未知';
  }

  /// 是否支持4K硬件解码
  bool get supports4KDecoding {
    final fourKFeatures = [
      'h264_4k',
      'hevc_4k',
      'vp9_4k',
      'av1_4k',
    ];

    return memoryMB != null && memoryMB! >= 2048 ||
        fourKFeatures.any((feature) => features.contains(feature));
  }

  /// 是否支持8K硬件解码
  bool get supports8KDecoding {
    return memoryMB != null && memoryMB! >= 8192 ||
        features.contains('8k_decoding');
  }

  @override
  String toString() {
    return 'GPUInfo('
        'vendor: $vendor, '
        'model: $model, '
        'memory: ${memoryMB ?? 'N/A'}MB, '
        'level: $performanceLevel'
        ')';
  }
}
