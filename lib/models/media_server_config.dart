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

  MediaServerConfig({
    required this.id,
    required this.type,
    required this.name,
    required this.url,
    required this.username,
    required this.token,
    this.domain,
    this.port,
  });
}
