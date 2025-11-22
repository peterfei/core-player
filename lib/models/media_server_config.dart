import 'package:hive/hive.dart';

part 'media_server_config.g.dart';

@HiveType(typeId: 10)
class MediaServerConfig extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String type; // 'emby', 'jellyfin', 'plex', 'feiniu', 'synology'

  @HiveField(2)
  final String name;

  @HiveField(3)
  final String url;

  @HiveField(4)
  final String username;

  @HiveField(5)
  final String token;

  @HiveField(6)
  final String? domain;

  @HiveField(7)
  final int? port;

  @HiveField(8)
  final List<String>? sharedFolders;

  MediaServerConfig({
    required this.id,
    required this.type,
    required this.name,
    required this.url,
    required this.username,
    required this.token,
    this.domain,
    this.port,
    this.sharedFolders,
  });
  
  /// 创建副本并更新共享文件夹
  MediaServerConfig copyWith({
    String? id,
    String? type,
    String? name,
    String? url,
    String? username,
    String? token,
    String? domain,
    int? port,
    List<String>? sharedFolders,
  }) {
    return MediaServerConfig(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      url: url ?? this.url,
      username: username ?? this.username,
      token: token ?? this.token,
      domain: domain ?? this.domain,
      port: port ?? this.port,
      sharedFolders: sharedFolders ?? this.sharedFolders,
    );
  }
}
