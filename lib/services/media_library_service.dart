import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

part 'media_library_service.g.dart';

@HiveType(typeId: 11)
class ScannedVideo extends HiveObject {
  @HiveField(0)
  final String path;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String sourceId;

  @HiveField(3)
  final int size;

  @HiveField(4)
  final DateTime? addedAt;

  ScannedVideo({
    required this.path,
    required this.name,
    required this.sourceId,
    required this.size,
    this.addedAt,
  });
  
  /// 生成路径的 hash 值作为唯一标识
  /// 用于避免 Hive key 长度超过 255 字符的限制
  String get pathHash {
    final bytes = utf8.encode(path);
    final digest = md5.convert(bytes);
    return digest.toString();
  }
}

class MediaLibraryService {
  static const String _boxName = 'media_library';

  static Future<void> initialize() async {
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(ScannedVideoAdapter());
    }
    await Hive.openBox<ScannedVideo>(_boxName);
  }

  static Box<ScannedVideo> get _box => Hive.box<ScannedVideo>(_boxName);

  static List<ScannedVideo> getAllVideos() {
    return _box.values.toList();
  }

  static Future<void> addVideo(ScannedVideo video) async {
    // Use path hash as key to avoid duplicates and length limitation
    await _box.put(video.pathHash, video);
  }

  static Future<void> addVideos(List<ScannedVideo> videos) async {
    final Map<String, ScannedVideo> entries = {
      for (var v in videos) v.pathHash: v
    };
    await _box.putAll(entries);
  }
  
  static Future<void> clear() async {
    await _box.clear();
  }
}
