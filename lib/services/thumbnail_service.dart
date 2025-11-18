import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:video_player/video_player.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'settings_service.dart';
import 'history_service.dart';

class ThumbnailService {
  static const String _thumbnailsDir = 'thumbnails';
  static const int _maxCacheSize = 100 * 1024 * 1024; // 100MB
  static const int _maxThumbnailCount = 1000;

  /// 获取缩略图目录
  static Future<Directory> get _thumbnailsDirectory async {
    if (kIsWeb) {
      // Web 平台使用内存中的目录
      return Directory.systemTemp;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final thumbsDir = Directory(path.join(appDir.path, _thumbnailsDir));

    if (!await thumbsDir.exists()) {
      await thumbsDir.create(recursive: true);
    }

    return thumbsDir;
  }

  /// 生成视频缩略图文件路径
  static Future<String> _getThumbnailPath(String videoPath) async {
    if (kIsWeb) {
      // Web平台返回虚拟路径，实际使用Base64
      return 'web_thumbnail_${_generateHash(videoPath)}';
    }

    final thumbnailsDir = await _thumbnailsDirectory;
    // 使用视频路径的hash作为文件名，确保唯一性
    final fileName = '${_generateHash(videoPath)}.jpg';
    return path.join(thumbnailsDir.path, fileName);
  }

  /// 生成字符串的简单hash
  static String _generateHash(String input) {
    final bytes = utf8.encode(input);
    final digest = const Base64Encoder().convert(bytes);
    return digest.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').substring(0, 16);
  }

  /// 生成视频缩略图
  static Future<String?> generateThumbnail(String videoPath) async {
    try {
      // 检查设置是否启用了缩略图
      final thumbnailsEnabled = await SettingsService.isThumbnailsEnabled();
      if (!thumbnailsEnabled) {
        return null;
      }

      if (kIsWeb) {
        // Web 平台直接生成Base64缩略图
        return await _generateWebThumbnail(videoPath);
      }

      final thumbnailPath = await _getThumbnailPath(videoPath);

      // 检查缩略图是否已存在
      if (await File(thumbnailPath).exists()) {
        return thumbnailPath;
      }

      // 尝试多种方法生成缩略图
      bool success = false;

      // 1. 尝试使用系统命令（如果可用）
      if (Platform.isMacOS || Platform.isLinux) {
        success =
            await _generateThumbnailWithSystemCommand(videoPath, thumbnailPath);
        if (success) {
          print('使用系统命令成功生成缩略图');
        }
      }

      // 2. 尝试使用 FlutterFFmpeg 插件
      if (!success) {
        success = await _generateThumbnailWithFFmpeg(videoPath, thumbnailPath);
        if (success) {
          print('使用FFmpeg插件成功生成缩略图');
        }
      }

      // 3. 尝试使用 video_player（虽然不能真正提取帧，但至少能处理流程）
      if (!success) {
        success =
            await _generateThumbnailWithVideoPlayer(videoPath, thumbnailPath);
        if (success) {
          print('使用VideoPlayer成功处理缩略图');
        }
      }

      // 4. 如果所有方法都失败，创建增强的彩色占位符
      if (!success) {
        print('所有缩略图生成方法失败，使用增强占位符');
        await _createEnhancedPlaceholder(thumbnailPath, videoPath);
        // 即使占位符创建成功也返回路径
        return thumbnailPath;
      }

      return thumbnailPath;
    } catch (e) {
      print('生成缩略图失败: $e');
      // 创建占位符作为备选
      if (!kIsWeb) {
        try {
          final thumbnailPath = await _getThumbnailPath(videoPath);
          await _createEnhancedPlaceholder(thumbnailPath, videoPath);
          return thumbnailPath;
        } catch (placeholderError) {
          print('创建占位符也失败: $placeholderError');
        }
      }
      return null;
    }
  }

  /// 使用 FFmpeg 生成缩略图（暂时禁用）
  static Future<bool> _generateThumbnailWithFFmpeg(
      String videoPath, String thumbnailPath) async {
    try {
      // FFmpeg插件暂时不可用
      print('FFmpeg 插件暂时禁用');
      return false;

      /*final flutterFFmpeg = FlutterFFmpeg();
      final command = '-i "$videoPath" -ss 00:00:01 -vframes 1 -q:v 2 "$thumbnailPath"';
      final result = await flutterFFmpeg.execute(command);
      return result == 0;*/
    } catch (e) {
      print('FFmpeg 生成缩略图失败: $e');
      return false;
    }
  }

  /// 使用系统命令生成缩略图（macOS/Linux）
  static Future<bool> _generateThumbnailWithSystemCommand(
      String videoPath, String thumbnailPath) async {
    try {
      if (kIsWeb || !Platform.isMacOS && !Platform.isLinux) {
        return false;
      }

      // macOS/Linux系统命令
      String command;
      if (Platform.isMacOS) {
        // macOS使用sips命令
        command =
            'ffmpeg -i "$videoPath" -ss 00:00:01 -vframes 1 -vf "scale=160:90" "$thumbnailPath" 2>/dev/null';
      } else {
        // Linux使用ffmpeg命令
        command =
            'ffmpeg -i "$videoPath" -ss 00:00:01 -vframes 1 -vf "scale=160:90" "$thumbnailPath" 2>/dev/null';
      }

      final result = await Process.run('bash', ['-c', command]);
      return result.exitCode == 0;
    } catch (e) {
      print('系统命令生成缩略图失败: $e');
      return false;
    }
  }

  /// 生成增强的彩色占位符
  static Future<void> _createEnhancedPlaceholder(
      String thumbnailPath, String videoPath) async {
    try {
      final videoName = HistoryService.extractVideoName(videoPath);
      final bytes =
          await _generateColorfulPlaceholder(videoName, 0, DateTime.now());

      if (kIsWeb) {
        // Web平台不保存文件
        return;
      }

      final thumbnailFile = File(thumbnailPath);
      await thumbnailFile.writeAsBytes(bytes);
    } catch (e) {
      print('创建增强占位符失败: $e');
    }
  }

  /// 使用 video_player 生成缩略图
  static Future<bool> _generateThumbnailWithVideoPlayer(
      String videoPath, String thumbnailPath) async {
    try {
      final controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();

      // 跳转到第1秒
      await controller.seekTo(const Duration(seconds: 1));

      // video_player 不能直接导出帧，所以我们创建占位符
      await controller.dispose();

      // 创建一个基于视频文件信息的占位符缩略图
      await _createVideoBasedPlaceholder(thumbnailPath, videoPath);

      return true;
    } catch (e) {
      print('VideoPlayer 生成缩略图失败: $e');
      return false;
    }
  }

  /// 创建基于视频信息的占位符缩略图
  static Future<void> _createVideoBasedPlaceholder(
      String thumbnailPath, String videoPath) async {
    try {
      // 获取视频文件信息
      final file = File(videoPath);
      final fileSize = await file.length();
      final lastModified = await file.lastModified();

      // 创建一个简单的图像文件，基于视频信息生成不同颜色
      final bytes = await _generateColorfulPlaceholder(
        path.basenameWithoutExtension(videoPath),
        fileSize,
        lastModified,
      );

      final thumbnailFile = File(thumbnailPath);
      await thumbnailFile.writeAsBytes(bytes);
    } catch (e) {
      print('创建视频信息占位符失败: $e');
      // 使用基础占位符
      await _createPlaceholderThumbnail(thumbnailPath, videoPath);
    }
  }

  /// 生成彩色占位符图像
  static Future<Uint8List> _generateColorfulPlaceholder(
      String videoName, int fileSize, DateTime lastModified) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(160, 90);

    // 创建渐变背景
    final gradient = ui.Gradient.linear(
      Offset.zero,
      Offset(size.width, size.height),
      [
        _generateColorFromName(videoName),
        _generateColorFromName(videoName + '_alt')
      ],
    );

    final bgPaint = Paint()..shader = gradient;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, bgPaint);

