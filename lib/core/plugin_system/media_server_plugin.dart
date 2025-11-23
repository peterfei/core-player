import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'core_plugin.dart';

/// 连接测试结果状态
enum ConnectionTestStatus {
  success,              // 成功
  authenticationFailed, // 认证失败
  timeout,              // 超时
  networkError,         // 网络错误
  invalidConfiguration, // 配置无效
  serverNotFound,       // 服务器未找到
  accessDenied,         // 访问被拒绝
  unsupportedVersion,   // 不支持的版本
  unknownError,         // 未知错误
}

/// 连接测试结果状态扩展
extension ConnectionTestStatusExtension on ConnectionTestStatus {
  /// 是否成功
  bool get isSuccess => this == ConnectionTestStatus.success;

  /// 是否为认证问题
  bool get isAuthError => this == ConnectionTestStatus.authenticationFailed || this == ConnectionTestStatus.accessDenied;

  /// 是否为网络问题
  bool get isNetworkError => this == ConnectionTestStatus.timeout || this == ConnectionTestStatus.networkError || this == ConnectionTestStatus.serverNotFound;
}

/// 连接测试结果
@immutable
class ConnectionTestResult {
  final ConnectionTestStatus status;
  final String? message;
  final Map<String, dynamic>? serverInfo;
  final Duration? latency;
  final String? suggestion;

  const ConnectionTestResult({
    required this.status,
    this.message,
    this.serverInfo,
    this.latency,
    this.suggestion,
  });

  factory ConnectionTestResult.success({
    String? message,
    Map<String, dynamic>? serverInfo,
    Duration? latency,
  }) {
    return ConnectionTestResult(
      status: ConnectionTestStatus.success,
      message: message ?? 'Connection successful',
      serverInfo: serverInfo ?? {},
      latency: latency,
    );
  }

  factory ConnectionTestResult.authenticationFailed({
    String? message,
    String? suggestion,
  }) {
    return ConnectionTestResult(
      status: ConnectionTestStatus.authenticationFailed,
      message: message ?? 'Authentication failed',
      suggestion: suggestion ?? 'Please check your credentials',
    );
  }

  factory ConnectionTestResult.timeout({
    String? message,
    String? suggestion,
  }) {
    return ConnectionTestResult(
      status: ConnectionTestStatus.timeout,
      message: message ?? 'Connection timeout',
      suggestion: suggestion ?? 'Please check your network connection',
    );
  }

  factory ConnectionTestResult.networkError({
    String? message,
    String? suggestion,
  }) {
    return ConnectionTestResult(
      status: ConnectionTestStatus.networkError,
      message: message ?? 'Network error',
      suggestion: suggestion ?? 'Please check if the server is accessible',
    );
  }

  factory ConnectionTestResult.invalidConfiguration({
    String? message,
    String? suggestion,
  }) {
    return ConnectionTestResult(
      status: ConnectionTestStatus.invalidConfiguration,
      message: message ?? 'Invalid configuration',
      suggestion: suggestion ?? 'Please check your server settings',
    );
  }

  factory ConnectionTestResult.serverNotFound({
    String? message,
    String? suggestion,
  }) {
    return ConnectionTestResult(
      status: ConnectionTestStatus.serverNotFound,
      message: message ?? 'Server not found',
      suggestion: suggestion ?? 'Please verify the server address',
    );
  }

  factory ConnectionTestResult.accessDenied({
    String? message,
    String? suggestion,
  }) {
    return ConnectionTestResult(
      status: ConnectionTestStatus.accessDenied,
      message: message ?? 'Access denied',
      suggestion: suggestion ?? 'Check your permissions',
    );
  }

  factory ConnectionTestResult.unsupportedVersion({
    String? message,
    String? suggestion,
  }) {
    return ConnectionTestResult(
      status: ConnectionTestStatus.unsupportedVersion,
      message: message ?? 'Unsupported server version',
      suggestion: suggestion ?? 'Please upgrade your server',
    );
  }

  factory ConnectionTestResult.unknownError({
    String? message,
    String? suggestion,
  }) {
    return ConnectionTestResult(
      status: ConnectionTestStatus.unknownError,
      message: message ?? 'Unknown error occurred',
      suggestion: suggestion ?? 'Please contact support',
    );
  }

  /// 是否成功
  bool get isSuccess => status.isSuccess;

  /// 是否为认证问题
  bool get isAuthError => status.isAuthError;

  /// 是否为网络问题
  bool get isNetworkError => status.isNetworkError;

  @override
  String toString() {
    return 'ConnectionTestResult(status: $status, message: $message)';
  }
}

