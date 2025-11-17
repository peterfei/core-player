import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'buffer_config.dart';

/// 带宽采样数据点
class BandwidthSample {
  final double bandwidth;      // 带宽 (bps)
  final DateTime timestamp;    // 采样时间
  final Duration responseTime; // 响应时间

  const BandwidthSample({
    required this.bandwidth,
    required this.timestamp,
    required this.responseTime,
  });
}

/// 网络统计数据
class NetworkStats {
  final double currentBandwidth;    // 当前带宽 (bps)
  final double averageBandwidth;    // 平均带宽
  final double peakBandwidth;       // 峰值带宽
  final double minBandwidth;        // 最低带宽
  final double stability;           // 稳定性 (0-1)
  final double packetLoss;          // 丢包率
  final int latency;                // 延迟 (ms)
  final NetworkQuality quality;     // 质量等级
  final DateTime timestamp;
  final ConnectivityResult? connectionType; // 连接类型
  final int totalSamples;           // 总采样数

  const NetworkStats({
    this.currentBandwidth = 0,
    this.averageBandwidth = 0,
    this.peakBandwidth = 0,
    this.minBandwidth = 0,
    this.stability = 0,
    this.packetLoss = 0,
    this.latency = 0,
    this.quality = NetworkQuality.critical,
    required this.timestamp,
    this.connectionType,
    this.totalSamples = 0,
  });

  NetworkStats copyWith({
    double? currentBandwidth,
    double? averageBandwidth,
    double? peakBandwidth,
    double? minBandwidth,
    double? stability,
    double? packetLoss,
    int? latency,
    NetworkQuality? quality,
    DateTime? timestamp,
    ConnectivityResult? connectionType,
    int? totalSamples,
  }) {
    return NetworkStats(
      currentBandwidth: currentBandwidth ?? this.currentBandwidth,
      averageBandwidth: averageBandwidth ?? this.averageBandwidth,
      peakBandwidth: peakBandwidth ?? this.peakBandwidth,
      minBandwidth: minBandwidth ?? this.minBandwidth,
      stability: stability ?? this.stability,
      packetLoss: packetLoss ?? this.packetLoss,
      latency: latency ?? this.latency,
      quality: quality ?? this.quality,
      timestamp: timestamp ?? this.timestamp,
      connectionType: connectionType ?? this.connectionType,
      totalSamples: totalSamples ?? this.totalSamples,
    );
  }

  /// 根据带宽评估网络质量
  static NetworkQuality assessQuality(double bandwidth, double stability) {
    // 考虑稳定性的质量评估
    final adjustedBandwidth = bandwidth * (0.5 + stability * 0.5);

    if (adjustedBandwidth > 10000000) return NetworkQuality.excellent; // >10 Mbps
    if (adjustedBandwidth > 5000000) return NetworkQuality.good;      // 5-10 Mbps
    if (adjustedBandwidth > 2000000) return NetworkQuality.moderate;   // 2-5 Mbps
    if (adjustedBandwidth > 1000000) return NetworkQuality.poor;       // 1-2 Mbps
    return NetworkQuality.critical;                                   // <1 Mbps
  }

  Map<String, dynamic> toJson() {
    return {
      'currentBandwidth': currentBandwidth,
      'averageBandwidth': averageBandwidth,
      'peakBandwidth': peakBandwidth,
      'minBandwidth': minBandwidth,
      'stability': stability,
      'packetLoss': packetLoss,
      'latency': latency,
      'quality': quality.name,
      'timestamp': timestamp.toIso8601String(),
      'connectionType': connectionType?.name,
      'totalSamples': totalSamples,
    };
  }

  factory NetworkStats.fromJson(Map<String, dynamic> json) {
    return NetworkStats(
      currentBandwidth: json['currentBandwidth']?.toDouble() ?? 0,
      averageBandwidth: json['averageBandwidth']?.toDouble() ?? 0,
      peakBandwidth: json['peakBandwidth']?.toDouble() ?? 0,
      minBandwidth: json['minBandwidth']?.toDouble() ?? 0,
      stability: json['stability']?.toDouble() ?? 0,
      packetLoss: json['packetLoss']?.toDouble() ?? 0,
      latency: json['latency'] ?? 0,
      quality: NetworkQuality.values.firstWhere(
        (e) => e.name == json['quality'],
        orElse: () => NetworkQuality.critical,
      ),
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      connectionType: json['connectionType'] != null
          ? ConnectivityResult.values.firstWhere(
              (e) => e.name == json['connectionType'],
            )
          : null,
      totalSamples: json['totalSamples'] ?? 0,
    );
  }
}

