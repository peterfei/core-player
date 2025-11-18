import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_info.dart';

/// 缓冲策略枚举
enum BufferStrategy {
  conservative, // 保守策略：大缓冲，适合不稳定网络
  balanced, // 平衡策略：中等缓冲，默认选择
  aggressive, // 激进策略：小缓冲，适合高速网络
  adaptive // 自适应策略：根据网络动态调整
}

/// 缓冲健康状态
enum BufferHealth {
  critical, // 红色：缓冲 < 2秒，即将卡顿
  warning, // 黄色：缓冲 < 10秒，需要加速
  healthy, // 绿色：缓冲充足
  excellent // 蓝色：缓冲超过目标值
}

/// 网络质量等级
enum NetworkQuality {
  excellent, // >10 Mbps, 稳定
  good, // 5-10 Mbps
  moderate, // 2-5 Mbps
  poor, // 1-2 Mbps
  critical // <1 Mbps, 不稳定
}

/// 连接状态
enum ConnectionState { connected, reconnecting, offline, failed }

/// ABR算法类型
enum AbrAlgorithm {
  throughput, // 吞吐量算法
  bola, // BOLA算法
  dynamic // 动态算法
}

/// 缓冲阈值配置
class BufferThresholds {
  final Duration minBuffer; // 最小缓冲时长: 5秒
  final Duration maxBuffer; // 最大缓冲时长: 60秒
  final Duration targetBuffer; // 目标缓冲时长: 30秒
  final Duration rebufferTrigger; // 重缓冲触发阈值: 2秒
  final int bufferSizeMB; // 缓冲区大小: 10-100MB
  final Duration? lowBufferThreshold; // 低缓冲阈值

  const BufferThresholds({
    this.minBuffer = const Duration(seconds: 5),
    this.maxBuffer = const Duration(seconds: 60),
    this.targetBuffer = const Duration(seconds: 30),
    this.rebufferTrigger = const Duration(seconds: 2),
    this.bufferSizeMB = 50,
    this.lowBufferThreshold,
  });

  Map<String, dynamic> toJson() {
    return {
      'minBufferSeconds': minBuffer.inSeconds,
      'maxBufferSeconds': maxBuffer.inSeconds,
      'targetBufferSeconds': targetBuffer.inSeconds,
      'rebufferTriggerSeconds': rebufferTrigger.inSeconds,
      'bufferSizeMB': bufferSizeMB,
    };
  }

  factory BufferThresholds.fromJson(Map<String, dynamic> json) {
    return BufferThresholds(
      minBuffer: Duration(seconds: json['minBufferSeconds'] ?? 5),
      maxBuffer: Duration(seconds: json['maxBufferSeconds'] ?? 60),
      targetBuffer: Duration(seconds: json['targetBufferSeconds'] ?? 30),
      rebufferTrigger: Duration(seconds: json['rebufferTriggerSeconds'] ?? 2),
      bufferSizeMB: json['bufferSizeMB'] ?? 50,
      lowBufferThreshold: json['lowBufferThresholdSeconds'] != null
          ? Duration(seconds: json['lowBufferThresholdSeconds'])
          : null,
    );
  }
}

/// 预加载策略
class PreloadStrategy {
  final Duration prebufferDuration; // 播放前预缓冲时长
  final bool enableBackgroundPreload; // 是否启用后台预加载
  final Duration lowPowerPrebuffer; // 低功耗模式下的预加载策略
  final int preloadNextSegments; // 预加载下一段数量
  final Duration preloadWindow; // 预加载窗口大小
  final bool networkAware; // 是否网络感知
  final bool bandwidthBased; // 是否基于带宽调整

  const PreloadStrategy({
    this.prebufferDuration = const Duration(seconds: 10),
    this.enableBackgroundPreload = true,
    this.lowPowerPrebuffer = const Duration(seconds: 5),
    this.preloadNextSegments = 1,
    this.preloadWindow = const Duration(seconds: 30),
    this.networkAware = true,
    this.bandwidthBased = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'prebufferDurationSeconds': prebufferDuration.inSeconds,
      'enableBackgroundPreload': enableBackgroundPreload,
      'lowPowerPrebufferSeconds': lowPowerPrebuffer.inSeconds,
      'preloadNextSegments': preloadNextSegments,
      'preloadWindowSeconds': preloadWindow.inSeconds,
      'networkAware': networkAware,
      'bandwidthBased': bandwidthBased,
    };
  }

