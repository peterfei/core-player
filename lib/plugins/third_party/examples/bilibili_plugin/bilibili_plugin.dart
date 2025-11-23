import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../../core/plugin_system/core_plugin.dart';
import '../../../../../core/plugin_system/plugin_interface.dart';

/// Bilibili集成插件
///
/// 功能：
/// - Bilibili视频播放
/// - 弹幕显示和管理
/// - 分P播放支持
/// - 视频质量选择
/// - 历史记录和收藏
/// - 搜索功能
/// - 用户信息获取
/// - 直播支持
class BilibiliPlugin extends CorePlugin {
  static final _metadata = PluginMetadata(
    id: 'third_party.bilibili',
    name: 'Bilibili 插件',
    version: '1.8.0',
    description: 'Bilibili视频播放和功能集成插件，支持视频播放、弹幕显示、分P播放等功能',
    author: 'CorePlayer Community',
    icon: Icons.live_tv,
    capabilities: ['video_streaming', 'danmaku_display', 'multi_part_support', 'live_streaming'],
    license: PluginLicense.mit,
  );

  /// 插件内部状态
  PluginState _internalState = PluginState.uninitialized;

  /// HTTP客户端
  http.Client? _httpClient;

  /// 当前视频信息
  BilibiliVideoInfo? _currentVideo;

  /// 弹幕管理器
  DanmakuManager _danmakuManager = DanmakuManager();

  /// 搜索历史
  final List<String> _searchHistory = [];

  /// 收藏列表
  final List<String> _favorites = [];

  /// 观看历史
  final List<BilibiliWatchHistory> _watchHistory = [];

  /// 配置
  BilibiliConfig _config = const BilibiliConfig();

  /// 基础API URL
  static const String _baseUrl = 'https://api.bilibili.com';

  /// 弹幕事件流
  final StreamController<DanmakuEvent> _danmakuController =
      StreamController<DanmakuEvent>.broadcast();

  /// 插件事件流
  final StreamController<BilibiliEvent> _eventController =
      StreamController<BilibiliEvent>.broadcast();

  BilibiliPlugin();

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

    // 加载配置
    await _loadConfig();

    // 加载缓存数据
    await _loadCacheData();

    // 初始化弹幕管理器
    _danmakuManager.initialize();

