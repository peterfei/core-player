import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../core/plugin_system/core_plugin.dart';
import '../core/plugin_system/plugin_interface.dart';

/// 插件性能监控和优化服务
class PluginPerformanceService {
  static final PluginPerformanceService _instance = PluginPerformanceService._internal();
  factory PluginPerformanceService() => _instance;
  PluginPerformanceService._internal();

  final Map<String, PluginPerformanceMetrics> _metrics = {};
  final StreamController<PluginPerformanceEvent> _performanceController =
      StreamController<PluginPerformanceEvent>.broadcast();
  final Map<String, Timer> _memoryMonitorTimers = {};

  /// 性能事件流
  Stream<PluginPerformanceEvent> get performanceStream => _performanceController.stream;

  /// 获取所有插件性能指标
  Map<String, PluginPerformanceMetrics> get metrics => Map.unmodifiable(_metrics);

  /// 最大允许内存使用 (MB)
  static const int maxMemoryUsageMB = 256;

  /// 最大允许初始化时间 (毫秒)
  static const int maxInitTimeMs = 5000;

  /// 初始化性能监控
  void initialize() {
    if (kDebugMode) {
      developer.log('PluginPerformanceService initialized');
    }
  }

  /// 开始监控插件性能
  Future<void> startMonitoring(String pluginId, CorePlugin plugin) async {
    // 初始化性能指标
    _metrics[pluginId] = PluginPerformanceMetrics(
      pluginId: pluginId,
      pluginName: plugin.metadata.name,
      startTime: DateTime.now(),
    );

    // 开始内存监控
    _startMemoryMonitoring(pluginId);

    if (kDebugMode) {
      developer.log('Started performance monitoring for plugin: $pluginId');
    }
  }

  /// 停止监控插件性能
  void stopMonitoring(String pluginId) {
    _memoryMonitorTimers[pluginId]?.cancel();
    _memoryMonitorTimers.remove(pluginId);

    final metrics = _metrics[pluginId];
    if (metrics != null) {
      metrics.endTime = DateTime.now();
      _performanceController.add(PluginPerformanceEvent(
        pluginId: pluginId,
        type: PluginPerformanceEventType.monitoringStopped,
        metrics: metrics,
      ));
    }

    if (kDebugMode) {
      developer.log('Stopped performance monitoring for plugin: $pluginId');
    }
  }

  /// 记录插件初始化开始
  void recordInitStart(String pluginId) {
    final metrics = _metrics[pluginId];
    if (metrics != null) {
      metrics.initStartTime = DateTime.now();
      _performanceController.add(PluginPerformanceEvent(
        pluginId: pluginId,
        type: PluginPerformanceEventType.initStarted,
        metrics: metrics,
      ));
    }
  }

  /// 记录插件初始化完成
  void recordInitComplete(String pluginId, {bool success = true}) {
    final metrics = _metrics[pluginId];
    if (metrics != null && metrics.initStartTime != null) {
      final initTime = DateTime.now().difference(metrics.initStartTime!).inMilliseconds;
      metrics.initTime = initTime;
      metrics.initSuccess = success;

      _performanceController.add(PluginPerformanceEvent(
        pluginId: pluginId,
        type: success
            ? PluginPerformanceEventType.initCompleted
            : PluginPerformanceEventType.initFailed,
        metrics: metrics,
      ));

      // 检查初始化时间是否过长
      if (initTime > maxInitTimeMs) {
        _performanceController.add(PluginPerformanceEvent(
          pluginId: pluginId,
          type: PluginPerformanceEventType.slowInit,
          metrics: metrics,
        ));
      }
    }
  }

  /// 记录插件激活
  void recordActivation(String pluginId, {bool success = true}) {
    final metrics = _metrics[pluginId];
    if (metrics != null) {
      metrics.activationCount++;
      metrics.lastActivationTime = DateTime.now();

      if (!success) {
        metrics.activationFailures++;
      }

      _performanceController.add(PluginPerformanceEvent(
        pluginId: pluginId,
        type: success
            ? PluginPerformanceEventType.activated
            : PluginPerformanceEventType.activationFailed,
        metrics: metrics,
      ));
    }
  }

  /// 记录内存使用
  void recordMemoryUsage(String pluginId, int memoryMB) {
    final metrics = _metrics[pluginId];
    if (metrics != null) {
      metrics.currentMemoryUsageMB = memoryMB;
      metrics.peakMemoryUsageMB = math.max(metrics.peakMemoryUsageMB, memoryMB);

      _performanceController.add(PluginPerformanceEvent(
        pluginId: pluginId,
        type: PluginPerformanceEventType.memoryUsage,
        metrics: metrics,
        data: {'memoryMB': memoryMB},
      ));

      // 检查内存使用是否过高
      if (memoryMB > maxMemoryUsageMB) {
        _performanceController.add(PluginPerformanceEvent(
          pluginId: pluginId,
          type: PluginPerformanceEventType.highMemoryUsage,
          metrics: metrics,
          data: {'memoryMB': memoryMB},
        ));
      }
    }
  }