/// 视频质量等级
enum VideoQuality {
  auto('Auto'),
  low('360p'),
  medium('720p'),
  high('1080p'),
  ultraHD('4K');

  const VideoQuality(this.displayName);
  final String displayName;
}

/// 视频流类型
enum StreamType {
  direct('Direct Play'),
  transcode('Transcoded'),
  proxy('Local Proxy');

  const StreamType(this.displayName);
  final String displayName;
}

/// 服务器配置基类
abstract class ServerConfig {
  String get serverId;    // 服务器唯一ID
  String get name;        // 显示名称
  String get type;        // 类型: 'smb', 'emby', 'jellyfin', 'plex'
  String get host;        // 服务器地址
  int? get port;          // 端口号

  Map<String, dynamic> toJson();

  ServerConfig();

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'smb':
        return SMBServerConfig.fromJson(json);
      case 'emby':
        return EmbyServerConfig.fromJson(json);
      case 'jellyfin':
        return JellyfinServerConfig.fromJson(json);
      case 'plex':
        return PlexServerConfig.fromJson(json);
      default:
        throw ArgumentError('Unknown server type: $type');
    }
  }
}

/// SMB 服务器配置
class SMBServerConfig extends ServerConfig {
  final String _host;
  final int _port;
  final String username;
  final String password;
  final String? domain;
  final String share;
  final List<String>? sharedFolders;

  @override
  final String serverId;

  SMBServerConfig({
    required String host,
    int port = 445,
    required this.username,
    required this.password,
    this.domain,
    required this.share,
    this.sharedFolders,
  }) : _host = host, _port = port, serverId = _generateId(), super();

  @override
  String get name => '$_host:$_port/$share';

  @override
  String get host => _host;

  @override
  int? get port => _port;

  @override
  String get type => 'smb';

  SMBServerConfig.fromJson(Map<String, dynamic> json)
      : _host = json['host'] as String,
        _port = json['port'] as int? ?? 445,
        username = json['username'] as String,
        password = json['password'] as String,
        domain = json['domain'] as String?,
        share = json['share'] as String,
        sharedFolders = (json['sharedFolders'] as List<dynamic>?)?.cast<String>(),
        serverId = json['serverId'] as String,
        super();

  @override
  Map<String, dynamic> toJson() {
    return {
      'serverId': serverId,
      'type': type,
      'host': _host,
      'port': _port,
      'username': username,
      'password': password,
      'domain': domain,
      'share': share,
      'sharedFolders': sharedFolders,
    };
  }