  factory PreloadStrategy.fromJson(Map<String, dynamic> json) {
    return PreloadStrategy(
      prebufferDuration:
          Duration(seconds: json['prebufferDurationSeconds'] ?? 10),
      enableBackgroundPreload: json['enableBackgroundPreload'] ?? true,
      lowPowerPrebuffer:
          Duration(seconds: json['lowPowerPrebufferSeconds'] ?? 5),
      preloadNextSegments: json['preloadNextSegments'] ?? 1,
      preloadWindow: Duration(seconds: json['preloadWindowSeconds'] ?? 30),
      networkAware: json['networkAware'] ?? true,
      bandwidthBased: json['bandwidthBased'] ?? true,
    );
  }
}

/// 缓冲配置
class BufferConfig {
  final BufferStrategy strategy;
  final BufferThresholds thresholds;
  final PreloadStrategy preload;
  final bool autoAdjust;

  const BufferConfig({
    this.strategy = BufferStrategy.adaptive,
    this.thresholds = const BufferThresholds(),
    this.preload = const PreloadStrategy(),
    this.autoAdjust = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'strategy': strategy.name,
      'thresholds': thresholds.toJson(),
      'preload': preload.toJson(),
      'autoAdjust': autoAdjust,
    };
  }

  factory BufferConfig.fromJson(Map<String, dynamic> json) {
    return BufferConfig(
      strategy: BufferStrategy.values.firstWhere(
        (e) => e.name == json['strategy'],
        orElse: () => BufferStrategy.adaptive,
      ),
      thresholds: BufferThresholds.fromJson(json['thresholds'] ?? {}),
      preload: PreloadStrategy.fromJson(json['preload'] ?? {}),
      autoAdjust: json['autoAdjust'] ?? true,
    );
  }

