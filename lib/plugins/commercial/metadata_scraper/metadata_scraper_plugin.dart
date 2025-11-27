import 'dart:async';
import 'package:flutter/material.dart';
import 'package:yinghe_player/core/plugin_system/core_plugin.dart';
import 'package:yinghe_player/core/plugin_system/plugin_interface.dart';
import 'src/scraper_logic.dart';
import '../../../services/metadata_scraper_service.dart'; // For ScrapingResult
import '../../../models/series.dart';
import '../../../models/episode.dart';

/// 自动元数据刮削插件
class MetadataScraperPlugin extends CorePlugin {
  /// 插件内部状态
  PluginState _internalState = PluginState.uninitialized;
  
  /// 核心逻辑实现
  late final MetadataScraperLogic _logic;

  /// 构造函数,支持可选的动态 metadata
  MetadataScraperPlugin({super.metadata});

  @override
  PluginMetadata get staticMetadata => PluginMetadata(
    id: 'com.coreplayer.metadata_scraper',
    name: '自动元数据刮削',
    version: '1.0.0',
    description: '自动从TMDB等源刮削视频的元数据信息',
    author: 'CorePlayer Team',
    icon: Icons.movie_filter,
    capabilities: ['metadata', 'scraper', 'tmdb'],
    permissions: [PluginPermission.network],
    license: PluginLicense.proprietary,
  );

  @override
  PluginState get state => _internalState;

  @override
  void setStateInternal(PluginState newState) {
    _internalState = newState;
  }

  @override
  Future<void> onInitialize() async {
    _logic = MetadataScraperLogic();
    print('MetadataScraperPlugin initialized (Pro Edition)');
  }

  @override
  Future<void> onActivate() async {
    print('✅ MetadataScraperPlugin activated - Automatic metadata scraping enabled');
    _internalState = PluginState.active;
  }

  @override
  Future<void> onDeactivate() async {
    print('MetadataScraperPlugin deactivated');
    _internalState = PluginState.inactive;
  }

  @override
  Future<void> onDispose() async {
    print('MetadataScraperPlugin disposed');
  }

  @override
  Future<bool> onHealthCheck() async {
    // For now, we'll assume it's always healthy if active.
    return state == PluginState.active;
  }

  // MARK: - Public API
  
  Future<ScrapingResult> scrapeSeries(
    Series series, {
    Function(String)? onProgress,
    bool forceUpdate = false,
  }) {
    return _logic.scrapeSeries(series, onProgress: onProgress, forceUpdate: forceUpdate);
  }
  
  Future<List<ScrapingResult>> scrapeBatchSeries(
    List<Series> seriesList, {
    Function(int current, int total, String status)? onProgress,
    bool forceUpdate = false,
    int delayBetweenRequests = 500,
  }) {
    return _logic.scrapeBatchSeries(
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
    return _logic.scrapeEpisode(episode, tmdbId, seasonNumber);
  }
}
