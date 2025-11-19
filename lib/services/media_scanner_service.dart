import 'package:path/path.dart' as p;
import 'file_source/file_source.dart';

class MediaScannerService {
  static final MediaScannerService _instance = MediaScannerService._();
  static MediaScannerService get instance => _instance;

  MediaScannerService._();

  // Supported video extensions
  static const Set<String> _videoExtensions = {
    '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.mpg', '.mpeg', '.ts'
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
}
