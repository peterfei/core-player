import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:media_kit/media_kit.dart';
// system_info2有API问题，暂时禁用
// import 'package:system_info2/system_info2.dart';

/// 性能监控数据模型
class PerformanceMetrics {
  /// 时间戳
  final DateTime timestamp;

  /// 当前帧率
  final double fps;

  /// 目标帧率
  final double targetFps;

  /// 丢帧数量
  final int droppedFrames;

  /// 丢帧百分比
  final double droppedFramePercentage;

  /// CPU占用率（0-100）
  final double cpuUsage;

  /// 内存占用（MB）
  final double memoryUsage;

  /// GPU占用率（0-100，如果可用）
  final double gpuUsage;

  /// 缓冲进度（0-100）
  final double bufferPercentage;

  /// 缓冲时长（毫秒）
  final int bufferedMs;

  /// 解码器类型
  final String decoderType;

  /// 视频分辨率
  final String resolution;

  /// 网络带宽（bps，仅网络视频）
  final int? networkBandwidth;

  const PerformanceMetrics({
    required this.timestamp,
    required this.fps,
    required this.targetFps,
    required this.droppedFrames,
    required this.droppedFramePercentage,
    required this.cpuUsage,
    required this.memoryUsage,
    required this.gpuUsage,
    required this.bufferPercentage,
    required this.bufferedMs,
    required this.decoderType,
    required this.resolution,
    this.networkBandwidth,
  });

  /// 创建性能快照
  factory PerformanceMetrics.snapshot({
    required double fps,
    required double targetFps,
    required int droppedFrames,
    required double cpuUsage,
    required double memoryUsage,
    required double gpuUsage,
    required double bufferPercentage,
    required int bufferedMs,
    required String decoderType,
    required String resolution,
    int? networkBandwidth,
  }) {
    return PerformanceMetrics(
      timestamp: DateTime.now(),
      fps: fps,
      targetFps: targetFps,
      droppedFrames: droppedFrames,
      droppedFramePercentage: targetFps > 0
          ? (droppedFrames / (fps + droppedFrames)) * 100
          : 0.0,
      cpuUsage: cpuUsage,
      memoryUsage: memoryUsage,
      gpuUsage: gpuUsage,
      bufferPercentage: bufferPercentage,
      bufferedMs: bufferedMs,
      decoderType: decoderType,
      resolution: resolution,
      networkBandwidth: networkBandwidth,
    );
  }

  /// 是否性能良好
  bool get isGoodPerformance {
    return fps >= targetFps * 0.9 &&
           droppedFramePercentage <= 1.0 &&
           cpuUsage <= 80 &&
           bufferPercentage >= 20;
  }

  /// 是否性能优秀
  bool get isExcellentPerformance {
    return fps >= targetFps * 0.98 &&
           droppedFramePercentage <= 0.1 &&
           cpuUsage <= 50 &&
           bufferPercentage >= 50;
  }

  /// 是否性能差
  bool get isPoorPerformance {
    return fps < targetFps * 0.5 ||
           droppedFramePercentage >= 5.0 ||
           cpuUsage >= 90 ||
           bufferPercentage < 10;
  }

  /// 性能等级
  String get performanceLevel {
    if (isExcellentPerformance) return '优秀';
    if (isGoodPerformance) return '良好';
    if (isPoorPerformance) return '较差';
    return '一般';
  }

  /// 性能颜色
  String get performanceColor {
    if (isExcellentPerformance) return '#4CAF50'; // 绿色
    if (isGoodPerformance) return '#2196F3'; // 蓝色
    if (isPoorPerformance) return '#FF5722'; // 橙红色
    return '#FFC107'; // 黄色
  }

  @override
  String toString() {
    return 'PerformanceMetrics('
        'fps: ${fps.toStringAsFixed(1)}/${targetFps.toStringAsFixed(1)}, '
        'dropped: ${droppedFramePercentage.toStringAsFixed(1)}%, '
        'cpu: ${cpuUsage.toStringAsFixed(1)}%, '
        'memory: ${memoryUsage.toStringAsFixed(1)}MB'
        ')';
  }
}

/// 性能统计信息
class PerformanceStats {
  /// 平均帧率
  final double averageFps;

  /// 最高帧率
  final double maxFps;

  /// 最低帧率
  final double minFps;

  /// 总丢帧数
  final int totalDroppedFrames;

  /// 平均CPU占用
  final double averageCpuUsage;

