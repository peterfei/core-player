import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'settings_service.dart';
import '../utils/default_cover_generator.dart';
import '../utils/video_thumbnail_extractor.dart';

class CoverFallbackService {
  static const String _metadataDir = 'metadata';
  static const String _coversDir = 'covers';
  static const String _thumbnailsDir = 'thumbnails';

  static late Directory _coversDirectory;
  static late Directory _thumbnailsDirectory;

  static Future<void> initialize() async {
    if (kIsWeb) return;

    final appDir = await getApplicationDocumentsDirectory();
    final metadataPath = path.join(appDir.path, _metadataDir);
    
    _coversDirectory = Directory(path.join(metadataPath, _coversDir));
    _thumbnailsDirectory = Directory(path.join(metadataPath, _thumbnailsDir));

    if (!await _coversDirectory.exists()) {
      await _coversDirectory.create(recursive: true);
    }

    if (!await _thumbnailsDirectory.exists()) {
      await _thumbnailsDirectory.create(recursive: true);
    }
  }

  /// 获取封面路径
  /// [series] 剧集对象 (Map or Object)
  /// [forceRefresh] 是否强制刷新
  static Future<String?> getCoverPath(dynamic series, {bool forceRefresh = false}) async {
    try {
      if (series == null) return null;

      // 1. 尝试获取 TMDB 封面
      String? posterPath;
      String? name;
      String? path;
      String? id;

      if (series is Map) {
        posterPath = series['posterPath'];
        name = series['name'];
        path = series['path'];
        id = series['id']?.toString() ?? path?.hashCode.toString();
      } else {
        try {
          // 尝试作为 Series 对象访问
          // Series 类属性: thumbnailPath, name, folderPath, id
          posterPath = (series as dynamic).thumbnailPath;
          name = (series as dynamic).name;
          path = (series as dynamic).folderPath;
          id = (series as dynamic).id?.toString() ?? path?.hashCode.toString();
        } catch (e) {
          // 如果不是 Series，尝试通用属性
          try {
             posterPath = (series as dynamic).posterPath;
             name = (series as dynamic).name;
             path = (series as dynamic).path;
             id = (series as dynamic).id?.toString() ?? path?.hashCode.toString();
          } catch (e2) {
             debugPrint('无法解析 Series 对象: $e2');
          }
        }
      }

      // 如果有有效的网络图片或本地图片，直接返回
      if (posterPath != null && posterPath.isNotEmpty) {
        if (posterPath.startsWith('http') || File(posterPath).existsSync()) {
          return posterPath;
        }
      }

      if (id == null || name == null) return null;

      // 2. 尝试视频截图 (如果启用且是专业版)
      final enableVideoThumbnails = await SettingsService.isVideoThumbnailsEnabled();
      if (enableVideoThumbnails && path != null) {
        // 找到第一个视频文件
        final videoFile = await _findFirstVideoFile(path);
        if (videoFile != null) {
          final thumbnail = await VideoThumbnailExtractor.extractThumbnail(videoFile.path, id);
          if (thumbnail != null) return thumbnail.path;
        }
      }

      // 3. 生成默认封面
      final cover = await DefaultCoverGenerator.generateCover(name, id);
      return cover?.path;
    } catch (e) {
      debugPrint('获取封面路径失败: $e');
      return null;
    }
  }

  static Future<File?> _findFirstVideoFile(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return null;

      final videoExtensions = {'.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm'};
      
      // 仅搜索第一层，避免深度递归
      await for (final entity in dir.list(recursive: false)) {
        if (entity is File) {
          final ext = path.extension(entity.path).toLowerCase();
          if (videoExtensions.contains(ext)) {
            return entity;
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
