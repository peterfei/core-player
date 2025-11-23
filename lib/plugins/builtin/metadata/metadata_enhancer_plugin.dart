import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/plugin_system/core_plugin.dart';
import '../../../core/plugin_system/plugin_interface.dart';

/// 元数据增强插件
///
/// 功能：
/// - 自动获取视频元数据（TMDB、IMDB等）
/// - 本地元数据缓存
/// - 元数据批量处理
/// - 多语言支持
/// - 海报和剧照下载
/// - 剧集和季信息管理
/// - 评分和评论系统
class MetadataEnhancerPlugin extends CorePlugin {
  static final _metadata = PluginMetadata(
    id: 'coreplayer.metadata_enhancer',
    name: '元数据增强插件',
    version: '1.0.0',
    description: '自动获取和丰富视频文件的元数据信息，支持多种数据源和本地缓存',
    author: 'CorePlayer Team',
    icon: Icons.info,
    capabilities: ['metadata_fetching', 'local_cache', 'poster_download', 'multi_language'],
    license: PluginLicense.bsd,
  );

  /// 插件内部状态
  PluginState _internalState = PluginState.uninitialized;

  /// 元数据缓存
  final Map<String, MediaMetadata> _cache = {};

  /// 支持的元数据源
  final List<MetadataSource> _sources = [];

  /// 缓存大小限制
  static const int _maxCacheSize = 1000;

  /// HTTP客户端
  late final http.Client _httpClient;

  MetadataEnhancerPlugin();

  @override
  PluginMetadata get metadata => _metadata;

  @override
  PluginState get state => _internalState;

  @override
  void setStateInternal(PluginState newState) {
    _internalState = newState;
  }

  @override
  Future<void> onInitialize() async {
    // 初始化HTTP客户端
    _httpClient = http.Client();

    // 注册元数据源
    await _registerMetadataSources();

    // 加载缓存数据
    await _loadCache();

    setStateInternal(PluginState.initialized);
    print('MetadataEnhancerPlugin initialized');
  }

  @override
  Future<void> onActivate() async {
    setStateInternal(PluginState.active);
    print('MetadataEnhancerPlugin activated - Metadata enhancement enabled');
  }

  @override
  Future<void> onDeactivate() async {
    await _saveCache();
    setStateInternal(PluginState.ready);
    print('MetadataEnhancerPlugin deactivated');
  }

  @override
  void onDispose() {
    _httpClient.close();
    _cache.clear();
    _sources.clear();
    setStateInternal(PluginState.disposed);
  }

