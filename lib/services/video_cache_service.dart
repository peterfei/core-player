import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/cache_entry.dart';
import '../models/cache_config.dart';

class VideoCacheService {
  static VideoCacheService? _instance;
  static VideoCacheService get instance {
    _instance ??= VideoCacheService._();
    return _instance!;
  }

  VideoCacheService._();

  late Box<CacheEntry> _cacheBox;
  late Directory _cacheDirectory;
  CacheConfig _config = const CacheConfig();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 初始化Hive
      await Hive.initFlutter();

      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(CacheEntryAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(CacheStrategyAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(CacheStatsAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(CacheConfigAdapter());
      }
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(DownloadProgressAdapter());
      }

      // 打开缓存数据库（带超时）
      _cacheBox = await Hive.openBox<CacheEntry>('video_cache')
          .timeout(Duration(seconds: 10));

      // 获取缓存目录
      final appDir = await getApplicationDocumentsDirectory()
          .timeout(Duration(seconds: 5));
      _cacheDirectory = Directory(path.join(appDir.path, 'video_cache'));

      if (!await _cacheDirectory.exists()) {
        await _cacheDirectory
            .create(recursive: true)
            .timeout(Duration(seconds: 5));
      }

      // 加载配置
      _config = await CacheConfig.load();

      // 执行自动清理（在后台进行，不阻塞初始化）
      if (_config.autoCleanup) {
        Future.microtask(() => _autoCleanup());
      }

      _initialized = true;
    } catch (e) {
      print('Failed to initialize VideoCacheService: $e');
      // 初始化失败时，标记为已初始化但禁用缓存功能
      _initialized = true;
      _config = const CacheConfig(isEnabled: false);
    }
  }

  String _generateCacheKey(String url) {
    // 移除查询参数中的时效性token
    final uri = Uri.parse(url);
    final cleanUrl = '${uri.scheme}://${uri.host}${uri.path}';
    return md5.convert(utf8.encode(cleanUrl)).toString();
  }

  Future<String?> getCachePath(String url) async {
    await _ensureInitialized();

    final cacheKey = _generateCacheKey(url);
    final entry = _cacheBox.get(cacheKey);

    if (entry != null &&
        entry.isComplete &&
        await File(entry.localPath).exists()) {
      entry.updateAccess();
      return entry.localPath;
    }

    return null;
  }

  Future<bool> hasCache(String url) async {
    await _ensureInitialized();
    return await getCachePath(url) != null;
  }

  Future<bool> hasPartialCache(String url) async {
    await _ensureInitialized();

    final cacheKey = _generateCacheKey(url);
    final entry = _cacheBox.get(cacheKey);

    if (entry != null && await File(entry.localPath).exists()) {
      return !entry.isComplete;
    }

    return false;
  }

  Future<CacheEntry?> getCacheEntry(String url) async {
    await _ensureInitialized();

    final cacheKey = _generateCacheKey(url);
    return _cacheBox.get(cacheKey);
  }

  Future<String> createCacheFile(String url, {String? title}) async {
    await _ensureInitialized();

    final cacheKey = _generateCacheKey(url);
    final fileName = '$cacheKey.mp4';
    final filePath = path.join(_cacheDirectory.path, fileName);

    // 创建缓存条目
    final entry = CacheEntry(
      id: cacheKey,
      url: url,
      localPath: filePath,
      fileSize: 0, // 将在下载完成时更新
      createdAt: DateTime.now(),
      lastAccessedAt: DateTime.now(),
      accessCount: 1,
      isComplete: false,
      downloadedBytes: 0,
      title: title ?? path.basenameWithoutExtension(Uri.parse(url).path),
    );

    await _cacheBox.put(cacheKey, entry);
    return filePath;
  }

  Future<void> updateCacheProgress(String url, int downloadedBytes,
      {int? totalBytes}) async {
    await _ensureInitialized();

    final cacheKey = _generateCacheKey(url);
    final entry = _cacheBox.get(cacheKey);

    if (entry != null) {
      final updatedEntry = CacheEntry(
        id: entry.id,
        url: entry.url,
        localPath: entry.localPath,
        fileSize: totalBytes ?? entry.fileSize,
        createdAt: entry.createdAt,
        lastAccessedAt: DateTime.now(),
        accessCount: entry.accessCount,
        isComplete: entry.isComplete,
        downloadedBytes: downloadedBytes,
        title: entry.title,
        thumbnail: entry.thumbnail,
        duration: entry.duration,
      );

      await _cacheBox.put(cacheKey, updatedEntry);
    }
  }

  Future<void> markCacheComplete(
    String url,
    int totalSize, {
    String? thumbnail,
    Duration? duration,
  }) async {
    await _ensureInitialized();

    final cacheKey = _generateCacheKey(url);
    final entry = _cacheBox.get(cacheKey);

    if (entry != null) {
      final completedEntry = CacheEntry(
        id: entry.id,
        url: entry.url,
        localPath: entry.localPath,
        fileSize: totalSize,
        createdAt: entry.createdAt,
        lastAccessedAt: DateTime.now(),
        accessCount: entry.accessCount + 1,
        isComplete: true,
        downloadedBytes: totalSize,
        title: entry.title,
        thumbnail: thumbnail,
        duration: duration,
      );

      await _cacheBox.put(cacheKey, completedEntry);
    }
  }

  Future<void> _autoCleanup() async {
    await _ensureInitialized();

    // 清理过期条目
    final cutoffDate =
        DateTime.now().subtract(Duration(days: _config.maxAgeDays));
    final expiredEntries = _cacheBox.values
        .where((entry) => entry.createdAt.isBefore(cutoffDate))
        .toList();

    for (final entry in expiredEntries) {
      await removeCache(entry.url);
    }

    // 如果缓存大小超过限制，执行LRU清理
    await _enforceSizeLimit();
  }

  Future<void> _enforceSizeLimit() async {
    await _ensureInitialized();

    final stats = await getStats();
    if (stats.totalSize <= _config.maxSizeBytes) return;

    // 按最后访问时间排序，删除最旧的条目
    final entries = _cacheBox.values.toList()
      ..sort((a, b) => a.lastAccessedAt.compareTo(b.lastAccessedAt));

    int removedSize = 0;
    for (final entry in entries) {
      await removeCache(entry.url);
      removedSize += entry.fileSize;

      if (stats.totalSize - removedSize <= _config.maxSizeBytes * 0.8) {
        break; // 清理到80%即可
      }
    }
  }

  Future<void> removeCache(String url) async {
    await _ensureInitialized();

    final cacheKey = _generateCacheKey(url);
    final entry = _cacheBox.get(cacheKey);

    if (entry != null) {
      try {
        final file = File(entry.localPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Failed to delete cache file: $e');
      }

      await _cacheBox.delete(cacheKey);
    }
  }

  Future<void> clearAllCache() async {
    await _ensureInitialized();

    // 删除所有缓存文件
    for (final entry in _cacheBox.values) {
      try {
        final file = File(entry.localPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Failed to delete cache file: $e');
      }
    }

    // 清空数据库
    await _cacheBox.clear();
  }

  Future<CacheStats> getStats() async {
    await _ensureInitialized();

    final entries = _cacheBox.values.toList();
    final totalEntries = entries.length;
    final totalSize =
        entries.fold<int>(0, (sum, entry) => sum + entry.downloadedBytes);
    final completedEntries = entries.where((entry) => entry.isComplete).length;
    final partialEntries = totalEntries - completedEntries;

    // 简化的命中率计算（实际应该统计访问次数）
    final hitRate = totalEntries > 0 ? completedEntries / totalEntries : 0.0;

    return CacheStats(
      totalEntries: totalEntries,
      totalSize: totalSize,
      completedEntries: completedEntries,
      partialEntries: partialEntries,
      hitRate: hitRate,
    );
  }

  Future<List<CacheEntry>> getAllCachedVideos() async {
    await _ensureInitialized();

    return _cacheBox.values.where((entry) => entry.isComplete).toList()
      ..sort((a, b) => b.lastAccessedAt.compareTo(a.lastAccessedAt));
  }

  Future<List<CacheEntry>> getPartialCachedVideos() async {
    await _ensureInitialized();

    return _cacheBox.values.where((entry) => !entry.isComplete).toList()
      ..sort((a, b) => b.lastAccessedAt.compareTo(a.lastAccessedAt));
  }

  Future<void> updateConfig(CacheConfig config) async {
    _config = config;
    await config.save();

    if (config.autoCleanup) {
      await _autoCleanup();
    }
  }

  CacheConfig get config => _config;

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
