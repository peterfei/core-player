import 'package:path/path.dart' as p;
import '../models/series.dart';
import '../models/episode.dart';
import 'media_library_service.dart';
import 'metadata_store_service.dart';

/// 剧集服务
/// 负责从扫描的视频中识别和分组剧集
class SeriesService {
  /// 处理视频列表，分组为剧集并保存到媒体库
  static Future<void> processAndSaveSeries(List<ScannedVideo> videos) async {
    // Clear old series data
    await MediaLibraryService.clearSeriesInfo();

    // 1. Group videos
    final domainSeriesList = groupVideosBySeries(videos);
    
    // 2. Convert to ScannedSeries
    final scannedSeriesList = domainSeriesList.map((s) => ScannedSeries(
      id: s.id,
      name: s.name,
      folderPath: s.folderPath,
      episodeCount: s.episodeCount,
      addedAt: s.addedAt,
    )).toList();
    
    // 3. Save ScannedSeries
    await MediaLibraryService.saveSeries(scannedSeriesList);
    
    // 4. Create and Save ScannedEpisodes
    final allScannedEpisodes = <ScannedEpisode>[];
    for (var series in domainSeriesList) {
       final episodes = getEpisodesForSeries(series, videos);
       final scannedEpisodes = episodes.map((e) => ScannedEpisode(
         id: e.id,
         seriesId: e.seriesId,
         name: e.name,
         path: e.path,
         size: e.size,
         episodeNumber: e.episodeNumber,
         addedAt: e.addedAt,
         sourceId: e.sourceId,
       )).toList();
       allScannedEpisodes.addAll(scannedEpisodes);
    }
    await MediaLibraryService.saveEpisodes(allScannedEpisodes);
  }

  /// 获取所有已保存的剧集（转换为领域模型）
  /// 并根据 TMDB ID 合并重复的剧集（例如不同季度的文件夹）
  static Future<List<Series>> getAllSavedSeries() async {
    final scannedSeries = MediaLibraryService.getAllSeries();
    
    // 1. 转换为 Series 对象并填充元数据
    final List<Series> initialList = scannedSeries.map((s) {
      final metadata = MetadataStoreService.getSeriesMetadata(s.folderPath);
      return Series(
        id: s.id,
        name: metadata?['name'] ?? s.name, // 优先使用元数据名称
        folderPath: s.folderPath,
        episodeCount: s.episodeCount,
        addedAt: s.addedAt,
        tmdbId: metadata?['tmdbId'],
        thumbnailPath: metadata?['posterPath'],
        backdropPath: metadata?['backdropPath'],
        overview: metadata?['overview'],
        rating: metadata?['rating'],
        releaseDate: metadata?['releaseDate'] != null ? DateTime.tryParse(metadata!['releaseDate']) : null,
      );
    }).toList();

    // 2. 按 TMDB ID 分组并合并
    return mergeSeriesList(initialList);
  }

  /// 合并重复的剧集列表 (纯逻辑，易于测试)
  static List<Series> mergeSeriesList(List<Series> inputList) {
    final Map<int, List<Series>> tmdbGroups = {};
    final List<Series> unmergedList = [];

    for (var series in inputList) {
      if (series.tmdbId != null && series.tmdbId! > 0) {
        if (!tmdbGroups.containsKey(series.tmdbId)) {
          tmdbGroups[series.tmdbId!] = [];
        }
        tmdbGroups[series.tmdbId!]!.add(series);
      } else {
        unmergedList.add(series);
      }
    }

    // 3. 处理合并
    final List<Series> mergedList = [];
    
    // 添加未合并的（没有 TMDB ID 的）
    mergedList.addAll(unmergedList);

    // 处理有 TMDB ID 的
    for (var entry in tmdbGroups.entries) {
      final group = entry.value;
      if (group.isEmpty) continue;

      if (group.length == 1) {
        mergedList.add(group.first);
      } else {
        // 合并多个 Series
        // 排序：优先保留元数据最完整的，或者按文件夹名称排序
        group.sort((a, b) => a.folderPath.compareTo(b.folderPath));
        
        final mainSeries = group.first;
        final allFolderPaths = group.map((s) => s.folderPath).toList();
        final totalEpisodes = group.fold<int>(0, (sum, s) => sum + s.episodeCount);

        // 创建合并后的 Series
        // 使用主 Series 的 ID 和元数据，但包含所有文件夹路径
        mergedList.add(mainSeries.copyWith(
          folderPaths: allFolderPaths,
          episodeCount: totalEpisodes,
        ));
      }
    }

    // 4. 排序
    mergedList.sort((a, b) => a.name.compareTo(b.name));

    return mergedList;
  }
  