  @override
  Future<bool> healthCheck() async {
    try {
      // 测试网络连接和基本功能
      await _testMetadataConnection();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 注册元数据源
  Future<void> _registerMetadataSources() async {
    _sources.addAll([
      TMDBMetadataSource(_httpClient),
      OMDbMetadataSource(_httpClient),
      LocalMetadataSource(),
    ]);
  }

  /// 加载缓存数据
  Future<void> _loadCache() async {
    try {
      // 实际实现会从本地存储加载
      if (kDebugMode) {
        print('Loading metadata cache...');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load metadata cache: $e');
      }
    }
  }

  /// 保存缓存数据
  Future<void> _saveCache() async {
    try {
      // 实际实现会保存到本地存储
      if (kDebugMode) {
        print('Saving metadata cache...');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save metadata cache: $e');
      }
    }
  }

  /// 测试元数据连接
  Future<void> _testMetadataConnection() async {
    // 实际实现会测试各数据源的连接
    final source = _sources.first;
    if (source is OnlineMetadataSource) {
      await source.testConnection();
    }
  }

  /// 获取媒体元数据
  Future<MediaMetadata> getMetadata({
    required String mediaType,
    required String title,
    int? year,
    String? imdbId,
    String? tmdbId,
    String language = 'zh-CN',
    bool forceRefresh = false,
  }) async {
    // 生成缓存键
    final cacheKey = _generateCacheKey(mediaType, title, year, imdbId, tmdbId, language);

    // 检查缓存
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final cachedMetadata = _cache[cacheKey]!;
      if (_isCacheValid(cachedMetadata)) {
        return cachedMetadata;
      }
    }

    // 从数据源获取
    MediaMetadata? metadata;
    for (final source in _sources) {
      try {
        metadata = await source.searchMetadata(
          mediaType: mediaType,
          title: title,
          year: year,
          imdbId: imdbId,
          tmdbId: tmdbId,
          language: language,
        );

        if (metadata != null) {
          // 获取详细信息
          metadata = await source.getDetailedMetadata(metadata, language);
          break;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching from ${source.name}: $e');
        }
        continue;
      }
    }

    // 如果没有找到，创建基本元数据
    metadata ??= _createBasicMetadata(mediaType, title, year);

    // 更新缓存
    await _updateCache(cacheKey, metadata);

    return metadata;
  }

  /// 批量获取元数据
  Future<List<MediaMetadata>> getBatchMetadata(List<MetadataRequest> requests) async {
    final results = <MediaMetadata>[];

    // 并发处理请求
    final futures = requests.map((request) async {
      try {
        return await getMetadata(
          mediaType: request.mediaType,
          title: request.title,
          year: request.year,
          imdbId: request.imdbId,
          tmdbId: request.tmdbId,
          language: request.language,
          forceRefresh: request.forceRefresh,
        );
      } catch (e) {
        if (kDebugMode) {
          print('Error processing batch request: $e');
        }
        return null;
      }
    });

    final responses = await Future.wait(futures);

    for (final metadata in responses) {
      if (metadata != null) {
        results.add(metadata);
      }
    }

    return results;
  }

  /// 搜索媒体
  Future<List<MediaMetadata>> searchMedia({
    required String query,
    required String mediaType,
    int year,
    String language = 'zh-CN',
    int limit = 20,
  }) async {
    final results = <MediaMetadata>[];

    for (final source in _sources) {
      try {
        final searchResults = await source.search(
          query: query,
          mediaType: mediaType,
          year: year,
          language: language,
          limit: limit,
        );
        results.addAll(searchResults);
      } catch (e) {
        if (kDebugMode) {
          print('Error searching in ${source.name}: $e');
        }
      }
    }

    // 去重并限制结果数量
    final uniqueResults = <String, MediaMetadata>{};
    for (final metadata in results) {
      final key = metadata.imdbId ?? metadata.tmdbId ?? '${metadata.title}_${metadata.year}';
      uniqueResults[key] = metadata;
    }

    return uniqueResults.values.take(limit).toList();
  }

  /// 下载海报
  Future<String?> downloadPoster(MediaMetadata metadata, String quality) async {
    for (final source in _sources) {
      if (source is OnlineMetadataSource) {
        try {
          final posterUrl = await source.getPosterUrl(metadata, quality);
          if (posterUrl != null) {
            final localPath = await _downloadImage(posterUrl, metadata.id, 'poster');
            return localPath;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error downloading poster from ${source.name}: $e');
          }
        }
      }
    }
    return null;
  }

  /// 下载剧照
  Future<List<String>> downloadBackdrops(MediaMetadata metadata, int limit) async {
    final backdropUrls = <String>[];

    for (final source in _sources) {
      if (source is OnlineMetadataSource) {
        try {
          final urls = await source.getBackdropUrls(metadata, limit);
          backdropUrls.addAll(urls);
        } catch (e) {
          if (kDebugMode) {
            print('Error getting backdrop URLs from ${source.name}: $e');
          }
        }
      }
    }

    final backdropPaths = <String>[];
    for (int i = 0; i < math.min(backdropUrls.length, limit); i++) {
      try {
        final path = await _downloadImage(backdropUrls[i], metadata.id, 'backdrop_$i');
        backdropPaths.add(path);
      } catch (e) {
        if (kDebugMode) {
          print('Error downloading backdrop $i: $e');
        }
      }
    }

    return backdropPaths;
  }

  /// 下载图片
  Future<String> _downloadImage(String url, String mediaId, String imageType) async {
    // 实际实现会下载图片并保存到本地
    // 这里是简化实现
    final response = await _httpClient.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final directory = Directory.systemTemp;
      final fileName = '${mediaId}_${imageType}.jpg';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    }
    throw Exception('Failed to download image: $url');
  }

