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
      print('=== 开始生成缩略图 ===');
      print('视频路径: $videoPath');
      print('尺寸: ${width}x$height');
      print('时间点: ${seekSeconds}s');

      // 检查是否启用缩略图
      final thumbnailsEnabled = await SettingsService.isThumbnailsEnabled();
      print('缩略图功能启用: $thumbnailsEnabled');
      if (!thumbnailsEnabled) {
        print('缩略图功能已禁用，返回null');
        return null;
      }

      // 检查视频文件是否存在
      if (!await File(videoPath).exists()) {
        print('视频文件不存在: $videoPath');
        return null;
      }

      if (kIsWeb) {
        // Web平台使用Base64缩略图
        print('Web平台，生成Base64缩略图');
        return await _generateWebThumbnail(videoPath, width, height);
      }

      final thumbnailPath = await _getThumbnailPath(videoPath, width, height);
      print('缩略图保存路径: $thumbnailPath');

      // 检查是否已存在
      if (await File(thumbnailPath).exists()) {
        print('缩略图已存在，直接返回');
        return thumbnailPath;
      }

      // macOS和Linux: 尝试FFmpeg
      if (Platform.isMacOS || Platform.isLinux) {
        print('${Platform.isMacOS ? 'macOS' : 'Linux'}: 尝试使用FFmpeg生成缩略图...');
        final success = await _trySystemFFmpeg(videoPath, thumbnailPath, width, height, seekSeconds);
        if (success) {
          print('✅ 使用FFmpeg成功生成缩略图');
          return thumbnailPath;
        } else {
          print('❌ FFmpeg生成缩略图失败');
        }
      }

      // 尝试使用VideoPlayer获取视频信息创建占位符
      print('尝试使用VideoPlayer创建占位符...');
      final success = await _tryVideoPlayerPlaceholder(videoPath, thumbnailPath, width, height);
      if (success) {
        print('✅ 使用VideoPlayer创建占位符成功');
        return thumbnailPath;
      } else {
        print('❌ VideoPlayer创建占位符失败');
      }

      // 最后使用基础占位符
      print('使用基础占位符...');
      await _createBasicPlaceholder(thumbnailPath, videoPath, width, height);
      print('✅ 基础占位符创建完成');
      return thumbnailPath;

    } catch (e) {
      print('❌ 生成缩略图失败: $e');
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

      print('尝试使用FFmpeg生成缩略图...');

      // FFmpeg命令参数
      final arguments = [
        '-i', videoPath,
        '-ss', seekSeconds.toStringAsFixed(2),
        '-vframes', '1',
        '-vf', 'scale=$width:$height',
        '-q:v', '5',
        '-y',
        thumbnailPath
      ];

      final result = await Process.run('ffmpeg', arguments);
      final success = result.exitCode == 0;
      final fileExists = await File(thumbnailPath).exists();

      if (success && fileExists) {
        final fileSize = await File(thumbnailPath).length();
        print('✅ FFmpeg成功生成缩略图 ($fileSize bytes)');
        return true;
      }

      // 检查是否是权限错误
      if (result.stderr.toString().contains('Operation not permitted') ||
          result.stderr.toString().contains('Permission denied')) {
        print('⚠️  FFmpeg权限不足（macOS沙盒限制），将使用占位符');
        return false;
      }

      print('❌ FFmpeg执行失败，返回码: ${result.exitCode}');
      return false;
    } catch (e) {
      // 捕获ProcessException（如ffmpeg未找到）
      if (e.toString().contains('No such file or directory')) {
        print('⚠️  未找到FFmpeg命令，将使用占位符');
      } else if (e.toString().contains('Operation not permitted')) {
        print('⚠️  FFmpeg权限不足（macOS沙盒限制），将使用占位符');
      } else {
        print('⚠️  FFmpeg执行异常: $e，将使用占位符');
      }
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
      print('尝试使用VideoPlayer获取视频信息...');
      final controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();

      // 获取详细视频信息
      final duration = controller.value.duration;
      final size = controller.value.size;
      final videoName = HistoryService.extractVideoName(videoPath);

      print('获取视频信息成功: 时长=${duration}, 分辨率=${size}');

      await controller.dispose();

      // 创建增强的基于视频信息的占位符
      await _createEnhancedVideoInfoPlaceholder(thumbnailPath, videoName, width, height, duration, size);
      print('✅ 增强VideoPlayer占位符创建成功');
      return true;
    } catch (e) {
      print('VideoPlayer占位符失败: $e');
      return false;
    }
  }

  /// 创建增强的视频信息占位符
  static Future<void> _createEnhancedVideoInfoPlaceholder(
    String thumbnailPath,
    String videoName,
    int width,
    int height,
    Duration duration,
    Size videoSize,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(width.toDouble(), height.toDouble());

    // 生成基于视频名称的颜色
    final color = _generateColorFromName(videoName);

    // 创建更复杂的渐变背景
    final gradient = ui.Gradient.linear(
      Offset.zero,
      Offset(size.width, size.height),
      [
        color,
        _generateColorFromName(videoName + '_alt'),
        color.withValues(alpha: 0.7),
      ],
      [0.0, 0.6, 1.0],
    );

    final bgPaint = Paint()..shader = gradient;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 绘制半透明遮罩
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);

    // 绘制网格纹理
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const gridSize = 20.0;
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 绘制播放按钮
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final buttonRadius = width * 0.15;

    // 播放按钮阴影
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(
      Offset(centerX + 2, centerY + 2),
      buttonRadius,
      shadowPaint,
    );

    // 播放按钮背景
    final buttonPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9);
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

    // 添加视频信息面板
    final panelPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7);
    final panelRect = Rect.fromLTWH(8, size.height - 50, size.width - 16, 42);
    final rrect = RRect.fromRectAndRadius(panelRect, const Radius.circular(6));
    canvas.drawRRect(rrect, panelPaint);

    // 添加视频名称
    final namePainter = TextPainter(
      text: TextSpan(
        text: _getShortName(videoName, width ~/ 15),
        style: TextStyle(
          color: Colors.white,
          fontSize: width * 0.06,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: Offset(width * 0.005, width * 0.005),
              blurRadius: width * 0.01,
              color: Colors.black.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    namePainter.layout(maxWidth: size.width - 70);
    namePainter.paint(canvas, Offset(16, size.height - 45));

    // 添加分辨率信息
    final resolutionText = '${videoSize.width.toInt()}×${videoSize.height.toInt()}';
    final resolutionPainter = TextPainter(
      text: TextSpan(
        text: resolutionText,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: width * 0.045,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    resolutionPainter.layout();
    resolutionPainter.paint(canvas, Offset(16, size.height - 25));

    // 添加时长信息
    final durationText = _formatDuration(duration);
    final durationPainter = TextPainter(
      text: TextSpan(
        text: durationText,
        style: TextStyle(
          color: Colors.white,
          fontSize: width * 0.06,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: Offset(width * 0.005, width * 0.005),
              blurRadius: width * 0.01,
              color: Colors.black.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    durationPainter.layout();
    durationPainter.paint(canvas, Offset(size.width - durationPainter.width - 16, size.height - 32));

    // 添加视频类型标签
    final typeLabel = 'VIDEO';
    final typePainter = TextPainter(
      text: TextSpan(
        text: typeLabel,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: width * 0.03,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    typePainter.layout();
    typePainter.paint(canvas, Offset(size.width - typePainter.width - 16, 16));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final thumbnailFile = File(thumbnailPath);
      await thumbnailFile.writeAsBytes(byteData.buffer.asUint8List());
    }
  }

  /// 创建视频信息占位符（保持向后兼容）
  static Future<void> _createVideoInfoPlaceholder(
    String thumbnailPath,
    String videoName,
    int width,
    int height,
    Duration duration,
  ) async {
    await _createEnhancedVideoInfoPlaceholder(
      thumbnailPath,
      videoName,
      width,
      height,
      duration,
      const Size(1920, 1080), // 默认分辨率
    );
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