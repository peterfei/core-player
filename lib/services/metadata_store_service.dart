import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

class MetadataStoreService {
  static const String _seriesBoxName = 'series_metadata';
  static const String _episodeBoxName = 'episode_metadata';
  static Box? _seriesBox;
  static Box? _episodeBox;

  static Future<void> init() async {
    if (_seriesBox != null && _episodeBox != null) return;
    _seriesBox = await Hive.openBox(_seriesBoxName);
    _episodeBox = await Hive.openBox(_episodeBoxName);
  }

  /// 保存剧集元数据
  static Future<void> saveSeriesMetadata(String folderPath, Map<String, dynamic> metadata) async {
    if (_seriesBox == null) await init();
    await _seriesBox!.put(folderPath.hashCode.toString(), metadata);
    debugPrint('💾 已保存剧集元数据: $folderPath');
  }

  /// 获取剧集元数据
  static Map<String, dynamic>? getSeriesMetadata(String folderPath) {
    if (_seriesBox == null) return null;
    final data = _seriesBox!.get(folderPath.hashCode.toString());
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  /// 检查剧集是否已刮削
  static bool isScraped(String folderPath) {
    final metadata = getSeriesMetadata(folderPath);
    return metadata != null && metadata['tmdbId'] != null;
  }

  /// 获取所有已刮削的剧集路径
  static List<String> getAllScrapedSeriesPaths() {
    if (_seriesBox == null) return [];
    return _seriesBox!.keys
        .map((key) => key.toString())
        .toList();
  }

  /// 保存集数元数据
  static Future<void> saveEpisodeMetadata(String episodeId, Map<String, dynamic> metadata) async {
    if (_episodeBox == null) await init();
    await _episodeBox!.put(episodeId, metadata);
    debugPrint('💾 已保存集数元数据: $episodeId');
  }

  /// 获取集数元数据
  static Map<String, dynamic>? getEpisodeMetadata(String episodeId) {
    if (_episodeBox == null) return null;
    final data = _episodeBox!.get(episodeId);
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  /// 删除剧集元数据
  static Future<void> deleteSeriesMetadata(String folderPath) async {
    if (_seriesBox == null) await init();
    await _seriesBox!.delete(folderPath.hashCode.toString());
    debugPrint('🗑️ 已删除剧集元数据: $folderPath');
  }

  /// 删除集数元数据
  static Future<void> deleteEpisodeMetadata(String episodeId) async {
    if (_episodeBox == null) await init();
    await _episodeBox!.delete(episodeId);
    debugPrint('🗑️ 已删除集数元数据: $episodeId');
  }

  /// 清除所有元数据
  static Future<void> clear() async {
    if (_seriesBox == null || _episodeBox == null) await init();
    await _seriesBox!.clear();
    await _episodeBox!.clear();
    debugPrint('🗑️ 已清除所有元数据');
  }
}