  /// 获取已保存的剧集集数（转换为领域模型）
  static Future<List<Episode>> getSavedEpisodesForSeries(String seriesId) async {
    final scannedEpisodes = MediaLibraryService.getEpisodesForSeries(seriesId);
    return scannedEpisodes.map((e) => Episode(
      id: e.id,
      seriesId: e.seriesId,
      name: e.name,
      path: e.path,
      size: e.size,
      episodeNumber: e.episodeNumber,
      addedAt: e.addedAt,
      sourceId: e.sourceId,
    )).toList();
  }

  /// 从扫描的视频列表中分组出剧集
  static List<Series> groupVideosBySeries(List<ScannedVideo> videos) {
    // 按清洗后的剧集名称分组
    final Map<String, List<ScannedVideo>> nameGroups = {};
    // 记录每个组涉及的所有文件夹路径
    final Map<String, Set<String>> nameToPathsMap = {};
    
    for (var video in videos) {
      final folderPath = _extractFolderPath(video.path);
      final folderName = p.basename(folderPath);
      
      // 清洗文件夹名称作为分组键
      String seriesName = cleanSeriesName(folderName);
      if (seriesName.isEmpty) {
        seriesName = folderName; // 回退到原始文件夹名
      }
      
      if (!nameGroups.containsKey(seriesName)) {
        nameGroups[seriesName] = [];
        nameToPathsMap[seriesName] = {};
      }
      nameGroups[seriesName]!.add(video);
      nameToPathsMap[seriesName]!.add(folderPath);
    }
    
    // 转换为 Series 对象
    final seriesList = <Series>[];
    for (var entry in nameGroups.entries) {
      final seriesName = entry.key;
      final episodeCount = entry.value.length;
      final folderPaths = nameToPathsMap[seriesName]!;
      
      // 确定主路径：优先选择有元数据的路径，否则选第一个
      String mainFolderPath = folderPaths.first;
      for (final path in folderPaths) {
        if (MetadataStoreService.isScraped(path)) {
          mainFolderPath = path;
          break;
        }
      }
      
      if (episodeCount > 0) {
        // 使用清洗后的名称创建 Series
        // ID 使用名称的哈希，以确保跨文件夹合并后的唯一性
        seriesList.add(Series(
          id: seriesName.hashCode.toString(),
          name: seriesName,
          folderPath: mainFolderPath, // 使用选定的主路径（可能有元数据）
          episodeCount: episodeCount,
          addedAt: entry.value.first.addedAt ?? DateTime.now(),
        ));
      }
    }
    
    // 按名称排序
    seriesList.sort((a, b) => a.name.compareTo(b.name));
    
    return seriesList;
  }

/// 从扫描的视频列表中获取剧集列表，并应用元数据和合并逻辑
static Future<List<Series>> getSeriesListFromVideos(List<ScannedVideo> videos) async {
  // 1. 初步分组 (按文件夹名称)
  final initialSeries = groupVideosBySeries(videos);
  
  // 2. 填充元数据
  final List<Series> populatedList = initialSeries.map((s) {
    final metadata = MetadataStoreService.getSeriesMetadata(s.folderPath);
    return s.copyWith(
      name: metadata?['name'] ?? s.name, // 优先使用元数据名称
      tmdbId: metadata?['tmdbId'],
      thumbnailPath: metadata?['posterPath'],
      backdropPath: metadata?['backdropPath'],
      overview: metadata?['overview'],
      rating: metadata?['rating'],
      releaseDate: metadata?['releaseDate'] != null ? DateTime.tryParse(metadata!['releaseDate']) : null,
    );
  }).toList();

  // 3. 合并重复剧集 (按 TMDB ID)
  return mergeSeriesList(populatedList);
}