  /// 生成缓存键
  String _generateCacheKey(
    String mediaType,
    String title,
    int? year,
    String? imdbId,
    String? tmdbId,
    String language,
  ) {
    final parts = [
      mediaType,
      title,
      year?.toString() ?? '',
      imdbId ?? '',
      tmdbId ?? '',
      language,
    ];
    return parts.join('|').toLowerCase().hashCode.toString();
  }

  /// 检查缓存是否有效
  bool _isCacheValid(MediaMetadata metadata) {
    final now = DateTime.now();
    final cacheAge = now.difference(metadata.lastUpdated);
    return cacheAge.inDays < 30; // 30天缓存期
  }

  /// 更新缓存
  Future<void> _updateCache(String key, MediaMetadata metadata) async {
    _cache[key] = metadata;

    // 检查缓存大小
    if (_cache.length > _maxCacheSize) {
      _cleanupCache();
    }

    // 异步保存缓存
    unawaited(_saveCache());
  }

  /// 清理缓存
  void _cleanupCache() {
    final entries = _cache.entries.toList()
      ..sort((a, b) => a.value.lastUpdated.compareTo(b.value.lastUpdated));

    // 删除最旧的条目
    final toRemove = entries.length - _maxCacheSize;
    for (int i = 0; i < toRemove; i++) {
      _cache.remove(entries[i].key);
    }
  }

  /// 创建基本元数据
  MediaMetadata _createBasicMetadata(String mediaType, String title, int? year) {
    return MediaMetadata(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      mediaType: mediaType,
      title: title,
      year: year,
      lastUpdated: DateTime.now(),
    );
  }

  /// 获取缓存统计
  MetadataCacheStats getCacheStats() {
    final now = DateTime.now();
    var totalSize = 0;
    var expiredCount = 0;

    for (final metadata in _cache.values) {
      totalSize += _calculateMetadataSize(metadata);
      if (now.difference(metadata.lastUpdated).inDays > 30) {
        expiredCount++;
      }
    }

    return MetadataCacheStats(
      totalEntries: _cache.length,
      expiredEntries: expiredCount,
      estimatedSize: totalSize,
      lastCleanup: DateTime.now(), // 简化实现
    );
  }

  /// 计算元数据大小
  int _calculateMetadataSize(MediaMetadata metadata) {
    // 简化实现，实际应该计算序列化后的大小
    return 1024; // 1KB估算
  }

  /// 清理过期缓存
  Future<void> cleanupExpiredCache() async {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _cache.entries) {
      if (now.difference(entry.value.lastUpdated).inDays > 30) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _cache.remove(key);
    }

    await _saveCache();

    if (kDebugMode) {
      print('Cleaned up ${expiredKeys.length} expired cache entries');
    }
  }

  /// 导出元数据
  Future<Map<String, dynamic>> exportMetadata(String mediaId) async {
    final metadata = _cache.values.firstWhere(
      (m) => m.id == mediaId,
      orElse: () => throw Exception('Metadata not found: $mediaId'),
    );

    return {
      'version': '1.0.0',
      'metadata': metadata.toJson(),
      'exportDate': DateTime.now().toIso8601String(),
    };
  }

  /// 导入元数据
  Future<void> importMetadata(Map<String, dynamic> data) async {
    try {
      final metadataData = data['metadata'];
      if (metadataData != null) {
        final metadata = MediaMetadata.fromJson(metadataData);
        final cacheKey = _generateCacheKey(
          metadata.mediaType,
          metadata.title,
          metadata.year,
          metadata.imdbId,
          metadata.tmdbId,
          'zh-CN',
        );
        await _updateCache(cacheKey, metadata);
      }
    } catch (e) {
      throw Exception('导入元数据失败: $e');
    }
  }
}

/// 元数据请求
class MetadataRequest {
  final String mediaType;
  final String title;
  final int? year;
  final String? imdbId;
  final String? tmdbId;
  final String language;
  final bool forceRefresh;

