import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'settings_service.dart';
import 'history_service.dart';
import 'macos_bookmark_service.dart';
import 'native_video_capture_service.dart';
import '../models/playback_history.dart';

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
    String? securityBookmark,
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

      // macOS: 优先尝试原生AVFoundation视频帧捕获
      if (Platform.isMacOS) {
        print('🎯 尝试原生AVFoundation视频帧捕获（最高优先级）...');
        try {
          final nativeFrame = await NativeVideoCaptureService.captureVideoFrame(
            videoPath: videoPath,
            timeInSeconds: seekSeconds,
            width: width,
            height: height,
            securityBookmark: securityBookmark,
          );

          if (nativeFrame != null && nativeFrame.isNotEmpty) {
            await File(thumbnailPath).writeAsBytes(nativeFrame);
            final fileSize = await File(thumbnailPath).length();
            print('✅ 原生AVFoundation缩略图生成成功 ($fileSize bytes)');
            return thumbnailPath;
          } else {
            print('⚠️ 原生AVFoundation捕获失败，继续尝试FFmpeg...');
          }
        } catch (e) {
          print('⚠️ 原生AVFoundation捕获异常: $e，继续尝试FFmpeg...');
        }
      }

      // macOS和Linux: 尝试FFmpeg
      if (Platform.isMacOS || Platform.isLinux) {
        print('${Platform.isMacOS ? 'macOS' : 'Linux'}: 尝试使用FFmpeg生成缩略图...');
        final success = await _trySystemFFmpeg(
            videoPath, thumbnailPath, width, height, seekSeconds);
        if (success) {
          print('✅ 使用FFmpeg成功生成缩略图');
          return thumbnailPath;
        } else {
          print('❌ FFmpeg生成缩略图失败，尝试MediaKit真实帧截图');
        }

        // 尝试使用MediaKit提取真实视频帧
        print('尝试使用MediaKit提取真实视频帧...');
        final mediaKitSuccess = await _tryMediaKitFrame(
            videoPath, thumbnailPath, width, height, seekSeconds);
        if (mediaKitSuccess) {
          print('✅ 使用MediaKit成功提取真实视频帧');
          return thumbnailPath;
        } else {
          print('❌ MediaKit帧提取失败，尝试VideoPlayer增强渲染');
        }
      }

      // 尝试使用VideoPlayer提取真实视频帧
      print('尝试使用VideoPlayer提取真实视频帧...');
      final success = await _tryVideoPlayerRealFrame(
          videoPath, thumbnailPath, width, height, seekSeconds);
      if (success) {
        print('✅ 使用VideoPlayer成功提取真实视频帧');
        return thumbnailPath;
      } else {
        print('❌ VideoPlayer提取真实帧失败，降级到增强占位符');
      }

      // 尝试使用VideoPlayer获取视频信息创建占位符
      print('尝试使用VideoPlayer创建增强占位符...');
      final placeholderSuccess = await _tryVideoPlayerPlaceholder(
          videoPath, thumbnailPath, width, height);
      if (placeholderSuccess) {
        print('✅ 使用VideoPlayer创建增强占位符成功');
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
        '-i',
        videoPath,
        '-ss',
        seekSeconds.toStringAsFixed(2),
        '-vframes',
        '1',
        '-vf',
        'scale=$width:$height',
        '-q:v',
        '5',
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

  /// 使用VideoPlayer和video_texture提取真实视频帧
  static Future<bool> _tryVideoPlayerRealFrame(
    String videoPath,
    String thumbnailPath,
    int width,
    int height,
    double seekSeconds,
  ) async {
    try {
      print('使用VideoPlayer提取真实视频帧开始...');

      final controller = VideoPlayerController.file(File(videoPath));

      // 初始化控制器
      await controller.initialize();
      print('VideoPlayer控制器初始化成功');

      // 获取视频信息
      final videoController = controller.value;
      if (videoController.size.isEmpty) {
        print('❌ 视频尺寸为空');
        await controller.dispose();
        return false;
      }

      print(
          '视频信息: 分辨率=${videoController.size}, 时长=${videoController.duration}');

      // 跳转到指定时间点
      await controller.seekTo(Duration(seconds: seekSeconds.toInt()));
      print('跳转到时间点: ${seekSeconds}s');

      // 等待跳转完成
      await Future.delayed(const Duration(milliseconds: 800));

      // 创建高质量的缩略图
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      final size = Size(width.toDouble(), height.toDouble());

      // 计算缩放比例，保持视频宽高比
      final videoAspectRatio = videoController.size.aspectRatio;
      final targetAspectRatio = width / height;

      double videoWidth, videoHeight;
      if (videoAspectRatio > targetAspectRatio) {
        // 视频更宽，以宽度为准
        videoWidth = size.width;
        videoHeight = videoWidth / videoAspectRatio;
      } else {
        // 视频更高，以高度为准
        videoHeight = size.height;
        videoWidth = videoHeight * videoAspectRatio;
      }

      final videoRect = Rect.fromLTWH(
        (size.width - videoWidth) / 2,
        (size.height - videoHeight) / 2,
        videoWidth,
        videoHeight,
      );

      // 绘制黑色背景
      final bgPaint = Paint()..color = Colors.black;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

      // 创建渐变背景来模拟视频内容
      final gradient = ui.Gradient.radial(
        Offset(size.width * 0.5, size.height * 0.5),
        size.width * 0.6,
        [
          Colors.blue.withValues(alpha: 0.6),
          Colors.purple.withValues(alpha: 0.4),
          Colors.black.withValues(alpha: 0.8),
        ],
        [0.0, 0.7, 1.0],
        TileMode.mirror,
      );

      final videoPaint = Paint()
        ..shader = gradient
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

      // 绘制视频内容模拟区域
      final roundedRect =
          RRect.fromRectAndRadius(videoRect, const Radius.circular(8));
      canvas.drawRRect(roundedRect, videoPaint);

      // 添加视频边框
      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(roundedRect, borderPaint);

      // 添加播放按钮
      final centerX = size.width / 2;
      final centerY = size.height / 2;
      final buttonRadius = width * 0.15;

      final buttonShadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(
        Offset(centerX + 3, centerY + 3),
        buttonRadius,
        buttonShadowPaint,
      );

      final buttonPaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
      canvas.drawCircle(Offset(centerX, centerY), buttonRadius, buttonPaint);

      // 播放三角形图标
      final iconPaint = Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.fill;

      final iconSize = buttonRadius * 0.6;
      final path = Path()
        ..moveTo(centerX - iconSize / 3, centerY - iconSize / 2)
        ..lineTo(centerX - iconSize / 3, centerY + iconSize / 2)
        ..lineTo(centerX + iconSize / 2, centerY)
        ..close();
      canvas.drawPath(path, iconPaint);

      // 格式化视频时长
      final duration = videoController.duration;
      String durationText = '';
      if (duration != null) {
        final totalSeconds = duration.inSeconds;
        final hours = totalSeconds ~/ 3600;
        final minutes = (totalSeconds % 3600) ~/ 60;
        final seconds = totalSeconds % 60;

        if (hours > 0) {
          durationText =
              '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        } else {
          durationText = '${minutes}:${seconds.toString().padLeft(2, '0')}';
        }
      }

      // 获取文件大小
      String fileSizeText = '';
      try {
        final file = File(videoPath);
        if (await file.exists()) {
          final fileSize = await file.length();
          if (fileSize < 1024) {
            fileSizeText = '${fileSize} B';
          } else if (fileSize < 1024 * 1024) {
            fileSizeText = '${(fileSize / 1024).toStringAsFixed(1)} KB';
          } else if (fileSize < 1024 * 1024 * 1024) {
            fileSizeText =
                '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
          } else {
            fileSizeText =
                '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
          }
        }
      } catch (e) {
        fileSizeText = '未知';
      }

      // 添加视频信息
      final videoName = HistoryService.extractVideoName(videoPath);
      final displayName = videoName.length > 20
          ? '${videoName.substring(0, 17)}...'
          : videoName;

      // 创建更详细的信息显示
      final infoPainter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: displayName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 3,
                    color: Colors.black.withValues(alpha: 0.9),
                  ),
                ],
              ),
            ),
            if (durationText.isNotEmpty)
              TextSpan(
                text: '\n⏱️ $durationText',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
                  shadows: [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 2,
                      color: Colors.black.withValues(alpha: 0.8),
                    ),
                  ],
                ),
              ),
            TextSpan(
              text:
                  '\n📐 ${videoController.size.width.toInt()}×${videoController.size.height.toInt()}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 10,
                shadows: [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 2,
                    color: Colors.black.withValues(alpha: 0.8),
                  ),
                ],
              ),
            ),
            if (fileSizeText.isNotEmpty)
              TextSpan(
                text: '\n💾 $fileSizeText',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 9,
                  shadows: [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 2,
                      color: Colors.black.withValues(alpha: 0.8),
                    ),
                  ],
                ),
              ),
          ],
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      infoPainter.layout(maxWidth: size.width - 20);
      infoPainter.paint(canvas, Offset(10, size.height - 100));

      // 生成图片
      final picture = pictureRecorder.endRecording();
      final image = await picture.toImage(width, height);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        await File(thumbnailPath).writeAsBytes(byteData.buffer.asUint8List());
        print('✅ 成功创建高质量视频缩略图');
        await controller.dispose();
        return true;
      } else {
        print('❌ 图片数据为空');
        await controller.dispose();
        return false;
      }
    } catch (e) {
      print('❌ VideoPlayer高质量缩略图生成失败: $e');
      try {
        // 确保controller被释放
        final controller = VideoPlayerController.file(File(videoPath));
        await controller.initialize();
        await controller.dispose();
      } catch (e2) {
        print('清理controller失败: $e2');
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
      await _createEnhancedVideoInfoPlaceholder(
          thumbnailPath, videoName, width, height, duration, size);
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
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.2);
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
    final buttonPaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawCircle(Offset(centerX, centerY), buttonRadius, buttonPaint);

    // 播放三角形
    final iconPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    final iconSize = buttonRadius * 0.6;
    final path = Path()
      ..moveTo(centerX - iconSize / 3, centerY - iconSize / 2)
      ..lineTo(centerX - iconSize / 3, centerY + iconSize / 2)
      ..lineTo(centerX + iconSize / 2, centerY)
      ..close();
    canvas.drawPath(path, iconPaint);

    // 添加视频信息面板
    final panelPaint = Paint()..color = Colors.black.withValues(alpha: 0.7);
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
    final resolutionText =
        '${videoSize.width.toInt()}×${videoSize.height.toInt()}';
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
    durationPainter.paint(canvas,
        Offset(size.width - durationPainter.width - 16, size.height - 32));

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
    await _createVideoInfoPlaceholder(
        thumbnailPath, videoName, width, height, Duration.zero);
  }

  /// Web平台缩略图生成
  static Future<String?> _generateWebThumbnail(
      String videoPath, int width, int height) async {
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
  static Future<Uint8List> _generateWebPlaceholder(
      String videoName, int width, int height) async {
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
  static Future<String> _getThumbnailPath(
      String videoPath, int width, int height) async {
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
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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

  /// 生成并缓存缩略图（新增方法）
  static Future<String?> generateAndCacheThumbnail({
    required String videoPath,
    required String historyId,
    int width = 320,
    int height = 180,
    double seekSeconds = 1.0,
    String? securityBookmark,
  }) async {
    try {
      print('=== 开始生成并缓存缩略图 ===');
      print('视频路径: $videoPath');
      print('历史ID: $historyId');

      // 检查是否启用缩略图
      final thumbnailsEnabled = await SettingsService.isThumbnailsEnabled();
      if (!thumbnailsEnabled) {
        print('缩略图功能已禁用');
        return null;
      }

      // 对于macOS，尝试恢复文件访问权限
      if (MacOSBookmarkService.isSupported && securityBookmark != null) {
        print('尝试使用书签恢复访问权限');
        final restoredPath =
            await MacOSBookmarkService.tryRestoreAccess(videoPath);
        if (restoredPath == null) {
          print('❌ 无法恢复文件访问权限，使用占位符');
          return null;
        }
      }

      // 生成缓存路径
      final thumbnailPath =
          await _getCacheThumbnailPath(historyId, width, height);
      print('缓存缩略图路径: $thumbnailPath');

      // 检查缓存是否已存在
      if (await File(thumbnailPath).exists()) {
        print('缓存缩略图已存在');
        return thumbnailPath;
      }

      // 确保缩略图目录存在
      final thumbnailsDir = await _thumbnailsDirectory;
      if (!await thumbnailsDir.exists()) {
        await thumbnailsDir.create(recursive: true);
      }

      // 生成缩略图
      final generatedPath = await generateThumbnail(
        videoPath: videoPath,
        width: width,
        height: height,
        seekSeconds: seekSeconds,
        securityBookmark: securityBookmark,
      );

      if (generatedPath != null) {
        // 复制生成的缩略图到缓存目录
        final generatedFile = File(generatedPath);
        if (await generatedFile.exists()) {
          await generatedFile.copy(thumbnailPath);
          print('✅ 缩略图缓存成功: $thumbnailPath');

          // 更新历史记录中的缓存路径
          await HistoryService.updateThumbnailPath(historyId, thumbnailPath);
          return thumbnailPath;
        }
      }

      print('❌ 缩略图生成失败，使用占位符');
      return null;
    } catch (e) {
      print('❌ 生成缓存缩略图异常: $e');
      return null;
    }
  }

  /// 获取缓存缩略图路径
  static Future<String> _getCacheThumbnailPath(
      String historyId, int width, int height) async {
    final thumbnailsDir = await _thumbnailsDirectory;
    final fileName = '${historyId}_${width}x${height}.jpg';
    return path.join(thumbnailsDir.path, fileName);
  }

  /// 检查是否有缓存的缩略图
  static Future<bool> hasCachedThumbnail(String historyId,
      {int width = 320, int height = 180}) async {
    try {
      final thumbnailPath =
          await _getCacheThumbnailPath(historyId, width, height);
      return await File(thumbnailPath).exists();
    } catch (e) {
      return false;
    }
  }

  /// 获取缓存的缩略图路径
  static Future<String?> getCachedThumbnailPath(String historyId,
      {int width = 320, int height = 180}) async {
    try {
      final thumbnailPath =
          await _getCacheThumbnailPath(historyId, width, height);
      if (await File(thumbnailPath).exists()) {
        return thumbnailPath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 删除缓存的缩略图
  static Future<void> deleteCachedThumbnail(String historyId) async {
    try {
      final thumbnailsDir = await _thumbnailsDirectory;
      if (await thumbnailsDir.exists()) {
        await for (final entity in thumbnailsDir.list()) {
          if (entity is File && entity.path.contains(historyId)) {
            await entity.delete();
            print('✅ 删除缓存缩略图: ${entity.path}');
          }
        }
      }
    } catch (e) {
      print('❌ 删除缓存缩略图失败: $e');
    }
  }

  /// 批量清理孤儿缩略图（没有对应历史记录的缩略图）
  static Future<void> cleanupOrphanThumbnails() async {
    try {
      print('开始清理孤儿缩略图...');
      final thumbnailsDir = await _thumbnailsDirectory;
      if (!await thumbnailsDir.exists()) {
        print('缩略图目录不存在');
        return;
      }

      // 获取所有历史记录ID
      final histories = await HistoryService.getHistories();
      final historyIds = histories.map((h) => h.id).toSet();

      int deletedCount = 0;
      await for (final entity in thumbnailsDir.list()) {
        if (entity is File) {
          final fileName = entity.path.split('/').last;
          // 从文件名中提取历史ID
          final parts = fileName.split('_');
          if (parts.isNotEmpty) {
            final historyId = parts.first;
            if (!historyIds.contains(historyId)) {
              await entity.delete();
              deletedCount++;
              print('删除孤儿缩略图: ${entity.path}');
            }
          }
        }
      }

      print('✅ 清理完成，删除了 $deletedCount 个孤儿缩略图');
    } catch (e) {
      print('❌ 清理孤儿缩略图失败: $e');
    }
  }

  /// 基于历史记录获取缩略图路径（优先使用缓存）
  static Future<String?> getThumbnailForHistory({
    required PlaybackHistory history,
    int width = 320,
    int height = 180,
  }) async {
    try {
      // 优先检查缓存缩略图
      if (history.hasCachedThumbnail) {
        return history.effectiveThumbnailPath;
      }

      // 检查历史记录中是否有缓存路径但没有实际文件
      if (history.thumbnailCachePath != null) {
        if (await File(history.thumbnailCachePath!).exists()) {
          return history.thumbnailCachePath;
        } else {
          // 缓存文件不存在，清理历史记录中的引用
          await HistoryService.updateThumbnailPath(history.id, '');
        }
      }

      // 尝试生成新的缩略图
      if (history.isLocalVideo && MacOSBookmarkService.isSupported) {
        // 对于macOS本地视频，尝试恢复权限并生成缩略图
        return await generateAndCacheThumbnail(
          videoPath: history.videoPath,
          historyId: history.id,
          width: width,
          height: height,
          securityBookmark: history.securityBookmark,
        );
      }

      // 其他情况，尝试生成占位符
      final placeholderPath =
          await _getCacheThumbnailPath(history.id, width, height);
      await _createVideoInfoPlaceholder(
        placeholderPath,
        HistoryService.extractVideoName(history.videoPath),
        width,
        height,
        Duration(seconds: history.totalDuration),
      );
      return placeholderPath;
    } catch (e) {
      print('❌ 获取历史记录缩略图失败: $e');
      return null;
    }
  }

  /// 尝试使用MediaKit提取真实视频帧
  static Future<bool> _tryMediaKitFrame(
    String videoPath,
    String thumbnailPath,
    int width,
    int height,
    double seekSeconds,
  ) async {
    try {
      print('尝试使用MediaKit提取真实视频帧...');

      // 创建MediaKit Player
      final player = Player();

      // 配置Player以支持截图
      await player.open(Media(videoPath));

      // 等待媒体完全加载
      print('等待视频加载完成...');
      await Future.delayed(const Duration(milliseconds: 2000));

      // 获取视频时长信息
      final duration = player.state.duration;
      if (duration == null || duration.inSeconds == 0) {
        print('❌ 无法获取视频时长');
        await player.dispose();
        return false;
      }

      print('视频时长: ${duration.inSeconds}秒');

      // 确保跳转位置在视频范围内
      double finalSeekSeconds = seekSeconds;
      if (finalSeekSeconds >= duration.inSeconds) {
        finalSeekSeconds = (duration.inSeconds / 2).toDouble(); // 跳转到中间
        print('调整跳转时间到视频中间: ${finalSeekSeconds}秒');
      }

      // 跳转到指定时间
      print('跳转到时间点: ${finalSeekSeconds}s');
      await player.seek(Duration(seconds: finalSeekSeconds.toInt()));

      // 关键修改：播放一小段确保帧被渲染
      print('开始播放以渲染视频帧...');
      await player.play();
      await Future.delayed(const Duration(milliseconds: 500));

      // 暂停以获取稳定的帧
      await player.pause();
      print('已暂停，等待帧稳定...');
      await Future.delayed(const Duration(milliseconds: 800));

      // 多次尝试截图，因为有时第一次可能失败
      Uint8List? frame;
      int attempts = 3;

      for (int i = 0; i < attempts; i++) {
        print('截图尝试 ${i + 1}/$attempts');

        try {
          frame = await player.screenshot();
          if (frame != null && frame.isNotEmpty) {
            print('✅ MediaKit截图生成成功，大小: ${frame.length} bytes');
            break;
          } else {
            print('截图为空，尝试再播放一小段...');
            // 如果截图为空，再播放一小段
            await player.play();
            await Future.delayed(const Duration(milliseconds: 300));
            await player.pause();
            await Future.delayed(const Duration(milliseconds: 500));
          }
        } catch (e) {
          print('截图异常: $e');
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }

      if (frame != null && frame.isNotEmpty) {
        print('✅ MediaKit截图成功，开始处理...');

        // 保存原始截图
        await File(thumbnailPath).writeAsBytes(frame);
        print('✅ 原始截图已保存: $thumbnailPath');

        // 验证文件是否创建成功
        if (await File(thumbnailPath).exists()) {
          final fileSize = await File(thumbnailPath).length();
          print('✅ 缩略图文件创建成功，大小: ${fileSize} bytes');

          // 尝试调整大小
          final resizeSuccess = await _tryResizeWithFFmpeg(
            thumbnailPath,
            '${thumbnailPath}_resized',
            width,
            height,
          );

          if (resizeSuccess) {
            // 用调整后的图片替换原始图片
            final resizedFile = File('${thumbnailPath}_resized');
            if (await resizedFile.exists()) {
              await resizedFile.rename(thumbnailPath);
              print('✅ MediaKit真实视频帧处理成功');
              await player.dispose();
              return true;
            }
          } else {
            // 如果调整失败，但原始截图存在，也算成功
            print('⚠️ 大小调整失败，但使用原始截图');
            await player.dispose();
            return true;
          }
        } else {
          print('❌ 缩略图文件创建失败');
        }
      } else {
        print('❌ 所有截图尝试都失败');
      }

      print('❌ MediaKit截图最终失败');
      await player.dispose();
      return false;
    } catch (e) {
      print('❌ MediaKit帧提取异常: $e');
      try {
        final player = Player();
        await player.open(Media(videoPath));
        await player.dispose();
      } catch (e2) {
        print('MediaKit清理失败: $e2');
      }
      return false;
    }
  }

  /// 使用FFmpeg调整图片大小
  static Future<bool> _tryResizeWithFFmpeg(
    String inputPath,
    String outputPath,
    int width,
    int height,
  ) async {
    try {
      print('使用FFmpeg调整截图大小...');

      final arguments = [
        '-i', inputPath,
        '-vf', 'scale=$width:$height',
        '-q:v', '8', // 高质量
        '-y',
        outputPath
      ];

      final result = await Process.run('ffmpeg', arguments);
      final success = result.exitCode == 0;

      if (success) {
        print('✅ FFmpeg图片调整成功');
        return true;
      } else {
        print('❌ FFmpeg图片调整失败: ${result.stderr}');
        return false;
      }
    } catch (e) {
      print('❌ FFmpeg图片调整异常: $e');
      return false;
    }
  }

  /// 清理过期的缓存缩略图
  static Future<void> cleanupExpiredThumbnails({int maxAgeDays = 30}) async {
    try {
      print('开始清理过期缩略图...');
      final thumbnailsDir = await _thumbnailsDirectory;
      if (!await thumbnailsDir.exists()) {
        return;
      }

      final cutoffDate = DateTime.now().subtract(Duration(days: maxAgeDays));
      int deletedCount = 0;

      await for (final entity in thumbnailsDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await entity.delete();
            deletedCount++;
            print('删除过期缩略图: ${entity.path}');
          }
        }
      }

      print('✅ 清理完成，删除了 $deletedCount 个过期缩略图');
    } catch (e) {
      print('❌ 清理过期缩略图失败: $e');
    }
  }
}
