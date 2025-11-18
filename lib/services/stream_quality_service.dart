import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/buffer_config.dart';
import '../models/network_stats.dart';
import 'bandwidth_monitor_service.dart';

/// 流质量服务
class StreamQualityService {
  static final StreamQualityService _instance =
      StreamQualityService._internal();
  factory StreamQualityService() => _instance;
  StreamQualityService._internal();

  final BandwidthMonitorService _bandwidthMonitor = BandwidthMonitorService();

  // 质量等级定义
  static const List<QualityLevel> _defaultQualities = [
    QualityLevel.p2160, // 4K
    QualityLevel.p1440, // 1440p
    QualityLevel.p1080, // 1080p
    QualityLevel.p720, // 720p
    QualityLevel.p480, // 480p
    QualityLevel.p360, // 360p
    QualityLevel.auto, // 自动
  ];

  List<QualityLevel> _availableQualities = [];
  QualityLevel _currentQuality = QualityLevel.auto;
  AbrAlgorithm _algorithm = AbrAlgorithm.dynamic;
  bool _autoMode = true;
  QualityLevel _maxQuality = QualityLevel.p1080;
  bool _hdOnlyOnWifi = true;

  // HLS/DASH 流信息
  String? _currentStreamUrl;
  StreamType _streamType = StreamType.unknown;
  Map<String, dynamic>? _streamManifest;

  // 事件控制
  final StreamController<QualityChangeEvent> _qualityChangeController =
      StreamController<QualityChangeEvent>.broadcast();

  /// 获取质量变化事件流
  Stream<QualityChangeEvent> get qualityChangeStream =>
      _qualityChangeController.stream;

  /// 获取可用质量列表
  List<QualityLevel> get availableQualities =>
      UnmodifiableListView(_availableQualities);

  /// 获取当前质量
  QualityLevel get currentQuality => _currentQuality;

  /// 获取当前算法
  AbrAlgorithm get algorithm => _algorithm;

  /// 是否自动模式
  bool get isAutoMode => _autoMode;

  /// 设置流URL并解析可用质量
  Future<void> setStreamUrl(String url) async {
    _currentStreamUrl = url;

    // 检测流类型
    _streamType = _detectStreamType(url);

    // 解析可用质量
    if (_streamType == StreamType.hls) {
      await _parseHlsManifest(url);
    } else if (_streamType == StreamType.dash) {
      await _parseDashManifest(url);
    } else {
      // 直接流视频，使用默认质量
      _availableQualities = List.from(_defaultQualities);
    }

    print('Stream quality service initialized for: $url');
    print(
        'Available qualities: ${_availableQualities.map((q) => q.name).join(', ')}');
  }

  /// 检测流类型
  StreamType _detectStreamType(String url) {
    final uri = Uri.parse(url.toLowerCase());

    if (uri.path.endsWith('.m3u8')) {
      return StreamType.hls;
    } else if (uri.path.endsWith('.mpd')) {
      return StreamType.dash;
    } else if (uri.hasQuery && uri.query.contains('m3u8')) {
      return StreamType.hls;
    } else if (uri.hasQuery && uri.query.contains('mpd')) {
      return StreamType.dash;
    } else {
      return StreamType.direct;
    }
  }

  /// 解析 HLS manifest
  Future<void> _parseHlsManifest(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch HLS manifest');
      }

