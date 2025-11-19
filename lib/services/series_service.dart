import 'package:path/path.dart' as p;
import '../models/series.dart';
import '../models/episode.dart';
import 'media_library_service.dart';

/// 剧集服务
/// 负责从扫描的视频中识别和分组剧集
class SeriesService {
  /// 从扫描的视频列表中分组出剧集
  static List<Series> groupVideosBySeries(List<ScannedVideo> videos) {
    // 按文件夹路径分组
    final Map<String, List<ScannedVideo>> folderGroups = {};
    
    for (var video in videos) {
      final folderPath = _extractFolderPath(video.path);
      if (!folderGroups.containsKey(folderPath)) {
        folderGroups[folderPath] = [];
      }
      folderGroups[folderPath]!.add(video);
    }
    
    // 将每个文件夹组转换为 Series 对象
    final seriesList = <Series>[];
    for (var entry in folderGroups.entries) {
      final folderPath = entry.key;
      final episodeCount = entry.value.length;
      
      // 只有包含多个视频的文件夹才创建剧集
      // 单个视频的文件夹归入"未分类"
      if (episodeCount > 1) {
        seriesList.add(Series.fromPath(folderPath, episodeCount));
      }
    }
    
    // 按名称排序
    seriesList.sort((a, b) => a.name.compareTo(b.name));
    
    return seriesList;
  }

  /// 获取指定剧集的所有集数
  static List<Episode> getEpisodesForSeries(
    Series series,
    List<ScannedVideo> allVideos,
  ) {
    // 筛选出属于该剧集的视频
    final seriesVideos = allVideos.where((video) {
      final folderPath = _extractFolderPath(video.path);
      return folderPath == series.folderPath;
    }).toList();
    
    // 转换为 Episode 对象
    final episodes = seriesVideos.map((video) {
      return Episode(
        id: video.pathHash,
        seriesId: series.id,
        name: video.name,
        path: video.path,
        size: video.size,
        episodeNumber: parseEpisodeNumber(video.name),
        addedAt: video.addedAt ?? DateTime.now(),
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

  /// 从文件名解析集数编号
  /// 支持多种常见格式：
  /// - "第01集", "第1集"
  /// - "E01", "e01", "EP01", "ep01"
  /// - "01", "1" (纯数字)
  /// - "S01E01" (季+集)
  static int? parseEpisodeNumber(String filename) {
    // 移除文件扩展名
    final nameWithoutExt = p.basenameWithoutExtension(filename);
    
    // 正则表达式模式列表
    final patterns = [
      RegExp(r'第\s*(\d+)\s*集'),           // 第01集, 第1集
      RegExp(r'[Ee][Pp]?\s*(\d+)'),        // E01, EP01, e01, ep01
      RegExp(r'[Ss]\d+[Ee](\d+)'),         // S01E01
      RegExp(r'\b(\d{1,3})\b'),            // 01, 1, 001
    ];
    
    for (var pattern in patterns) {
      final match = pattern.firstMatch(nameWithoutExt);
      if (match != null) {
        final numStr = match.group(1);
        if (numStr != null) {
          return int.tryParse(numStr);
        }
      }
    }
    
    return null;
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