  /// 开始内存监控
  void _startMemoryMonitoring(String pluginId) {
    _memoryMonitorTimers[pluginId] = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkMemoryUsage(pluginId),
    );
  }

  /// 检查内存使用情况
  Future<void> _checkMemoryUsage(String pluginId) async {
    try {
      final memoryUsage = await _getCurrentMemoryUsage();
      recordMemoryUsage(pluginId, memoryUsage);
    } catch (e) {
      if (kDebugMode) {
        developer.log('Failed to check memory usage for plugin $pluginId: $e');
      }
    }
  }

  /// 获取当前内存使用量
  Future<int> _getCurrentMemoryUsage() async {
    // 这里应该实现平台特定的内存获取逻辑
    // 暂时返回一个估算值
    return 50; // 估算50MB
  }

  /// 获取插件性能统计
  PluginPerformanceSummary getPerformanceSummary() {
    final totalPlugins = _metrics.length;
    final activePlugins = _metrics.values.where((m) => m.isActive).length;
    final totalInitTime = _metrics.values
        .where((m) => m.initTime != null)
        .fold<int>(0, (sum, m) => sum + m.initTime!);
    final avgInitTime = totalInitTime > 0
        ? (totalInitTime / _metrics.values.where((m) => m.initTime != null).length).round()
        : 0;
    final totalMemoryUsage = _metrics.values
        .fold<int>(0, (sum, m) => sum + m.currentMemoryUsageMB);
    final avgMemoryUsage = totalPlugins > 0 ? (totalMemoryUsage / totalPlugins).round() : 0;

    return PluginPerformanceSummary(
      totalPlugins: totalPlugins,
      activePlugins: activePlugins,
      averageInitTimeMs: avgInitTime,
      totalMemoryUsageMB: totalMemoryUsage,
      averageMemoryUsageMB: avgMemoryUsage,
    );
  }

  /// 获取性能建议
  List<String> getPerformanceSuggestions() {
    final suggestions = <String>[];
    final summary = getPerformanceSummary();

    // 初始化时间建议
    if (summary.averageInitTimeMs > 2000) {
      suggestions.add('插件平均初始化时间较长，建议优化插件初始化逻辑');
    }

    // 内存使用建议
    if (summary.averageMemoryUsageMB > 100) {
      suggestions.add('插件平均内存使用较高，建议检查内存泄漏');
    }

    // 激活失败建议
    final highFailureRatePlugins = _metrics.entries.where((entry) {
      final metrics = entry.value;
      return metrics.activationCount > 0 &&
             (metrics.activationFailures / metrics.activationCount) > 0.2;
    }).length;

    if (highFailureRatePlugins > 0) {
      suggestions.add('检测到插件激活失败率较高，建议检查插件配置');
    }

    // 慢初始化插件建议
    final slowInitPlugins = _metrics.values.where((m) =>
        m.initTime != null && m.initTime! > maxInitTimeMs).length;

    if (slowInitPlugins > 0) {
      suggestions.add('检测到慢初始化插件，建议实现异步初始化');
    }

    return suggestions;
  }

  /// 清理资源
  void dispose() {
    for (final timer in _memoryMonitorTimers.values) {
      timer.cancel();
    }
    _memoryMonitorTimers.clear();
    _metrics.clear();
    _performanceController.close();
  }
}

/// 插件性能指标
class PluginPerformanceMetrics {
  final String pluginId;
  final String pluginName;
  final DateTime startTime;
  DateTime? endTime;
  DateTime? initStartTime;
  int? initTime;
  bool? initSuccess;
  int activationCount = 0;
  int activationFailures = 0;
  DateTime? lastActivationTime;
  int currentMemoryUsageMB = 0;
  int peakMemoryUsageMB = 0;

  PluginPerformanceMetrics({
    required this.pluginId,
    required this.pluginName,
    required this.startTime,
  });

  /// 是否为活跃插件
  bool get isActive => endTime == null;

  /// 激活成功率
  double get activationSuccessRate {
    if (activationCount == 0) return 1.0;
    return (activationCount - activationFailures) / activationCount;
  }

  /// 运行时长
  Duration? get runtime {
    if (endTime == null) {
      return DateTime.now().difference(startTime);
    }
    return endTime!.difference(startTime);
  }

  Map<String, dynamic> toJson() {
    return {
      'pluginId': pluginId,
      'pluginName': pluginName,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'initTime': initTime,
      'initSuccess': initSuccess,
      'activationCount': activationCount,
      'activationFailures': activationFailures,
      'activationSuccessRate': activationSuccessRate,
      'lastActivationTime': lastActivationTime?.toIso8601String(),
      'currentMemoryUsageMB': currentMemoryUsageMB,
      'peakMemoryUsageMB': peakMemoryUsageMB,
      'runtime': runtime?.inMilliseconds,
    };
  }
}

/// 插件性能事件
class PluginPerformanceEvent {
  final String pluginId;
  final PluginPerformanceEventType type;
  final PluginPerformanceMetrics metrics;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  PluginPerformanceEvent({
    required this.pluginId,
    required this.type,
    required this.metrics,
    this.data,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    return 'PluginPerformanceEvent($pluginId: $type)';
  }
}

/// 插件性能事件类型
enum PluginPerformanceEventType {
  initStarted,
  initCompleted,
  initFailed,
  slowInit,
  activated,
  activationFailed,
  deactivated,
  memoryUsage,
  highMemoryUsage,
  monitoringStopped,
}

/// 插件性能统计摘要
class PluginPerformanceSummary {
  final int totalPlugins;
  final int activePlugins;
  final int averageInitTimeMs;
  final int totalMemoryUsageMB;
  final int averageMemoryUsageMB;

  const PluginPerformanceSummary({
    required this.totalPlugins,
    required this.activePlugins,
    required this.averageInitTimeMs,
    required this.totalMemoryUsageMB,
    required this.averageMemoryUsageMB,
  });

  double get activationRate => totalPlugins > 0 ? activePlugins / totalPlugins : 0.0;
}