import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'history_service.dart';
import 'settings_service.dart';

/// 缩略图生成服务
class ThumbnailGeneratorService {
  static ThumbnailGeneratorService? _instance;
  static ThumbnailGeneratorService get instance {
    _instance ??= ThumbnailGeneratorService._();
    return _instance!;
  }

  ThumbnailGeneratorService._();

  late Directory _thumbnailDirectory;
  bool _initialized = false;

  /// 网络视频延迟截图时间（播放开始后）
  static const Duration networkVideoDelay = Duration(seconds: 3);

  /// 本地视频截图位置（5%进度）
  static const double localVideoPosition = 0.05;

  /// 缩略图尺寸
  static const int thumbnailWidth = 320;
  static const int thumbnailHeight = 180;
  static const int thumbnailQuality = 85; // JPEG质量

  /// 初始化缩略图服务
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final appDir = await getApplicationSupportDirectory();
      _thumbnailDirectory = Directory(path.join(appDir.path, 'thumbnails'));

      if (!await _thumbnailDirectory.exists()) {
        await _thumbnailDirectory.create(recursive: true);
      }

      _initialized = true;
      print('✅ ThumbnailGeneratorService initialized');
    } catch (e) {
      print('❌ Failed to initialize ThumbnailGeneratorService: $e');
      _initialized = true; // 标记为已初始化但禁用功能
    }
  }

  /// 为网络视频生成缩略图
  Future<String?> generateNetworkThumbnail(
    Player player,
    String videoUrl, {
    Duration? delay,
  }) async {
    await _ensureInitialized();

    try {
      // 检查用户是否启用了缩略图生成
      final thumbnailsEnabled = await SettingsService.isThumbnailsEnabled();
      if (!thumbnailsEnabled) {
        print('⚠️ Thumbnails are disabled in settings');
        return null;
      }

      // 等待播放开始
      await _waitForPlaybackStart(player);

      // 延迟指定时间（默认3秒）
      await Future.delayed(delay ?? networkVideoDelay);

      // 截图
      final imageBytes = await player.screenshot(format: 'image/jpeg');
      if (imageBytes == null || imageBytes.isEmpty) {
        print('⚠️ Screenshot returned empty data');
        return null;
      }

      // 保存到缓存目录
      final thumbnailPath = await _saveThumbnail(videoUrl, imageBytes);
      print('✅ Network thumbnail generated: $thumbnailPath');

      // 更新历史记录
      await _updateHistoryThumbnail(videoUrl, thumbnailPath);

      return thumbnailPath;
    } catch (e) {
      print('❌ Failed to generate network thumbnail: $e');
      return null;
    }
  }

  /// 为本地视频生成缩略图
  Future<String?> generateLocalThumbnail(
    Player player,
    String videoPath,
    Duration videoDuration,
  ) async {
    await _ensureInitialized();

    try {
      // 检查用户是否启用了缩略图生成
      final thumbnailsEnabled = await SettingsService.isThumbnailsEnabled();
      if (!thumbnailsEnabled) {
        print('⚠️ Thumbnails are disabled in settings');
        return null;
      }

      // 跳转到5%进度
      final position = Duration(
          milliseconds: (videoDuration.inMilliseconds * localVideoPosition).toInt());
      await player.seek(position);

      // 等待跳转完成
      await Future.delayed(Duration(milliseconds: 500));

      // 截图
      final imageBytes = await player.screenshot(format: 'image/jpeg');
      if (imageBytes == null || imageBytes.isEmpty) {
        print('⚠️ Screenshot returned empty data');
        return null;
      }

      // 保存到缓存目录
      final thumbnailPath = await _saveThumbnail(videoPath, imageBytes);
      print('✅ Local thumbnail generated: $thumbnailPath');

      // 更新历史记录
      await _updateHistoryThumbnail(videoPath, thumbnailPath, isNetwork: false);

      return thumbnailPath;
    } catch (e) {
      print('❌ Failed to generate local thumbnail: $e');
      return null;
    }
  }

  /// 等待播放开始
  Future<void> _waitForPlaybackStart(Player player) async {
    final completer = Completer<void>();
    late StreamSubscription<bool> subscription;

    subscription = player.stream.playing.listen((playing) {
      if (playing && !completer.isCompleted) {
        completer.complete();
        subscription.cancel();
      }
    });

    // 超时保护（10秒）
    await completer.future.timeout(
      Duration(seconds: 10),
      onTimeout: () {
        subscription.cancel();
        throw TimeoutException('Playback did not start in time');
      },
    );
  }

  /// 保存缩略图到本地
  Future<String> _saveThumbnail(String videoIdentifier, Uint8List imageBytes) async {
    // 生成缩略图文件名（基于视频标识的hash）
    final hash = sha256.convert(utf8.encode(videoIdentifier)).toString();
    final filename = '$hash.jpg';
    final thumbnailPath = path.join(_thumbnailDirectory.path, filename);

    // 可选：调整图片大小以节省空间
    final resizedBytes = await _resizeImage(imageBytes);

    // 写入文件
    final file = File(thumbnailPath);
    await file.writeAsBytes(resizedBytes);

    return thumbnailPath;
  }

  /// 调整图片大小
  Future<Uint8List> _resizeImage(Uint8List imageBytes) async {
    try {
      // 创建 codec
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // 创建图片大小
      final targetWidth = thumbnailWidth;
      final targetHeight = thumbnailHeight;

      // 计算保持宽高比的缩放
      final sourceWidth = image.width.toDouble();
      final sourceHeight = image.height.toDouble();
      final aspectRatio = sourceWidth / sourceHeight;

      int finalWidth, finalHeight;
      if (aspectRatio > (targetWidth / targetHeight)) {
        finalWidth = targetWidth;
        finalHeight = (targetWidth / aspectRatio).round();
      } else {
        finalHeight = targetHeight;
        finalWidth = (targetHeight * aspectRatio).round();
      }

      // 创建画布
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);

      // 绘制图片
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, sourceWidth, sourceHeight),
        Rect.fromLTWH(0, 0, finalWidth.toDouble(), finalHeight.toDouble()),
        Paint(),
      );

      // 转换为图片
      final picture = pictureRecorder.endRecording();
      final resizedImage = await picture.toImage(finalWidth, finalHeight);
      final byteData = await resizedImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }

      // 如果调整失败，返回原图
      return imageBytes;
    } catch (e) {
      print('⚠️ Failed to resize image: $e');
      return imageBytes;
    }
  }

  /// 更新历史记录的缩略图路径
  Future<void> _updateHistoryThumbnail(
    String videoPath,
    String thumbnailPath, {
    bool isNetwork = true,
  }) async {
    try {
      final histories = await HistoryService.getHistories();

      // 查找匹配的历史记录
      for (final history in histories) {
        if (history.videoPath == videoPath ||
            (isNetwork && history.sourceType == 'network' && history.videoPath == videoPath)) {
          await HistoryService.updateThumbnailPath(history.id, thumbnailPath);
          print('✅ Updated thumbnail for history: $videoPath');
          break;
        }
      }
    } catch (e) {
      print('❌ Failed to update history thumbnail: $e');
    }
  }

  /// 获取视频的缩略图路径
  Future<String?> getThumbnailPath(String videoIdentifier) async {
    await _ensureInitialized();

    final hash = sha256.convert(utf8.encode(videoIdentifier)).toString();
    final filename = '$hash.jpg';
    final thumbnailPath = path.join(_thumbnailDirectory.path, filename);

    if (await File(thumbnailPath).exists()) {
      return thumbnailPath;
    }

    return null;
  }

  /// 清理无效的缩略图
  Future<void> cleanupInvalidThumbnails() async {
    await _ensureInitialized();

    try {
      final histories = await HistoryService.getHistories();

      // 获取所有有效的缩略图路径
      final validPaths = <String>{};
      for (final history in histories) {
        if (history.thumbnailCachePath != null) {
          final file = File(history.thumbnailCachePath!);
          if (await file.exists()) {
            validPaths.add(history.thumbnailCachePath!);
          }
        }
      }

      // 扫描缩略图目录，删除无效文件
      final files = _thumbnailDirectory.listSync();
      for (final file in files) {
        if (file is File && !validPaths.contains(file.path)) {
          try {
            await file.delete();
            print('🗑️ Deleted orphaned thumbnail: ${file.path}');
          } catch (e) {
            print('⚠️ Failed to delete orphaned thumbnail ${file.path}: $e');
          }
        }
      }
    } catch (e) {
      print('❌ Failed to cleanup invalid thumbnails: $e');
    }
  }

  /// 获取缩略图缓存大小
  Future<int> getCacheSize() async {
    await _ensureInitialized();

    try {
      int totalSize = 0;
      final files = _thumbnailDirectory.listSync();
      for (final file in files) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      return totalSize;
    } catch (e) {
      print('❌ Failed to calculate cache size: $e');
      return 0;
    }
  }

  /// 清空所有缩略图
  Future<void> clearAllThumbnails() async {
    await _ensureInitialized();

    try {
      final files = _thumbnailDirectory.listSync();
      for (final file in files) {
        if (file is File) {
          await file.delete();
        }
      }
      print('✅ Cleared all thumbnails');
    } catch (e) {
      print('❌ Failed to clear thumbnails: $e');
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }
}