import 'package:flutter/foundation.dart';
import '../services/series_service.dart';
import '../services/media_library_service.dart';
import '../services/metadata_scraper_service.dart';
import '../services/settings_service.dart';

/// 自动刮削服务
/// 负责在媒体扫描后自动触发元数据刮削
class AutoScraperService {
  /// 自动刮削视频列表
  /// 
  /// [videos] 已扫描的视频列表
  /// [onProgress] 进度回调，参数为 (当前索引, 总数, 状态描述)
  /// 返回刮削结果摘要
  static Future<AutoScrapingResult> autoScrapeVideos(
    List<ScannedVideo> videos, {
    Function(int current, int total, String status)? onProgress,
  }) async {
    debugPrint('');
    debugPrint('🤖 ═══════════════════════════════════════════════════════');
    debugPrint('🤖 自动刮削服务: 开始处理');
    debugPrint('🤖 视频数量: ${videos.length}');
    debugPrint('🤖 ═══════════════════════════════════════════════════════');

    // 检查是否启用自动刮削
    final autoScrapeEnabled = await SettingsService.getAutoScrapeEnabled();
    debugPrint('🤖 自动刮削设置: ${autoScrapeEnabled ? "已启用" : "已禁用"}');
    
    if (!autoScrapeEnabled) {
      debugPrint('🤖 自动刮削已禁用，跳过');
      debugPrint('🤖 ═══════════════════════════════════════════════════════');
      debugPrint('');
      return AutoScrapingResult(
        totalVideos: videos.length,
        totalSeries: 0,
        scrapedSeries: 0,
        failedSeries: 0,
        skipped: true,
      );
    }

    // 分组为剧集
    onProgress?.call(0, videos.length, '正在分组视频...');
    debugPrint('🤖 分组视频为剧集...');
    
    final seriesList = SeriesService.groupVideosBySeries(videos);
    debugPrint('🤖 找到 ${seriesList.length} 个剧集');

    if (seriesList.isEmpty) {
      debugPrint('🤖 没有找到剧集，退出');
      debugPrint('🤖 ═══════════════════════════════════════════════════════');
      debugPrint('');
      return AutoScrapingResult(
        totalVideos: videos.length,
        totalSeries: 0,
        scrapedSeries: 0,
        failedSeries: 0,
        skipped: false,
      );
    }

    // 批量刮削
    debugPrint('🤖 开始批量刮削...');
    int successCount = 0;
    int failedCount = 0;

    for (int i = 0; i < seriesList.length; i++) {
      final series = seriesList[i];
      onProgress?.call(i, seriesList.length, '正在刮削: ${series.name}');
      
      debugPrint('🤖 [$i/${seriesList.length}] 刮削: ${series.name}');
      
      final result = await MetadataScraperService.scrapeSeries(
        series,
        onProgress: (status) {
          debugPrint('   → $status');
        },
        forceUpdate: false, // 不强制更新，如果已存在则跳过
      );

      if (result.success) {
        successCount++;
        debugPrint('   ✅ 成功');
      } else {
        failedCount++;
        debugPrint('   ❌ 失败: ${result.errorMessage}');
      }

      // 延迟以避免 API 限流（TMDB 限制每秒4个请求，使用500ms更保守）
      if (i < seriesList.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500)); // 从300ms增加到500ms
      }
    }

    onProgress?.call(seriesList.length, seriesList.length, '刮削完成');
    
    // 重新处理并保存剧集数据，以确保 Series.folderPath 指向已刮削的路径
    debugPrint('🤖 刮削完成，正在刷新剧集分组数据...');
    await SeriesService.processAndSaveSeries(videos);
    
    debugPrint('');
    debugPrint('🤖 ═══════════════════════════════════════════════════════');
    debugPrint('🤖 自动刮削完成');
    debugPrint('🤖 总剧集数: ${seriesList.length}');
    debugPrint('🤖 成功: $successCount');
    debugPrint('🤖 失败: $failedCount');
    debugPrint('🤖 ═══════════════════════════════════════════════════════');
    debugPrint('');

    return AutoScrapingResult(
      totalVideos: videos.length,
      totalSeries: seriesList.length,
      scrapedSeries: successCount,
      failedSeries: failedCount,
      skipped: false,
    );
  }
}

/// 自动刮削结果
class AutoScrapingResult {
  final int totalVideos;
  final int totalSeries;
  final int scrapedSeries;
  final int failedSeries;
  final bool skipped;

  AutoScrapingResult({
    required this.totalVideos,
    required this.totalSeries,
    required this.scrapedSeries,
    required this.failedSeries,
    required this.skipped,
  });

  @override
  String toString() {
    if (skipped) {
      return '自动刮削已禁用';
    }
    return '视频: $totalVideos, 剧集: $totalSeries, 成功: $scrapedSeries, 失败: $failedSeries';
  }
}
