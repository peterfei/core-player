import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../core/scraping/naming_patterns.dart';
import '../models/series.dart';
import '../models/episode.dart';
import '../core/plugin_system/plugin_registry.dart';
import '../core/plugin_system/plugin_interface.dart';
import '../core/scraping/name_parser.dart';
import '../core/scraping/similarity_calculator.dart';
import '../core/scraping/scraping_candidate.dart';
import 'tmdb_service.dart';
import 'settings_service.dart';
import 'metadata_store_service.dart';
import 'image_download_service.dart';

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
    // 优先尝试使用插件 (如果可用)
    final plugin = PluginRegistry().get<CorePlugin>(_pluginId);
    if (plugin != null && plugin.state == PluginState.active) {
      try {
        return await (plugin as dynamic).scrapeSeries(
          series,
          onProgress: onProgress,
          forceUpdate: forceUpdate,
        );
      } catch (e) {
        debugPrint('❌ 插件刮削失败，尝试使用内置刮削: $e');
      }
    }

    // 内置增强刮削逻辑
    return _scrapeSeriesInternal(series, onProgress: onProgress);
  }

  static Future<ScrapingResult> _scrapeSeriesInternal(
    Series series, {
    Function(String)? onProgress,
  }) async {
    try {
      onProgress?.call('正在分析文件名...');
      
      // 1. 生成搜索候选词
      final candidates = NameParser.generateCandidates(series.name);
      
      // Fallback: 如果文件名看起来像文件 (有扩展名) 且解析结果可能不理想，
      // 尝试添加父文件夹名称作为候选
      // e.g. "/path/to/南来北往/n来b往.mp4" -> "南来北往"
      final extension = series.name.split('.').last.toLowerCase();
      if (NamingPatterns.videoExtensions.contains(extension)) {
        // 尝试从路径获取父文件夹名
        // series.folderPath 可能是文件路径
        final parentDir = path.dirname(series.folderPath);
        final parentName = path.basename(parentDir);
        
        // 过滤掉通用文件夹名
        if (!NamingPatterns.invalidNames.contains(parentName.toLowerCase()) && 
            !['download', 'downloads', 'movie', 'movies', 'tv', 'series', 'video', 'videos'].contains(parentName.toLowerCase())) {
             
           // 解析父文件夹名
           final parentCandidates = NameParser.generateCandidates(parentName);
           for (final candidate in parentCandidates) {
             // 避免重复
             if (!candidates.any((c) => c.query == candidate.query)) {
               candidates.add(candidate);
             }
           }
        }
      }

      if (candidates.isEmpty) {
        return ScrapingResult(
          seriesId: series.id,
          seriesName: series.name,
          success: false,
          errorMessage: '无法从文件名提取有效信息',
        );
      }

      Map<String, dynamic>? bestMatch;
      double bestScore = 0.0;
      String? bestType; // 'tv' or 'movie'
      
      final similarityThreshold = await SettingsService.getScrapingSimilarityThreshold();
      final minConfidence = await SettingsService.getScrapingMinConfidence();

      // 2. 遍历候选词进行搜索
      for (final candidate in candidates) {
        onProgress?.call('正在搜索: ${candidate.query}');
        
        // 搜索电视剧
        final tvResults = await TMDBService.searchTVShow(candidate.query);
        final (tvMatch, tvScore) = _findBestMatch(candidate, tvResults, isMovie: false);
        
        if (tvScore > bestScore) {
          bestScore = tvScore;
          bestMatch = tvMatch;
          bestType = 'tv';
        }

        // 搜索电影
        final movieResults = await TMDBService.searchMovie(candidate.query);
        final (movieMatch, movieScore) = _findBestMatch(candidate, movieResults, isMovie: true);
        
        if (movieScore > bestScore) {
          bestScore = movieScore;
          bestMatch = movieMatch;
          bestType = 'movie';
        }

        // 搜索合集 (Collection)
        // 如果是电影系列，通常会有合集信息
        final collectionResults = await TMDBService.searchCollection(candidate.query);
        final (collectionMatch, collectionScore) = _findBestMatch(candidate, collectionResults, isMovie: false); // Collection has 'name' like TV

        // 合集优先策略：
        // 1. 如果合集分数 >= 0.75，且与当前最佳分数相差不大（<0.15），优先选择合集
        // 2. 或者合集分数本身就是最高的
        // 这样可以确保 "哈利波特全集" 匹配到 "Harry Potter Collection" 而不是单部电影
        if (collectionScore >= 0.75) {
          if (collectionScore > bestScore || (bestScore - collectionScore) < 0.15) {
            bestScore = collectionScore;
            bestMatch = collectionMatch;
            bestType = 'collection';
          }
        }

        // 如果找到足够好的匹配，提前结束
        if (bestScore > similarityThreshold) break;
      }

      if (bestMatch == null || bestScore < minConfidence) {
        return ScrapingResult(
          seriesId: series.id,
          seriesName: series.name,
          success: false,
          errorMessage: '未找到匹配结果 (最高相似度: ${bestScore.toStringAsFixed(2)})',
        );
      }

      onProgress?.call('获取详细信息...');
      final tmdbId = bestMatch['id'];
      final details = await TMDBService.getDetails(tmdbId, type: bestType!);

      if (details != null) {
        // 下载图片
        onProgress?.call('下载封面...');
        final images = await ImageDownloadService.downloadSeriesImages(
          tmdbId: tmdbId,
          posterPath: details['poster_path'],
          backdropPath: details['backdrop_path'],
        );
        
        // 保存元数据到数据库
        final metadata = {
          'tmdbId': tmdbId,
          'name': details[bestType == 'movie' ? 'title' : 'name'], // Collection uses 'name'
          'originalName': details[bestType == 'movie' ? 'original_title' : 'original_name'], // Collection uses 'original_name'
          'overview': details['overview'],
          'posterPath': images['poster'] ?? details['poster_path'], // 优先使用本地路径
          'backdropPath': images['backdrop'] ?? details['backdrop_path'], // 优先使用本地路径
          'rating': (details['vote_average'] as num?)?.toDouble(),
          'releaseDate': details[bestType == 'movie' ? 'release_date' : (bestType == 'tv' ? 'first_air_date' : null)], // Collection might not have date
          'status': details['status'],
          'type': bestType,
          'scrapedAt': DateTime.now().toIso8601String(),
        };
        
        // 保存到数据库
        await MetadataStoreService.saveSeriesMetadata(series.folderPath, metadata);
        
        return ScrapingResult(
          seriesId: series.id,
          seriesName: series.name,
          success: true,
          metadata: metadata,
        );
      } else {
        return ScrapingResult(
          seriesId: series.id,
          seriesName: series.name,
          success: false,
          errorMessage: '获取详情失败',
        );
      }
    } catch (e) {
      debugPrint('内置刮削异常: $e');
      return ScrapingResult(
        seriesId: series.id,
        seriesName: series.name,
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  static (Map<String, dynamic>?, double) _findBestMatch(
    ScrapingCandidate candidate,
    List<Map<String, dynamic>> results, {
    required bool isMovie,
  }) {
    if (results.isEmpty) return (null, 0.0);

    Map<String, dynamic>? bestItem;
    double maxScore = 0.0;

    for (final item in results) {
      final title = item[isMovie ? 'title' : 'name'] as String?;
      final originalTitle = item[isMovie ? 'original_title' : 'original_name'] as String?;
      final releaseDate = item[isMovie ? 'release_date' : 'first_air_date'] as String?;
      
      if (title == null) continue;

      // 计算名称相似度
      double score = SimilarityCalculator.calculate(candidate.query, title);
      
      // 如果有rawQuery (包含混淆字符)，也尝试匹配
      if (candidate.rawQuery != null && candidate.rawQuery != candidate.query) {
        final rawScore = SimilarityCalculator.calculate(candidate.rawQuery!, title);
        if (rawScore > score) score = rawScore;
      }
      
      // 如果有原名，也尝试匹配
      if (originalTitle != null && originalTitle != title) {
        final originalScore = SimilarityCalculator.calculate(candidate.query, originalTitle);
        if (originalScore > score) score = originalScore;
        
        // 同样尝试用rawQuery匹配原名
        if (candidate.rawQuery != null && candidate.rawQuery != candidate.query) {
          final rawOriginalScore = SimilarityCalculator.calculate(candidate.rawQuery!, originalTitle);
          if (rawOriginalScore > score) score = rawOriginalScore;
        }
      }

      // 年份匹配加分
      if (candidate.year != null && releaseDate != null && releaseDate.length >= 4) {
        final itemYear = int.tryParse(releaseDate.substring(0, 4));
        if (itemYear == candidate.year) {
          score += 0.15; // 年份匹配奖励
        } else if (itemYear != null && (itemYear - candidate.year!).abs() <= 1) {
          score += 0.05; // 年份接近奖励
        } else {
          score -= 0.1; // 年份不匹配惩罚
        }
      }

      if (score > maxScore) {
        maxScore = score;
        bestItem = item;
      }
    }

    return (bestItem, maxScore);
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