      final manifest = response.body;
      _parseHlsContent(manifest, url);
    } catch (e) {
      print('Error parsing HLS manifest: $e');
      // 解析失败时使用默认质量
      _availableQualities = List.from(_defaultQualities);
    }
  }

  /// 解析 HLS 内容
  void _parseHlsContent(String content, String baseUrl) {
    final lines = content.split('\n');
    final qualities = <QualityLevel>{};

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // 查找分辨率信息
      if (line.startsWith('#EXT-X-STREAM-INF')) {
        String? resolution;
        int? bandwidth;

        // 解析带宽
        final bandwidthMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
        if (bandwidthMatch != null) {
          bandwidth = int.parse(bandwidthMatch.group(1)!);
        }

        // 解析分辨率
        final resolutionMatch =
            RegExp(r'RESOLUTION=(\d+x\d+)').firstMatch(line);
        if (resolutionMatch != null) {
          resolution = resolutionMatch.group(1);
        }

        if (resolution != null || bandwidth != null) {
          final quality = _determineQualityFromHls(resolution, bandwidth);
          if (quality != QualityLevel.auto) {
            qualities.add(quality);
          }
        }
      }
    }

    // 添加自动模式
    qualities.add(QualityLevel.auto);

    _availableQualities = qualities.toList()
      ..sort((a, b) => b.height.compareTo(a.height));
    _streamManifest = {
      'type': 'hls',
      'parsed': true,
      'qualities': qualities.length
    };
  }

  /// 根据 HLS 信息确定质量等级
  QualityLevel _determineQualityFromHls(String? resolution, int? bandwidth) {
    if (resolution != null) {
      final height = int.parse(resolution.split('x').last);

      if (height >= 2160) return QualityLevel.p2160;
      if (height >= 1440) return QualityLevel.p1440;
      if (height >= 1080) return QualityLevel.p1080;
      if (height >= 720) return QualityLevel.p720;
      if (height >= 480) return QualityLevel.p480;
      if (height >= 360) return QualityLevel.p360;
    }

    if (bandwidth != null) {
      if (bandwidth >= 20000000) return QualityLevel.p2160; // 20 Mbps
      if (bandwidth >= 10000000) return QualityLevel.p1440; // 10 Mbps
      if (bandwidth >= 5000000) return QualityLevel.p1080; // 5 Mbps
      if (bandwidth >= 2500000) return QualityLevel.p720; // 2.5 Mbps
      if (bandwidth >= 1000000) return QualityLevel.p480; // 1 Mbps
      if (bandwidth >= 500000) return QualityLevel.p360; // 0.5 Mbps
    }

    return QualityLevel.auto;
  }

  /// 解析 DASH manifest
  Future<void> _parseDashManifest(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch DASH manifest');
      }

      final manifest = response.body;
      _parseDashContent(manifest);
    } catch (e) {
      print('Error parsing DASH manifest: $e');
      // 解析失败时使用默认质量
      _availableQualities = List.from(_defaultQualities);
    }
  }

  /// 解析 DASH 内容
  void _parseDashContent(String content) {
    // 简化的 DASH 解析，实际项目中可能需要更复杂的解析
    final qualities = <QualityLevel>{};

    // 查找质量信息（简化版本）
    final qualityMatches =
        RegExp(r'qualityLevels=\[(.*?)\]').allMatches(content);

    for (var match in qualityMatches) {
      final qualityStr = match.group(1)!;
      // 解析质量等级并添加到列表
      // 这里需要根据实际的 DASH manifest 格式进行解析
    }

    // 添加默认质量
    _availableQualities = List.from(_defaultQualities);
    _streamManifest = {
      'type': 'dash',
      'parsed': true,
      'qualities': _availableQualities.length
    };
  }

  /// 设置 ABR 算法
  void setAbrAlgorithm(AbrAlgorithm algorithm) {
    _algorithm = algorithm;
  }

  /// 设置最大质量限制
  void setMaxQuality(QualityLevel maxQuality) {
    _maxQuality = maxQuality;
  }

  /// 设置仅 WiFi 高清
  void setHdOnlyOnWifi(bool hdOnlyOnWifi) {
    _hdOnlyOnWifi = hdOnlyOnWifi;
  }

  /// 手动设置质量
  void setQuality(QualityLevel quality) {
    if (_availableQualities.contains(quality)) {
      final previousQuality = _currentQuality;
      _currentQuality = quality;
      _autoMode = (quality == QualityLevel.auto);

      // 发送质量变化事件
      _qualityChangeController.add(QualityChangeEvent(
        previousQuality: previousQuality,
        currentQuality: quality,
        reason: ChangeReason.manual,
        timestamp: DateTime.now(),
      ));

      print('Quality set to: ${quality.name}');
    }
  }

  /// 自动选择质量
  void autoSelectQuality() {
    if (!_autoMode) return;

    final stats = _bandwidthMonitor.currentStats;
    QualityLevel selectedQuality;

    switch (_algorithm) {
      case AbrAlgorithm.throughput:
        selectedQuality = _selectByThroughput(stats);
        break;
      case AbrAlgorithm.bola:
        selectedQuality = _selectByBola(stats);
        break;
      case AbrAlgorithm.dynamic:
        selectedQuality = _selectByDynamic(stats);
        break;
    }

    // 应用质量限制
    selectedQuality = _applyQualityLimits(selectedQuality, stats);

    if (selectedQuality != _currentQuality) {
      final previousQuality = _currentQuality;
      _currentQuality = selectedQuality;

      // 发送质量变化事件
      _qualityChangeController.add(QualityChangeEvent(
        previousQuality: previousQuality,
        currentQuality: selectedQuality,
        reason: ChangeReason.adaptive,
        timestamp: DateTime.now(),
      ));

      print(
          'Auto-selected quality: ${selectedQuality.name} (${stats.currentBandwidth.toInt()} bps)');
    }
  }

  /// 基于吞吐量选择质量
  QualityLevel _selectByThroughput(NetworkStats stats) {
    final bandwidth = stats.currentBandwidth;

    // 选择不超过当前带宽70%的最高质量
    for (var quality in _defaultQualities) {
      if (quality == QualityLevel.auto) continue;
      if (quality.bitrate <= bandwidth * 0.7) {
        return quality;
      }
    }

    return QualityLevel.p360; // 默认最低质量
  }

  /// 基于 BOLA 算法选择质量
  QualityLevel _selectByBola(NetworkStats stats) {
    // BOLA 算法简化实现
    // 实际实现需要考虑缓冲区占用情况

    final bandwidth = stats.currentBandwidth;
    final stability = stats.stability;

    // 根据稳定性调整选择
    double bandwidthMultiplier = stability > 0.7 ? 0.8 : 0.6;

    for (var quality in _defaultQualities) {
      if (quality == QualityLevel.auto) continue;
      if (quality.bitrate <= bandwidth * bandwidthMultiplier) {
        return quality;
      }
    }

    return QualityLevel.p360;
  }

  /// 基于动态算法选择质量
  QualityLevel _selectByDynamic(NetworkStats stats) {
    final bandwidth = stats.currentBandwidth;
    final stability = stats.stability;
    final quality = stats.quality;

    // 结合多种因素的动态选择
    double effectiveBandwidth = bandwidth;

    // 根据网络质量调整
    switch (quality) {
      case NetworkQuality.excellent:
        effectiveBandwidth *= 0.9;
        break;
      case NetworkQuality.good:
        effectiveBandwidth *= 0.8;
        break;
      case NetworkQuality.moderate:
        effectiveBandwidth *= 0.6;
        break;
      case NetworkQuality.poor:
        effectiveBandwidth *= 0.4;
        break;
      case NetworkQuality.critical:
        effectiveBandwidth *= 0.3;
        break;
    }

    // 根据稳定性进一步调整
    effectiveBandwidth *= stability;

    // 选择合适的质量
    for (var quality in _defaultQualities) {
      if (quality == QualityLevel.auto) continue;
      if (quality.bitrate <= effectiveBandwidth) {
        return quality;
      }
    }

    return QualityLevel.p360;
  }

  /// 应用质量限制
  QualityLevel _applyQualityLimits(QualityLevel selected, NetworkStats stats) {
    // 应用最大质量限制
    if (selected.height > _maxQuality.height) {
      selected = _maxQuality;
    }

    // WiFi 限制检查（需要连接状态）
    if (_hdOnlyOnWifi && selected.height > 720) {
      // 这里需要检查实际连接类型
      // 暂时使用网络质量作为代理
      if (stats.quality.index > NetworkQuality.moderate.index) {
        selected = QualityLevel.p720;
      }
    }

    return selected;
  }

  /// 获取质量的构建 URL（用于实际切换）
  String? getQualityUrl(QualityLevel quality) {
    if (_currentStreamUrl == null || _streamType == StreamType.direct) {
      return _currentStreamUrl; // 直接流不支持质量切换
    }

    // HLS/DASH 质量切换逻辑
    // 这里需要根据实际的流媒体协议实现
    // 简化版本，实际需要更复杂的处理

    return _currentStreamUrl; // 临时返回原URL
  }

  /// 启动自动质量选择
  void startAutoQualitySelection() {
    _autoMode = true;

    // 定期执行自动质量选择
    Timer.periodic(const Duration(seconds: 5), (_) {
      if (_autoMode) {
        autoSelectQuality();
      }
    });
  }

  /// 停止自动质量选择
  void stopAutoQualitySelection() {
    _autoMode = false;
  }

  /// 获取质量统计信息
  Map<String, dynamic> getQualityStats() {
    return {
      'currentQuality': _currentQuality.name,
      'availableQualities': _availableQualities.map((q) => q.name).toList(),
      'autoMode': _autoMode,
      'algorithm': _algorithm.name,
      'maxQuality': _maxQuality.name,
      'hdOnlyOnWifi': _hdOnlyOnWifi,
      'streamType': _streamType.name,
      'streamUrl': _currentStreamUrl,
    };
  }

  /// 重置服务
  void reset() {
    _availableQualities.clear();
    _currentQuality = QualityLevel.auto;
    _autoMode = true;
    _currentStreamUrl = null;
    _streamType = StreamType.unknown;
    _streamManifest = null;
  }

  /// 销毁服务
  void dispose() {
    _qualityChangeController.close();
  }
}