  const MetadataRequest({
    required this.mediaType,
    required this.title,
    this.year,
    this.imdbId,
    this.tmdbId,
    this.language = 'zh-CN',
    this.forceRefresh = false,
  });
}

/// 媒体元数据
class MediaMetadata {
  final String id;
  final String mediaType;
  final String title;
  final int? year;
  final String? imdbId;
  final String? tmdbId;
  final String? description;
  final String? director;
  final List<String> genres;
  final List<String> cast;
  final String? releaseDate;
  final double? rating;
  final int? duration;
  final String? language;
  final List<String> countries;
  final String? posterUrl;
  final List<String> backdropUrls;
  final DateTime lastUpdated;

  const MediaMetadata({
    required this.id,
    required this.mediaType,
    required this.title,
    this.year,
    this.imdbId,
    this.tmdbId,
    this.description,
    this.director,
    this.genres = const [],
    this.cast = const [],
    this.releaseDate,
    this.rating,
    this.duration,
    this.language,
    this.countries = const [],
    this.posterUrl,
    this.backdropUrls = const [],
    required this.lastUpdated,
  });

  factory MediaMetadata.fromJson(Map<String, dynamic> json) {
    return MediaMetadata(
      id: json['id'],
      mediaType: json['mediaType'],
      title: json['title'],
      year: json['year'],
      imdbId: json['imdbId'],
      tmdbId: json['tmdbId'],
      description: json['description'],
      director: json['director'],
      genres: List<String>.from(json['genres'] ?? []),
      cast: List<String>.from(json['cast'] ?? []),
      releaseDate: json['releaseDate'],
      rating: json['rating']?.toDouble(),
      duration: json['duration'],
      language: json['language'],
      countries: List<String>.from(json['countries'] ?? []),
      posterUrl: json['posterUrl'],
      backdropUrls: List<String>.from(json['backdropUrls'] ?? []),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mediaType': mediaType,
      'title': title,
      'year': year,
      'imdbId': imdbId,
      'tmdbId': tmdbId,
      'description': description,
      'director': director,
      'genres': genres,
      'cast': cast,
      'releaseDate': releaseDate,
      'rating': rating,
      'duration': duration,
      'language': language,
      'countries': countries,
      'posterUrl': posterUrl,
      'backdropUrls': backdropUrls,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

/// 元数据源接口
abstract class MetadataSource {
  String get name;
  Future<List<MediaMetadata>> search({
    required String query,
    required String mediaType,
    int? year,
    String language = 'zh-CN',
    int limit = 20,
  });
  Future<MediaMetadata?> searchMetadata({
    required String mediaType,
    required String title,
    int? year,
    String? imdbId,
    String? tmdbId,
    String language = 'zh-CN',
  });
  Future<MediaMetadata?> getDetailedMetadata(MediaMetadata metadata, String language);
}

/// 在线元数据源
abstract class OnlineMetadataSource extends MetadataSource {
  Future<String?> getPosterUrl(MediaMetadata metadata, String quality);
  Future<List<String>> getBackdropUrls(MediaMetadata metadata, int limit);
  Future<void> testConnection();
}

/// 本地元数据源
abstract class LocalMetadataSource extends MetadataSource {
  Future<MediaMetadata?> getLocalMetadata(String filePath);
}

/// TMDB数据源
class TMDBMetadataSource extends OnlineMetadataSource {
  final http.Client _client;
  static const String _apiKey = 'YOUR_TMDB_API_KEY'; // 实际使用时需要配置
  static const String _baseUrl = 'https://api.themoviedb.org/3';

  TMDBMetadataSource(this._client);

  @override
  String get name => 'TMDB';

  @override
  Future<List<MediaMetadata>> search({
    required String query,
    required String mediaType,
    int? year,
    String language = 'zh-CN',
    int limit = 20,
  }) async {
    // 实际实现会调用TMDB API
    // 这里是简化实现
    print('Searching TMDB for: $query');
    return [];
  }

  @override
  Future<MediaMetadata?> searchMetadata({
    required String mediaType,
    required String title,
    int? year,
    String? imdbId,
    String? tmdbId,
    String language = 'zh-CN',
  }) async {
    // 简化实现
    print('Searching TMDB metadata for: $title');
    return null;
  }

  @override
  Future<MediaMetadata?> getDetailedMetadata(MediaMetadata metadata, String language) async {
    // 简化实现
    print('Getting detailed TMDB metadata for: ${metadata.title}');
    return metadata;
  }

  @override
  Future<String?> getPosterUrl(MediaMetadata metadata, String quality) async {
    // 简化实现
    return metadata.posterUrl;
  }

  @override
  Future<List<String>> getBackdropUrls(MediaMetadata metadata, int limit) async {
    // 简化实现
    return metadata.backdropUrls;
  }

  @override
  Future<void> testConnection() async {
    final url = '$_baseUrl/configuration?api_key=$_apiKey';
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('TMDB connection test failed');
    }
  }
}

/// OMDb数据源
class OMDbMetadataSource extends OnlineMetadataSource {
  final http.Client _client;
  static const String _apiKey = 'YOUR_OMDB_API_KEY'; // 实际使用时需要配置
  static const String _baseUrl = 'http://www.omdbapi.com';

  OMDbMetadataSource(this._client);

  @override
  String get name => 'OMDb';

  @override
  Future<List<MediaMetadata>> search({
    required String query,
    required String mediaType,
    int? year,
    String language = 'zh-CN',
    int limit = 20,
  }) async {
    // 简化实现
    print('Searching OMDb for: $query');
    return [];
  }

  @override
  Future<MediaMetadata?> searchMetadata({
    required String mediaType,
    required String title,
    int? year,
    String? imdbId,
    String? tmdbId,
    String language = 'zh-CN',
  }) async {
    // 简化实现
    print('Searching OMDb metadata for: $title');
    return null;
  }

  @override
  Future<MediaMetadata?> getDetailedMetadata(MediaMetadata metadata, String language) async {
    // 简化实现
    print('Getting detailed OMDb metadata for: ${metadata.title}');
    return metadata;
  }

  @override
  Future<String?> getPosterUrl(MediaMetadata metadata, String quality) async {
    // 简化实现
    return metadata.posterUrl;
  }

  @override
  Future<List<String>> getBackdropUrls(MediaMetadata metadata, int limit) async {
    // 简化实现
    return metadata.backdropUrls;
  }

  @override
  Future<void> testConnection() async {
    final url = '$_baseUrl/?apikey=$_apiKey&s=game';
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('OMDb connection test failed');
    }
  }
}

/// 本地数据源
class LocalMetadataSource extends MetadataSource {
  @override
  String get name => 'Local';