    // 绘制半透明遮罩
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.3);
    canvas.drawRect(rect, overlayPaint);

    // 绘制播放按钮圆形背景
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final buttonRadius = 25.0;

    final buttonPaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawCircle(Offset(centerX, centerY), buttonRadius, buttonPaint);

    // 绘制播放三角形
    final iconPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    final iconSize = 20.0;
    final path = Path()
      ..moveTo(centerX - iconSize / 3, centerY - iconSize / 2)
      ..lineTo(centerX - iconSize / 3, centerY + iconSize / 2)
      ..lineTo(centerX + iconSize / 2, centerY)
      ..close();

    canvas.drawPath(path, iconPaint);

    // 添加视频图标
    final videoIconPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // 小视频图标
    final videoIconSize = 12.0;
    final videoIconX = size.width - 20;
    final videoIconY = 15.0;

    canvas.drawRect(
      Rect.fromLTWH(videoIconX, videoIconY, videoIconSize * 1.5, videoIconSize),
      videoIconPaint,
    );

    // 视频播放小三角
    final smallPath = Path()
      ..moveTo(videoIconX + 3.0, videoIconY + 3.0)
      ..lineTo(videoIconX + 3.0, videoIconY + videoIconSize - 3.0)
      ..lineTo(videoIconX + videoIconSize, videoIconY + videoIconSize / 2.0)
      ..close();

    canvas.drawPath(smallPath, videoIconPaint);

    // 添加视频名称
    final namePainter = TextPainter(
      text: TextSpan(
        text: _getShortName(videoName, 15),
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: const Offset(1, 1),
              blurRadius: 2,
              color: Colors.black.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    namePainter.layout(maxWidth: size.width - 15);
    namePainter.paint(canvas, Offset(8, size.height - 25));

    // 添加时长占位符（如果没有实际时长）
    final durationPainter = TextPainter(
      text: const TextSpan(
        text: '00:00',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          shadows: [
            Shadow(
              offset: Offset(1, 1),
              blurRadius: 2,
              color: Colors.black54,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    durationPainter.layout();
    durationPainter.paint(canvas,
        Offset(size.width - durationPainter.width - 8, size.height - 18));

    final picture = recorder.endRecording();
    final image =
        await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  /// 从视频名称生成颜色
  static Color _generateColorFromName(String videoName) {
    final hash = videoName.hashCode.abs();
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(0.8, hue, 0.7, 0.8).toColor();
  }

  /// 获取短名称
  static String _getShortName(String name, int maxLength) {
    if (name.length <= maxLength) return name;
    return name.substring(0, maxLength - 3) + '...';
  }

  /// 创建基础占位符缩略图
  static Future<void> _createPlaceholderThumbnail(
      String thumbnailPath, String videoPath) async {
    try {
      if (kIsWeb) {
        // Web平台不创建文件，直接返回
        return;
      }
      // 创建一个基于视频文件信息的占位符
      await _createVideoBasedPlaceholder(thumbnailPath, videoPath);
    } catch (e) {
      print('创建占位符缩略图失败: $e');
    }
  }

  /// 获取视频缩略图路径
  static Future<String?> getThumbnail(String videoPath) async {
    try {
      if (kIsWeb) {
        // Web平台直接生成并返回Base64缩略图
        return await _generateWebThumbnail(videoPath);
      }

      final thumbnailPath = await _getThumbnailPath(videoPath);

      if (await File(thumbnailPath).exists()) {
        return thumbnailPath;
      }

      // 如果缩略图不存在，尝试生成
      return await generateThumbnail(videoPath);
    } catch (e) {
      print('获取缩略图失败: $e');
      return null;
    }
  }

  /// 删除缩略图
  static Future<void> deleteThumbnail(String videoPath) async {
    try {
      if (kIsWeb) {
        // Web平台不需要删除操作
        return;
      }
      final thumbnailPath = await _getThumbnailPath(videoPath);
      final file = File(thumbnailPath);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('删除缩略图失败: $e');
    }
  }

  /// 清理缓存
  static Future<void> clearCache() async {
    try {
      if (kIsWeb) {
        // Web平台不需要清理缓存
        return;
      }
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

  /// 清理过期缩略图
  static Future<void> cleanExpiredThumbnails() async {
    try {
      if (kIsWeb) {
        // Web平台不需要清理缩略图
        return;
      }

      final thumbnailsDir = await _thumbnailsDirectory;

      if (!await thumbnailsDir.exists()) return;

      final files = <File>[];

      await for (final entity in thumbnailsDir.list()) {
        if (entity is File) {
          files.add(entity);
        }
      }

      // 按修改时间排序，最旧的在前
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return aStat.modified.compareTo(bStat.modified);
      });

      // 删除最旧的文件，直到缓存大小和数量在限制内
      int totalSize = 0;
      for (final file in files) {
        totalSize += await file.length();
      }

      // 如果超出限制，删除最旧的文件
      int filesToDelete = 0;
      if (files.length > _maxThumbnailCount) {
        filesToDelete += files.length - _maxThumbnailCount;
      }
      if (totalSize > _maxCacheSize) {
        final sizeToDelete = totalSize - _maxCacheSize;
        int currentSize = 0;

        for (int i = 0; i < files.length; i++) {
          if (currentSize >= sizeToDelete) break;
          currentSize += await files[i].length();
          filesToDelete = i + 1;
        }
      }

      // 删除需要删除的文件
      for (int i = 0; i < filesToDelete && i < files.length; i++) {
        await files[i].delete();
      }
    } catch (e) {
      print('清理过期缩略图失败: $e');
    }
  }

  /// 获取缓存统计信息
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      if (kIsWeb) {
        // Web平台返回空统计
        return {
          'fileCount': 0,
          'totalSize': 0,
          'formattedSize': '0 B',
        };
      }

      final thumbnailsDir = await _thumbnailsDirectory;

      if (!await thumbnailsDir.exists()) {
        return {
          'fileCount': 0,
          'totalSize': 0,
          'formattedSize': '0 B',
        };
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
      print('获取缓存统计失败: $e');
      return {
        'fileCount': 0,
        'totalSize': 0,
        'formattedSize': '0 B',
      };
    }
  }

  /// 格式化文件大小
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 生成Web平台的缩略图（Base64格式）
  static Future<String?> _generateWebThumbnail(String videoPath) async {
    try {
      // Web平台暂时生成Base64格式的占位符缩略图
      final videoName = HistoryService.extractVideoName(videoPath);
      final bytes =
          await _generateColorfulPlaceholder(videoName, 0, DateTime.now());
      final base64Data = base64Encode(bytes);
      return 'data:image/png;base64,$base64Data';
    } catch (e) {
      print('Web缩略图生成失败: $e');
      return null;
    }
  }

  /// 检查缩略图是否存在
  static Future<bool> thumbnailExists(String videoPath) async {
    try {
      if (kIsWeb) {
        // Web 平台不支持缩略图缓存
        return false;
      }
      final thumbnailPath = await _getThumbnailPath(videoPath);
      return await File(thumbnailPath).exists();
    } catch (e) {
      return false;
    }
  }
}
