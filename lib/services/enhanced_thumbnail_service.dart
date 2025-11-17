import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'thumbnail_service.dart';
import 'settings_service.dart';
import 'history_service.dart';

/// 缩略图质量枚举
enum ThumbnailQuality {
  low('低质量 (160x90)', 160, 90, 10),
  medium('中等质量 (320x180)', 320, 180, 15),
  high('高质量 (640x360)', 640, 360, 25);

  const ThumbnailQuality(this.label, this.width, this.height, this.quality);
  final String label;
  final int width;
  final int height;
  final int quality;
}

/// 缩略图截取位置枚举
enum ThumbnailPosition {
  start('开始 (1秒)', 1),
  quarter('25%位置', 0.25),
  middle('中间 (50%)', 0.5),
  custom('自定义位置', -1);

  const ThumbnailPosition(this.label, this.position);
  final String label;
  final double position; // 秒数或比例
}

class EnhancedThumbnailService {
  static const String _cacheDir = 'enhanced_thumbnails';
  static const int _maxMemoryCacheSize = 50; // 内存缓存最大数量
  static final Map<String, Uint8List> _memoryCache = {};

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

  /// 生成增强缩略图（支持质量和位置控制）
  static Future<String?> generateEnhancedThumbnail({
    required String videoPath,
    ThumbnailQuality quality = ThumbnailQuality.medium,
    ThumbnailPosition position = ThumbnailPosition.start,
    double? customSeconds,
    bool useGif = false,
    int gifDuration = 3, // GIF持续秒数
  }) async {
    try {
      // 检查是否启用缩略图
      final thumbnailsEnabled = await SettingsService.isThumbnailsEnabled();
      if (!thumbnailsEnabled) {
        return null;
      }

      // 生成缓存键
      final cacheKey = _generateCacheKey(videoPath, quality, position, customSeconds, useGif);

      if (kIsWeb) {
        // Web平台使用内存缓存
        if (_memoryCache.containsKey(cacheKey)) {
          return _memoryCacheToBase64(_memoryCache[cacheKey]!);
        }
        return await _generateWebEnhancedThumbnail(videoPath, quality, cacheKey);
      }

      // 桌面平台使用文件缓存
      final thumbnailPath = await _getThumbnailPath(cacheKey);
      if (await File(thumbnailPath).exists()) {
        return thumbnailPath;
      }

      // 使用增强方法生成缩略图（暂时不支持GIF）
      return await _generateEnhancedImageThumbnail(
        videoPath,
        thumbnailPath,
        quality,
        position,
        customSeconds,
      );
    } catch (e) {
      print('生成增强缩略图失败: $e');
      // 降级到基础缩略图服务
      return await ThumbnailService.generateThumbnail(videoPath);
    }
  }

  /// 生成增强图片缩略图
  static Future<String?> _generateEnhancedImageThumbnail(
    String videoPath,
    String thumbnailPath,
    ThumbnailQuality quality,
    ThumbnailPosition position,
    double? customSeconds,
  ) async {
    // 计算截取时间
    double seekTime = _calculateSeekTime(position, customSeconds);

    // 尝试多种方法
    bool success = false;

    // 1. 尝试使用 video_thumbnail 包（最稳定）
    success = await _tryVideoThumbnailPackage(videoPath, thumbnailPath, quality, seekTime);
    if (success) {
      print('使用video_thumbnail包成功生成缩略图');
      return thumbnailPath;
    }

    // 2. 尝试使用 flutter_ffmpeg
    success = await _tryFlutterFFmpeg(videoPath, thumbnailPath, quality, seekTime);
    if (success) {
      print('使用flutter_ffmpeg成功生成缩略图');
      return thumbnailPath;
    }

    // 3. 尝试使用系统命令
    if (Platform.isMacOS || Platform.isLinux) {
      success = await _trySystemCommand(videoPath, thumbnailPath, quality, seekTime);
      if (success) {
        print('使用系统命令成功生成缩略图');
        return thumbnailPath;
      }
    }

    // 4. 所有方法都尝试失败

    // 5. 最后使用增强占位符
    await _createEnhancedPlaceholder(thumbnailPath, videoPath);
    print('使用增强占位符');
    return thumbnailPath;
  }

