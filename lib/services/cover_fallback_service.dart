import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'settings_service.dart';
import '../utils/default_cover_generator.dart';
import '../utils/video_thumbnail_extractor.dart';
import 'macos_bookmark_service.dart';

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
      List<String>? paths; // 支持多个路径
      String? id;

      if (series is Map) {
        posterPath = series['posterPath'];
        name = series['name'];
        path = series['path'];
        id = series['id']?.toString() ?? path?.hashCode.toString();
      } else {
        try {
          // 尝试作为 Series 对象访问
          // Series 类属性: thumbnailPath, name, folderPath, folderPaths, id
          posterPath = (series as dynamic).thumbnailPath;
          name = (series as dynamic).name;
          path = (series as dynamic).folderPath;
          
          // 尝试获取 folderPaths 列表
          try {
            paths = List<String>.from((series as dynamic).folderPaths ?? [path]);
          } catch (e) {
            paths = path != null ? [path] : null;
          }
          
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

      // 如果有有效的网络图片或本地图片，直接返回（刮削成功）
      if (posterPath != null && posterPath.isNotEmpty) {
        if (posterPath.startsWith('http') || File(posterPath).existsSync()) {
          return posterPath;
        }
      }

      if (id == null || name == null) return null;

      // 2. 刮削失败的情况：优先尝试视频截图
      // 检查是否启用视频缩略图功能
      final enableVideoThumbnails = await SettingsService.isVideoThumbnailsEnabled();
      if (enableVideoThumbnails) {
        debugPrint('📸 刮削失败，尝试提取视频帧作为封面: $name');
        
        // 尝试从所有可能的路径中查找视频文件
        final searchPaths = paths ?? (path != null ? [path] : <String>[]);
        debugPrint('🔍 搜索路径列表: $searchPaths');
        
        for (final searchPath in searchPaths) {
          final videoFile = await _findFirstVideoFile(searchPath);
          if (videoFile != null) {
            final thumbnail = await VideoThumbnailExtractor.extractThumbnail(videoFile.path, id);
            if (thumbnail != null) {
              debugPrint('✅ 成功提取视频帧: ${thumbnail.path}');
              return thumbnail.path;
            } else {
              debugPrint('⚠️ 视频帧提取失败，尝试下一个路径');
            }
          }
        }
        
        debugPrint('⚠️ 所有路径都未找到视频文件，将使用默认封面');
      }

      // 3. 最后回退：生成默认渐变色封面
      debugPrint('🎨 生成默认渐变色封面: $name');
      final cover = await DefaultCoverGenerator.generateCover(name, id);
      return cover?.path;
    } catch (e) {
      debugPrint('获取封面路径失败: $e');
      return null;
    }
  }

  static Future<File?> _findFirstVideoFile(String pathStr) async {
    try {
      debugPrint('🔍 查找视频文件: $pathStr');
      
      // 尝试恢复权限 (macOS 沙盒)
      await _ensureAccess(pathStr);
      
      // 如果路径本身就是文件
      if (await File(pathStr).exists()) {
        final ext = path.extension(pathStr).toLowerCase();
        final videoExtensions = {'.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.ts', '.m2ts'};
        if (videoExtensions.contains(ext)) {
          debugPrint('✅ 找到视频文件（路径本身）: $pathStr');
          return File(pathStr);
        }
        debugPrint('⚠️ 路径是文件但不是视频格式: $ext');
        return null;
      }

      final dir = Directory(pathStr);
      if (!await dir.exists()) {
        debugPrint('❌ 目录不存在: $pathStr');
        return null;
      }

      final videoExtensions = {'.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.ts', '.m2ts'};
      
      debugPrint('📂 开始搜索目录: $pathStr');
      int fileCount = 0;
      
      // 搜索第一层和第二层（支持嵌套一层的情况）
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          fileCount++;
          final ext = path.extension(entity.path).toLowerCase();
          if (videoExtensions.contains(ext)) {
            debugPrint('✅ 找到视频文件: ${entity.path}');
            return entity;
          }
        }
        
        // 限制搜索深度，避免性能问题
        if (fileCount > 100) {
          debugPrint('⚠️ 已搜索 100 个文件，停止搜索');
          break;
        }
      }
      
      debugPrint('❌ 未找到视频文件（共搜索 $fileCount 个文件）');
      return null;
    } catch (e) {
      debugPrint('❌ 查找视频文件异常: $e');
      return null;
    }
  }

  // 记录已恢复权限的书签路径，避免重复调用
  static final Set<String> _restoredBookmarks = {};

  /// 确保有权限访问路径 (macOS)
  /// 策略：尝试恢复所有已缓存的书签。这比路径匹配更可靠，
  /// 因为它规避了符号链接、/Volumes 前缀等路径差异问题。
  static Future<void> _ensureAccess(String pathStr) async {
    if (!Platform.isMacOS) return;
    
    try {
      // 获取所有已缓存的书签路径
      final allBookmarks = await MacOSBookmarkService.getBookmarkedPaths();
      if (allBookmarks.isEmpty) {
        debugPrint('⚠️ 无可用书签，请重新添加视频文件夹以恢复访问权限');
        return;
      }

      bool newRestored = false;
      
      for (final bookmarkPath in allBookmarks) {
        // 如果尚未恢复过该书签，则尝试恢复
        if (!_restoredBookmarks.contains(bookmarkPath)) {
          final result = await MacOSBookmarkService.tryRestoreAccess(bookmarkPath);
          if (result != null) {
            _restoredBookmarks.add(bookmarkPath);
            newRestored = true;
          }
        }
      }
      
      if (newRestored) {
        debugPrint('🔓 已刷新文件访问权限 (当前已激活 ${_restoredBookmarks.length} 个书签)');
        // 打印书签列表供调试 (仅在有新恢复时)
        // debugPrint('   已激活路径: $_restoredBookmarks');
      }
      
    } catch (e) {
      debugPrint('⚠️ 批量恢复权限异常: $e');
    }
  }
}
