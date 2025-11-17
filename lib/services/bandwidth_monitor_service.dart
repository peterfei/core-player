import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/network_stats.dart';
import '../models/buffer_config.dart';

/// 带宽监控服务
class BandwidthMonitorService {
  static final BandwidthMonitorService _instance = BandwidthMonitorService._internal();
  factory BandwidthMonitorService() => _instance;
  BandwidthMonitorService._internal();

  final BandwidthHistory _history = BandwidthHistory();
  final StreamController<NetworkStats> _statsController = StreamController<NetworkStats>.broadcast();
  Timer? _monitoringTimer;
  Timer? _samplingTimer;
  bool _isMonitoring = false;

  // 配置参数
  static const Duration _monitoringInterval = Duration(seconds: 2);   // 监控间隔
  static const Duration _samplingInterval = Duration(seconds: 5);     // 采样间隔
  static const Duration _testDuration = Duration(seconds: 2);         // 测试下载时长
  static const String _testUrl = 'https://httpbin.org/bytes/1048576'; // 1MB 测试文件
  static const int _testFileSize = 1048576; // 1MB

  /// 获取网络统计流
  Stream<NetworkStats> get networkStatsStream => _statsController.stream;

  /// 开始监控
  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;

    // 立即执行一次带宽测试
    _performBandwidthTest();

    // 定期执行带宽测试
    _samplingTimer = Timer.periodic(_samplingInterval, (_) {
      _performBandwidthTest();
    });

