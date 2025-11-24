import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:media_kit/media_kit.dart';
import '../models/hardware_acceleration_config.dart';

/// 硬件加速服务
///
/// 🔥 插件基础设施服务 - 供插件使用
///
/// 负责检测、启用和管理硬件加速。这是一个基础设施服务，供插件使用。
/// HEVC 高级解码器插件包会复用这个服务来获取硬件加速能力。
///
/// 功能：
/// - 检测平台硬件加速能力 (VideoToolbox, DXVA2, VAAPI, MediaCodec)
/// - 支持的编解码器硬件加速检测 (H.264, HEVC, VP9, AV1)
/// - 硬件加速配置和管理
/// - 事件通知机制
///
/// 插件使用示例：
/// ```dart
/// final hwService = HardwareAccelerationService.instance;
/// await hwService.initialize();
///
/// if (hwService.isHardwareAccelerationSupported) {
///   final config = await hwService.getRecommendedConfig();
///   if (config.supportedCodecs['hevc'] == true) {
///     // 启用 HEVC 硬件解码
///   }
/// }
/// ```
class HardwareAccelerationService {
  static HardwareAccelerationService? _instance;
  static HardwareAccelerationService get instance {
    _instance ??= HardwareAccelerationService._internal();
    return _instance!;
  }

  HardwareAccelerationService._internal();

  /// 当前硬件加速配置
  HardwareAccelerationConfig? _currentConfig;

  /// 配置更新流
  final StreamController<HardwareAccelerationEvent> _eventController =
      StreamController<HardwareAccelerationEvent>.broadcast();

  /// 硬件加速事件流
  Stream<HardwareAccelerationEvent> get events => _eventController.stream;

  /// 获取当前配置
  HardwareAccelerationConfig? get currentConfig => _currentConfig;

  /// 是否支持硬件加速
  bool get isHardwareAccelerationSupported {
    if (_currentConfig == null) return false;
    return _currentConfig!.status != HwAccelStatus.unavailable &&
        _currentConfig!.status != HwAccelStatus.error &&
        _currentConfig!.type != HwAccelType.none;
  }

  /// 是否已启用硬件加速
  bool get isHardwareAccelerationEnabled {
    return _currentConfig?.enabled == true &&
        _currentConfig?.type != HwAccelType.none;
  }

  /// 初始化硬件加速服务
  Future<void> initialize() async {
    if (kIsWeb) {
      _fireEvent(const HardwareAccelerationEvent.notSupported(
        'Web平台不支持硬件加速控制',
      ));
      _currentConfig = HardwareAccelerationConfig.forPlatform(enabled: false);
      return;
    }

    try {
      _fireEvent(const HardwareAccelerationEvent.detectionStarted());

      // 检测硬件加速能力
      final config = await detectHardwareAccelerationCapability();
      _currentConfig = config;

      if (config.enabled && config.status == HwAccelStatus.available) {
        _fireEvent(HardwareAccelerationEvent.detected(config));
      } else {
        _fireEvent(HardwareAccelerationEvent.notSupported(
          '硬件加速不可用: ${config.statusDescription}',
        ));
      }
    } catch (e) {
      final error = '硬件加速初始化失败: $e';
      print(error);
      _fireEvent(HardwareAccelerationEvent.error(error));
      _currentConfig = HardwareAccelerationConfig.detectionFailed(e.toString());
    }
  }

  /// 检测硬件加速能力
  Future<HardwareAccelerationConfig>
      detectHardwareAccelerationCapability() async {
    final targetPlatform = defaultTargetPlatform;

    switch (targetPlatform) {
      case TargetPlatform.macOS:
        return await _detectVideoToolbox();
      case TargetPlatform.windows:
        return await _detectWindowsHardwareAcceleration();
      case TargetPlatform.linux:
        return await _detectLinuxHardwareAcceleration();
      case TargetPlatform.android:
        return await _detectAndroidHardwareAcceleration();
      case TargetPlatform.iOS:
        return await _detectVideoToolbox();
      default:
        return HardwareAccelerationConfig.forPlatform(platform: targetPlatform);
    }
  }

  /// 获取推荐的硬件加速配置
  Future<HardwareAccelerationConfig> getRecommendedConfig() async {
    if (_currentConfig != null &&
        _currentConfig!.status != HwAccelStatus.error) {
      return _currentConfig!;
    }

    return await detectHardwareAccelerationCapability();
  }

