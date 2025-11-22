import 'package:hive_flutter/hive_flutter.dart';
import '../models/media_server_config.dart';

class MediaServerService {
  static const String _boxName = 'media_servers';

  static Future<void> initialize() async {
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(MediaServerConfigAdapter());
    }
    await Hive.openBox<MediaServerConfig>(_boxName);
  }

  static Box<MediaServerConfig> get _box => Hive.box<MediaServerConfig>(_boxName);

  static List<MediaServerConfig> getServers() {
    return _box.values.toList();
  }

  static Future<void> addServer(MediaServerConfig config) async {
    await _box.put(config.id, config);
  }

  static Future<void> removeServer(String id) async {
    await _box.delete(id);
  }
  
  static Future<void> updateServer(MediaServerConfig config) async {
    await _box.put(config.id, config);
  }
}