  @override
  Future<List<MediaMetadata>> search({
    required String query,
    required String mediaType,
    int? year,
    String language = 'zh-CN',
    int limit = 20,
  }) async {
    // 实际实现会搜索本地媒体库
    print('Searching local metadata for: $query');
    return [];
  }

  @override
  Future<MediaMetadata?> searchMetadata({
    required String mediaType,
    required String title,
    int? year,
    String? imdbId,
    String? tmdbId,
    String language = 'zh-CN',
  }) async {
    // 简化实现
    print('Searching local metadata for: $title');
    return null;
  }

  @override
  Future<MediaMetadata?> getDetailedMetadata(MediaMetadata metadata, String language) async {
    // 简化实现
    print('Getting detailed local metadata for: ${metadata.title}');
    return metadata;
  }

  /// 获取本地元数据
  Future<MediaMetadata?> getLocalMetadata(String filePath) async {
    // 实际实现会解析文件名和文件夹结构
    final fileName = filePath.split('/').last;
    // 这里应该实现文件名解析逻辑
    return null;
  }
}

/// 元数据缓存统计
class MetadataCacheStats {
  final int totalEntries;
  final int expiredEntries;
  final int estimatedSize;
  final DateTime lastCleanup;

  const MetadataCacheStats({
    required this.totalEntries,
    required this.expiredEntries,
    required this.estimatedSize,
    required this.lastCleanup,
  });
}