  /// 启用硬件加速
  Future<bool> enableHardwareAcceleration({
    HwAccelType? preferredType,
    Map<String, dynamic>? customSettings,
  }) async {
    try {
      _fireEvent(HardwareAccelerationEvent.enabling());

      final config = await getRecommendedConfig();

      // 如果指定了首选类型，尝试使用
      if (preferredType != null) {
        final testConfig = config.copyWith(
          type: preferredType,
          enabled: true,
          platformSpecificSettings:
              customSettings ?? config.platformSpecificSettings,
        );

        // 测试配置是否可用
        final testResult = await _testHardwareAcceleration(testConfig);
        if (testResult) {
          _currentConfig = testConfig.copyWith(status: HwAccelStatus.active);
          _fireEvent(HardwareAccelerationEvent.enabled(_currentConfig!));
          return true;
        }
      }

      // 使用推荐的配置
      final enabledConfig = config.copyWith(
        enabled: true,
        platformSpecificSettings:
            customSettings ?? config.platformSpecificSettings,
      );

      final testResult = await _testHardwareAcceleration(enabledConfig);
      if (testResult) {
        _currentConfig = enabledConfig.copyWith(status: HwAccelStatus.active);
        _fireEvent(HardwareAccelerationEvent.enabled(_currentConfig!));
        return true;
      } else {
        _currentConfig = enabledConfig.copyWith(status: HwAccelStatus.error);
        _fireEvent(HardwareAccelerationEvent.testFailed(
          '硬件加速测试失败',
          _currentConfig!,
        ));
        return false;
      }
    } catch (e) {
      final error = '启用硬件加速失败: $e';
      print(error);
      _fireEvent(HardwareAccelerationEvent.error(error));
      return false;
    }
  }

  /// 禁用硬件加速
  Future<void> disableHardwareAcceleration() async {
    try {
      _currentConfig = _currentConfig?.copyWith(
            enabled: false,
            status: HwAccelStatus.disabled,
          ) ??
          HardwareAccelerationConfig.disabled();

      _fireEvent(HardwareAccelerationEvent.disabled());
    } catch (e) {
      final error = '禁用硬件加速失败: $e';
      print(error);
      _fireEvent(HardwareAccelerationEvent.error(error));
    }
  }

  /// 检查硬件加速状态
  Future<HwAccelStatus> getStatus() async {
    if (_currentConfig == null) {
      return HwAccelStatus.unknown;
    }

    // 测试当前配置是否仍然有效
    if (_currentConfig!.enabled) {
      final isValid = await _testHardwareAcceleration(_currentConfig!);
      if (isValid) {
        return HwAccelStatus.active;
      } else {
        _currentConfig = _currentConfig!.copyWith(status: HwAccelStatus.error);
        return HwAccelStatus.error;
      }
    }

    return _currentConfig!.status;
  }

  /// 降级到软件解码
  Future<void> fallbackToSoftwareDecoding() async {
    if (_currentConfig != null && _currentConfig!.enabled) {
      _fireEvent(const HardwareAccelerationEvent.fallingBack());
      await disableHardwareAcceleration();
      _fireEvent(HardwareAccelerationEvent.fallback('已切换到软件解码'));
    }
  }

  /// 检查特定编解码器是否支持硬件加速
  bool isCodecSupported(String codec) {
    if (_currentConfig == null || !_currentConfig!.enabled) {
      return false;
    }

    return _currentConfig!.supportsCodec(codec);
  }

  /// 获取编解码器特定配置
  Map<String, dynamic> getCodecConfig(String codec) {
    if (_currentConfig == null) {
      return {'hwdec': 'no'};
    }

    return _currentConfig!.getCodecConfig(codec);
  }

  /// 获取性能优化建议
  List<String> getPerformanceOptimizations() {
    final suggestions = <String>[];

    if (_currentConfig == null) {
      suggestions.add('硬件加速未初始化');
      return suggestions;
    }

    if (!_currentConfig!.enabled) {
      suggestions.add('建议启用硬件加速以提升性能');
    } else if (_currentConfig!.type == HwAccelType.none) {
      suggestions.add('设备不支持硬件加速');
    }

    // 根据GPU信息提供建议
    final gpuInfo = _currentConfig!.gpuInfo;
    if (gpuInfo != null) {
      if (gpuInfo.performanceLevel == '低端') {
        suggestions.add('使用较低分辨率或帧率以提升性能');
      }

      if (gpuInfo.memoryMB != null && gpuInfo.memoryMB! < 2048) {
        suggestions.add('GPU内存较少，建议减少预加载量');
      }

      if (!gpuInfo.supports4KDecoding) {
        suggestions.add('GPU不支持4K硬件解码');
      }
    }

    return suggestions;
  }

