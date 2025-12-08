import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class ScannedVideo extends HiveObject {
  final String path;
  final String name;
  final String? sourceId;
  final int size;
  final DateTime? addedAt;

  ScannedVideo({
    required this.path,
    required this.name,
    this.sourceId,
    required this.size,
    this.addedAt,
  });
  
  /// 生成路径的 hash 值作为唯一标识
  String get pathHash {
    final bytes = utf8.encode(path);
    final digest = md5.convert(bytes);
    return digest.toString();
  }
}

class ScannedSeries extends HiveObject {
  final String id;
  final String name;
  final String folderPath;
  final int episodeCount;
  final DateTime addedAt;

  ScannedSeries({
    required this.id,
    required this.name,
    required this.folderPath,
    required this.episodeCount,
    required this.addedAt,
  });
}

class ScannedEpisode extends HiveObject {
  final String id;
  final String seriesId;
  final String name;
  final String path;
  final int size;
  final int? episodeNumber;
  final DateTime addedAt;
  final String? sourceId;

  ScannedEpisode({
    required this.id,
    required this.seriesId,
    required this.name,
    required this.path,
    required this.size,
    this.episodeNumber,
    required this.addedAt,
    this.sourceId,
  });
}

class ScannedVideoAdapter extends TypeAdapter<ScannedVideo> {
  @override
  final int typeId = 11;

  @override
  ScannedVideo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScannedVideo(
      path: fields[0] as String,
      name: fields[1] as String,
      sourceId: fields[2] as String?,
      size: fields[3] as int,
      addedAt: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ScannedVideo obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.path)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.sourceId)
      ..writeByte(3)
      ..write(obj.size)
      ..writeByte(4)
      ..write(obj.addedAt);
  }
}

class ScannedSeriesAdapter extends TypeAdapter<ScannedSeries> {
  @override
  final int typeId = 12;

  @override
  ScannedSeries read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScannedSeries(
      id: fields[0] as String,
      name: fields[1] as String,
      folderPath: fields[2] as String,
      episodeCount: fields[3] as int,
      addedAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ScannedSeries obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.folderPath)
      ..writeByte(3)
      ..write(obj.episodeCount)
      ..writeByte(4)
      ..write(obj.addedAt);
  }
}

class ScannedEpisodeAdapter extends TypeAdapter<ScannedEpisode> {
  @override
  final int typeId = 13;

  @override
  ScannedEpisode read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScannedEpisode(
      id: fields[0] as String,
      seriesId: fields[1] as String,
      name: fields[2] as String,
      path: fields[3] as String,
      size: fields[4] as int,
      episodeNumber: fields[5] as int?,
      addedAt: fields[6] as DateTime,
      sourceId: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ScannedEpisode obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.seriesId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.path)
      ..writeByte(4)
      ..write(obj.size)
      ..writeByte(5)
      ..write(obj.episodeNumber)
      ..writeByte(6)
      ..write(obj.addedAt)
      ..writeByte(7)
      ..write(obj.sourceId);
  }
}

class MediaLibraryService {
  static const String _boxName = 'media_library';
  static const String _seriesBoxName = 'series_library';
  static const String _episodesBoxName = 'episodes_library';
  
  static late Box<ScannedVideo> _box;
  static late Box<ScannedSeries> _seriesBox;
  static late Box<ScannedEpisode> _episodesBox;

  // 文件夹图片缓存: folderPath -> {type: path}
  static final Map<String, Map<String, String>> _folderImages = {};

  static Future<void> init() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocDir.path);
    
    if (!Hive.isAdapterRegistered(11)) Hive.registerAdapter(ScannedVideoAdapter());
    if (!Hive.isAdapterRegistered(12)) Hive.registerAdapter(ScannedSeriesAdapter());
    if (!Hive.isAdapterRegistered(13)) Hive.registerAdapter(ScannedEpisodeAdapter());

    _box = await Hive.openBox<ScannedVideo>(_boxName);
    _seriesBox = await Hive.openBox<ScannedSeries>(_seriesBoxName);
    _episodesBox = await Hive.openBox<ScannedEpisode>(_episodesBoxName);
  }

  static List<ScannedVideo> getAllVideos() {
    return _box.values.toList();
  }

  static Future<void> addVideo(ScannedVideo video) async {
    await _box.put(video.pathHash, video);
  }

  static Future<void> addVideos(List<ScannedVideo> videos) async {
    final Map<String, ScannedVideo> entries = {
      for (var video in videos) video.pathHash: video
    };
    await _box.putAll(entries);
  }

  // --- Series Methods ---

  static Future<void> saveSeries(List<ScannedSeries> seriesList) async {
    final Map<String, ScannedSeries> entries = {
      for (var series in seriesList) series.id: series
    };
    await _seriesBox.putAll(entries);
  }

  static List<ScannedSeries> getAllSeries() {
    return _seriesBox.values.toList();
  }

  static Future<void> saveEpisodes(List<ScannedEpisode> episodes) async {
    final Map<String, ScannedEpisode> entries = {
      for (var episode in episodes) episode.id: episode
    };
    await _episodesBox.putAll(entries);
  }

  static List<ScannedEpisode> getEpisodesForSeries(String seriesId) {
    return _episodesBox.values.where((e) => e.seriesId == seriesId).toList();
  }

  static Future<void> removeSeries(String seriesId) async {
    if (_seriesBox.isOpen && _seriesBox.containsKey(seriesId)) {
      await _seriesBox.delete(seriesId);
    }
  }

  static Future<void> removeEpisodes(List<String> episodeIds) async {
    if (_episodesBox.isOpen) {
      await _episodesBox.deleteAll(episodeIds);
    }
  }
  
  /// 添加文件夹图片
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

  static Future<void> clearSeriesInfo() async {
    if (_seriesBox.isOpen) await _seriesBox.clear();
    if (_episodesBox.isOpen) await _episodesBox.clear();
  }

  static Future<void> clear() async {
    await _box.clear();
    await _seriesBox.clear();
    await _episodesBox.clear();
    _folderImages.clear();
  }
}