  /// 从本地存储加载配置
  static Future<BufferConfig> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('buffer_config');
      if (configJson != null) {
        final Map<String, dynamic> json = jsonDecode(configJson);
        return BufferConfig.fromJson(json);
      }
    } catch (e) {
      // 如果加载失败，使用默认配置
      print('Failed to load buffer config: $e');
    }
    return const BufferConfig();
  }

  /// 保存配置到本地存储
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = jsonEncode(toJson());
      await prefs.setString('buffer_config', configJson);
    } catch (e) {
      print('Failed to save buffer config: $e');
    }
  }

  /// 重置为默认配置
  static Future<void> resetToDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('buffer_config');
    } catch (e) {
      print('Failed to reset buffer config: $e');
    }
  }

  BufferConfig copyWith({
    BufferStrategy? strategy,
    BufferThresholds? thresholds,
    PreloadStrategy? preload,
    bool? autoAdjust,
  }) {
    return BufferConfig(
      strategy: strategy ?? this.strategy,
      thresholds: thresholds ?? this.thresholds,
      preload: preload ?? this.preload,
      autoAdjust: autoAdjust ?? this.autoAdjust,
    );
  }

  /// 为超高清视频优化的缓冲配置
  BufferConfig optimizeForUltraHD(VideoInfo videoInfo) {
    if (!videoInfo.isUltraHD && !videoInfo.isLargeFile) {
      return this;
    }

    // 基础缓冲时长（秒）
    int baseBufferSec = thresholds.targetBuffer.inSeconds;
    int maxBufferSec = thresholds.maxBuffer.inSeconds;
    int bufferSizeMB = thresholds.bufferSizeMB;

    // 根据分辨率调整
    if (videoInfo.height >= 4320) {
      // 8K
      baseBufferSec = 30;
      maxBufferSec = 90;
      bufferSizeMB = 2000; // 2GB
      print(
          '🎬 为8K视频优化缓冲: ${baseBufferSec}s/${maxBufferSec}s, ${bufferSizeMB}MB');
    } else if (videoInfo.height >= 2160) {
      // 4K
      baseBufferSec = 20;
      maxBufferSec = 60;
      bufferSizeMB = 1000; // 1GB
      print(
          '🎬 为4K视频优化缓冲: ${baseBufferSec}s/${maxBufferSec}s, ${bufferSizeMB}MB');
    }

    // 根据码率进一步调整
    final bitrateMbps = videoInfo.bitrate ~/ (1000 * 1000);
    if (bitrateMbps > 50) {
      // 超高码率
      baseBufferSec += 10;
      maxBufferSec += 30;
      bufferSizeMB = (bufferSizeMB * 1.5).round();
      print('🎬 为超高码率(${bitrateMbps}Mbps)优化缓冲');
    } else if (bitrateMbps > 20) {
      // 高码率
      baseBufferSec += 5;
      maxBufferSec += 15;
      bufferSizeMB = (bufferSizeMB * 1.2).round();
      print('🎬 为高码率(${bitrateMbps}Mbps)优化缓冲');
    }

    // 大文件特殊处理
    if (videoInfo.isLargeFile) {
      // 增加预加载范围，减少seek时的重新缓冲
      baseBufferSec = (baseBufferSec * 1.3).round();
      maxBufferSec = (maxBufferSec * 1.2).round();
      print('🎬 为大文件(${videoInfo.formattedFileSize})优化缓冲');
    }

    // 高帧率视频需要更多缓冲
    if (videoInfo.fps >= 60) {
      baseBufferSec += 5;
      maxBufferSec += 10;
      print('🎬 为高帧率(${videoInfo.fpsLabel})视频优化缓冲');
    }

    // 创建优化后的阈值
    final optimizedThresholds = BufferThresholds(
      minBuffer: Duration(seconds: (baseBufferSec * 0.3).round()),
      maxBuffer: Duration(seconds: maxBufferSec),
      targetBuffer: Duration(seconds: baseBufferSec),
      rebufferTrigger: Duration(seconds: (baseBufferSec * 0.1).round()),
      bufferSizeMB: bufferSizeMB,
      lowBufferThreshold: Duration(seconds: (baseBufferSec * 0.5).round()),
    );

    // 创建优化后的预加载策略
    final optimizedPreload = PreloadStrategy(
      preloadNextSegments: videoInfo.isLargeFile ? 2 : 1,
      preloadWindow: Duration(seconds: baseBufferSec),
      networkAware: preload.networkAware,
      bandwidthBased: preload.bandwidthBased,
    );

    return BufferConfig(
      strategy: strategy,
      thresholds: optimizedThresholds,
      preload: optimizedPreload,
      autoAdjust: autoAdjust,
    );
  }

  /// 获取当前配置的描述
  String getDescription() {
    return '缓冲策略: ${strategy.name}, '
        '目标缓冲: ${thresholds.targetBuffer.inSeconds}s, '
        '缓冲大小: ${thresholds.bufferSizeMB}MB, '
        '自动调整: ${autoAdjust ? "开启" : "关闭"}';
  }

  /// 获取性能等级
  String getPerformanceLevel() {
    final targetSec = thresholds.targetBuffer.inSeconds;
    final sizeMB = thresholds.bufferSizeMB;

    if (targetSec >= 20 && sizeMB >= 1000) {
      return '🚀 超高性能 (适合4K/8K)';
    } else if (targetSec >= 15 && sizeMB >= 500) {
      return '⚡ 高性能 (适合1080p/4K)';
    } else if (targetSec >= 10 && sizeMB >= 200) {
      return '📈 标准性能 (适合720p/1080p)';
    } else {
      return '📉 基础性能 (适合480p)';
    }
  }

  /// 根据视频质量推荐配置
  static BufferConfig getRecommendedConfig(VideoInfo videoInfo) {
    final defaultConfig = const BufferConfig();

    if (videoInfo.isUltraHD || videoInfo.isLargeFile) {
      return defaultConfig.optimizeForUltraHD(videoInfo);
    }

    return defaultConfig;
  }
}

/// 缓冲扩展配置（用于高级设置）
class AdvancedBufferConfig extends BufferConfig {
  final AbrAlgorithm abrAlgorithm;
  final QualityLevel maxQuality;
  final bool hdOnlyOnWifi;
  final bool autoDowngrade;
  final int maxRetries;
  final int connectionTimeout;
  final bool showNetworkStats;

  const AdvancedBufferConfig({
    super.strategy = BufferStrategy.adaptive,
    super.thresholds = const BufferThresholds(),
    super.preload = const PreloadStrategy(),
    super.autoAdjust = true,
    this.abrAlgorithm = AbrAlgorithm.dynamic,
    this.maxQuality = QualityLevel.p1080,
    this.hdOnlyOnWifi = true,
    this.autoDowngrade = true,
    this.maxRetries = 5,
    this.connectionTimeout = 10,
    this.showNetworkStats = false,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'abrAlgorithm': abrAlgorithm.name,
      'maxQuality': maxQuality.name,
      'hdOnlyOnWifi': hdOnlyOnWifi,
      'autoDowngrade': autoDowngrade,
      'maxRetries': maxRetries,
      'connectionTimeout': connectionTimeout,
      'showNetworkStats': showNetworkStats,
    };
  }

