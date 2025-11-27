import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/series.dart';
import '../models/episode.dart';
import '../core/plugin_system/plugin_registry.dart';
import '../core/plugin_system/plugin_interface.dart';

/// 刮削结果
class ScrapingResult {
  final String seriesId;
  final String seriesName;
  final bool success;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;

  ScrapingResult({
    required this.seriesId,
    required this.seriesName,
    required this.success,
    this.errorMessage,
    this.metadata,
  });
}

/// 元数据刮削服务 (Facade)
/// 代理到 com.coreplayer.metadata_scraper 插件
class MetadataScraperService {
  static const String _pluginId = 'com.coreplayer.metadata_scraper';

  /// 为单个剧集刮削元数据
  static Future<ScrapingResult> scrapeSeries(
    Series series, {
    Function(String)? onProgress,
    bool forceUpdate = false,
  }) async {
    final plugin = PluginRegistry().get<CorePlugin>(_pluginId);
    
    if (plugin != null && plugin.state == PluginState.active) {
      try {
        // 使用 dynamic 调用插件方法
        return await (plugin as dynamic).scrapeSeries(
          series,
          onProgress: onProgress,
          forceUpdate: forceUpdate,
        );
      } catch (e) {
        debugPrint('❌ 调用刮削插件失败: $e');
        return ScrapingResult(
          seriesId: series.id,
          seriesName: series.name,
          success: false,
          errorMessage: '插件调用失败: $e',
        );
      }
    } else {
      debugPrint('⚠️ 刮削插件不可用或未激活');
      return ScrapingResult(
        seriesId: series.id,
        seriesName: series.name,
        success: false,
        errorMessage: '自动刮削功能仅在专业版可用',
      );
    }
  }

  /// 批量刮削多个剧集
  static Future<List<ScrapingResult>> scrapeBatchSeries(
    List<Series> seriesList, {
    Function(int current, int total, String status)? onProgress,
    bool forceUpdate = false,
    int delayBetweenRequests = 500,
  }) async {
    final plugin = PluginRegistry().get<CorePlugin>(_pluginId);

    if (plugin != null && plugin.state == PluginState.active) {
       try {
        return await (plugin as dynamic).scrapeBatchSeries(
          seriesList,
          onProgress: onProgress,
          forceUpdate: forceUpdate,
          delayBetweenRequests: delayBetweenRequests,
        );
      } catch (e) {
        debugPrint('❌ 调用刮削插件失败: $e');
        return [];
      }
    } else {
       debugPrint('⚠️ 刮削插件不可用或未激活');
       return [];
    }
  }

  /// 刮削集数详细信息
  static Future<Map<String, dynamic>?> scrapeEpisode(
    Episode episode,
    int tmdbId,
    int seasonNumber,
  ) async {
    final plugin = PluginRegistry().get<CorePlugin>(_pluginId);

    if (plugin != null && plugin.state == PluginState.active) {
      try {
        return await (plugin as dynamic).scrapeEpisode(episode, tmdbId, seasonNumber);
      } catch (e) {
        debugPrint('❌ 调用刮削插件失败: $e');
        return null;
      }
    }
    return null;
  }
}