    setStateInternal(PluginState.initialized);
    print('BilibiliPlugin initialized');
  }

  @override
  Future<void> onActivate() async {
    setStateInternal(PluginState.active);

    // 发送激活事件
    _eventController.add(BilibiliEvent(
      type: BilibiliEventType.pluginActivated,
      timestamp: DateTime.now(),
    ));

    print('BilibiliPlugin activated - Bilibili integration enabled');
  }

  @override
  Future<void> onDeactivate() async {
    // 停止弹幕
    _danmakuManager.stop();

    setStateInternal(PluginState.ready);

    // 发送停用事件
    _eventController.add(BilibiliEvent(
      type: BilibiliEventType.pluginDeactivated,
      timestamp: DateTime.now(),
    ));

    print('BilibiliPlugin deactivated');
  }

  @override
  void onDispose() {
    _httpClient?.close();
    _danmakuManager.dispose();
    _searchHistory.clear();
    _favorites.clear();
    _watchHistory.clear();
    _danmakuController.close();
    _eventController.close();
    setStateInternal(PluginState.disposed);
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final response = await _httpClient?.get(Uri.parse('$_baseUrl/x/web-interface/nav'));
      return response?.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 搜索Bilibili视频
  Future<BilibiliSearchResult> searchVideos(String query, {int page = 1}) async {
    if (_httpClient == null) {
      throw Exception('HTTP client not initialized');
    }

    try {
      // 添加到搜索历史
      if (!_searchHistory.contains(query)) {
        _searchHistory.insert(0, query);
        if (_searchHistory.length > 50) {
          _searchHistory.removeLast();
        }
      }

      final response = await _httpClient!.get(
        Uri.parse('$_baseUrl/x/web-interface/search/type?search_type=video&keyword=$query&page=$page'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 0) {
          final result = data['data'];
          final videos = result['result'].map((item) {
            return BilibiliVideoInfo(
              bvid: item['bvid'],
              aid: item['aid'],
              title: item['title'],
              description: item['description'],
              author: item['author'],
              playCount: item['play'],
              danmakuCount: item['video_review'],
              duration: item['duration'],
              picUrl: item['pic'],
              publishedAt: DateTime.fromMillisecondsSinceEpoch(item['pubdate'] * 1000),
            );
          }).toList();

          return BilibiliSearchResult(
            query: query,
            videos: videos,
            totalResults: result['numResults'],
            currentPage: result['num'],
            pageSize: result['size'],
          );
        } else {
          throw Exception('API error: ${data['message']}');
        }
      } else {
        throw Exception('Failed to search videos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('搜索Bilibili视频失败: $e');
    }
  }

  /// 获取视频详细信息
  Future<BilibiliVideoInfo> getVideoDetails(String bvid) async {
    if (_httpClient == null) {
      throw Exception('HTTP client not initialized');
    }

    try {
      final response = await _httpClient!.get(
        Uri.parse('$_baseUrl/x/web-interface/view?bvid=$bvid'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 0) {
          final videoData = data['data'];
          final video = BilibiliVideoInfo(
            bvid: videoData['bvid'],
            aid: videoData['aid'],
            title: videoData['title'],
            description: videoData['desc'],
            author: videoData['owner']['name'],
            playCount: videoData['stat']['view'],
            danmakuCount: videoData['stat']['danmaku'],
            likeCount: videoData['stat']['like'],
            coinCount: videoData['stat']['coin'],
            favoriteCount: videoData['stat']['favorite'],
            duration: _formatDuration(videoData['duration']),
            picUrl: videoData['pic'],
            publishedAt: DateTime.fromMillisecondsSinceEpoch(videoData['pubdate'] * 1000),
            cid: videoData['cid'],
            parts: (videoData['pages'] as List)
                .map((page) => BilibiliVideoPart(
                      cid: page['cid'],
                      page: page['page'],
                      part: page['part'],
                      duration: _formatDuration(page['duration']),
                    ))
                .toList(),
          );

          _currentVideo = video;

          // 添加到观看历史
          _addToWatchHistory(video);

          // 发送事件
          _eventController.add(BilibiliEvent(
            type: BilibiliEventType.videoLoaded,
            bvid: bvid,
            timestamp: DateTime.now(),
          ));

          return video;
        } else {
          throw Exception('API error: ${data['message']}');
        }
      } else {
        throw Exception('Failed to get video details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取视频详情失败: $e');
    }
  }

  /// 获取弹幕
  Future<List<Danmaku>> getDanmaku(String bvid, int cid) async {
    if (_httpClient == null) {
      throw Exception('HTTP client not initialized');
    }

    try {
      final response = await _httpClient!.get(
        Uri.parse('$_baseUrl/x/v1/dm/list.so?oid=$cid'),
      );

      if (response.statusCode == 200) {
        // 解析XML弹幕数据
        final danmakuXml = response.body;
        final danmakuList = _parseDanmakuXml(danmakuXml);

        return danmakuList;
      } else {
        throw Exception('Failed to get danmaku: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取弹幕失败: $e');
    }
  }

  /// 开始播放弹幕
  void startDanmaku(String bvid, int cid) async {
    try {
      final danmakuList = await getDanmaku(bvid, cid);
      _danmakuManager.start(danmakuList);

      // 发送弹幕事件
      _danmakuController.add(DanmakuEvent(
        type: DanmakuEventType.started,
        bvid: bvid,
        cid: cid,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      print('Failed to start danmaku: $e');
    }
  }

  /// 停止弹幕
  void stopDanmaku() {
    _danmakuManager.stop();

    _danmakuController.add(DanmakuEvent(
      type: DanmakuEventType.stopped,
      timestamp: DateTime.now(),
    ));
  }

  /// 发送弹幕
  void sendDanmaku(String text, {DanmakuMode mode = DanmakuMode.scroll, int color = 0xFFFFFF}) {
    final danmaku = Danmaku(
      text: text,
      time: DateTime.now(),
      mode: mode,
      color: color,
      isOwn: true,
    );

    _danmakuManager.addDanmaku(danmaku);

    _danmakuController.add(DanmakuEvent(
      type: DanmakuEventType.sent,
      danmaku: danmaku,
      timestamp: DateTime.now(),
    ));
  }

  /// 获取视频播放URL
  Future<String> getPlaybackUrl(String bvid, int cid, {int quality = 80}) async {
    if (_httpClient == null) {
      throw Exception('HTTP client not initialized');
    }

    try {
      final response = await _httpClient!.get(
        Uri.parse('$_baseUrl/x/player/playurl?bvid=$bvid&cid=$cid&qn=$quality'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 0) {
          return data['data']['durl'][0]['url'];
        } else {
          throw Exception('API error: ${data['message']}');
        }
      } else {
        throw Exception('Failed to get playback URL: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取播放URL失败: $e');
    }
  }

  /// 添加到收藏
  void addToFavorites(String bvid) {
    if (!_favorites.contains(bvid)) {
      _favorites.add(bvid);
      _saveFavorites();

      _eventController.add(BilibiliEvent(
        type: BilibiliEventType.addedToFavorites,
        bvid: bvid,
        timestamp: DateTime.now(),
      ));
    }
  }

  /// 从收藏中移除
  void removeFromFavorites(String bvid) {
    _favorites.remove(bvid);
    _saveFavorites();

    _eventController.add(BilibiliEvent(
      type: BilibiliEventType.removedFromFavorites,
      bvid: bvid,
      timestamp: DateTime.now(),
    ));
  }

  /// 检查是否已收藏
  bool isFavorite(String bvid) {
    return _favorites.contains(bvid);
  }

  /// 获取直播信息
  Future<BilibiliLiveInfo> getLiveInfo(int roomId) async {
    if (_httpClient == null) {
      throw Exception('HTTP client not initialized');
    }

    try {
      final response = await _httpClient!.get(
        Uri.parse('$_baseUrl/xlive/web-room/v1/index/getInfoByRoom?room_id=$roomId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 0) {
          final roomInfo = data['data']['room_info'];
          final anchorInfo = data['data']['anchor_info']['base_info'];

          return BilibiliLiveInfo(
            roomId: roomInfo['room_id'],
            title: roomInfo['title'],
            description: roomInfo['description'],
            anchorName: anchorInfo['uname'],
            faceUrl: anchorInfo['face'],
            liveStatus: roomInfo['live_status'],
            liveStartTime: roomInfo['live_start_time'] > 0
                ? DateTime.fromMillisecondsSinceEpoch(roomInfo['live_start_time'] * 1000)
                : null,
            keyframe: roomInfo['keyframe'],
            online: roomInfo['online'],
          );
        } else {
          throw Exception('API error: ${data['message']}');
        }
      } else {
        throw Exception('Failed to get live info: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取直播信息失败: $e');
    }
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

  /// 获取观看历史
  List<BilibiliWatchHistory> getWatchHistory() {
    return List.unmodifiable(_watchHistory);
  }

  /// 清除观看历史
  void clearWatchHistory() {
    _watchHistory.clear();
    _saveWatchHistory();
  }

  /// 设置配置
  void setConfig(BilibiliConfig config) {
    _config = config;
    _danmakuManager.updateConfig(config);
    _saveConfig();
  }

  /// 获取当前配置
  BilibiliConfig get config => _config;

  /// 获取当前视频
  BilibiliVideoInfo? get currentVideo => _currentVideo;

  /// 获取弹幕事件流
  Stream<DanmakuEvent> get danmakuStream => _danmakuController.stream;

  /// 获取插件事件流
  Stream<BilibiliEvent> get eventStream => _eventController.stream;

  /// 获取统计信息
  BilibiliStats getStats() {
    return BilibiliStats(
      searchHistoryCount: _searchHistory.length,
      favoritesCount: _favorites.length,
      watchHistoryCount: _watchHistory.length,
      danmakuCount: _danmakuManager.totalDanmakuCount,
      lastActivity: DateTime.now(),
    );
  }

  /// 格式化时长
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${secs.toString().padLeft(2, '0')}';
    }
  }

  /// 解析弹幕XML
  List<Danmaku> _parseDanmakuXml(String xml) {
    // 简化的XML解析，实际实现需要更完整的XML解析器
    final danmakuList = <Danmaku>[];
    final regex = RegExp(r'<d p="([^"]+)">([^<]+)</d>');

    for (final match in regex.allMatches(xml)) {
      final params = match.group(1)!.split(',');
      final text = match.group(2)!;

      final time = double.parse(params[0]);
      final mode = DanmakuMode.values[int.parse(params[1])];
      final fontSize = int.parse(params[2]);
      final color = int.parse(params[3]);

      danmakuList.add(Danmaku(
        text: text,
        time: DateTime.now().add(Duration(milliseconds: (time * 1000).round())),
        mode: mode,
        fontSize: fontSize,
        color: color,
        isOwn: false,
      ));
    }

    return danmakuList;
  }

  /// 添加到观看历史
  void _addToWatchHistory(BilibiliVideoInfo video) {
    final history = BilibiliWatchHistory(
      bvid: video.bvid,
      title: video.title,
      author: video.author,
      watchedAt: DateTime.now(),
      duration: video.duration,
    );

    _watchHistory.removeWhere((item) => item.bvid == video.bvid);
    _watchHistory.insert(0, history);

    if (_watchHistory.length > 100) {
      _watchHistory.removeLast();
    }

    _saveWatchHistory();
  }

  /// 加载配置
  Future<void> _loadConfig() async {
    // 实际实现会从本地存储加载
    _config = const BilibiliConfig(
      danmakuEnabled: true,
      danmakuOpacity: 0.8,
      danmakuFontSize: 25,
      danmakuSpeed: 1.0,
      danmakuBlocked: [],
      playbackQuality: 80,
      autoPlay: true,
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
      'Flutter教程',
      '编程学习',
      '科技评测',
    ]);
    _favorites.addAll([
      'BV1xx411c7mu', // 示例BV号
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

  /// 保存观看历史
  Future<void> _saveWatchHistory() async {
    // 实际实现会保存到本地存储
  }
}

/// Bilibili视频信息
class BilibiliVideoInfo {
  final String bvid;
  final int aid;
  final String title;
  final String description;
  final String author;
  final int playCount;
  final int danmakuCount;
  final int likeCount;
  final int coinCount;
  final int favoriteCount;
  final String duration;
  final String picUrl;
  final DateTime publishedAt;
  final int cid;
  final List<BilibiliVideoPart> parts;

  const BilibiliVideoInfo({
    required this.bvid,
    required this.aid,
    required this.title,
    required this.description,
    required this.author,
    required this.playCount,
    required this.danmakuCount,
    this.likeCount = 0,
    this.coinCount = 0,
    this.favoriteCount = 0,
    required this.duration,
    required this.picUrl,
    required this.publishedAt,
    required this.cid,
    this.parts = const [],
  });
}

/// Bilibili视频分P
class BilibiliVideoPart {
  final int cid;
  final int page;
  final String part;
  final String duration;

  const BilibiliVideoPart({
    required this.cid,
    required this.page,
    required this.part,
    required this.duration,
  });
}

/// 弹幕管理器
class DanmakuManager {
  List<Danmaku> _danmakuList = [];
  Timer? _timer;
  bool _isRunning = false;
  BilibiliConfig _config = const BilibiliConfig();

  void initialize() {
    // 初始化逻辑
  }

  void start(List<Danmaku> danmakuList) {
    _danmakuList = danmakuList;
    _isRunning = true;

    // 启动定时器，按时间发送弹幕
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_isRunning) {
        _checkAndSendDanmaku();
      }
    });
  }

  void stop() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
  }

  void addDanmaku(Danmaku danmaku) {
    _danmakuList.add(danmaku);
  }

  void updateConfig(BilibiliConfig config) {
    _config = config;
  }

  void dispose() {
    stop();
    _danmakuList.clear();
  }

  int get totalDanmakuCount => _danmakuList.length;

  void _checkAndSendDanmaku() {
    final now = DateTime.now();
    final activeDanmaku = _danmakuList.where((d) {
      final diff = now.difference(d.time);
      return diff.inMilliseconds >= 0 && diff.inMilliseconds <= 5000; // 5秒窗口
    }).toList();

    // 这里应该将弹幕发送到UI层显示
    for (final danmaku in activeDanmaku) {
      _displayDanmaku(danmaku);
    }
  }

  void _displayDanmaku(Danmaku danmaku) {
    // 实际实现会将弹幕发送到UI组件显示
    print('Displaying danmaku: ${danmaku.text}');
  }
}

/// 弹幕
class Danmaku {
  final String text;
  final DateTime time;
  final DanmakuMode mode;
  final int fontSize;
  final int color;
  final bool isOwn;

  const Danmaku({
    required this.text,
    required this.time,
    this.mode = DanmakuMode.scroll,
    this.fontSize = 25,
    this.color = 0xFFFFFF,
    this.isOwn = false,
  });
}

/// 弹幕模式
enum DanmakuMode {
  scroll,
  top,
  bottom,
}

/// Bilibili搜索结果
class BilibiliSearchResult {
  final String query;
  final List<BilibiliVideoInfo> videos;
  final int totalResults;
  final int currentPage;
  final int pageSize;

  const BilibiliSearchResult({
    required this.query,
    required this.videos,
    required this.totalResults,
    required this.currentPage,
    required this.pageSize,
  });
}

/// Bilibili直播信息
class BilibiliLiveInfo {
  final int roomId;
  final String title;
  final String description;
  final String anchorName;
  final String faceUrl;
  final int liveStatus;
  final DateTime? liveStartTime;
  final String keyframe;
  final int online;

  const BilibiliLiveInfo({
    required this.roomId,
    required this.title,
    required this.description,
    required this.anchorName,
    required this.faceUrl,
    required this.liveStatus,
    this.liveStartTime,
    required this.keyframe,
    required this.online,
  });
}

/// Bilibili观看历史
class BilibiliWatchHistory {
  final String bvid;
  final String title;
  final String author;
  final DateTime watchedAt;
  final String duration;

  const BilibiliWatchHistory({
    required this.bvid,
    required this.title,
    required this.author,
    required this.watchedAt,
    required this.duration,
  });
}

/// Bilibili配置
class BilibiliConfig {
  final bool danmakuEnabled;
  final double danmakuOpacity;
  final int danmakuFontSize;
  final double danmakuSpeed;
  final List<String> danmakuBlocked;
  final int playbackQuality;
  final bool autoPlay;

  const BilibiliConfig({
    this.danmakuEnabled = true,
    this.danmakuOpacity = 0.8,
    this.danmakuFontSize = 25,
    this.danmakuSpeed = 1.0,
    this.danmakuBlocked = const [],
    this.playbackQuality = 80,
    this.autoPlay = true,
  });
}

/// Bilibili事件类型
enum BilibiliEventType {
  pluginActivated,
  pluginDeactivated,
  videoLoaded,
  addedToFavorites,
  removedFromFavorites,
  searchCompleted,
}

/// Bilibili事件
class BilibiliEvent {
  final BilibiliEventType type;
  final String? bvid;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  const BilibiliEvent({
    required this.type,
    this.bvid,
    required this.timestamp,
    this.data,
  });
}

/// 弹幕事件类型
enum DanmakuEventType {
  started,
  stopped,
  sent,
  received,
}

/// 弹幕事件
class DanmakuEvent {
  final DanmakuEventType type;
  final String? bvid;
  final int? cid;
  final Danmaku? danmaku;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  const DanmakuEvent({
    required this.type,
    this.bvid,
    this.cid,
    this.danmaku,
    required this.timestamp,
    this.data,
  });
}

/// Bilibili统计信息
class BilibiliStats {
  final int searchHistoryCount;
  final int favoritesCount;
  final int watchHistoryCount;
  final int danmakuCount;
  final DateTime lastActivity;

  const BilibiliStats({
    required this.searchHistoryCount,
    required this.favoritesCount,
    required this.watchHistoryCount,
    required this.danmakuCount,
    required this.lastActivity,
  });
}