/// 流类型
enum StreamType {
  unknown,
  direct, // 直接视频文件
  hls, // HTTP Live Streaming
  dash, // Dynamic Adaptive Streaming over HTTP
}

/// 质量变化事件
class QualityChangeEvent {
  final QualityLevel previousQuality;
  final QualityLevel currentQuality;
  final ChangeReason reason;
  final DateTime timestamp;

  const QualityChangeEvent({
    required this.previousQuality,
    required this.currentQuality,
    required this.reason,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'previousQuality': previousQuality.name,
      'currentQuality': currentQuality.name,
      'reason': reason.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'QualityChangeEvent: ${previousQuality.name} -> ${currentQuality.name} (${reason.name})';
  }
}

/// 质量变化原因
enum ChangeReason {
  manual, // 手动切换
  adaptive, // 自适应切换
  network, // 网络变化
  buffer, // 缓冲问题
}

/// 扩展 QualityLevel 枚举
extension QualityLevelExtension on QualityLevel {
  /// 获取显示名称
  String get displayName {
    switch (this) {
      case QualityLevel.auto:
        return '自动';
      case QualityLevel.p2160:
        return '4K';
      case QualityLevel.p1440:
        return '1440p';
      case QualityLevel.p1080:
        return '1080p';
      case QualityLevel.p720:
        return '720p';
      case QualityLevel.p480:
        return '480p';
      case QualityLevel.p360:
        return '360p';
    }
  }

  /// 获取质量描述
  String get description {
    switch (this) {
      case QualityLevel.auto:
        return '根据网络自动选择';
      case QualityLevel.p2160:
        return '超高清 (4K)';
      case QualityLevel.p1440:
        return '高清 (2K)';
      case QualityLevel.p1080:
        return '全高清 (FHD)';
      case QualityLevel.p720:
        return '高清 (HD)';
      case QualityLevel.p480:
        return '标清 (SD)';
      case QualityLevel.p360:
        return '流畅 (LD)';
    }
  }

  /// 获取比特率描述
  String get bitrateDescription {
    if (this == QualityLevel.auto) return '自适应';
    return formatBitrate(bitrate);
  }

  /// 获取图标
  IconData get icon {
    switch (this) {
      case QualityLevel.auto:
        return Icons.auto_fix_high;
      case QualityLevel.p2160:
        return Icons.hd_outlined;
      case QualityLevel.p1440:
        return Icons.high_quality;
      case QualityLevel.p1080:
        return Icons.hd;
      case QualityLevel.p720:
        return Icons.sd;
      case QualityLevel.p480:
        return Icons.sd_outlined;
      case QualityLevel.p360:
        return Icons.low_priority;
    }
  }
}
