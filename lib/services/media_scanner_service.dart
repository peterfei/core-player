import 'dart:io';
import 'package:path/path.dart' as p;
import 'file_source/file_source.dart';
import 'media_library_service.dart';

import 'excluded_paths_service.dart';

class MediaScannerService {
  static final MediaScannerService _instance = MediaScannerService._();
  static MediaScannerService get instance => _instance;

  MediaScannerService._();

  // Supported video extensions
  static const Set<String> _videoExtensions = {
    '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.mpg', '.mpeg', '.ts'
  };

  // Supported image extensions
  static const Set<String> _imageExtensions = {
    '.jpg', '.jpeg', '.png', '.webp', '.bmp'
  };

  Future<List<FileItem>> scanSource(FileSource source, String rootPath, {bool recursive = true}) async {
    final List<FileItem> videoFiles = [];
    
    print('🔍 开始扫描源: ${source.name}, 路径: $rootPath');
    
    try {
      await source.connect();
      print('✅ 连接成功: ${source.name}');
      await _scanDirectory(source, rootPath, videoFiles, recursive);
      print('✅ 扫描完成，找到 ${videoFiles.length} 个视频文件');
    } catch (e) {
      print('❌ 扫描源 ${source.name} 时出错: $e');
      rethrow;
    } finally {
      await source.disconnect();
    }

    return videoFiles;
  }

  Future<void> _scanDirectory(
    FileSource source, 
    String path, 
    List<FileItem> results, 
    bool recursive
  ) async {
    // Check if path is excluded
    if (ExcludedPathsService.isExcluded(path)) {
      print('🚫 跳过已排除路径: $path');
      return;
    }

    try {
      print('📂 扫描目录: $path');
      final items = await source.listFiles(path);
      print('  找到 ${items.length} 个项目');
      
      int videoCount = 0;
      for (final item in items) {
        if (item.isDirectory) {
          print('  📁 目录: ${item.name}');
          if (recursive) {
            await _scanDirectory(source, item.path, results, recursive);
          }
        } else {
          if (_isVideoFile(item.name)) {
            print('  🎬 视频: ${item.name} (${item.size} bytes)');
            results.add(item);
            videoCount++;
          } else if (_isImageFile(item.name)) {
            // 处理图片文件
            final imageType = _getImageType(item.name);
            if (imageType != null) {
              print('  🖼️ 图片: ${item.name} -> $imageType');
              // 记录到 MediaLibraryService
              // 注意：这里假设 path 是文件夹路径，item.path 是文件完整路径
              // 对于 SMB，path 可能是 smb://server/share/folder
              // 我们需要提取父文件夹路径
              final parentPath = path; // 当前扫描的目录就是父目录
              MediaLibraryService.addFolderImage(parentPath, imageType, item.path);
            }
          }
        }
      }
      if (videoCount > 0) {
        print('  ✅ 在 $path 找到 $videoCount 个视频');
      }
    } catch (e) {
      print('❌ 扫描目录 $path 时出错: $e');
    }
  }

  bool _isVideoFile(String filename) {
    final ext = p.extension(filename).toLowerCase();
    return _videoExtensions.contains(ext);
  }

  bool _isImageFile(String filename) {
    final ext = p.extension(filename).toLowerCase();
    return _imageExtensions.contains(ext);
  }

  String? _getImageType(String filename) {
    final name = p.basenameWithoutExtension(filename).toLowerCase();
    
    if (const {'poster', 'cover', 'folder', 'keyart', 'movie'}.contains(name)) {
      return 'poster';
    }
    
    if (const {'fanart', 'backdrop', 'background', 'art'}.contains(name)) {
      return 'backdrop';
    }
    
    if (const {'logo', 'clearlogo', 'title'}.contains(name)) {
      return 'logo';
    }
    
    // 也可以支持 seasonXX-poster.jpg 等格式，这里先简单处理
    if (name.startsWith('season') && name.endsWith('poster')) {
      return 'season_poster';
    }
    
    return null;
  }
}