  /// 峰值CPU占用
  final double maxCpuUsage;

  /// 平均内存占用
  final double averageMemoryUsage;

  /// 峰值内存占用
  final double maxMemoryUsage;

  /// 监控时长（秒）
  final int monitoringDuration;

  /// 性能问题数量
  final int performanceIssues;

  const PerformanceStats({
    required this.averageFps,
    required this.maxFps,
    required this.minFps,
    required this.totalDroppedFrames,
    required this.averageCpuUsage,
    required this.maxCpuUsage,
    required this.averageMemoryUsage,
    required this.maxMemoryUsage,
    required this.monitoringDuration,
    required this.performanceIssues,
  });

  @override
  String toString() {
    return 'PerformanceStats('
        'avgFps: ${averageFps.toStringAsFixed(1)}, '
        'maxFps: ${maxFps.toStringAsFixed(1)}, '
        'avgCpu: ${averageCpuUsage.toStringAsFixed(1)}%, '
        'issues: $performanceIssues'
        ')';
  }
}

/// 性能监控服务
/// 实时监控播放器性能指标
class PerformanceMonitorService {
  static PerformanceMonitorService? _instance;
  static PerformanceMonitorService get instance {
    _instance ??= PerformanceMonitorService._internal();
    return _instance!;
  }

  PerformanceMonitorService._internal();

  /// 当前播放器
  Player? _player;

  /// 监控状态
  bool _isMonitoring = false;

  /// 性能指标定时器
  Timer? _metricsTimer;

  /// 性能指标流
  final StreamController<PerformanceMetrics> _metricsController =
      StreamController<PerformanceMetrics>.broadcast();

  /// 统计数据
  final List<PerformanceMetrics> _metricsHistory = [];

  /// 系统信息缓存
  Map<String, dynamic>? _systemInfo;

  /// 监控间隔（毫秒）
  int _monitoringInterval = 1000;

  /// 上次帧数统计
  int _lastFrameCount = 0;

  /// 总丢帧数
  int _totalDroppedFrames = 0;

  /// 性能问题检测
  int _performanceIssueCount = 0;

  /// 监控开始时间
  DateTime? _monitoringStartTime;

  /// 性能指标流
  Stream<PerformanceMetrics> get metricsStream => _metricsController.stream;

  /// 当前性能指标
  PerformanceMetrics? get currentMetrics {
    return _metricsHistory.isEmpty ? null : _metricsHistory.last;
  }

  /// 是否正在监控
  bool get isMonitoring => _isMonitoring;

  /// 开始监控
  void startMonitoring(Player player, {int intervalMs = 1000}) {
    if (_isMonitoring) {
      stopMonitoring();
    }

    _player = player;
    _monitoringInterval = intervalMs;
    _isMonitoring = true;
    _monitoringStartTime = DateTime.now();
    _totalDroppedFrames = 0;
    _performanceIssueCount = 0;

    // 初始化系统信息
    _initializeSystemInfo();

    // 启动性能指标采集
    _metricsTimer = Timer.periodic(
      Duration(milliseconds: _monitoringInterval),
      (_) => _collectMetrics(),
    );

    print('性能监控已启动');
  }

  /// 停止监控
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _metricsTimer?.cancel();
    _metricsTimer = null;
    _player = null;

