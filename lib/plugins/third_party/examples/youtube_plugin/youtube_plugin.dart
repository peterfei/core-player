import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../../core/plugin_system/core_plugin.dart';
import '../../../../../core/plugin_system/plugin_interface.dart';

/// YouTube集成插件
///
/// 功能：
/// - YouTube视频播放
/// - 播放列表管理
/// - 字幕下载和显示
/// - 视频质量选择
/// - 历史记录
/// - 收藏管理
/// - 搜索功能
/// - 离线缓存支持
class YouTubePlugin extends CorePlugin {
  static final _metadata = PluginMetadata(
    id: 'third_party.youtube',
    name: 'YouTube 插件',
    version: '2.1.0',
    description: 'YouTube视频播放和功能集成插件，支持视频播放、播放列表管理、字幕下载等功能',
    author: 'CorePlayer Community',
    icon: Icons.play_circle_filled,
    capabilities: ['video_streaming', 'subtitle_download', 'playlist_management', 'video_search'],
    license: PluginLicense.mit,
  );

  /// 插件内部状态
  PluginState _internalState = PluginState.uninitialized;

  /// YouTube API客户端
  http.Client? _apiClient;

  /// 当前播放信息
  YouTubeVideoInfo? _currentVideo;

  /// 播放列表缓存
  final Map<String, YouTubePlaylist> _playlists = {};

  /// 字幕缓存
  final Map<String, List<YouTubeCaption>> _captions = {};

  /// 搜索历史
  final List<String> _searchHistory = [];

  /// 收藏列表
  final List<String> _favorites = [];

  /// 配置
  YouTubeConfig _config = const YouTubeConfig();

  /// API密钥（实际使用时需要配置）
  static const String _apiKey = 'YOUR_YOUTUBE_API_KEY';

  /// 基础API URL
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';

  /// 插件变更事件流
  final StreamController<YouTubeEvent> _eventController =
      StreamController<YouTubeEvent>.broadcast();

  YouTubePlugin();

  @override
  PluginMetadata get staticMetadata => _metadata;

  @override
  PluginState get state => _internalState;

  @override
  void setStateInternal(PluginState newState) {
    _internalState = newState;
  }

  @override
  Future<void> onInitialize() async {
    // 初始化HTTP客户端
    _apiClient = http.Client();

    // 加载配置
    await _loadConfig();

    // 加载缓存数据
    await _loadCacheData();

    setStateInternal(PluginState.ready);
    print('YouTubePlugin initialized');
  }

  @override
  Future<void> onActivate() async {
    setStateInternal(PluginState.active);

    // 发送激活事件
    _eventController.add(YouTubeEvent(
      type: YouTubeEventType.pluginActivated,
      timestamp: DateTime.now(),
    ));

    print('YouTubePlugin activated - YouTube integration enabled');
  }

  @override
  Future<void> onDeactivate() async {
    setStateInternal(PluginState.ready);

    // 发送停用事件
    _eventController.add(YouTubeEvent(
      type: YouTubeEventType.pluginDeactivated,
      timestamp: DateTime.now(),
    ));

    print('YouTubePlugin deactivated');
  }