  factory AdvancedBufferConfig.fromJson(Map<String, dynamic> json) {
    return AdvancedBufferConfig(
      strategy: BufferStrategy.values.firstWhere(
        (e) => e.name == json['strategy'],
        orElse: () => BufferStrategy.adaptive,
      ),
      thresholds: BufferThresholds.fromJson(json['thresholds'] ?? {}),
      preload: PreloadStrategy.fromJson(json['preload'] ?? {}),
      autoAdjust: json['autoAdjust'] ?? true,
      abrAlgorithm: AbrAlgorithm.values.firstWhere(
        (e) => e.name == json['abrAlgorithm'],
        orElse: () => AbrAlgorithm.dynamic,
      ),
      maxQuality: QualityLevel.values.firstWhere(
        (e) => e.name == json['maxQuality'],
        orElse: () => QualityLevel.p1080,
      ),
      hdOnlyOnWifi: json['hdOnlyOnWifi'] ?? true,
      autoDowngrade: json['autoDowngrade'] ?? true,
      maxRetries: json['maxRetries'] ?? 5,
      connectionTimeout: json['connectionTimeout'] ?? 10,
      showNetworkStats: json['showNetworkStats'] ?? false,
    );
  }

  static Future<AdvancedBufferConfig> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('advanced_buffer_config');
      if (configJson != null) {
        final Map<String, dynamic> json = jsonDecode(configJson);
        return AdvancedBufferConfig.fromJson(json);
      }
    } catch (e) {
      print('Failed to load advanced buffer config: $e');
    }
    return const AdvancedBufferConfig();
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = jsonEncode(toJson());
      await prefs.setString('advanced_buffer_config', configJson);
    } catch (e) {
      print('Failed to save advanced buffer config: $e');
    }
  }

  static Future<void> resetToDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('advanced_buffer_config');
    } catch (e) {
      print('Failed to reset advanced buffer config: $e');
    }
  }

  AdvancedBufferConfig copyWithAdvanced({
    BufferStrategy? strategy,
    BufferThresholds? thresholds,
    PreloadStrategy? preload,
    bool? autoAdjust,
    AbrAlgorithm? abrAlgorithm,
    QualityLevel? maxQuality,
    bool? hdOnlyOnWifi,
    bool? autoDowngrade,
    int? maxRetries,
    int? connectionTimeout,
    bool? showNetworkStats,
  }) {
    return AdvancedBufferConfig(
      strategy: strategy ?? this.strategy,
      thresholds: thresholds ?? this.thresholds,
      preload: preload ?? this.preload,
      autoAdjust: autoAdjust ?? this.autoAdjust,
      abrAlgorithm: abrAlgorithm ?? this.abrAlgorithm,
      maxQuality: maxQuality ?? this.maxQuality,
      hdOnlyOnWifi: hdOnlyOnWifi ?? this.hdOnlyOnWifi,
      autoDowngrade: autoDowngrade ?? this.autoDowngrade,
      maxRetries: maxRetries ?? this.maxRetries,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      showNetworkStats: showNetworkStats ?? this.showNetworkStats,
    );
  }
}

/// 画质等级
enum QualityLevel {
  auto('auto', 0, 0, '自动'),
  p360('360p', 500000, 360, '360p'),
  p480('480p', 1000000, 480, '480p'),
  p720('720p', 2500000, 720, '720p'),
  p1080('1080p', 5000000, 1080, '1080p'),
  p1440('1440p', 10000000, 1440, '1440p'),
  p2160('4K', 20000000, 2160, '4K');

  const QualityLevel(this.name, this.bitrate, this.height, this.displayName);

  final String name;
  final int bitrate; // bps
  final int height; // 像素高度
  final String displayName;
}

/// 格式化比特率
String formatBitrate(int bitrate) {
  if (bitrate == 0) return '自动';
  final kbps = bitrate / 1000;
  final mbps = kbps / 1000;

  if (mbps >= 1) {
    return '${mbps.toStringAsFixed(1)} Mbps';
  } else {
    return '${kbps.toStringAsFixed(0)} kbps';
  }
}

/// 格式化网速
String formatSpeed(double speed) {
  if (speed == 0) return '未知';
  final kbps = speed / 1000;
  final mbps = kbps / 1000;

  if (mbps >= 1) {
    return '${mbps.toStringAsFixed(1)} Mbps';
  } else {
    return '${kbps.toStringAsFixed(0)} kbps';
  }
}