  /// 重置硬件加速配置
  Future<void> reset() async {
    try {
      _currentConfig = null;
      await initialize();
      _fireEvent(HardwareAccelerationEvent.reset());
    } catch (e) {
      final error = '重置硬件加速失败: $e';
      print(error);
      _fireEvent(HardwareAccelerationEvent.error(error));
    }
  }

  /// 检测VideoToolbox (macOS/iOS)
  Future<HardwareAccelerationConfig> _detectVideoToolbox() async {
    try {
      // TODO: 实现实际的VideoToolbox检测
      // 这里需要调用平台特定的代码

      // 模拟检测结果
      final now = DateTime.now();
      final config = HardwareAccelerationConfig(
        type: HwAccelType.videotoolbox,
        enabled: true,
        supportedCodecs: ['h264', 'hevc', 'vp9'], // AV1在较新macOS上支持
        platformSpecificSettings: {
          'videotoolbox-allow-decoding-hevc': true,
          'videotoolbox-allow-decoding-prores': true,
        },
        detectedAt: now,
        status: HwAccelStatus.available,
        gpuInfo: GPUInfo(
          vendor: 'Apple',
          model: 'Apple Silicon/Intel GPU',
          name: 'macOS GPU',
          memoryMB: 4096, // 估计值
          driverVersion: Platform.operatingSystemVersion,
        ),
        driverInfo: 'macOS VideoToolbox Framework',
        version: Platform.operatingSystemVersion,
      );

      print('VideoToolbox检测成功: ${config.displayName}');
      return config;
    } catch (e) {
      print('VideoToolbox检测失败: $e');
      return HardwareAccelerationConfig.detectionFailed(e.toString());
    }
  }

  /// 检测Windows硬件加速
  Future<HardwareAccelerationConfig>
      _detectWindowsHardwareAcceleration() async {
    try {
      // TODO: 实现实际的Windows硬件加速检测
      // 检测D3D11VA和DXVA2支持

      // 模拟检测结果
      final now = DateTime.now();
      final config = HardwareAccelerationConfig(
        type: HwAccelType.d3d11va, // 优先使用D3D11VA
        enabled: true,
        supportedCodecs: ['h264', 'hevc', 'vp9'],
        platformSpecificSettings: {
          'd3d11va-zero-copy': true,
        },
        detectedAt: now,
        status: HwAccelStatus.available,
        gpuInfo: GPUInfo(
          vendor: 'NVIDIA/AMD/Intel',
          model: 'Windows GPU',
          name: 'Windows Display Adapter',
          memoryMB: 4096, // 估计值
          driverVersion: 'Unknown', // TODO: 获取实际驱动版本
        ),
        driverInfo: 'Windows D3D11VA Framework',
        version: Platform.operatingSystemVersion,
      );

      print('Windows硬件加速检测成功: ${config.displayName}');
      return config;
    } catch (e) {
      print('Windows硬件加速检测失败: $e');
      return HardwareAccelerationConfig.detectionFailed(e.toString());
    }
  }

  /// 检测Linux硬件加速
  Future<HardwareAccelerationConfig> _detectLinuxHardwareAcceleration() async {
    try {
      // TODO: 实现实际的Linux硬件加速检测
      // 检测VAAPI和VDPAU支持

      // 模拟检测结果
      final now = DateTime.now();
      final config = HardwareAccelerationConfig(
        type: HwAccelType.vaapi, // 优先使用VAAPI
        enabled: true,
        supportedCodecs: ['h264', 'hevc', 'vp9', 'av1'],
        platformSpecificSettings: {
          'vaapi-device': '/dev/dri/renderD128',
        },
        detectedAt: now,
        status: HwAccelStatus.available,
        gpuInfo: GPUInfo(
          vendor: 'Intel/AMD/NVIDIA',
          model: 'Linux GPU',
          name: 'Linux Display Adapter',
          memoryMB: 2048, // 估计值
          driverVersion: 'Unknown', // TODO: 获取实际驱动版本
        ),
        driverInfo: 'Linux VAAPI Framework',
        version: Platform.operatingSystemVersion,
      );

      print('Linux硬件加速检测成功: ${config.displayName}');
      return config;
    } catch (e) {
      print('Linux硬件加速检测失败: $e');
      return HardwareAccelerationConfig.detectionFailed(e.toString());
    }
  }