  @override
  Future<void> onDispose() async {
    _apiClient?.close();
    _playlists.clear();
    _captions.clear();
    _searchHistory.clear();
    _favorites.clear();
    _eventController.close();
    setStateInternal(PluginState.disposed);
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final response = await _apiClient?.get(
        Uri.parse('$_baseUrl/search?part=snippet&q=test&type=video&maxResults=1&key=$_apiKey'),
      );
      return response?.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 搜索YouTube视频
  Future<YouTubeSearchResult> searchVideos(String query, {int maxResults = 20}) async {
    if (_apiClient == null) {
      throw Exception('API client not initialized');
    }

    try {
      // 添加到搜索历史
      if (!_searchHistory.contains(query)) {
        _searchHistory.insert(0, query);
        if (_searchHistory.length > 50) {
          _searchHistory.removeLast();
        }
      }

      final response = await _apiClient!.get(
        Uri.parse('$_baseUrl/search?part=snippet&q=$query&type=video&maxResults=$maxResults&key=$_apiKey'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List;

        final videos = items.map((item) {
          final snippet = item['snippet'];
          return YouTubeVideoInfo(
            id: item['id']['videoId'],
            title: snippet['title'],
            description: snippet['description'],
            channelTitle: snippet['channelTitle'],
            publishedAt: DateTime.parse(snippet['publishedAt']),
            thumbnailUrl: snippet['thumbnails']['high']['url'],
            duration: '', // 需要额外API调用获取
          );
        }).toList();

        return YouTubeSearchResult(
          query: query,
          videos: videos,
          totalResults: data['pageInfo']['totalResults'],
          nextPageToken: data['nextPageToken'],
        );
      } else {
        throw Exception('Failed to search videos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('搜索YouTube视频失败: $e');
    }
  }

  /// 获取视频详细信息
  Future<YouTubeVideoInfo> getVideoDetails(String videoId) async {
    if (_apiClient == null) {
      throw Exception('API client not initialized');
    }

    try {
      final response = await _apiClient!.get(
        Uri.parse('$_baseUrl/videos?part=snippet,contentDetails,statistics&id=$videoId&key=$_apiKey'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final item = data['items'][0];

        final snippet = item['snippet'];
        final contentDetails = item['contentDetails'];
        final statistics = item['statistics'];

        final video = YouTubeVideoInfo(
          id: item['id'],
          title: snippet['title'],
          description: snippet['description'],
          channelTitle: snippet['channelTitle'],
          publishedAt: DateTime.parse(snippet['publishedAt']),
          thumbnailUrl: snippet['thumbnails']['high']['url'],
          duration: contentDetails['duration'],
          viewCount: int.parse(statistics['viewCount'] ?? '0'),
          likeCount: int.parse(statistics['likeCount'] ?? '0'),
        );

        _currentVideo = video;

        // 发送事件
        _eventController.add(YouTubeEvent(
          type: YouTubeEventType.videoLoaded,
          videoId: videoId,
          timestamp: DateTime.now(),
        ));

        return video;
      } else {
        throw Exception('Failed to get video details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取视频详情失败: $e');
    }
  }

  /// 获取视频字幕
  Future<List<YouTubeCaption>> getVideoCaptions(String videoId) async {
    if (_apiClient == null) {
      throw Exception('API client not initialized');
    }

    try {
      // 检查缓存
      if (_captions.containsKey(videoId)) {
        return _captions[videoId]!;
      }

      final response = await _apiClient!.get(
        Uri.parse('$_baseUrl/captions?videoId=$videoId&key=$_apiKey'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List;

        final captions = items.map((item) {
          return YouTubeCaption(
            id: item['id'],
            language: item['languageCode'],
            name: item['name'],
            isAutoGenerated: item['trackKind'] == 'asr',
          );
        }).toList();

        _captions[videoId] = captions;
        return captions;
      } else {
        throw Exception('Failed to get captions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取字幕失败: $e');
    }
  }

  /// 下载字幕
  Future<String> downloadCaption(String captionId, {String format = 'srt'}) async {
    if (_apiClient == null) {
      throw Exception('API client not initialized');
    }

    try {
      final response = await _apiClient!.get(
        Uri.parse('$_baseUrl/captions/$captionId?tfmt=$format&key=$_apiKey'),
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('Failed to download caption: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('下载字幕失败: $e');
    }
  }

  /// 获取播放列表
  Future<YouTubePlaylist> getPlaylist(String playlistId) async {
    if (_apiClient == null) {
      throw Exception('API client not initialized');
    }

    try {
      // 检查缓存
      if (_playlists.containsKey(playlistId)) {
        return _playlists[playlistId]!;
      }

      final response = await _apiClient!.get(
        Uri.parse('$_baseUrl/playlists?part=snippet,contentDetails&id=$playlistId&key=$_apiKey'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final item = data['items'][0];

        final snippet = item['snippet'];
        final contentDetails = item['contentDetails'];

        final playlist = YouTubePlaylist(
          id: item['id'],
          title: snippet['title'],
          description: snippet['description'],
          channelTitle: snippet['channelTitle'],
          publishedAt: DateTime.parse(snippet['publishedAt']),
          videoCount: int.parse(contentDetails['itemCount']),
          thumbnailUrl: snippet['thumbnails']['high']['url'],
        );

        _playlists[playlistId] = playlist;
        return playlist;
      } else {
        throw Exception('Failed to get playlist: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取播放列表失败: $e');
    }
  }

  /// 添加到收藏
  void addToFavorites(String videoId) {
    if (!_favorites.contains(videoId)) {
      _favorites.add(videoId);
      _saveFavorites();

      _eventController.add(YouTubeEvent(
        type: YouTubeEventType.addedToFavorites,
        videoId: videoId,
        timestamp: DateTime.now(),
      ));
    }
  }

  /// 从收藏中移除
  void removeFromFavorites(String videoId) {
    _favorites.remove(videoId);
    _saveFavorites();

    _eventController.add(YouTubeEvent(
      type: YouTubeEventType.removedFromFavorites,
      videoId: videoId,
      timestamp: DateTime.now(),
    ));
  }

  /// 检查是否已收藏
  bool isFavorite(String videoId) {
    return _favorites.contains(videoId);
  }

  /// 获取播放URL
  String getPlaybackUrl(String videoId, {String quality = 'medium'}) {
    // 这里需要实现YouTube视频URL解析逻辑
    // 实际应用中可能需要第三方服务或库来获取直链
    return 'https://www.youtube.com/watch?v=$videoId';
  }

  /// 获取搜索历史
  List<String> getSearchHistory() {
    return List.unmodifiable(_searchHistory);
  }

  /// 清除搜索历史
  void clearSearchHistory() {
    _searchHistory.clear();
    _saveSearchHistory();
  }

  /// 获取收藏列表
  List<String> getFavorites() {
    return List.unmodifiable(_favorites);
  }

  /// 设置配置
  void setYouTubeConfig(YouTubeConfig config) {
    _config = config;
    _saveConfig();
  }

  /// 获取当前配置
  YouTubeConfig get config => _config;

  /// 获取当前视频
  YouTubeVideoInfo? get currentVideo => _currentVideo;

  /// 获取事件流
  Stream<YouTubeEvent> get eventStream => _eventController.stream;

  /// 获取统计信息
  YouTubeStats getStats() {
    return YouTubeStats(
      searchHistoryCount: _searchHistory.length,
      favoritesCount: _favorites.length,
      playlistsCached: _playlists.length,
      captionsCached: _captions.length,
      lastActivity: DateTime.now(),
    );
  }

  /// 加载配置
  Future<void> _loadConfig() async {
    // 实际实现会从本地存储加载
    _config = const YouTubeConfig(
      playbackQuality: VideoQuality.medium,
      autoPlay: true,
      subtitlesEnabled: true,
      cacheEnabled: true,
    );
  }

  /// 保存配置
  Future<void> _saveConfig() async {
    // 实际实现会保存到本地存储
  }

  /// 加载缓存数据
  Future<void> _loadCacheData() async {
    // 实际实现会从本地存储加载
    // 这里使用模拟数据
    _searchHistory.addAll([
      'Flutter tutorial',
      'Dart programming',
      'CorePlayer features',
    ]);
    _favorites.addAll([
      'dQw4w9WgXcQ', // Never Gonna Give You Up
    ]);
  }

  /// 保存搜索历史
  Future<void> _saveSearchHistory() async {
    // 实际实现会保存到本地存储
  }

  /// 保存收藏列表
  Future<void> _saveFavorites() async {
    // 实际实现会保存到本地存储
  }
}

/// YouTube视频信息
class YouTubeVideoInfo {
  final String id;
  final String title;
  final String description;
  final String channelTitle;
  final DateTime publishedAt;
  final String thumbnailUrl;
  final String duration;
  final int viewCount;
  final int likeCount;

  const YouTubeVideoInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.channelTitle,
    required this.publishedAt,
    required this.thumbnailUrl,
    this.duration = '',
    this.viewCount = 0,
    this.likeCount = 0,
  });
}

/// YouTube播放列表
class YouTubePlaylist {
  final String id;
  final String title;
  final String description;
  final String channelTitle;
  final DateTime publishedAt;
  final int videoCount;
  final String thumbnailUrl;

  const YouTubePlaylist({
    required this.id,
    required this.title,
    required this.description,
    required this.channelTitle,
    required this.publishedAt,
    required this.videoCount,
    required this.thumbnailUrl,
  });
}

/// YouTube字幕
class YouTubeCaption {
  final String id;
  final String language;
  final String name;
  final bool isAutoGenerated;

  const YouTubeCaption({
    required this.id,
    required this.language,
    required this.name,
    this.isAutoGenerated = false,
  });
}

/// YouTube搜索结果
class YouTubeSearchResult {
  final String query;
  final List<YouTubeVideoInfo> videos;
  final int totalResults;
  final String? nextPageToken;

  const YouTubeSearchResult({
    required this.query,
    required this.videos,
    required this.totalResults,
    this.nextPageToken,
  });
}

/// YouTube配置
class YouTubeConfig {
  final VideoQuality playbackQuality;
  final bool autoPlay;
  final bool subtitlesEnabled;
  final bool cacheEnabled;
  final String preferredLanguage;

  const YouTubeConfig({
    this.playbackQuality = VideoQuality.medium,
    this.autoPlay = true,
    this.subtitlesEnabled = true,
    this.cacheEnabled = true,
    this.preferredLanguage = 'zh-CN',
  });
}

/// 视频质量枚举
enum VideoQuality {
  auto,
  tiny,
  small,
  medium,
  large,
  hd720,
  hd1080,
  hd1440,
  hd2160,
  highres,
}

/// YouTube事件类型
enum YouTubeEventType {
  pluginActivated,
  pluginDeactivated,
  videoLoaded,
  addedToFavorites,
  removedFromFavorites,
  searchCompleted,
  captionDownloaded,
}

/// YouTube事件
class YouTubeEvent {
  final YouTubeEventType type;
  final String? videoId;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  const YouTubeEvent({
    required this.type,
    this.videoId,
    required this.timestamp,
    this.data,
  });
}

/// YouTube统计信息
class YouTubeStats {
  final int searchHistoryCount;
  final int favoritesCount;
  final int playlistsCached;
  final int captionsCached;
  final DateTime lastActivity;

  const YouTubeStats({
    required this.searchHistoryCount,
    required this.favoritesCount,
    required this.playlistsCached,
    required this.captionsCached,
    required this.lastActivity,
  });
}