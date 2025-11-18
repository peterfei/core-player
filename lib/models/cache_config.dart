import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cache_entry.dart';

part 'cache_config.g.dart';

@HiveType(typeId: 3)
class CacheConfig {
  @HiveField(0)
  final bool isEnabled;

  @HiveField(1)
  final int maxSizeBytes;

  @HiveField(2)
  final CacheStrategy strategy;

  @HiveField(3)
  final bool allowCellular;

  @HiveField(4)
  final bool autoCleanup;

  @HiveField(5)
  final int maxAgeDays;

  @HiveField(6)
  final int concurrentDownloads;

  @HiveField(7)
  final int chunkSizeKB;

  const CacheConfig({
    this.isEnabled = true,
    this.maxSizeBytes = 2 * 1024 * 1024 * 1024, // 2GB
    this.strategy = CacheStrategy.balanced,
    this.allowCellular = false,
    this.autoCleanup = true,
    this.maxAgeDays = 30,
    this.concurrentDownloads = 3,
    this.chunkSizeKB = 1024, // 1MB chunks
  });

  CacheConfig copyWith({
    bool? isEnabled,
    int? maxSizeBytes,
    CacheStrategy? strategy,
    bool? allowCellular,
    bool? autoCleanup,
    int? maxAgeDays,
    int? concurrentDownloads,
    int? chunkSizeKB,
  }) {
    return CacheConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      maxSizeBytes: maxSizeBytes ?? this.maxSizeBytes,
      strategy: strategy ?? this.strategy,
      allowCellular: allowCellular ?? this.allowCellular,
      autoCleanup: autoCleanup ?? this.autoCleanup,
      maxAgeDays: maxAgeDays ?? this.maxAgeDays,
      concurrentDownloads: concurrentDownloads ?? this.concurrentDownloads,
      chunkSizeKB: chunkSizeKB ?? this.chunkSizeKB,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'maxSizeBytes': maxSizeBytes,
      'strategy': strategy.index,
      'allowCellular': allowCellular,
      'autoCleanup': autoCleanup,
      'maxAgeDays': maxAgeDays,
      'concurrentDownloads': concurrentDownloads,
      'chunkSizeKB': chunkSizeKB,
    };
  }

  factory CacheConfig.fromJson(Map<String, dynamic> json) {
    return CacheConfig(
      isEnabled: json['isEnabled'] as bool? ?? true,
      maxSizeBytes: json['maxSizeBytes'] as int? ?? 2 * 1024 * 1024 * 1024,
      strategy: CacheStrategy.values[json['strategy'] as int? ?? 1],
      allowCellular: json['allowCellular'] as bool? ?? false,
      autoCleanup: json['autoCleanup'] as bool? ?? true,
      maxAgeDays: json['maxAgeDays'] as int? ?? 30,
      concurrentDownloads: json['concurrentDownloads'] as int? ?? 3,
      chunkSizeKB: json['chunkSizeKB'] as int? ?? 1024,
    );
  }

  static const String _prefKey = 'cache_config';

  static Future<CacheConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString(_prefKey);

    if (configJson != null) {
      try {
        final Map<String, dynamic> json = Map<String, dynamic>.from(
            // 简单的JSON解析，实际项目中建议使用dart:convert
            {});
        return CacheConfig.fromJson(json);
      } catch (e) {
        // 如果解析失败，返回默认配置
        return const CacheConfig();
      }
    }

    return const CacheConfig();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = toJson();
    // 实际项目中需要将configJson序列化为JSON字符串
    // await prefs.setString(_prefKey, jsonEncode(configJson));
  }
}

@HiveType(typeId: 4)
class DownloadProgress {
  @HiveField(0)
  final String url;

  @HiveField(1)
  final int downloadedBytes;

  @HiveField(2)
  final int totalBytes;

  @HiveField(3)
  final double speed; // bytes per second

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  final String? error;

  const DownloadProgress({
    required this.url,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.speed,
    required this.timestamp,
    this.error,
  });

  double get progressPercentage {
    if (totalBytes <= 0) return 0.0;
    return downloadedBytes / totalBytes;
  }

  bool get isComplete => downloadedBytes >= totalBytes && totalBytes > 0;

  bool get hasError => error != null;

  Duration get estimatedTimeRemaining {
    if (speed <= 0 || totalBytes <= 0) return Duration.zero;
    final remainingBytes = totalBytes - downloadedBytes;
    return Duration(seconds: (remainingBytes / speed).ceil());
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'downloadedBytes': downloadedBytes,
      'totalBytes': totalBytes,
      'speed': speed,
      'timestamp': timestamp.toIso8601String(),
      'error': error,
    };
  }
}
