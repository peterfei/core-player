import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../models/series.dart';
import '../models/episode.dart';
import 'tmdb_service.dart';
import 'metadata_store_service.dart';
import 'media_library_service.dart';
import 'series_service.dart';

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

/// 元数据刮削服务
/// 负责从 TMDB 搜索并下载剧集元数据
class MetadataScraperService {
  static const String _imagesFolderName = 'metadata/images';
  
  /// 获取图片存储目录
  static Future<Directory> _getImagesDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDocDir.path, _imagesFolderName));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  /// 智能提取剧集名称
  /// 从文件夹名称中去除年份、特殊标记等
  static String extractSeriesName(String folderName) {
    // 从路径中提取文件夹名称
    String name = p.basename(folderName);
    
    // 去除常见的括号内容，如 (2023)、[1080p]、【中文字幕】等
    name = name.replaceAll(RegExp(r'\s*[\(\[\{【].*?[\)\]\}】]\s*'), ' ');
    
    // 去除年份（四位数字）
    name = name.replaceAll(RegExp(r'\s*\d{4}\s*'), ' ');
    
    // 去除季数标记，如 S01、Season 1、第一季等
    name = name.replaceAll(RegExp(r'\s*[Ss]\d+\s*'), ' ');
    name = name.replaceAll(RegExp(r'\s*[Ss]eason\s*\d+\s*', caseSensitive: false), ' ');
    name = name.replaceAll(RegExp(r'\s*第[一二三四五六七八九十\d]+季\s*'), ' ');
    
    // 去除分辨率标记，如 1080p、4K、HD等
    name = name.replaceAll(RegExp(r'\s*\d+[pP]\s*'), ' ');
    name = name.replaceAll(RegExp(r'\s*[4K|HD|UHD|BluRay|WEB-DL|WEBRip]+\s*', caseSensitive: false), ' ');
    
    // 去除常见的标记如 Complete、全集等
    name = name.replaceAll(RegExp(r'\s*[Cc]omplete\s*'), ' ');
    name = name.replaceAll(RegExp(r'\s*全集\s*'), ' ');
    
    // 去除多余的空格和特殊字符
    name = name.replaceAll(RegExp(r'[._-]+'), ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ');
    name = name.trim();
    
    return name;
  }

  /// 为单个剧集刮削元数据
  /// 
  /// [series] 要刮削的剧集
  /// [onProgress] 进度回调，参数为当前状态描述
  /// [forceUpdate] 是否强制更新已存在的元数据
  static Future<ScrapingResult> scrapeSeries(
    Series series, {
    Function(String)? onProgress,
    bool forceUpdate = false,
  }) async {
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('🎬 开始刮削剧集: ${series.name}');
    debugPrint('📂 文件夹路径: ${series.folderPath}');
    debugPrint('🆔 剧集 ID: ${series.id}');
    debugPrint('═══════════════════════════════════════════════════════');
    
    try {
      // 检查 TMDB 服务是否已初始化
      debugPrint('🔍 检查 TMDB 服务状态...');
      if (!TMDBService.isInitialized) {
        debugPrint('❌ TMDB 服务未初始化！');
        return ScrapingResult(
          seriesId: series.id,
          seriesName: series.name,
          success: false,
          errorMessage: 'TMDB 服务未初始化，请先配置 API Key',
        );
      }
      debugPrint('✅ TMDB 服务已初始化');

      // 检查是否已刮削
      debugPrint('📋 检查刮削状态...');
      final isAlreadyScraped = MetadataStoreService.isScraped(series.folderPath);
      debugPrint('   已刮削: $isAlreadyScraped, 强制更新: $forceUpdate');
      
      if (!forceUpdate && isAlreadyScraped) {
        debugPrint('⏭️  已存在元数据，跳过刮削');
        onProgress?.call('已存在元数据，跳过');
        return ScrapingResult(
          seriesId: series.id,
          seriesName: series.name,
          success: true,
          metadata: MetadataStoreService.getSeriesMetadata(series.folderPath),
        );
      }

      // 1. 提取剧集名称
      debugPrint('');
      debugPrint('📝 步骤1: 提取剧集名称');
      onProgress?.call('提取剧集名称...');
      final searchName = extractSeriesName(series.name);
      debugPrint('   原始名称: ${series.name}');
      debugPrint('   提取名称: $searchName');

      // 2. 搜索 TMDB
      debugPrint('');
      debugPrint('🔍 步骤2: 搜索 TMDB');
      onProgress?.call('搜索 TMDB...');
      debugPrint('   搜索关键词: $searchName');
      
      final searchResults = await TMDBService.searchTVShow(searchName);
      debugPrint('   找到 ${searchResults.length} 个结果');
      
      if (searchResults.isEmpty) {
        debugPrint('❌ 未找到匹配的剧集');
        return ScrapingResult(
          seriesId: series.id,
          seriesName: series.name,
          success: false,
          errorMessage: '未找到匹配的剧集',
        );
      }

      // 3. 选择第一个匹配结果
      debugPrint('');
      debugPrint('🎯 步骤3: 选择匹配结果');
      final firstResult = searchResults.first;
      final tmdbId = firstResult['id'] as int;
      final tmdbName = firstResult['name'] as String;
      debugPrint('   TMDB ID: $tmdbId');
      debugPrint('   TMDB 名称: $tmdbName');
      debugPrint('   匹配度: 第一个结果');

      // 4. 获取详细信息
      debugPrint('');
      debugPrint('📊 步骤4: 获取详细信息');
      onProgress?.call('获取详细信息...');
      
      final details = await TMDBService.getTVShowDetails(tmdbId);
      
      if (details == null) {
        debugPrint('❌ 无法获取剧集详情');
        return ScrapingResult(
          seriesId: series.id,
          seriesName: series.name,
          success: false,
          errorMessage: '无法获取剧集详情',
        );
      }
      
      debugPrint('   名称: ${details['name']}');
      debugPrint('   原始名称: ${details['original_name']}');
      debugPrint('   评分: ${details['vote_average']}');
      debugPrint('   首播日期: ${details['first_air_date']}');
      debugPrint('   季数: ${details['number_of_seasons']}');
      debugPrint('   集数: ${details['number_of_episodes']}');

      // 5. 下载图片
      debugPrint('');
      debugPrint('🖼️  步骤5: 下载图片');
      final imagesDir = await _getImagesDirectory();
      final seriesImagesDir = Directory(p.join(imagesDir.path, tmdbId.toString()));
      
      debugPrint('   图片目录: ${seriesImagesDir.path}');
      
      if (!await seriesImagesDir.exists()) {
        await seriesImagesDir.create(recursive: true);
        debugPrint('   ✅ 创建图片目录');
      } else {
        debugPrint('   ℹ️  图片目录已存在');
      }

      String? posterPath;
      String? backdropPath;

      // 下载海报
      final posterUrl = TMDBService.getImageUrl(details['poster_path']);
      debugPrint('');
      debugPrint('   📥 下载海报:');
      debugPrint('      URL: $posterUrl');
      
      if (posterUrl != null) {
        onProgress?.call('下载海报...');
        posterPath = await downloadImage(
          posterUrl,
          p.join(seriesImagesDir.path, 'poster.jpg'),
        );
        if (posterPath != null) {
          debugPrint('      ✅ 海报已保存: $posterPath');
        } else {
          debugPrint('      ❌ 海报下载失败');
        }
      } else {
        debugPrint('      ⚠️  无海报URL');
      }

      // 下载背景图
      final backdropUrl = TMDBService.getImageUrl(details['backdrop_path']);
      debugPrint('');
      debugPrint('   📥 下载背景图:');
      debugPrint('      URL: $backdropUrl');
      
      if (backdropUrl != null) {
        onProgress?.call('下载背景图...');
        backdropPath = await downloadImage(
          backdropUrl,
          p.join(seriesImagesDir.path, 'backdrop.jpg'),
        );
        if (backdropPath != null) {
          debugPrint('      ✅ 背景图已保存: $backdropPath');
        } else {
          debugPrint('      ❌ 背景图下载失败');
        }
      } else {
        debugPrint('      ⚠️  无背景图URL');
      }

      // 6. 构建元数据
      debugPrint('');
      debugPrint('💾 步骤6: 构建并保存元数据');
      final metadata = {
        'tmdbId': tmdbId,
        'name': details['name'],
        'originalName': details['original_name'],
        'overview': details['overview'],
        'posterPath': posterPath,
        'backdropPath': backdropPath,
        'rating': (details['vote_average'] as num?)?.toDouble(),
        'releaseDate': details['first_air_date'],
        'status': details['status'],
        'numberOfSeasons': details['number_of_seasons'],
        'numberOfEpisodes': details['number_of_episodes'],
        'networks': details['networks'],
        'genres': details['genres'],
        'scrapedAt': DateTime.now().toIso8601String(),
      };

      debugPrint('   元数据字段数: ${metadata.length}');

      // 7. 保存元数据
      onProgress?.call('保存元数据...');
      await MetadataStoreService.saveSeriesMetadata(series.folderPath, metadata);
      debugPrint('   ✅ 元数据已保存到存储');

      // 8. 刮削集数信息和封面
      debugPrint('');
      debugPrint('🎬 步骤8: 刮削集数信息');
      final scrapedEpisodesCount = await _scrapeEpisodesForSeries(
        series,
        tmdbId,
        details['number_of_seasons'] as int?,
        onProgress: onProgress,
      );
      debugPrint('   ✅ 已刮削 $scrapedEpisodesCount 集的元数据');

      debugPrint('');
      debugPrint('✅ ═══════════════════════════════════════════════════════');
      debugPrint('✅ 刮削成功: ${series.name}');
      debugPrint('✅ ═══════════════════════════════════════════════════════');
      debugPrint('');
      
      return ScrapingResult(
        seriesId: series.id,
        seriesName: series.name,
        success: true,
        metadata: metadata,
      );
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('❌ ═══════════════════════════════════════════════════════');
      debugPrint('❌ 刮削失败: ${series.name}');
      debugPrint('❌ 错误: $e');
      debugPrint('❌ 堆栈跟踪:');
      debugPrint('$stackTrace');
      debugPrint('❌ ═══════════════════════════════════════════════════════');
      debugPrint('');
      
      return ScrapingResult(
        seriesId: series.id,
        seriesName: series.name,
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// 为剧集刮削所有集数的信息
  /// 
  /// [series] 剧集
  /// [tmdbId] TMDB ID
  /// [numberOfSeasons] 总季数
  /// [onProgress] 进度回调
  /// 返回成功刮削的集数数量
  static Future<int> _scrapeEpisodesForSeries(
    Series series,
    int tmdbId,
    int? numberOfSeasons, {
    Function(String)? onProgress,
  }) async {
    if (numberOfSeasons == null || numberOfSeasons == 0) {
      return 0;
    }

    int scrapedCount = 0;

    try {
      // 获取该剧集的所有集数
      final allVideos = await _getVideosForSeries(series);
      
      debugPrint('   找到 ${allVideos.length} 个视频文件');

      // 逐季刮削
      for (int season = 1; season <= numberOfSeasons; season++) {
        onProgress?.call('刮削第 $season 季集数信息...');
        debugPrint('   正在刮削第 $season 季...');

        // 获取本季详情
        final seasonDetails = await TMDBService.getSeasonDetails(tmdbId, season);
        if (seasonDetails == null) {
          debugPrint('   ⚠️ 无法获取第 $season 季详情');
          continue;
        }

        final episodes = seasonDetails['episodes'] as List?;
        if (episodes == null || episodes.isEmpty) {
          debugPrint('   ⚠️ 第 $season 季没有集数信息');
          continue;
        }

        // 按季数过滤本地视频
        final seasonEpisodes = allVideos.where((ep) {
          // 这里简化处理，假设 episodeNumber 是全局编号或者通过文件名解析
          // 实际应用中可能需要更复杂的逻辑来匹配季和集
          return ep.episodeNumber != null && ep.episodeNumber! <= episodes.length;
        }).toList();

        debugPrint('   本地找到 ${seasonEpisodes.length} 个文件');

        // 逐集刮削
        for (final episodeData in episodes) {
          final episodeNumber = episodeData['episode_number'] as int;

          // 查找对应的本地Episode
          final matches = seasonEpisodes.where((ep) => ep.episodeNumber == episodeNumber);
          final localEpisode = matches.isNotEmpty ? matches.first : null;

          if (localEpisode == null) {
            // 如果找不到对应集数的本地文件，尝试按顺序匹配（如果集数很少且没有明确编号）
            // 但这可能会导致错误匹配，所以暂时只处理明确匹配的情况
            // 或者如果 seasonEpisodes 的数量正好对应，可以尝试按索引
             if (seasonEpisodes.length >= episodeNumber && seasonEpisodes[episodeNumber - 1].episodeNumber == null) {
               // 只有当本地文件没有解析出集数编号时，才尝试按索引匹配
               // 这是一个回退策略
             } else {
               continue; // 本地没有这一集
             }
          }

          final episode = localEpisode ?? seasonEpisodes[episodeNumber - 1];

          // 下载集数封面
          String? stillPath;
          final stillUrl = TMDBService.getImageUrl(episodeData['still_path']);
          if (stillUrl != null) {
            final imagesDir = await _getImagesDirectory();
            final seriesImagesDir = Directory(p.join(imagesDir.path, tmdbId.toString()));
            if (!await seriesImagesDir.exists()) {
              await seriesImagesDir.create(recursive: true);
            }

            stillPath = await downloadImage(
              stillUrl,
              p.join(seriesImagesDir.path, 'S${season}E${episodeNumber}_still.jpg'),
            );
          }

          // 构建并保存集数元数据
          final episodeMetadata = {
            'tmdbId': episodeData['id'],
            'name': episodeData['name'],
            'overview': episodeData['overview'],
            'stillPath': stillPath,
            'rating': (episodeData['vote_average'] as num?)?.toDouble(),
            'airDate': episodeData['air_date'],
            'episodeNumber': episodeNumber,
            'seasonNumber': season,
            'scrapedAt': DateTime.now().toIso8601String(),
          };

          await MetadataStoreService.saveEpisodeMetadata(episode.id, episodeMetadata);
          scrapedCount++;
        }

        // 添加延迟以避免API限流
        if (season < numberOfSeasons) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    } catch (e) {
      debugPrint('   ❌ 刮削集数失败: $e');
    }

    return scrapedCount;
  }

  /// 获取剧集的所有视频文件（Episode对象）
  static Future<List<Episode>> _getVideosForSeries(Series series) async {
    try {
      // 从 MediaLibraryService 获取所有视频
      final allVideos = MediaLibraryService.getAllVideos();
      
      // 使用 SeriesService 获取属于该剧集的集数
      return SeriesService.getEpisodesForSeries(series, allVideos);
    } catch (e) {
      debugPrint('获取剧集视频失败: $e');
      return [];
    }
  }

  /// 批量刮削多个剧集
  /// 
  /// [seriesList] 要刮削的剧集列表
  /// [onProgress] 进度回调，参数为 (已完成数量, 总数量, 当前状态描述)
  /// [forceUpdate] 是否强制更新已存在的元数据
  /// [delayBetweenRequests] 请求之间的延迟（毫秒），用于避免 API 限流
  static Future<List<ScrapingResult>> scrapeBatchSeries(
    List<Series> seriesList, {
    Function(int current, int total, String status)? onProgress,
    bool forceUpdate = false,
    int delayBetweenRequests = 500, // TMDB 限制每秒最多 4 个请求，500ms = 每秒2个请求（更保守）
  }) async {
    final results = <ScrapingResult>[];
    
    for (int i = 0; i < seriesList.length; i++) {
      final series = seriesList[i];
      
      // 更新总体进度
      onProgress?.call(i, seriesList.length, '正在处理: ${series.name}');
      
      // 刮削单个剧集
      final result = await scrapeSeries(
        series,
        onProgress: (status) {
          onProgress?.call(i, seriesList.length, '${series.name}: $status');
        },
        forceUpdate: forceUpdate,
      );
      
      results.add(result);
      
      // 延迟以避免 API 限流
      if (i < seriesList.length - 1) {
        await Future.delayed(Duration(milliseconds: delayBetweenRequests));
      }
    }
    
    // 最终进度
    final successCount = results.where((r) => r.success).length;
    final failedCount = results.length - successCount;
    onProgress?.call(
      seriesList.length,
      seriesList.length,
      '完成: 成功 $successCount, 失败 $failedCount',
    );
    
    return results;
  }

  /// 下载图片到本地
  /// 
  /// [imageUrl] 图片 URL
  /// [savePath] 保存路径（完整路径，包含文件名）
  /// 返回保存的文件路径，失败返回 null
  static Future<String?> downloadImage(String imageUrl, String savePath) async {
    try {
      debugPrint('📥 下载图片: $imageUrl -> $savePath');
      
      final response = await http.get(Uri.parse(imageUrl));
      
      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('✅ 图片已保存: $savePath');
        return savePath;
      } else {
        debugPrint('❌ 下载失败: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 下载图片异常: $e');
      return null;
    }
  }

  /// 刮削集数详细信息
  /// 
  /// [episode] 集数
  /// [tmdbId] 剧集的 TMDB ID
  /// [seasonNumber] 季数
  static Future<Map<String, dynamic>?> scrapeEpisode(
    Episode episode,
    int tmdbId,
    int seasonNumber,
  ) async {
    try {
      if (!TMDBService.isInitialized) {
        return null;
      }

      // 获取季详情
      final seasonDetails = await TMDBService.getSeasonDetails(tmdbId, seasonNumber);
      if (seasonDetails == null) {
        return null;
      }

      // 查找对应的集数
      final episodes = seasonDetails['episodes'] as List?;
      if (episodes == null || episode.episodeNumber == null) {
        return null;
      }

      final episodeData = episodes.firstWhere(
        (ep) => ep['episode_number'] == episode.episodeNumber,
        orElse: () => null,
      );

      if (episodeData == null) {
        return null;
      }

      // 下载集数截图（如果有）
      String? stillPath;
      final stillUrl = TMDBService.getImageUrl(episodeData['still_path']);
      if (stillUrl != null) {
        final imagesDir = await _getImagesDirectory();
        final seriesImagesDir = Directory(p.join(imagesDir.path, tmdbId.toString()));
        if (!await seriesImagesDir.exists()) {
          await seriesImagesDir.create(recursive: true);
        }
        
        stillPath = await downloadImage(
          stillUrl,
          p.join(seriesImagesDir.path, 'episode_${episode.episodeNumber}_still.jpg'),
        );
      }

      // 构建集数元数据
      final metadata = {
        'tmdbId': episodeData['id'],
        'name': episodeData['name'],
        'overview': episodeData['overview'],
        'stillPath': stillPath,
        'rating': (episodeData['vote_average'] as num?)?.toDouble(),
        'airDate': episodeData['air_date'],
        'episodeNumber': episodeData['episode_number'],
        'seasonNumber': episodeData['season_number'],
        'scrapedAt': DateTime.now().toIso8601String(),
      };

      // 保存集数元数据
      await MetadataStoreService.saveEpisodeMetadata(episode.id, metadata);

      return metadata;
    } catch (e) {
      debugPrint('❌ 刮削集数失败: ${episode.name}, 错误: $e');
      return null;
    }
  }
}
