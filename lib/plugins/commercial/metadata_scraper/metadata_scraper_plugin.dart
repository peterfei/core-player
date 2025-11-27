import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:coreplayer_pro_plugins/coreplayer_pro_plugins.dart' as pro;
import 'package:yinghe_player/core/plugin_system/core_plugin.dart';
import 'package:yinghe_player/core/plugin_system/plugin_interface.dart';

import '../../../services/metadata_scraper_service.dart' as vidhub;
import '../../../services/metadata_store_service.dart';
import '../../../services/tmdb_service.dart';
import '../../../models/series.dart';
import '../../../models/episode.dart';
import 'src/scraper_logic.dart';

/// 自动元数据刮削插件 (VidHub Adapter)
/// 
/// 这个类作为主应用和私有库中商业插件实现的桥梁。
/// 它负责注入主应用的特定服务（如TMDBService, MetadataStore）到插件中。
class MetadataScraperPlugin extends CorePlugin {
  final pro.MetadataScraperPlugin _impl = pro.MetadataScraperPlugin();
  
  // 保留旧的逻辑实例用于辅助功能（如集数刮削）
  late final MetadataScraperLogic _legacyLogic;

  MetadataScraperPlugin({super.metadata});

  @override
  PluginMetadata get staticMetadata => _impl.metadata;

  @override
  PluginState get state => _impl.state;

  @override
  void setStateInternal(PluginState newState) {
    _impl.setStateInternal(newState);
  }

  @override
  Future<void> onInitialize() async {
    _legacyLogic = MetadataScraperLogic();
    await _impl.onInitialize();
  }

  @override
  Future<void> onActivate() async {
    await _impl.onActivate();
  }

  @override
  Future<void> onDeactivate() async {
    await _impl.onDeactivate();
  }

  @override
  Future<void> onDispose() async {
    await _impl.onDispose();
  }

  @override
  Future<bool> onHealthCheck() async {
    return await _impl.onHealthCheck();
  }

  // MARK: - Adapter Methods

  /// 适配 scrapeSeries 方法
  Future<vidhub.ScrapingResult> scrapeSeries(
    Series series, {
    Function(String)? onProgress,
    bool forceUpdate = false,
  }) async {
    try {
      // 确保 legacyLogic 已初始化 (防卫性编程)
      // ignore: unnecessary_null_comparison
      if (_legacyLogic == null) _legacyLogic = MetadataScraperLogic();

      final result = await _impl.scrapeSeries(
        seriesId: series.id,
        seriesName: series.name,
        folderPath: series.folderPath,
        forceUpdate: forceUpdate,
        onProgress: onProgress,
        // 注入回调
        isScrapedCallback: (path) async => MetadataStoreService.isScraped(path),
        getMetadataCallback: (path) async => MetadataStoreService.getSeriesMetadata(path),
        saveMetadataCallback: (path, meta) async => MetadataStoreService.saveSeriesMetadata(path, meta),
        searchTMDBCallback: (query) async => TMDBService.searchTVShow(query),
        getTVDetailsCallback: (id) async => TMDBService.getTVShowDetails(id),
        getImageUrlCallback: (path) async => TMDBService.getImageUrl(path),
        downloadImageCallback: (url, path) async {
          try {
            final response = await http.get(Uri.parse(url));
            if (response.statusCode == 200) {
              final file = File(path);
              await file.writeAsBytes(response.bodyBytes);
              return path;
            }
          } catch (e) {
            print('Image download failed: $e');
          }
          return null;
        },
        scrapeEpisodesCallback: (tmdbId, seasonCount) async {
          // 调用本地逻辑来刮削集数
          return await _legacyLogic.scrapeEpisodesForSeries(
             series,
             tmdbId,
             seasonCount,
             onProgress: onProgress,
          );
        }
      );

      return vidhub.ScrapingResult(
        seriesId: result.seriesId,
        seriesName: result.seriesName,
        success: result.success,
        errorMessage: result.errorMessage,
        metadata: result.metadata,
      );
    } catch (e) {
      return vidhub.ScrapingResult(
        seriesId: series.id,
        seriesName: series.name,
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  Future<List<vidhub.ScrapingResult>> scrapeBatchSeries(
    List<Series> seriesList, {
    Function(int current, int total, String status)? onProgress,
    bool forceUpdate = false,
    int delayBetweenRequests = 500,
  }) {
    // ignore: unnecessary_null_comparison
    if (_legacyLogic == null) _legacyLogic = MetadataScraperLogic();
    
    return _legacyLogic.scrapeBatchSeries(
      seriesList, 
      onProgress: onProgress, 
      forceUpdate: forceUpdate, 
      delayBetweenRequests: delayBetweenRequests
    );
  }
  
  Future<Map<String, dynamic>?> scrapeEpisode(
    Episode episode,
    int tmdbId,
    int seasonNumber,
  ) {
    // ignore: unnecessary_null_comparison
    if (_legacyLogic == null) _legacyLogic = MetadataScraperLogic();

    return _legacyLogic.scrapeEpisode(episode, tmdbId, seasonNumber);
  }
}