  static String _generateId() {
    return 'smb_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Emby 服务器配置
class EmbyServerConfig extends ServerConfig {
  final String url;
  final String apiKey;
  final String? username;
  final String? userId;

  @override
  final String serverId;

  EmbyServerConfig({
    required this.url,
    required this.apiKey,
    this.username,
    this.userId,
  }) : serverId = _generateId(), super();

  @override
  String get name => Uri.parse(url).host;

  @override
  String get host => Uri.parse(url).host;

  @override
  int? get port => Uri.parse(url).port != 80 ? Uri.parse(url).port : null;

  @override
  String get type => 'emby';

  EmbyServerConfig.fromJson(Map<String, dynamic> json)
      : url = json['url'] as String,
        apiKey = json['apiKey'] as String,
        username = json['username'] as String?,
        userId = json['userId'] as String?,
        serverId = json['serverId'] as String,
        super();

  @override
  Map<String, dynamic> toJson() {
    return {
      'serverId': serverId,
      'type': type,
      'url': url,
      'apiKey': apiKey,
      'username': username,
      'userId': userId,
    };
  }

  static String _generateId() {
    return 'emby_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Jellyfin 服务器配置
class JellyfinServerConfig extends ServerConfig {
  final String url;
  final String apiKey;
  final String? username;
  final String? userId;

  JellyfinServerConfig({
    required this.url,
    required this.apiKey,
    this.username,
    this.userId,
  }) : serverId = _generateId();

  @override
  String get name => Uri.parse(url).host;

  @override
  String get type => 'jellyfin';

  @override
  String get host => Uri.parse(url).host;

  @override
  int? get port => Uri.parse(url).port != 80 ? Uri.parse(url).port : null;

  @override
  final String serverId;

  JellyfinServerConfig.fromJson(Map<String, dynamic> json)
      : serverId = json['serverId'] as String,
        url = json['url'] as String,
        apiKey = json['apiKey'] as String,
        username = json['username'] as String?,
        userId = json['userId'] as String?;

  @override
  Map<String, dynamic> toJson() {
    return {
      'serverId': serverId,
      'type': type,
      'url': url,
      'apiKey': apiKey,
      'username': username,
      'userId': userId,
    };
  }

  static String _generateId() {
    return 'jellyfin_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Plex 服务器配置
class PlexServerConfig extends ServerConfig {
  final String url;
  final String authToken;
  final String? username;
  final String? clientId;
  final String? machineIdentifier;

  PlexServerConfig({
    required this.url,
    required this.authToken,
    this.username,
    this.clientId,
    this.machineIdentifier,
  }) : serverId = _generateId();

  @override
  String get name => Uri.parse(url).host;

  @override
  String get type => 'plex';

  @override
  String get host => Uri.parse(url).host;

  @override
  int? get port => Uri.parse(url).port != 32400 ? Uri.parse(url).port : null;

  @override
  final String serverId;

  PlexServerConfig.fromJson(Map<String, dynamic> json)
      : serverId = json['serverId'] as String,
        url = json['url'] as String,
        authToken = json['authToken'] as String,
        username = json['username'] as String?,
        clientId = json['clientId'] as String?,
        machineIdentifier = json['machineIdentifier'] as String?;

  @override
  Map<String, dynamic> toJson() {
    return {
      'serverId': serverId,
      'type': type,
      'url': url,
      'authToken': authToken,
      'username': username,
      'clientId': clientId,
      'machineIdentifier': machineIdentifier,
    };
  }

  static String _generateId() {
    return 'plex_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// 视频元数据
@immutable
class VideoMetadata {
  final String id;
  final String title;
  final String? overview;
  final int? year;
  final String? director;
  final List<String> actors;
  final String? posterUrl;
  final String? backdropUrl;
  final double? rating;
  final int? runtime; // 分钟
  final String? resolution; // "1920x1080"
  final String? videoCodec; // "H.264"
  final String? audioCodec; // "AC3"
  final List<String> genres;
  final Map<String, dynamic> customData;

  const VideoMetadata({
    required this.id,
    required this.title,
    this.overview,
    this.year,
    this.director,
    this.actors = const [],
    this.posterUrl,
    this.backdropUrl,
    this.rating,
    this.runtime,
    this.resolution,
    this.videoCodec,
    this.audioCodec,
    this.genres = const [],
    this.customData = const {},
  });

  factory VideoMetadata.fromJson(Map<String, dynamic> json) {
    return VideoMetadata(
      id: json['id'] as String,
      title: json['title'] as String,
      overview: json['overview'] as String?,
      year: json['year'] as int?,
      director: json['director'] as String?,
      actors: (json['actors'] as List<dynamic>?)?.cast<String>() ?? [],
      posterUrl: json['posterUrl'] as String?,
      backdropUrl: json['backdropUrl'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      runtime: json['runtime'] as int?,
      resolution: json['resolution'] as String?,
      videoCodec: json['videoCodec'] as String?,
      audioCodec: json['audioCodec'] as String?,
      genres: (json['genres'] as List<dynamic>?)?.cast<String>() ?? [],
      customData: json['customData'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'overview': overview,
      'year': year,
      'director': director,
      'actors': actors,
      'posterUrl': posterUrl,
      'backdropUrl': backdropUrl,
      'rating': rating,
      'runtime': runtime,
      'resolution': resolution,
      'videoCodec': videoCodec,
      'audioCodec': audioCodec,
      'genres': genres,
      'customData': customData,
    };
  }

  VideoMetadata copyWith({
    String? id,
    String? title,
    String? overview,
    int? year,
    String? director,
    List<String>? actors,
    String? posterUrl,
    String? backdropUrl,
    double? rating,
    int? runtime,
    String? resolution,
    String? videoCodec,
    String? audioCodec,
    List<String>? genres,
    Map<String, dynamic>? customData,
  }) {
    return VideoMetadata(
      id: id ?? this.id,
      title: title ?? this.title,
      overview: overview ?? this.overview,
      year: year ?? this.year,
      director: director ?? this.director,
      actors: actors ?? this.actors,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      rating: rating ?? this.rating,
      runtime: runtime ?? this.runtime,
      resolution: resolution ?? this.resolution,
      videoCodec: videoCodec ?? this.videoCodec,
      audioCodec: audioCodec ?? this.audioCodec,
      genres: genres ?? this.genres,
      customData: customData ?? this.customData,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoMetadata && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'VideoMetadata(id: $id, title: $title, year: $year)';
  }
}

/// 视频项
@immutable
class VideoItem {
  final String id;
  final String title;
  final String path;
  final String? thumbnailUrl;
  final Duration? duration;
  final int? fileSize; // 字节
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final VideoMetadata? metadata;
  final Map<String, dynamic> customData;

  const VideoItem({
    required this.id,
    required this.title,
    required this.path,
    this.thumbnailUrl,
    this.duration,
    this.fileSize,
    this.createdAt,
    this.updatedAt,
    this.metadata,
    this.customData = const {},
  });

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
      id: json['id'] as String,
      title: json['title'] as String,
      path: json['path'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      duration: json['duration'] != null
          ? Duration(milliseconds: json['duration'] as int)
          : null,
      fileSize: json['fileSize'] as int?,
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int)
          : null,
      metadata: json['metadata'] != null
          ? VideoMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : null,
      customData: json['customData'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'path': path,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration?.inMilliseconds,
      'fileSize': fileSize,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'metadata': metadata?.toJson(),
      'customData': customData,
    };
  }

  VideoItem copyWith({
    String? id,
    String? title,
    String? path,
    String? thumbnailUrl,
    Duration? duration,
    int? fileSize,
    DateTime? createdAt,
    DateTime? updatedAt,
    VideoMetadata? metadata,
    Map<String, dynamic>? customData,
  }) {
    return VideoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      path: path ?? this.path,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
      customData: customData ?? this.customData,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'VideoItem(id: $id, title: $title, path: $path)';
  }
}

/// 媒体文件夹
@immutable
class MediaFolder {
  final String id;
  final String name;
  final String path;
  final int? videoCount;
  final DateTime? lastScanned;
  final Map<String, dynamic> customData;

  const MediaFolder({
    required this.id,
    required this.name,
    required this.path,
    this.videoCount,
    this.lastScanned,
    this.customData = const {},
  });

  factory MediaFolder.fromJson(Map<String, dynamic> json) {
    return MediaFolder(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
      videoCount: json['videoCount'] as int?,
      lastScanned: json['lastScanned'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastScanned'] as int)
          : null,
      customData: json['customData'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'videoCount': videoCount,
      'lastScanned': lastScanned?.millisecondsSinceEpoch,
      'customData': customData,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaFolder && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'MediaFolder(id: $id, name: $name, path: $path, videoCount: $videoCount)';
  }
}

/// 视频流信息
@immutable
class VideoStreamInfo {
  final String url;              // 播放URL
  final Map<String, String> headers; // HTTP headers
  final StreamType streamType;   // 流类型
  final VideoQuality? quality;   // 视频质量
  final bool requiresAuth;       // 是否需要认证
  final bool requiresProxy;      // 是否需要代理
  final String? proxyUrl;        // 代理URL
  final int? bandwidth;          // 带宽需求 (bps)
  final Duration? duration;      // 视频时长
  final Map<String, dynamic> customData;

  const VideoStreamInfo({
    required this.url,
    this.headers = const {},
    this.streamType = StreamType.direct,
    this.quality,
    this.requiresAuth = false,
    this.requiresProxy = false,
    this.proxyUrl,
    this.bandwidth,
    this.duration,
    this.customData = const {},
  });

  factory VideoStreamInfo.fromJson(Map<String, dynamic> json) {
    return VideoStreamInfo(
      url: json['url'] as String,
      headers: Map<String, String>.from(json['headers'] as Map<String, dynamic>? ?? {}),
      streamType: StreamType.values.firstWhere(
        (type) => type.name == json['streamType'],
        orElse: () => StreamType.direct,
      ),
      quality: json['quality'] != null
          ? VideoQuality.values.firstWhere(
              (quality) => quality.name == json['quality'],
              orElse: () => VideoQuality.auto,
            )
          : null,
      requiresAuth: json['requiresAuth'] as bool? ?? false,
      requiresProxy: json['requiresProxy'] as bool? ?? false,
      proxyUrl: json['proxyUrl'] as String?,
      bandwidth: json['bandwidth'] as int?,
      duration: json['duration'] != null
          ? Duration(milliseconds: json['duration'] as int)
          : null,
      customData: json['customData'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'headers': headers,
      'streamType': streamType.name,
      'quality': quality?.name,
      'requiresAuth': requiresAuth,
      'requiresProxy': requiresProxy,
      'proxyUrl': proxyUrl,
      'bandwidth': bandwidth,
      'duration': duration?.inMilliseconds,
      'customData': customData,
    };
  }

  @override
  String toString() {
    return 'VideoStreamInfo(url: $url, type: $streamType, quality: $quality)';
  }
}

/// 字幕轨道
@immutable
class SubtitleTrack {
  final String id;
  final String language;
  final String? languageCode;
  final String? title;
  final String format; // 'srt', 'vtt', 'ass'
  final bool isDefault;
  final bool isForced;
  final String? url;
  final Map<String, dynamic> customData;

  const SubtitleTrack({
    required this.id,
    required this.language,
    this.languageCode,
    this.title,
    required this.format,
    this.isDefault = false,
    this.isForced = false,
    this.url,
    this.customData = const {},
  });

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) {
    return SubtitleTrack(
      id: json['id'] as String,
      language: json['language'] as String,
      languageCode: json['languageCode'] as String?,
      title: json['title'] as String?,
      format: json['format'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
      isForced: json['isForced'] as bool? ?? false,
      url: json['url'] as String?,
      customData: json['customData'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'language': language,
      'languageCode': languageCode,
      'title': title,
      'format': format,
      'isDefault': isDefault,
      'isForced': isForced,
      'url': url,
      'customData': customData,
    };
  }

  @override
  String toString() {
    return 'SubtitleTrack(id: $id, language: $language, format: $format)';
  }
}

/// 扫描选项
class ScanOptions {
  final bool recursive;
  final List<String>? fileExtensions;
  final int? maxDepth;
  final bool includeHidden;
  final int? maxResults;
  final DateTime? modifiedSince;
  final String? searchQuery;

  const ScanOptions({
    this.recursive = true,
    this.fileExtensions = const ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm'],
    this.maxDepth,
    this.includeHidden = false,
    this.maxResults,
    this.modifiedSince,
    this.searchQuery,
  });

  Map<String, dynamic> toJson() {
    return {
      'recursive': recursive,
      'fileExtensions': fileExtensions,
      'maxDepth': maxDepth,
      'includeHidden': includeHidden,
      'maxResults': maxResults,
      'modifiedSince': modifiedSince?.millisecondsSinceEpoch,
      'searchQuery': searchQuery,
    };
  }

  factory ScanOptions.fromJson(Map<String, dynamic> json) {
    return ScanOptions(
      recursive: json['recursive'] as bool? ?? true,
      fileExtensions: (json['fileExtensions'] as List<dynamic>?)?.cast<String>(),
      maxDepth: json['maxDepth'] as int?,
      includeHidden: json['includeHidden'] as bool? ?? false,
      maxResults: json['maxResults'] as int?,
      modifiedSince: json['modifiedSince'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['modifiedSince'] as int)
          : null,
      searchQuery: json['searchQuery'] as String?,
    );
  }
}

/// 媒体服务器插件接口
abstract class MediaServerPlugin extends CorePlugin {
  /// 服务器类型标识
  String get serverType;

  /// 支持的协议（如 'smb://', 'http://'）
  List<String> get supportedProtocols;

  /// 当前连接的服务器配置
  ServerConfig? get currentConfig;

  /// 是否已连接
  bool get isConnected;

  // ===== 连接管理 =====

  /// 测试连接
  Future<ConnectionTestResult> testConnection(ServerConfig config);

  /// 连接服务器
  Future<void> connect(ServerConfig config);

  /// 断开连接
  Future<void> disconnect();

  /// 获取连接状态信息
  Map<String, dynamic> getConnectionInfo();

  // ===== 媒体库操作 =====

  /// 获取文件夹列表
  Future<List<MediaFolder>> getFolders();

  /// 扫描视频
  Future<List<VideoItem>> scanVideos({
    MediaFolder? folder,
    ScanOptions? options,
  });

  /// 获取视频元数据
  Future<VideoMetadata?> getVideoMetadata(String videoId);

  /// 搜索视频
  Future<List<VideoItem>> searchVideos(String query, {ScanOptions? options});

  /// 刷新媒体库
  Future<void> refreshLibrary({MediaFolder? folder});

  // ===== 流媒体 =====

  /// 获取视频流
  Future<VideoStreamInfo> getVideoStream(String videoId, {VideoQuality? quality});

  /// 获取缩略图URL
  Future<String?> getThumbnailUrl(String videoId);

  /// 支持字幕轨道
  Future<List<SubtitleTrack>> getSubtitleTracks(String videoId);

  /// 获取字幕内容
  Future<String?> getSubtitleContent(String videoId, String subtitleId);

  // ===== 配置UI =====

  /// 构建添加服务器界面
  Widget buildAddServerScreen({
    required Function(ServerConfig) onSave,
    ServerConfig? initialConfig,
  });

  /// 构建服务器详情界面
  Widget buildServerDetailScreen(ServerConfig config);

  /// 获取服务器配置验证器
  String? validateConfig(ServerConfig config);
}