  /// 获取指定剧集的所有集数
  static List<Episode> getEpisodesForSeries(
    Series series,
    List<ScannedVideo> allVideos,
  ) {
    // 筛选出属于该剧集的视频
    // 策略：检查视频的文件夹路径是否包含在 series.folderPaths 中
    final seriesVideos = allVideos.where((video) {
      final folderPath = _extractFolderPath(video.path);
      return series.folderPaths.contains(folderPath);
    }).toList();
    
    // 转换为 Episode 对象
    final episodes = seriesVideos.map((video) {
      final parsed = parseSeasonAndEpisode(video.name);
      
      // 如果文件名没有季数，尝试从文件夹名解析 (e.g. "Season 1")
      int? seasonNumber = parsed.season;
      if (seasonNumber == null) {
        final folderName = p.basename(_extractFolderPath(video.path));
        final seasonPattern = RegExp(r'(?:Season|S|第)\s*(\d+)\s*(?:季|Season)?', caseSensitive: false);
        final match = seasonPattern.firstMatch(folderName);
        if (match != null) {
          seasonNumber = int.tryParse(match.group(1)!);
        }
      }

      return Episode(
        id: video.pathHash,
        seriesId: series.id,
        name: video.name,
        path: video.path,
        size: video.size,
        episodeNumber: parsed.episode,
        seasonNumber: seasonNumber,
        addedAt: video.addedAt ?? DateTime.now(),
        sourceId: video.sourceId,
      );
    }).toList();
    
    // 按集数编号排序，如果没有编号则按名称排序
    episodes.sort((a, b) {
      if (a.episodeNumber != null && b.episodeNumber != null) {
        return a.episodeNumber!.compareTo(b.episodeNumber!);
      }
      return a.name.compareTo(b.name);
    });
    
    return episodes;
  }

  /// 清洗剧集名称，用于分组
  static String cleanSeriesName(String name) {
    var title = name;

    // 1. 移除方括号内容
    title = title.replaceAll(RegExp(r'[\[【\(].*?[\]】\)]'), '');

    // 2. 部分标准化分隔符 (仅替换 . 和 _，保留 - 以便后续匹配集数范围)
    title = title.replaceAll(RegExp(r'[._]'), ' ');

    // 3. 移除技术参数
    title = title.replaceAll(RegExp(r'\b(1080p|2160p|720p|4K|8K|WEB-DL|BluRay|HDR|DV|HEVC|x264|x265|AAC|AC3).*', caseSensitive: false), '');

    // 4. 移除季数标识
    title = title.replaceAll(RegExp(r'第\s*[一二三四五六七八九十]+\s*季'), '');
    title = title.replaceAll(RegExp(r'\bSeason\s*\d+\b', caseSensitive: false), '');
    title = title.replaceAll(RegExp(r'\bS\d+\b', caseSensitive: false), '');

    // 5. 移除集数标识
    // 支持 "第01-04集", "第1集"
    title = title.replaceAll(RegExp(r'第\s*\d+(?:\s*-\s*\d+)?\s*集'), '');
    // 支持 "EP01", "E01-04", "ep1"
    title = title.replaceAll(RegExp(r'\bE[Pp]?\d+(?:-\d+)?\b', caseSensitive: false), '');

    // 6. 最后处理剩余的连字符和多余空格
    title = title.replaceAll('-', ' ');
    title = title.replaceAll(RegExp(r'\s+'), ' ');
    
    // 7. 特殊处理：移除中文字符之间的空格
    // 解决 "盗墓笔记.重启" (变成 "盗墓笔记 重启") 和 "盗墓笔记重启" 不匹配的问题
    // 策略：如果是 中文+空格+中文，则移除空格
    title = title.replaceAllMapped(
      RegExp(r'([\u4e00-\u9fa5])\s+([\u4e00-\u9fa5])'),
      (match) => '${match.group(1)}${match.group(2)}',
    );

    return title.trim();
  }