/// 带宽历史记录
class BandwidthHistory {
  final List<BandwidthSample> samples;
  final Duration maxAge;          // 保留的最大时间长度
  final int maxSamples;           // 最大样本数

  BandwidthHistory({
    List<BandwidthSample>? samples,
    this.maxAge = const Duration(minutes: 10),
    this.maxSamples = 1000,
  }) : samples = samples ?? [];

  /// 添加新的带宽样本
  void addSample(BandwidthSample sample) {
    samples.add(sample);

    // 移除过期样本
    final cutoff = DateTime.now().subtract(maxAge);
    samples.removeWhere((s) => s.timestamp.isBefore(cutoff));

    // 限制样本数量
    if (samples.length > maxSamples) {
      samples.removeRange(0, samples.length - maxSamples);
    }
  }

  /// 获取最近的样本
  List<BandwidthSample> getRecentSamples(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return samples.where((s) => s.timestamp.isAfter(cutoff)).toList();
  }

  /// 计算平均带宽
  double getAverageBandwidth({Duration window = const Duration(minutes: 5)}) {
    final recent = getRecentSamples(window);
    if (recent.isEmpty) return 0;

    return recent.map((s) => s.bandwidth).reduce((a, b) => a + b) / recent.length;
  }

  /// 计算稳定性指数 (基于标准差)
  double getStability({Duration window = const Duration(minutes: 5)}) {
    final recent = getRecentSamples(window);
    if (recent.length < 2) return 1.0;

    final avg = recent.map((s) => s.bandwidth).reduce((a, b) => a + b) / recent.length;
    final variance = recent.map((s) => pow(s.bandwidth - avg, 2)).reduce((a, b) => a + b) / recent.length;
    final stdDev = sqrt(variance);

    // 稳定性 = 1 - (标准差/平均值的比例)
    final stability = avg > 0 ? 1 - (stdDev / avg) : 0;
    return max(0.0, min(1.0, stability as double));
  }

  /// 获取峰值带宽
  double getPeakBandwidth({Duration window = const Duration(minutes: 5)}) {
    final recent = getRecentSamples(window);
    if (recent.isEmpty) return 0;

    return recent.map((s) => s.bandwidth).reduce(max);
  }

  /// 获取最低带宽
  double getMinBandwidth({Duration window = const Duration(minutes: 5)}) {
    final recent = getRecentSamples(window);
    if (recent.isEmpty) return 0;

    return recent.map((s) => s.bandwidth).reduce(min);
  }

  /// 清理旧数据
  void cleanup() {
    final cutoff = DateTime.now().subtract(maxAge);
    samples.removeWhere((s) => s.timestamp.isBefore(cutoff));

    if (samples.length > maxSamples) {
      samples.removeRange(0, samples.length - maxSamples);
    }
  }

  /// 清空所有数据
  void clear() {
    samples.clear();
  }
}

/// 缓冲事件记录
class BufferEvent {
  final BufferHealth health;
  final double bufferProgress;    // 0-100%
  final Duration bufferedDuration;
  final DateTime timestamp;
  final NetworkStats? networkStats;

  const BufferEvent({
    required this.health,
    required this.bufferProgress,
    required this.bufferedDuration,
    required this.timestamp,
    this.networkStats,
  });

  Map<String, dynamic> toJson() {
    return {
      'health': health.name,
      'bufferProgress': bufferProgress,
      'bufferedDurationMs': bufferedDuration.inMilliseconds,
      'timestamp': timestamp.toIso8601String(),
      'networkStats': networkStats?.toJson(),
    };
  }

  factory BufferEvent.fromJson(Map<String, dynamic> json) {
    return BufferEvent(
      health: BufferHealth.values.firstWhere(
        (e) => e.name == json['health'],
        orElse: () => BufferHealth.critical,
      ),
      bufferProgress: json['bufferProgress']?.toDouble() ?? 0,
      bufferedDuration: Duration(milliseconds: json['bufferedDurationMs'] ?? 0),
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      networkStats: json['networkStats'] != null
          ? NetworkStats.fromJson(json['networkStats'])
          : null,
    );
  }
}

/// 播放质量报告
class PlaybackQualityReport {
  final Duration totalPlayTime;
  final Duration totalBufferTime;
  final int bufferEventCount;
  final Duration averageBufferDuration;
  final List<QualityLevel> qualitySwitches;
  final NetworkStats networkStats;
  final double qualityScore;  // 0-100
  final DateTime startTime;
  final DateTime endTime;