  /// 检测Android硬件加速
  Future<HardwareAccelerationConfig>
      _detectAndroidHardwareAcceleration() async {
    try {
      // TODO: 实现实际的Android MediaCodec检测

      // 模拟检测结果
      final now = DateTime.now();
      final config = HardwareAccelerationConfig(
        type: HwAccelType.mediacodec,
        enabled: true,
        supportedCodecs: ['h264', 'hevc', 'vp9', 'av1'],
        platformSpecificSettings: {
          'mediacodec-decoder': 'hardware',
        },
        detectedAt: now,
        status: HwAccelStatus.available,
        gpuInfo: GPUInfo(
          vendor: 'Qualcomm/Exynos/Adreno',
          model: 'Android GPU',
          name: 'Android Display Adapter',
          memoryMB: 1024, // 估计值
          driverVersion: Platform.operatingSystemVersion,
        ),
        driverInfo: 'Android MediaCodec Framework',
        version: Platform.operatingSystemVersion,
      );

      print('Android硬件加速检测成功: ${config.displayName}');
      return config;
    } catch (e) {
      print('Android硬件加速检测失败: $e');
      return HardwareAccelerationConfig.detectionFailed(e.toString());
    }
  }

  /// 测试硬件加速配置
  Future<bool> _testHardwareAcceleration(
      HardwareAccelerationConfig config) async {
    try {
      // TODO: 实现实际的硬件加速测试
      // 创建测试播放器，尝试加载测试视频

      print('测试硬件加速配置: ${config.displayName}');

      // 模拟测试结果
      await Future.delayed(const Duration(milliseconds: 100));

      // 在实际实现中，这里应该：
      // 1. 创建临时播放器
      // 2. 使用配置设置播放器
      // 3. 尝试加载测试视频
      // 4. 检查是否成功启用了硬件加速

      return config.enabled && config.type != HwAccelType.none;
    } catch (e) {
      print('硬件加速测试失败: $e');
      return false;
    }
  }

  /// 触发事件
  void _fireEvent(HardwareAccelerationEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// 销毁服务
  void dispose() {
    _eventController.close();
  }
}

/// 硬件加速事件
class HardwareAccelerationEvent {
  final HardwareAccelerationEventType type;
  final String? message;
  final HardwareAccelerationConfig? config;

  const HardwareAccelerationEvent._({
    required this.type,
    this.message,
    this.config,
  });

  const HardwareAccelerationEvent.detectionStarted()
      : type = HardwareAccelerationEventType.detectionStarted,
        message = null,
        config = null;

  factory HardwareAccelerationEvent.detected(
      HardwareAccelerationConfig config) {
    return HardwareAccelerationEvent._(
      type: HardwareAccelerationEventType.detected,
      message: '检测到硬件加速: ${config.displayName}',
      config: config,
    );
  }

  const HardwareAccelerationEvent.notSupported(String message)
      : type = HardwareAccelerationEventType.notSupported,
        message = message,
        config = null;

  factory HardwareAccelerationEvent.enabling() {
    return const HardwareAccelerationEvent._(
      type: HardwareAccelerationEventType.enabling,
      message: '正在启用硬件加速...',
    );
  }

  factory HardwareAccelerationEvent.enabled(HardwareAccelerationConfig config) {
    return HardwareAccelerationEvent._(
      type: HardwareAccelerationEventType.enabled,
      message: '硬件加速已启用: ${config.displayName}',
      config: config,
    );
  }

  const HardwareAccelerationEvent.disabled()
      : type = HardwareAccelerationEventType.disabled,
        message = '硬件加速已禁用',
        config = null;

  const HardwareAccelerationEvent.fallingBack()
      : type = HardwareAccelerationEventType.fallingBack,
        message = '正在降级到软件解码...',
        config = null;

  factory HardwareAccelerationEvent.fallback(String message) {
    return HardwareAccelerationEvent._(
      type: HardwareAccelerationEventType.fallback,
      message: message,
    );
  }

  factory HardwareAccelerationEvent.testFailed(
      String message, HardwareAccelerationConfig config) {
    return HardwareAccelerationEvent._(
      type: HardwareAccelerationEventType.testFailed,
      message: message,
      config: config,
    );
  }

  factory HardwareAccelerationEvent.error(String message) {
    return HardwareAccelerationEvent._(
      type: HardwareAccelerationEventType.error,
      message: message,
    );
  }

  const HardwareAccelerationEvent.reset()
      : type = HardwareAccelerationEventType.reset,
        message = '硬件加速配置已重置',
        config = null;

  @override
  String toString() {
    return 'HardwareAccelerationEvent(type: $type, message: $message)';
  }
}

/// 硬件加速事件类型
enum HardwareAccelerationEventType {
  detectionStarted,
  detected,
  notSupported,
  enabling,
  enabled,
  disabled,
  fallingBack,
  fallback,
  testFailed,
  error,
  reset,
}