  /// 使用 video_thumbnail 包生成缩略图
  static Future<bool> _tryVideoThumbnailPackage(
    String videoPath,
    String thumbnailPath,
    ThumbnailQuality quality,
    double seekTime,
  ) async {
    try {
      final thumbnailData = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: thumbnailPath,
        imageFormat: ImageFormat.PNG,
        maxWidth: quality.width,
        maxHeight: quality.height,
        timeMs: (seekTime * 1000).toInt(),
        quality: quality.quality,
      );
      return thumbnailData != null;
    } catch (e) {
      print('video_thumbnail包失败: $e');
      return false;
    }
  }

  
  /// 使用系统命令生成缩略图
  static Future<bool> _trySystemCommand(
    String videoPath,
    String thumbnailPath,
    ThumbnailQuality quality,
    double seekTime,
  ) async {
    try {
      String command;
      if (Platform.isMacOS) {
        command = 'ffmpeg -i "$videoPath" -ss ${seekTime.toStringAsFixed(2)} '
                  '-vframes 1 -vf "scale=${quality.width}:${quality.height}" '
                  '-q:v ${quality.quality} "$thumbnailPath" 2>/dev/null';
      } else {
        command = 'ffmpeg -i "$videoPath" -ss ${seekTime.toStringAsFixed(2)} '
                  '-vframes 1 -vf "scale=${quality.width}:${quality.height}" '
                  '-q:v ${quality.quality} "$thumbnailPath" 2>/dev/null';
      }

      final result = await Process.run('bash', ['-c', command]);
      return result.exitCode == 0;
    } catch (e) {
      print('系统命令失败: $e');
      return false;
    }
  }

  /// 使用 flutter_ffmpeg 生成缩略图
  static Future<bool> _tryFlutterFFmpeg(
    String videoPath,
    String thumbnailPath,
    ThumbnailQuality quality,
    double seekTime,
  ) async {
    try {
      final flutterFFmpeg = FlutterFFmpeg();
      final command = '-i "$videoPath" -ss ${seekTime.toStringAsFixed(2)} '
                    '-vframes 1 -vf "scale=${quality.width}:${quality.height}" '
                    '-q:v ${quality.quality} "$thumbnailPath"';

      final result = await flutterFFmpeg.execute(command);
      return result == 0;
    } catch (e) {
      print('flutter_ffmpeg失败: $e');
      return false;
    }
  }

  
  /// Web平台增强缩略图生成
  static Future<String?> _generateWebEnhancedThumbnail(
    String videoPath,
    ThumbnailQuality quality,
    String cacheKey,
  ) async {
    try {
      // Web平台使用更精美的占位符
      final videoName = HistoryService.extractVideoName(videoPath);
      final bytes = await _generateHighQualityPlaceholder(
        videoName,
        quality.width,
        quality.height
      );

      // 保存到内存缓存
      _memoryCache[cacheKey] = bytes;

      final base64Data = base64Encode(bytes);
      return 'data:image/png;base64,$base64Data';
    } catch (e) {
      print('Web增强缩略图生成失败: $e');
      return null;
    }
  }

  /// 生成高质量占位符
  static Future<Uint8List> _generateHighQualityPlaceholder(
    String videoName,
    int width,
    int height,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(width.toDouble(), height.toDouble());

    // 创建更复杂的渐变背景
    final gradient = ui.Gradient.linear(
      Offset.zero,
      Offset(size.width, size.height),
      [
        _generateColorFromName(videoName),
        _generateColorFromName(videoName + '_alt'),
        _generateColorFromName(videoName + '_alt2'),
      ],
      [0.0, 0.5, 1.0],
    );

    final bgPaint = Paint()..shader = gradient;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 添加网格图案
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final gridSize = 20.0;
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

    // 外圈
    final outerRingPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(centerX, centerY), buttonRadius + 5, outerRingPaint);

    // 主按钮
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

    // 添加视频标识
    if (width > 200) {
      // 只在较大尺寸时添加文字
      final textPainter = TextPainter(
        text: TextSpan(
          text: videoName.length > 20 ? '${videoName.substring(0, 17)}...' : videoName,
          style: TextStyle(
            color: Colors.white,
            fontSize: width * 0.06,
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
      textPainter.paint(canvas, Offset(10, size.height - 30));
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  /// 辅助方法
  static double _calculateSeekTime(ThumbnailPosition position, double? customSeconds) {
    switch (position) {
      case ThumbnailPosition.start:
        return 1.0;
      case ThumbnailPosition.quarter:
        return 2.0; // 假设视频8秒，取25%位置
      case ThumbnailPosition.middle:
        return 4.0; // 假设视频8秒，取中间
      case ThumbnailPosition.custom:
        return customSeconds ?? 1.0;
    }
  }

  static String _generateCacheKey(
    String videoPath,
    ThumbnailQuality quality,
    ThumbnailPosition position,
    double? customSeconds,
    bool useGif,
  ) {
    final pathHash = videoPath.hashCode.abs();
    final seekInfo = position == ThumbnailPosition.custom
        ? customSeconds?.toStringAsFixed(1) ?? '1.0'
        : position.name;
    final format = useGif ? 'gif' : 'png';
    return '${pathHash}_${quality.width}x${quality.height}_${seekInfo}.$format';
  }

  static Future<String> _getThumbnailPath(String cacheKey) async {
    final thumbnailsDir = await _thumbnailsDirectory;
    return path.join(thumbnailsDir.path, cacheKey);
  }

  static String _memoryCacheToBase64(Uint8List bytes) {
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }

  /// 创建增强占位符缩略图
  static Future<void> _createEnhancedPlaceholder(String thumbnailPath, String videoPath) async {
    try {
      if (kIsWeb) {
        return;
      }

      final videoName = HistoryService.extractVideoName(videoPath);
      final bytes = await _generateHighQualityPlaceholder(videoName, 160, 90);

      final thumbnailFile = File(thumbnailPath);
      await thumbnailFile.writeAsBytes(bytes);
    } catch (e) {
      print('创建增强占位符失败: $e');
    }
  }

  static Color _generateColorFromName(String videoName) {
    final hash = videoName.hashCode.abs();
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(0.8, hue, 0.7, 0.8).toColor();
  }

  /// 缓存管理
  static void clearMemoryCache() {
    _memoryCache.clear();
  }

  static int get memoryCacheSize => _memoryCache.length;

  /// 获取支持的平台功能
  static Map<String, bool> getSupportedFeatures() {
    return {
      'video_thumbnail_package': !kIsWeb,
      'system_command': !kIsWeb && (Platform.isMacOS || Platform.isLinux),
      'flutter_ffmpeg': !kIsWeb,
      'gif_generation': false, // 暂时禁用
      'memory_cache': kIsWeb,
      'file_cache': !kIsWeb,
      'quality_control': true,
      'position_control': true,
    };
  }
}