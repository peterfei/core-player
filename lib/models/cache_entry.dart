import 'package:hive/hive.dart';

part 'cache_entry.g.dart';

@HiveType(typeId: 0)
class CacheEntry extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String url;

  @HiveField(2)
  final String localPath;

  @HiveField(3)
  final int fileSize;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  DateTime lastAccessedAt;

  @HiveField(6)
  int accessCount;

  @HiveField(7)
  bool isComplete;

  @HiveField(8)
  int downloadedBytes;

  @HiveField(9)
  final String? title;

  @HiveField(10)
  final String? thumbnail;

  @HiveField(11)
  final Duration? duration;

  CacheEntry({
    required this.id,
    required this.url,
    required this.localPath,
    required this.fileSize,
    required this.createdAt,
    required this.lastAccessedAt,
    required this.accessCount,
    required this.isComplete,
    required this.downloadedBytes,
    this.title,
    this.thumbnail,
    this.duration,
  });

  double get downloadProgress {
    if (fileSize <= 0) return 0.0;
    return downloadedBytes / fileSize;
  }

  bool get isFullyCached => isComplete && downloadedBytes >= fileSize;

  void updateAccess() {
    lastAccessedAt = DateTime.now();
    accessCount++;
    save();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'localPath': localPath,
      'fileSize': fileSize,
      'createdAt': createdAt.toIso8601String(),
      'lastAccessedAt': lastAccessedAt.toIso8601String(),
      'accessCount': accessCount,
      'isComplete': isComplete,
      'downloadedBytes': downloadedBytes,
      'title': title,
      'thumbnail': thumbnail,
      'duration': duration?.inSeconds,
    };
  }

  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      id: json['id'] as String,
      url: json['url'] as String,
      localPath: json['localPath'] as String,
      fileSize: json['fileSize'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAccessedAt: DateTime.parse(json['lastAccessedAt'] as String),
      accessCount: json['accessCount'] as int,
      isComplete: json['isComplete'] as bool,
      downloadedBytes: json['downloadedBytes'] as int,
      title: json['title'] as String?,
      thumbnail: json['thumbnail'] as String?,
      duration: json['duration'] != null
          ? Duration(seconds: json['duration'] as int)
          : null,
    );
  }
}

@HiveType(typeId: 1)
enum CacheStrategy {
  @HiveField(0)
  aggressive,
  @HiveField(1)
  balanced,
  @HiveField(2)
  conservative,
}

@HiveType(typeId: 2)
class CacheStats {
  @HiveField(0)
  final int totalEntries;

  @HiveField(1)
  final int totalSize;

  @HiveField(2)
  final int completedEntries;

  @HiveField(3)
  final int partialEntries;

  @HiveField(4)
  final double hitRate;

  const CacheStats({
    required this.totalEntries,
    required this.totalSize,
    required this.completedEntries,
    required this.partialEntries,
    required this.hitRate,
  });

  factory CacheStats.empty() {
    return const CacheStats(
      totalEntries: 0,
      totalSize: 0,
      completedEntries: 0,
      partialEntries: 0,
      hitRate: 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalEntries': totalEntries,
      'totalSize': totalSize,
      'completedEntries': completedEntries,
      'partialEntries': partialEntries,
      'hitRate': hitRate,
    };
  }
}