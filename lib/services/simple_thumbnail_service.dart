import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'settings_service.dart';
import 'history_service.dart';

class SimpleThumbnailService {
  static const String _cacheDir = 'thumbnails';
  static const int _maxCacheSize = 50 * 1024 * 1024; // 50MB

  /// 获取缩略图目录
  static Future<Directory> get _thumbnailsDirectory async {
    if (kIsWeb) {
      return Directory.systemTemp;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final thumbsDir = Directory(path.join(appDir.path, _cacheDir));

    if (!await thumbsDir.exists()) {
      await thumbsDir.create(recursive: true);
    }

    return thumbsDir;
  }

  /// 生成视频缩略图
  static Future<String?> generateThumbnail({
    required String videoPath,
    int width = 320,
    int height = 180,
    double seekSeconds = 1.0,
  }) async {
    try {
      // 检查是否启用缩略图
      final thumbnailsEnabled = await SettingsService.isThumbnailsEnabled();
      if (!thumbnailsEnabled) {
        return null;
      }

      if (kIsWeb) {
        // Web平台使用Base64缩略图
        return await _generateWebThumbnail(videoPath, width, height);
      }

      final thumbnailPath = await _getThumbnailPath(videoPath, width, height);

      // 检查是否已存在
      if (await File(thumbnailPath).exists()) {
        return thumbnailPath;
      }

      // 尝试使用系统FFmpeg
      if (Platform.isMacOS || Platform.isLinux) {
        final success = await _trySystemFFmpeg(videoPath, thumbnailPath, width, height, seekSeconds);
        if (success) {
          print('使用系统FFmpeg成功生成缩略图');
          return thumbnailPath;
        }
      }

      // 尝试使用VideoPlayer（虽然不能真正提取帧，但可以创建占位符）
      final success = await _tryVideoPlayerPlaceholder(videoPath, thumbnailPath, width, height);
      if (success) {
        print('使用VideoPlayer创建占位符');
        return thumbnailPath;
      }

      // 最后使用基础占位符
      await _createBasicPlaceholder(thumbnailPath, videoPath, width, height);
      print('使用基础占位符');
      return thumbnailPath;

    } catch (e) {
      print('生成缩略图失败: $e');
      return null;
    }
  }

  /// 使用系统FFmpeg命令
  static Future<bool> _trySystemFFmpeg(
    String videoPath,
    String thumbnailPath,
    int width,
    int height,
    double seekSeconds,
  ) async {
    try {
      if (!Platform.isMacOS && !Platform.isLinux) {
        return false;
      }

      // 检查系统是否安装了FFmpeg
      final ffmpegCheck = await Process.run('which', ['ffmpeg']);
      if (ffmpegCheck.exitCode != 0) {
        print('系统未安装FFmpeg');
        return false;
      }

      final command = 'ffmpeg -i "$videoPath" -ss ${seekSeconds.toStringAsFixed(2)} '
                    '-vframes 1 -vf "scale=${width}:${height}" '
                    '-q:v 15 "$thumbnailPath" 2>/dev/null';

      final result = await Process.run('bash', ['-c', command]);
      return result.exitCode == 0 && await File(thumbnailPath).exists();
    } catch (e) {
      print('系统FFmpeg失败: $e');
      return false;
    }
  }

  /// 使用VideoPlayer创建占位符
  static Future<bool> _tryVideoPlayerPlaceholder(
    String videoPath,
    String thumbnailPath,
    int width,
    int height,
  ) async {
    try {
      final controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();

      // 获取视频信息
      final duration = controller.value.duration;
      final videoName = HistoryService.extractVideoName(videoPath);

      await controller.dispose();

      // 创建基于视频信息的占位符
      await _createVideoInfoPlaceholder(thumbnailPath, videoName, width, height, duration);
      return true;
    } catch (e) {
      print('VideoPlayer占位符失败: $e');
      return false;
    }
  }

  /// 创建视频信息占位符
  static Future<void> _createVideoInfoPlaceholder(
    String thumbnailPath,
    String videoName,
    int width,
    int height,
    Duration duration,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(width.toDouble(), height.toDouble());

    // 生成基于视频名称的颜色
    final color = _generateColorFromName(videoName);

    // 绘制背景
    final bgPaint = Paint()..color = color;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 绘制半透明遮罩
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);

    // 绘制播放按钮
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final buttonRadius = width * 0.15;

    final buttonPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, centerY), buttonRadius, buttonPaint);

    // 播放三角形
    final iconPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    final iconSize = buttonRadius * 0.6;
    final path = Path()
      ..moveTo(centerX - iconSize/3, centerY - iconSize/2)
      ..lineTo(centerX - iconSize/3, centerY + iconSize/2)
      ..lineTo(centerX + iconSize/2, centerY)
      ..close();
    canvas.drawPath(path, iconPaint);

    // 添加视频信息
    final textPainter = TextPainter(
      text: TextSpan(
        text: _getShortName(videoName, width ~/ 20),
        style: TextStyle(
          color: Colors.white,
          fontSize: width * 0.08,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: Offset(width * 0.01, width * 0.01),
              blurRadius: width * 0.02,
              color: Colors.black.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: size.width - 20);
    textPainter.paint(canvas, Offset(10, size.height - 40));

    // 添加时长信息
    final durationText = _formatDuration(duration);
    final durationPainter = TextPainter(
      text: TextSpan(
        text: durationText,
        style: TextStyle(
          color: Colors.white,
          fontSize: width * 0.06,
          shadows: [
            Shadow(
              offset: Offset(width * 0.01, width * 0.01),
              blurRadius: width * 0.02,
              color: Colors.black.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    durationPainter.layout();
    durationPainter.paint(canvas, Offset(size.width - durationPainter.width - 10, size.height - 25));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final thumbnailFile = File(thumbnailPath);
      await thumbnailFile.writeAsBytes(byteData.buffer.asUint8List());
    }
  }

  /// 创建基础占位符
  static Future<void> _createBasicPlaceholder(
    String thumbnailPath,
    String videoPath,
    int width,
    int height,
  ) async {
    final videoName = HistoryService.extractVideoName(videoPath);
    await _createVideoInfoPlaceholder(thumbnailPath, videoName, width, height, Duration.zero);
  }

  /// Web平台缩略图生成
  static Future<String?> _generateWebThumbnail(String videoPath, int width, int height) async {
    try {
      final videoName = HistoryService.extractVideoName(videoPath);
      final bytes = await _generateWebPlaceholder(videoName, width, height);
      final base64Data = base64Encode(bytes);
      return 'data:image/png;base64,$base64Data';
    } catch (e) {
      print('Web缩略图生成失败: $e');
      return null;
    }
  }

  /// Web平台占位符生成
  static Future<Uint8List> _generateWebPlaceholder(String videoName, int width, int height) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(width.toDouble(), height.toDouble());

    final color = _generateColorFromName(videoName);
    final bgPaint = Paint()..color = color;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 绘制播放按钮
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final buttonRadius = width * 0.15;

    final buttonPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, centerY), buttonRadius, buttonPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  /// 获取缩略图路径
  static Future<String> _getThumbnailPath(String videoPath, int width, int height) async {
    final thumbnailsDir = await _thumbnailsDirectory;
    final pathHash = videoPath.hashCode.abs();
    final fileName = '${pathHash}_${width}x${height}.jpg';
    return path.join(thumbnailsDir.path, fileName);
  }

  /// 辅助方法
  static Color _generateColorFromName(String videoName) {
    final hash = videoName.hashCode.abs();
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(0.8, hue, 0.7, 0.8).toColor();
  }

  static String _getShortName(String name, int maxLength) {
    if (name.length <= maxLength) return name;
    return name.substring(0, maxLength - 3) + '...';
  }

  static String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    } else {
      return '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    }
  }

  /// 缓存管理
  static Future<void> clearCache() async {
    try {
      if (kIsWeb) return;

      final thumbnailsDir = await _thumbnailsDirectory;
      if (await thumbnailsDir.exists()) {
        await for (final entity in thumbnailsDir.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      print('清理缓存失败: $e');
    }
  }

  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      if (kIsWeb) {
        return {'fileCount': 0, 'totalSize': 0, 'formattedSize': '0 B'};
      }

      final thumbnailsDir = await _thumbnailsDirectory;
      if (!await thumbnailsDir.exists()) {
        return {'fileCount': 0, 'totalSize': 0, 'formattedSize': '0 B'};
      }

      int fileCount = 0;
      int totalSize = 0;

      await for (final entity in thumbnailsDir.list()) {
        if (entity is File) {
          fileCount++;
          totalSize += await entity.length();
        }
      }

      return {
        'fileCount': fileCount,
        'totalSize': totalSize,
        'formattedSize': _formatFileSize(totalSize),
      };
    } catch (e) {
      return {'fileCount': 0, 'totalSize': 0, 'formattedSize': '0 B'};
    }
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 获取支持的功能
  static Map<String, bool> getSupportedFeatures() {
    return {
      'system_ffmpeg': !kIsWeb && (Platform.isMacOS || Platform.isLinux),
      'video_player': !kIsWeb,
      'web_thumbnails': kIsWeb,
      'file_cache': !kIsWeb,
    };
  }
}