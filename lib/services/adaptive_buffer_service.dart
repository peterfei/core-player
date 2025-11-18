import 'dart:async';
import 'dart:math';
import '../models/buffer_config.dart';
import '../models/network_stats.dart';
import 'bandwidth_monitor_service.dart';

/// 自适应缓冲策略服务
class AdaptiveBufferService {
  static final AdaptiveBufferService _instance =
      AdaptiveBufferService._internal();
  factory AdaptiveBufferService() => _instance;
  AdaptiveBufferService._internal();

  final BandwidthMonitorService _bandwidthMonitor = BandwidthMonitorService();
  BufferConfig _currentConfig = const BufferConfig();
  Timer? _adjustmentTimer;
  bool _isAdapting = false;

  /// 获取当前配置
  BufferConfig get currentConfig => _currentConfig;

  /// 设置缓冲配置
  void setConfig(BufferConfig config) {
    _currentConfig = config;
  }

  /// 开始自适应调整
  void startAdaptiveAdjustment() {
    if (_isAdapting) return;
    _isAdapting = true;

    // 每10秒调整一次缓冲策略
    _adjustmentTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _performAdaptiveAdjustment();
    });
  }

  /// 停止自适应调整
  void stopAdaptiveAdjustment() {
    _isAdapting = false;
    _adjustmentTimer?.cancel();
    _adjustmentTimer = null;
  }

  /// 是否正在自适应调整
  bool get isAdapting => _isAdapting;

  /// 根据网络状况计算最优缓冲大小
  BufferConfig calculateOptimalConfig(NetworkStats stats) {
    final strategy = _currentConfig.strategy;
    final quality = stats.quality;
    final bandwidth = stats.averageBandwidth;
    final stability = stats.stability;

    switch (strategy) {
      case BufferStrategy.conservative:
        return _createConservativeConfig();
      case BufferStrategy.balanced:
        return _createBalancedConfig(quality, bandwidth, stability);
      case BufferStrategy.aggressive:
        return _createAggressiveConfig(quality, bandwidth, stability);
      case BufferStrategy.adaptive:
        return _createAdaptiveConfig(quality, bandwidth, stability);
    }
  }

  /// 创建保守策略配置
  BufferConfig _createConservativeConfig() {
    return BufferConfig(
      strategy: BufferStrategy.conservative,
      thresholds: const BufferThresholds(
        minBuffer: Duration(seconds: 10),
        maxBuffer: Duration(seconds: 90),
        targetBuffer: Duration(seconds: 45),
        rebufferTrigger: Duration(seconds: 3),
        bufferSizeMB: 80,
      ),
      preload: const PreloadStrategy(
        prebufferDuration: Duration(seconds: 15),
        enableBackgroundPreload: false,
        lowPowerPrebuffer: Duration(seconds: 10),
      ),
      autoAdjust: false,
    );
  }

  /// 创建平衡策略配置
  BufferConfig _createBalancedConfig(
      NetworkQuality quality, double bandwidth, double stability) {
    Duration targetBuffer;
    int bufferSize;
    Duration prebufferDuration;

    switch (quality) {
      case NetworkQuality.excellent:
        targetBuffer = const Duration(seconds: 20);
        bufferSize = 30;
        prebufferDuration = const Duration(seconds: 5);
        break;
      case NetworkQuality.good:
        targetBuffer = const Duration(seconds: 30);
        bufferSize = 40;
        prebufferDuration = const Duration(seconds: 8);
        break;
      case NetworkQuality.moderate:
        targetBuffer = const Duration(seconds: 45);
        bufferSize = 60;
        prebufferDuration = const Duration(seconds: 12);
        break;
      case NetworkQuality.poor:
        targetBuffer = const Duration(seconds: 60);
        bufferSize = 80;
        prebufferDuration = const Duration(seconds: 18);
        break;
      case NetworkQuality.critical:
        targetBuffer = const Duration(seconds: 80);
        bufferSize = 100;
        prebufferDuration = const Duration(seconds: 25);
        break;
    }

    return BufferConfig(
      strategy: BufferStrategy.balanced,
      thresholds: BufferThresholds(
        minBuffer: Duration(seconds: (targetBuffer.inSeconds * 0.3).round()),
        maxBuffer: Duration(seconds: (targetBuffer.inSeconds * 2).round()),
        targetBuffer: targetBuffer,
        rebufferTrigger:
            Duration(seconds: (targetBuffer.inSeconds * 0.1).round()),
        bufferSizeMB: bufferSize,
      ),
      preload: PreloadStrategy(
        prebufferDuration: prebufferDuration,
        enableBackgroundPreload: quality == NetworkQuality.excellent ||
            quality == NetworkQuality.good,
        lowPowerPrebuffer:
            Duration(seconds: (prebufferDuration.inSeconds * 0.6).round()),
      ),
      autoAdjust: false,
    );
  }

  /// 创建激进策略配置
  BufferConfig _createAggressiveConfig(
      NetworkQuality quality, double bandwidth, double stability) {
    Duration targetBuffer;
    int bufferSize;
    Duration prebufferDuration;

    if (quality.index >= NetworkQuality.moderate.index) {
      // 网络良好时使用较小缓冲
      targetBuffer = const Duration(seconds: 10);
      bufferSize = 20;
      prebufferDuration = const Duration(seconds: 3);
    } else {
      // 网络较差时适度增加缓冲
      targetBuffer = const Duration(seconds: 20);
      bufferSize = 30;
      prebufferDuration = const Duration(seconds: 5);
    }

    return BufferConfig(
      strategy: BufferStrategy.aggressive,
      thresholds: BufferThresholds(
        minBuffer: Duration(seconds: 3),
        maxBuffer: Duration(seconds: 30),
        targetBuffer: targetBuffer,
        rebufferTrigger: Duration(seconds: 1),
        bufferSizeMB: bufferSize,
      ),
      preload: PreloadStrategy(
        prebufferDuration: prebufferDuration,
        enableBackgroundPreload: quality == NetworkQuality.excellent,
        lowPowerPrebuffer: const Duration(seconds: 2),
      ),
      autoAdjust: false,
    );
  }

  /// 创建自适应策略配置
  BufferConfig _createAdaptiveConfig(
      NetworkQuality quality, double bandwidth, double stability) {
    // 基于带宽计算基础缓冲要求
    Duration baseTargetBuffer = _calculateTargetBufferFromBandwidth(bandwidth);

    // 基于稳定性调整
    double stabilityFactor = 1.0 + (1.0 - stability) * 0.5; // 不稳定性最高增加50%

    // 基于质量调整
    double qualityFactor = _getQualityFactor(quality);

    Duration adjustedTargetBuffer = Duration(
      milliseconds:
          (baseTargetBuffer.inMilliseconds * stabilityFactor * qualityFactor)
              .round(),
    );

    // 限制缓冲范围
    adjustedTargetBuffer = Duration(
      seconds: max(5, min(60, adjustedTargetBuffer.inSeconds)),
    );

    // 计算其他参数
    final bufferSize = _calculateBufferSize(adjustedTargetBuffer, bandwidth);
    final prebufferDuration =
        _calculatePrebufferDuration(adjustedTargetBuffer, quality);

    return BufferConfig(
      strategy: BufferStrategy.adaptive,
      thresholds: BufferThresholds(
        minBuffer: Duration(
            seconds: max(3, (adjustedTargetBuffer.inSeconds * 0.2).round())),
        maxBuffer: Duration(
            seconds: max(15, (adjustedTargetBuffer.inSeconds * 1.5).round())),
        targetBuffer: adjustedTargetBuffer,
        rebufferTrigger: Duration(
            seconds: max(1, (adjustedTargetBuffer.inSeconds * 0.15).round())),
        bufferSizeMB: bufferSize,
      ),
      preload: PreloadStrategy(
        prebufferDuration: prebufferDuration,
        enableBackgroundPreload:
            quality.index <= NetworkQuality.good.index && stability > 0.7,
        lowPowerPrebuffer: Duration(
            seconds: max(2, (prebufferDuration.inSeconds * 0.5).round())),
      ),
      autoAdjust: true,
    );
  }

  /// 基于带宽计算目标缓冲时长
  Duration _calculateTargetBufferFromBandwidth(double bandwidth) {
    if (bandwidth <= 0) return const Duration(seconds: 30);

    // 高速网络减少缓冲，低速网络增加缓冲
    if (bandwidth >= 10000000) {
      // >10 Mbps
      return const Duration(seconds: 10);
    } else if (bandwidth >= 5000000) {
      // 5-10 Mbps
      return const Duration(seconds: 20);
    } else if (bandwidth >= 2000000) {
      // 2-5 Mbps
      return const Duration(seconds: 30);
    } else if (bandwidth >= 1000000) {
      // 1-2 Mbps
      return const Duration(seconds: 45);
    } else {
      // <1 Mbps
      return const Duration(seconds: 60);
    }
  }

  /// 获取质量调整因子
  double _getQualityFactor(NetworkQuality quality) {
    switch (quality) {
      case NetworkQuality.excellent:
        return 0.8; // 减少缓冲
      case NetworkQuality.good:
        return 1.0; // 标准
      case NetworkQuality.moderate:
        return 1.3; // 增加缓冲
      case NetworkQuality.poor:
        return 1.6; // 显著增加缓冲
      case NetworkQuality.critical:
        return 2.0; // 最大缓冲
    }
  }

  /// 计算缓冲区大小
  int _calculateBufferSize(Duration targetBuffer, double bandwidth) {
    // 基于目标缓冲时长和带宽计算最小缓冲区大小
    final minBufferSize =
        (bandwidth * targetBuffer.inSeconds / 8) / (1024 * 1024); // MB

    // 应用最小值和最大值限制
    final finalBufferSize = max(10, min(100, minBufferSize));

    return finalBufferSize.round();
  }

  /// 计算预缓冲时长
  Duration _calculatePrebufferDuration(
      Duration targetBuffer, NetworkQuality quality) {
    double ratio;
    switch (quality) {
      case NetworkQuality.excellent:
        ratio = 0.3; // 预缓冲30%的目标时长
        break;
      case NetworkQuality.good:
        ratio = 0.4;
        break;
      case NetworkQuality.moderate:
        ratio = 0.5;
        break;
      case NetworkQuality.poor:
        ratio = 0.7;
        break;
      case NetworkQuality.critical:
        ratio = 1.0; // 预缓冲完整目标时长
        break;
    }

    return Duration(seconds: max(3, (targetBuffer.inSeconds * ratio).round()));
  }

  /// 执行自适应调整
  void _performAdaptiveAdjustment() {
    try {
      final stats = _bandwidthMonitor.currentStats;

      if (stats.currentBandwidth <= 0) {
        // 没有带宽数据时不调整
        return;
      }

      final optimalConfig = calculateOptimalConfig(stats);

      // 检查是否需要调整配置
      if (_shouldAdjustConfig(_currentConfig, optimalConfig)) {
        _currentConfig = optimalConfig;

        // 通知配置已更新（这里可以添加回调或事件）
        print('Adaptive buffer config updated: ${optimalConfig.strategy}');
      }
    } catch (e) {
      print('Error in adaptive adjustment: $e');
    }
  }

  /// 判断是否需要调整配置
  bool _shouldAdjustConfig(BufferConfig current, BufferConfig optimal) {
    // 策略不同时需要调整
    if (current.strategy != optimal.strategy) {
      return true;
    }

    // 目标缓冲时长差异超过20%时需要调整
    final currentTargetSeconds = current.thresholds.targetBuffer.inSeconds;
    final optimalTargetSeconds = optimal.thresholds.targetBuffer.inSeconds;
    final difference = (optimalTargetSeconds - currentTargetSeconds).abs();
    final relativeDifference = difference / currentTargetSeconds;

    return relativeDifference > 0.2; // 差异超过20%
  }

  /// 监控缓冲健康状态
  BufferHealth getBufferHealth(
      Duration bufferedDuration, Duration targetBuffer) {
    if (bufferedDuration.inSeconds < 2) return BufferHealth.critical;
    if (bufferedDuration.inSeconds < targetBuffer.inSeconds * 0.3)
      return BufferHealth.warning;
    if (bufferedDuration.inSeconds < targetBuffer.inSeconds * 0.8)
      return BufferHealth.healthy;
    return BufferHealth.excellent;
  }

  /// 预测未来缓冲需求
  Duration predictBufferDuration(double bandwidth, Duration currentBuffer) {
    if (bandwidth <= 0) return currentBuffer;

    // 基于历史数据和当前状况预测
    final predictedBandwidth =
        _bandwidthMonitor.predictBandwidth(const Duration(seconds: 30));

    // 如果预测带宽低于当前，增加缓冲需求
    if (predictedBandwidth < bandwidth) {
      final reductionFactor = predictedBandwidth / bandwidth;
      return Duration(
        milliseconds: (currentBuffer.inMilliseconds / reductionFactor).round(),
      );
    }

    return currentBuffer;
  }

  /// 获取推荐的缓冲策略
  BufferStrategy getRecommendedStrategy(NetworkStats stats) {
    final bandwidth = stats.averageBandwidth;
    final stability = stats.stability;
    final quality = stats.quality;

    // 网络极不稳定时使用保守策略
    if (stability < 0.3 || quality == NetworkQuality.critical) {
      return BufferStrategy.conservative;
    }

    // 网络优秀且稳定时使用激进策略
    if (quality == NetworkQuality.excellent && stability > 0.8) {
      return BufferStrategy.aggressive;
    }

    // 一般情况使用自适应策略
    return BufferStrategy.adaptive;
  }

  /// 重置为默认配置
  void resetToDefault() {
    _currentConfig = const BufferConfig();
  }

  /// 销毁服务
  void dispose() {
    stopAdaptiveAdjustment();
  }
}