  const PlaybackQualityReport({
    required this.totalPlayTime,
    required this.totalBufferTime,
    required this.bufferEventCount,
    required this.averageBufferDuration,
    required this.qualitySwitches,
    required this.networkStats,
    required this.qualityScore,
    required this.startTime,
    required this.endTime,
  });

  /// 计算重缓冲率 (每小时重缓冲次数)
  double get rebufferrate {
    final playHours = totalPlayTime.inMilliseconds / (1000 * 60 * 60);
    return playHours > 0 ? bufferEventCount / playHours : 0;
  }

  /// 计算播放流畅度 (无卡顿时间占比)
  double get playSmoothness {
    final totalDuration = totalPlayTime + totalBufferTime;
    if (totalDuration.inMilliseconds == 0) return 0;
    return (totalPlayTime.inMilliseconds / totalDuration.inMilliseconds) * 100;
  }

  /// 质量等级描述
  String get qualityGrade {
    if (qualityScore >= 95) return 'A+';
    if (qualityScore >= 90) return 'A';
    if (qualityScore >= 85) return 'B+';
    if (qualityScore >= 80) return 'B';
    if (qualityScore >= 70) return 'C';
    if (qualityScore >= 60) return 'D';
    return 'F';
  }

  Map<String, dynamic> toJson() {
    return {
      'totalPlayTimeMs': totalPlayTime.inMilliseconds,
      'totalBufferTimeMs': totalBufferTime.inMilliseconds,
      'bufferEventCount': bufferEventCount,
      'averageBufferDurationMs': averageBufferDuration.inMilliseconds,
      'qualitySwitches': qualitySwitches.map((q) => q.name).toList(),
      'networkStats': networkStats.toJson(),
      'qualityScore': qualityScore,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'rebufferRate': rebufferrate,
      'playSmoothness': playSmoothness,
      'qualityGrade': qualityGrade,
    };
  }

  factory PlaybackQualityReport.fromJson(Map<String, dynamic> json) {
    return PlaybackQualityReport(
      totalPlayTime: Duration(milliseconds: json['totalPlayTimeMs'] ?? 0),
      totalBufferTime: Duration(milliseconds: json['totalBufferTimeMs'] ?? 0),
      bufferEventCount: json['bufferEventCount'] ?? 0,
      averageBufferDuration: Duration(milliseconds: json['averageBufferDurationMs'] ?? 0),
      qualitySwitches: (json['qualitySwitches'] as List<dynamic>?)
          ?.map((q) => QualityLevel.values.firstWhere(
                (e) => e.name == q,
                orElse: () => QualityLevel.auto,
              ))
          .toList() ?? [],
      networkStats: NetworkStats.fromJson(json['networkStats'] ?? {}),
      qualityScore: json['qualityScore']?.toDouble() ?? 0,
      startTime: DateTime.parse(json['startTime'] ?? DateTime.now().toIso8601String()),
      endTime: DateTime.parse(json['endTime'] ?? DateTime.now().toIso8601String()),
    );
  }

  @override
  String toString() {
    return '''
播放质量报告
=============
播放时长: ${totalPlayTime.inMinutes.toStringAsFixed(1)} 分钟
缓冲时长: ${totalBufferTime.inSeconds.toStringAsFixed(1)} 秒
重缓冲次数: $bufferEventCount
重缓冲率: ${rebufferrate.toStringAsFixed(2)} 次/小时
播放流畅度: ${playSmoothness.toStringAsFixed(1)}%
质量切换次数: ${qualitySwitches.length}
网络质量: ${networkStats.quality.name}
综合评分: $qualityScore ($qualityGrade)
    ''';
  }
}

/// 连接状态管理
class ConnectionStatus {
  final ConnectionState state;
  final String message;
  final DateTime timestamp;
  final int retryCount;

  const ConnectionStatus({
    required this.state,
    required this.message,
    required this.timestamp,
    this.retryCount = 0,
  });

  ConnectionStatus copyWith({
    ConnectionState? state,
    String? message,
    DateTime? timestamp,
    int? retryCount,
  }) {
    return ConnectionStatus(
      state: state ?? this.state,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state.name,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'retryCount': retryCount,
    };
  }

  factory ConnectionStatus.fromJson(Map<String, dynamic> json) {
    return ConnectionStatus(
      state: ConnectionState.values.firstWhere(
        (e) => e.name == json['state'],
        orElse: () => ConnectionState.failed,
      ),
      message: json['message'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      retryCount: json['retryCount'] ?? 0,
    );
  }
}