    // 定期更新网络统计
    _monitoringTimer = Timer.periodic(_monitoringInterval, (_) {
      _updateNetworkStats();
    });
  }

  /// 停止监控
  void stopMonitoring() {
    _isMonitoring = false;
    _samplingTimer?.cancel();
    _samplingTimer = null;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  /// 是否正在监控
  bool get isMonitoring => _isMonitoring;

  /// 获取当前网络统计
  NetworkStats get currentStats {
    final now = DateTime.now();
    final recent = _history.getRecentSamples(const Duration(minutes: 5));
    final current = recent.isNotEmpty ? recent.last : null;

    if (current == null) {
      return NetworkStats(timestamp: now);
    }

    final avgBandwidth = _history.getAverageBandwidth();
    final peakBandwidth = _history.getPeakBandwidth();
    final minBandwidth = _history.getMinBandwidth();
    final stability = _history.getStability();

    final quality = NetworkStats.assessQuality(avgBandwidth, stability);

    return NetworkStats(
      currentBandwidth: current.bandwidth,
      averageBandwidth: avgBandwidth,
      peakBandwidth: peakBandwidth,
      minBandwidth: minBandwidth,
      stability: stability,
      quality: quality,
      timestamp: now,
      totalSamples: recent.length,
    );
  }

  /// 执行带宽测试
  Future<void> _performBandwidthTest() async {
    try {
      // 检查网络连接
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        return;
      }

      final stopwatch = Stopwatch()..start();
      final response = await http.get(
        Uri.parse(_testUrl),
      ).timeout(const Duration(seconds: 10));

      stopwatch.stop();
      final downloadTime = stopwatch.elapsed;

      if (response.statusCode == 200 && downloadTime.inMilliseconds > 0) {
        // 计算带宽 (bits per second)
        final bandwidth = (_testFileSize * 8) / downloadTime.inMilliseconds * 1000;

        // 添加样本到历史记录
        final sample = BandwidthSample(
          bandwidth: bandwidth,
          timestamp: DateTime.now(),
          responseTime: downloadTime,
        );
        _history.addSample(sample);
      }
    } catch (e) {
      print('Bandwidth test failed: $e');
    }
  }

  /// 更新网络统计并发送事件
  void _updateNetworkStats() {
    final stats = currentStats;
    _statsController.add(stats);
  }

  /// 获取滑动窗口平均带宽
  double get averageBandwidth => _history.getAverageBandwidth();

  /// 获取带宽稳定性指数 (0-1)
  double get stabilityIndex => _history.getStability();

  /// 基于历史数据预测带宽
  double predictBandwidth(Duration ahead) {
    final recent = _history.getRecentSamples(const Duration(minutes: 5));
    if (recent.length < 3) {
      return averageBandwidth;
    }

    // 使用 EWMA (指数加权移动平均) 进行预测
    return _calculateEWMA(recent);
  }

  /// EWMA 算法实现
  double _calculateEWMA(List<BandwidthSample> samples) {
    if (samples.isEmpty) return 0;

    const double alpha = 0.3; // 平滑因子
    double ewma = samples.first.bandwidth;

    for (var sample in samples.skip(1)) {
      ewma = alpha * sample.bandwidth + (1 - alpha) * ewma;
    }

    return ewma;
  }

  /// 评估网络质量
  NetworkQuality assessNetworkQuality() {
    final stats = currentStats;
    return stats.quality;
  }

  /// 获取连接类型描述
  static String getConnectionTypeDescription(ConnectivityResult? result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return '移动网络';
      case ConnectivityResult.ethernet:
        return '有线网络';
      case ConnectivityResult.bluetooth:
        return '蓝牙';
      case ConnectivityResult.none:
        return '无网络';
      case ConnectivityResult.other:
        return '其他';
      default:
        return '未知';
    }
  }

  /// 检测网络是否稳定
  bool isNetworkStable() {
    final stability = stabilityIndex;
    final avgBandwidth = averageBandwidth;

    // 稳定性 > 0.7 且平均带宽 > 1 Mbps
    return stability > 0.7 && avgBandwidth > 1000000;
  }

  /// 获取建议的缓冲大小
  int getRecommendedBufferSize() {
    final stats = currentStats;
    final quality = stats.quality;

    return switch (quality) {
      NetworkQuality.excellent => 20,   // 20 MB
      NetworkQuality.good => 30,        // 30 MB
      NetworkQuality.moderate => 50,    // 50 MB
      NetworkQuality.poor => 80,        // 80 MB
      NetworkQuality.critical => 100,   // 100 MB
    };
  }

  /// 获取建议的预缓冲时长
  Duration getRecommendedPrebufferDuration() {
    final stats = currentStats;
    final quality = stats.quality;

    return switch (quality) {
      NetworkQuality.excellent => const Duration(seconds: 5),
      NetworkQuality.good => const Duration(seconds: 10),
      NetworkQuality.moderate => const Duration(seconds: 15),
      NetworkQuality.poor => const Duration(seconds: 20),
      NetworkQuality.critical => const Duration(seconds: 30),
    };
  }

  /// 清理历史数据
  void cleanup() {
    _history.cleanup();
  }

  /// 重置监控数据
  void reset() {
    stopMonitoring();
    _history.clear();
  }

  /// 诊断网络连接
  Future<Map<String, dynamic>> diagnoseNetwork() async {
    final connectivity = await Connectivity().checkConnectivity();
    final stats = currentStats;

    final diagnosis = <String, dynamic>{
      'connectionType': connectivity.name,
      'connectionDescription': getConnectionTypeDescription(connectivity),
      'currentBandwidth': stats.currentBandwidth,
      'averageBandwidth': stats.averageBandwidth,
      'peakBandwidth': stats.peakBandwidth,
      'stability': stats.stability,
      'quality': stats.quality.name,
      'totalSamples': stats.totalSamples,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // 执行快速测试
    try {
      final testStart = DateTime.now();
      final response = await http.get(
        Uri.parse('https://httpbin.org/delay/0'),
      ).timeout(const Duration(seconds: 5));
      final testEnd = DateTime.now();

      diagnosis['testSuccessful'] = response.statusCode == 200;
      diagnosis['responseTime'] = testEnd.difference(testStart).inMilliseconds;
    } catch (e) {
      diagnosis['testSuccessful'] = false;
      diagnosis['error'] = e.toString();
    }

    return diagnosis;
  }

  /// 获取推荐的画质
  QualityLevel getRecommendedQuality({bool preferQuality = false}) {
    final stats = currentStats;
    final bandwidth = stats.averageBandwidth;

    if (preferQuality) {
      // 偏向质量的推荐
      if (bandwidth > 15000000) return QualityLevel.p1440;  // 15 Mbps
      if (bandwidth > 8000000) return QualityLevel.p1080;   // 8 Mbps
      if (bandwidth > 4000000) return QualityLevel.p720;    // 4 Mbps
      if (bandwidth > 2000000) return QualityLevel.p480;    // 2 Mbps
      return QualityLevel.p360;
    } else {
      // 偏向流畅的推荐
      if (bandwidth > 20000000) return QualityLevel.p1440;  // 20 Mbps
      if (bandwidth > 10000000) return QualityLevel.p1080;   // 10 Mbps
      if (bandwidth > 5000000) return QualityLevel.p720;     // 5 Mbps
      if (bandwidth > 2500000) return QualityLevel.p480;     // 2.5 Mbps
      return QualityLevel.p360;
    }
  }

  @override
  String toString() {
    final stats = currentStats;
    return '''
BandwidthMonitorService Status:
- Monitoring: $_isMonitoring
- Current Bandwidth: ${formatSpeed(stats.currentBandwidth)}
- Average Bandwidth: ${formatSpeed(stats.averageBandwidth)}
- Peak Bandwidth: ${formatSpeed(stats.peakBandwidth)}
- Stability: ${(stats.stability * 100).toStringAsFixed(1)}%
- Quality: ${stats.quality.name}
- Total Samples: ${stats.totalSamples}
    ''';
  }

  /// 销毁服务
  void dispose() {
    stopMonitoring();
    _statsController.close();
  }
}