  /// 从文件名解析季数和集数编号
  static ({int? season, int? episode}) parseSeasonAndEpisode(String filename) {
    // 移除文件扩展名
    final nameWithoutExt = p.basenameWithoutExtension(filename);
    
    // 1. S01E01 格式 (最优先)
    final s01e01Pattern = RegExp(r'[Ss](\d+)[Ee](\d+)');
    final s01e01Match = s01e01Pattern.firstMatch(nameWithoutExt);
    if (s01e01Match != null) {
      return (
        season: int.tryParse(s01e01Match.group(1)!),
        episode: int.tryParse(s01e01Match.group(2)!)
      );
    }

    // 2. 第X季 第X集 格式
    final chinesePattern = RegExp(r'第\s*(\d+)\s*季.*第\s*(\d+)\s*集');
    final chineseMatch = chinesePattern.firstMatch(nameWithoutExt);
    if (chineseMatch != null) {
      return (
        season: int.tryParse(chineseMatch.group(1)!),
        episode: int.tryParse(chineseMatch.group(2)!)
      );
    }

    // 3. 仅集数 (尝试推断季数，如果文件夹名包含季数信息)
    // 这里只解析集数
    int? episode;
    final patterns = [
      RegExp(r'第\s*(\d+)\s*集'),           // 第01集, 第1集
      RegExp(r'[Ee][Pp]?\s*(\d+)'),        // E01, EP01, e01, ep01
      RegExp(r'\b(\d{1,3})\b'),            // 01, 1, 001
    ];
    
    for (var pattern in patterns) {
      final match = pattern.firstMatch(nameWithoutExt);
      if (match != null) {
        final numStr = match.group(1);
        if (numStr != null) {
          episode = int.tryParse(numStr);
          break;
        }
      }
    }
    
    return (season: null, episode: episode);
  }

  /// 从视频文件路径提取文件夹路径
  /// 例如: "/media/琅琊榜/第01集.mkv" -> "/media/琅琊榜"
  static String _extractFolderPath(String videoPath) {
    final directory = p.dirname(videoPath);
    return directory;
  }

  /// 获取未分类的视频（单个视频的文件夹）
  static List<ScannedVideo> getUncategorizedVideos(
    List<ScannedVideo> allVideos,
    List<Series> seriesList,
  ) {
    // 收集所有已分类视频的路径
    final Set<String> categorizedPaths = {};
    for (var series in seriesList) {
      final seriesVideos = allVideos.where((video) {
        final folderPath = _extractFolderPath(video.path);
        return folderPath == series.folderPath;
      });
      categorizedPaths.addAll(seriesVideos.map((v) => v.path));
    }
    
    // 返回未分类的视频
    return allVideos.where((video) {
      return !categorizedPaths.contains(video.path);
    }).toList();
  }

  /// 搜索剧集
  static List<Series> searchSeries(List<Series> seriesList, String query) {
    if (query.isEmpty) return seriesList;
    
    final lowerQuery = query.toLowerCase();
    return seriesList.where((series) {
      return series.name.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// 排序剧集
  static List<Series> sortSeries(List<Series> seriesList, String sortBy) {
    final sorted = List<Series>.from(seriesList);
    
    switch (sortBy) {
      case 'name_asc':
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'name_desc':
        sorted.sort((a, b) => b.name.compareTo(a.name));
        break;
      case 'date_asc':
        sorted.sort((a, b) => a.addedAt.compareTo(b.addedAt));
        break;
      case 'date_desc':
        sorted.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
      case 'episode_count_asc':
        sorted.sort((a, b) => a.episodeCount.compareTo(b.episodeCount));
        break;
      case 'episode_count_desc':
        sorted.sort((a, b) => b.episodeCount.compareTo(a.episodeCount));
        break;
    }
    
    return sorted;
  }
}