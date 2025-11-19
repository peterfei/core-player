import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'media_scanner_service.dart';
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
  static late Box<ScannedVideo> _box; // Changed to late initialization

  // 文件夹图片缓存: folderPath -> {type: path}
  static final Map<String, Map<String, String>> _folderImages = {};

  static Future<void> init() async { // Renamed initialize to init
    final appDocDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocDir.path);
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(ScannedVideoAdapter());
    }
    _box = await Hive.openBox<ScannedVideo>(_boxName);
    
    // TODO: 持久化 _folderImages
  }

  static List<ScannedVideo> getAllVideos() {
    return _box.values.toList();
  }

  static Future<void> addVideo(ScannedVideo video) async {
    // Use path hash as key to avoid duplicates and length limitation
    await _box.put(video.pathHash, video);
  }

  static Future<void> addVideos(List<ScannedVideo> videos) async {
    final Map<String, ScannedVideo> entries = {
      for (var video in videos) video.pathHash: video // Changed 'v' to 'video' for consistency
    };
    await _box.putAll(entries);
  }
  
  /// 添加文件夹图片
  /// [folderPath] 文件夹路径
  /// [type] 图片类型: 'poster', 'backdrop', 'logo' 等
  /// [path] 图片文件路径
  static void addFolderImage(String folderPath, String type, String path) {
    if (!_folderImages.containsKey(folderPath)) {
      _folderImages[folderPath] = {};
    }
    _folderImages[folderPath]![type] = path;
  }
  
  /// 获取文件夹的所有图片
  static Map<String, String> getFolderImages(String folderPath) {
    return _folderImages[folderPath] ?? {};
  }
  
  /// 获取文件夹的特定类型图片
  static String? getFolderImage(String folderPath, String type) {
    return _folderImages[folderPath]?[type];
  }

  static Future<void> clear() async {
    await _box.clear();
    _folderImages.clear();
  }
}
