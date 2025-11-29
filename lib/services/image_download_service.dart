import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tmdb_service.dart';

/// 图片下载服务
/// 负责下载 TMDB 图片到本地存储
class ImageDownloadService {
  static const String _imagesFolderName = 'metadata/images';

  /// 获取图片存储目录
  static Future<Directory> getImagesDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDocDir.path, _imagesFolderName));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  /// 下载单个图片
  /// 
  /// [url] 图片 URL
  /// [savePath] 保存路径
  /// 返回保存的文件路径，失败返回 null
  static Future<String?> downloadImage(String url, String savePath) async {
    try {
      debugPrint('   下载图片: $url');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('   保存到: $savePath');
        return savePath;
      } else {
        debugPrint('   ❌ 下载失败: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('   ❌ 下载异常: $e');
      return null;
    }
  }

  /// 为剧集下载所有图片（海报+背景）
  /// 
  /// [tmdbId] TMDB ID
  /// [posterPath] 海报路径（TMDB 路径，如 "/abc123.jpg"）
  /// [backdropPath] 背景图路径（TMDB 路径）
  /// 
  /// 返回 Map，包含 'poster' 和 'backdrop' 的本地路径
  static Future<Map<String, String?>> downloadSeriesImages({
    required int tmdbId,
    required String? posterPath,
    required String? backdropPath,
  }) async {
    final result = <String, String?>{
      'poster': null,
      'backdrop': null,
    };

    try {
      // 创建剧集图片目录
      final imagesDir = await getImagesDirectory();
      final seriesImagesDir = Directory(p.join(imagesDir.path, tmdbId.toString()));
      if (!await seriesImagesDir.exists()) {
        await seriesImagesDir.create(recursive: true);
      }

      // 下载海报
      if (posterPath != null && posterPath.isNotEmpty) {
        final posterUrl = TMDBService.getImageUrl(posterPath);
        if (posterUrl != null) {
          debugPrint('   下载海报...');
          final localPath = await downloadImage(
            posterUrl,
            p.join(seriesImagesDir.path, 'poster.jpg'),
          );
          result['poster'] = localPath;
        }
      }

      // 下载背景图
      if (backdropPath != null && backdropPath.isNotEmpty) {
        final backdropUrl = TMDBService.getImageUrl(backdropPath);
        if (backdropUrl != null) {
          debugPrint('   下载背景图...');
          final localPath = await downloadImage(
            backdropUrl,
            p.join(seriesImagesDir.path, 'backdrop.jpg'),
          );
          result['backdrop'] = localPath;
        }
      }
    } catch (e) {
      debugPrint('❌ 下载图片异常: $e');
    }

    return result;
  }
}