    print('性能监控已停止');
  }

  /// 设置监控间隔
  void setInterval(int intervalMs) {
    _monitoringInterval = intervalMs;

    if (_isMonitoring) {
      stopMonitoring();
      // 注意：这里无法直接重启，因为没有player引用
      // 调用者需要重新调用startMonitoring
    }
  }

  /// 获取性能统计
  PerformanceStats? getPerformanceStats() {
    if (_metricsHistory.isEmpty || _monitoringStartTime == null) {
      return null;
    }

    final fpsValues = _metricsHistory.map((m) => m.fps).toList();
    final cpuValues = _metricsHistory.map((m) => m.cpuUsage).toList();
    final memoryValues = _metricsHistory.map((m) => m.memoryUsage).toList();

    final averageFps = fpsValues.reduce((a, b) => a + b) / fpsValues.length;
    final maxFps = fpsValues.reduce(math.max);
    final minFps = fpsValues.reduce(math.min);
    final averageCpu = cpuValues.reduce((a, b) => a + b) / cpuValues.length;
    final maxCpu = cpuValues.reduce(math.max);
    final averageMemory = memoryValues.reduce((a, b) => a + b) / memoryValues.length;
    final maxMemory = memoryValues.reduce(math.max);

    final duration = DateTime.now().difference(_monitoringStartTime!).inSeconds;

    return PerformanceStats(
      averageFps: averageFps,
      maxFps: maxFps,
      minFps: minFps,
      totalDroppedFrames: _totalDroppedFrames,
      averageCpuUsage: averageCpu,
      maxCpuUsage: maxCpu,
      averageMemoryUsage: averageMemory,
      maxMemoryUsage: maxMemory,
      monitoringDuration: duration,
      performanceIssues: _performanceIssueCount,
    );
  }

  /// 获取性能报告
  Map<String, dynamic> getPerformanceReport() {
    final stats = getPerformanceStats();
    final current = currentMetrics;

    final report = {
      'timestamp': DateTime.now().toIso8601String(),
      'currentMetrics': current?.toJson(),
      'statistics': stats?.toJson(),
      'systemInfo': _systemInfo?.toJson(),
      'monitoringDuration': _monitoringStartTime != null
          ? DateTime.now().difference(_monitoringStartTime!).inSeconds
          : 0,
      'dataPoints': _metricsHistory.length,
    };

    return report;
  }

  /// 清除历史数据
  void clearHistory() {
    _metricsHistory.clear();
    _totalDroppedFrames = 0;
    _performanceIssueCount = 0;
    _monitoringStartTime = _isMonitoring ? DateTime.now() : null;
  }

  /// 限制历史数据大小
  void limitHistory({int maxDataPoints = 3600}) {
    if (_metricsHistory.length > maxDataPoints) {
      _metricsHistory.removeRange(0, _metricsHistory.length - maxDataPoints);
    }
  }

  /// 获取性能建议
  List<String> getPerformanceRecommendations() {
    final suggestions = <String>[];
    final current = currentMetrics;

    if (current == null) return suggestions;

    // CPU占用建议
    if (current.cpuUsage > 80) {
      suggestions.add('CPU占用过高，建议启用硬件加速');
    } else if (current.cpuUsage > 60) {
      suggestions.add('CPU占用较高，考虑降低视频质量');
    }

    // 内存占用建议
    if (current.memoryUsage > 1024) {
      suggestions.add('内存占用较高，减少预加载量');
    }

    // 帧率建议
    if (current.fps < current.targetFps * 0.8) {
      suggestions.add('帧率偏低，可能需要硬件加速');
    }

    // 丢帧建议
    if (current.droppedFramePercentage > 2) {
      suggestions.add('丢帧率过高，建议降低分辨率或启用硬件加速');
    }

    // 缓冲建议
    if (current.bufferPercentage < 20) {
      suggestions.add('缓冲不足，可能影响播放流畅度');
    }

    return suggestions;
  }

  /// 初始化系统信息
  Future<void> _initializeSystemInfo() async {
    try {
      if (!kIsWeb) {
        // TODO: 使用其他方式获取系统信息
        _systemInfo = {
          'platform': Platform.operatingSystem,
          'version': Platform.operatingSystemVersion,
          'architecture': Platform.operatingSystem,
        };
      }
    } catch (e) {
      print('获取系统信息失败: $e');
    }
  }

  /// 采集性能指标
  Future<void> _collectMetrics() async {
    try {
      final now = DateTime.now();
      final player = _player;
      if (player == null) return;

      // 获取基本播放状态
      final position = player.state.position;
      final duration = player.state.duration;
      final isPlaying = player.state.playing;

      // 计算帧率（这是一个估算）
      double currentFps = 0.0;
      double targetFps = 30.0; // 默认目标帧率

      if (isPlaying && duration.inMilliseconds > 0) {
        // 尝试从轨道信息获取帧率
        final tracks = player.state.tracks;
        if (tracks.video.isNotEmpty) {
          final videoTrack = tracks.video.first;
          if (videoTrack.fps != null && videoTrack.fps! > 0) {
            targetFps = videoTrack.fps!;
          }
        }

        // 估算当前帧率
        if (position.inMilliseconds > 0 && _lastFrameCount > 0) {
          // 这里是一个简化的估算，实际应该从播放器获取准确的帧率
          currentFps = targetFps;
        }
      }

      // 获取缓冲信息（如果可用）
      double bufferPercentage = 0.0;
      int bufferedMs = 0;

      // 获取解码器信息（这是模拟的，实际需要从播放器获取）
      String decoderType = 'Software'; // 默认软解

      // 获取分辨率信息
      String resolution = 'Unknown';
      final tracks = player.state.tracks;
      if (tracks.video.isNotEmpty) {
        // TODO: media_kit的VideoTrack API可能不同，需要查看实际API
        final videoTrack = tracks.video.first;
        resolution = 'Unknown'; // 暂时设置，需要获取实际分辨率
      }

      // 获取系统资源占用
      final cpuUsage = await _getCpuUsage();
      final memoryUsage = await _getMemoryUsage();
      final gpuUsage = await _getGpuUsage();

      // 计算丢帧（这是模拟的）
      int droppedFrames = 0;
      if (currentFps < targetFps * 0.9) {
        droppedFrames = ((targetFps - currentFps) * 0.1).round();
        _totalDroppedFrames += droppedFrames;
      }

      // 检测性能问题
      if (currentFps < targetFps * 0.5 || cpuUsage > 90) {
        _performanceIssueCount++;
      }

      // 创建性能指标
      final metrics = PerformanceMetrics.snapshot(
        fps: currentFps,
        targetFps: targetFps,
        droppedFrames: droppedFrames,
        cpuUsage: cpuUsage,
        memoryUsage: memoryUsage,
        gpuUsage: gpuUsage,
        bufferPercentage: bufferPercentage,
        bufferedMs: bufferedMs,
        decoderType: decoderType,
        resolution: resolution,
      );

      // 添加到历史记录
      _metricsHistory.add(metrics);

      // 限制历史记录大小
      limitHistory();

      // 发送到流
      if (!_metricsController.isClosed) {
        _metricsController.add(metrics);
      }

    } catch (e) {
      print('采集性能指标失败: $e');
    }
  }

  /// 获取CPU占用率
  Future<double> _getCpuUsage() async {
    try {
      if (kIsWeb) {
        return 0.0; // Web平台无法获取CPU占用
      }

      // 使用系统信息API获取CPU占用
      if (_systemInfo != null) {
        // TODO: 实现实际的CPU占用检测
        // 这里返回模拟值
        return 30.0 + math.Random().nextDouble() * 20.0; // 30-50%
      }

      return 0.0;
    } catch (e) {
      print('获取CPU占用失败: $e');
      return 0.0;
    }
  }

  /// 获取内存占用
  Future<double> _getMemoryUsage() async {
    try {
      if (kIsWeb) {
        return 0.0; // Web平台无法获取内存占用
      }

      // TODO: 实现实际的内存占用检测
      // 暂时返回模拟值
      return 100.0 + math.Random().nextDouble() * 200.0; // 100-300MB
    } catch (e) {
      print('获取内存占用失败: $e');
      return 0.0;
    }
  }

  /// 获取GPU占用
  Future<double> _getGpuUsage() async {
    try {
      if (kIsWeb) {
        return 0.0; // Web平台无法获取GPU占用
      }

      // TODO: 实现实际的GPU占用检测
      // 这是一个复杂的功能，需要平台特定实现
      return 20.0 + math.Random().nextDouble() * 30.0; // 模拟值
    } catch (e) {
      print('获取GPU占用失败: $e');
      return 0.0;
    }
  }

  /// 销毁服务
  void dispose() {
    stopMonitoring();
    _metricsController.close();
  }
}

/// 扩展方法
extension PerformanceMetricsExtension on PerformanceMetrics {
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'fps': fps,
      'targetFps': targetFps,
      'droppedFrames': droppedFrames,
      'droppedFramePercentage': droppedFramePercentage,
      'cpuUsage': cpuUsage,
      'memoryUsage': memoryUsage,
      'gpuUsage': gpuUsage,
      'bufferPercentage': bufferPercentage,
      'bufferedMs': bufferedMs,
      'decoderType': decoderType,
      'resolution': resolution,
      'networkBandwidth': networkBandwidth,
    };
  }
}

extension PerformanceStatsExtension on PerformanceStats {
  Map<String, dynamic> toJson() {
    return {
      'averageFps': averageFps,
      'maxFps': maxFps,
      'minFps': minFps,
      'totalDroppedFrames': totalDroppedFrames,
      'averageCpuUsage': averageCpuUsage,
      'maxCpuUsage': maxCpuUsage,
      'averageMemoryUsage': averageMemoryUsage,
      'maxMemoryUsage': maxMemoryUsage,
      'monitoringDuration': monitoringDuration,
      'performanceIssues': performanceIssues,
    };
  }
}