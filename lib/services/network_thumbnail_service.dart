import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'settings_service.dart';
import 'history_service.dart';

/// 网络视频缩略图生成服务（基于播放器截图）
class NetworkThumbnailService {
  /// 网络视频延迟截图时间（播放开始后）
  static const Duration delayBeforeScreenshot = Duration(seconds: 5);

  /// 活跃的缩略图生成操作追踪
  static final Map<String, Completer<void>> _activeOperations = {};

  /// 全局释放状态标志，用于立即阻止新操作
  static bool _isDisposing = false;

  /// 互斥锁保护截图操作
  static bool _isScreenshotInProgress = false;

  /// 为网络视频生成缩略图（基于播放器截图）
  static Future<String?> generateFromPlayer({
    required Player player,
    required String videoUrl,
    int width = 320,
    int height = 180,
    Duration? delay,
  }) async {
    final operationId = '${videoUrl.hashCode}_${DateTime.now().millisecondsSinceEpoch}';
    final completer = Completer<String?>();
    _activeOperations[operationId] = completer;

    try {
      print('🎬 开始为网络视频生成缩略图... [操作ID: $operationId]');
      print('URL: $videoUrl');
      print('尺寸: ${width}x$height');

      // 立即检查全局 disposing 状态
      if (_isDisposing) {
        print('⚠️ 服务正在释放中，取消缩略图生成 [操作ID: $operationId]');
        return null;
      }

      // 检查播放器是否已被释放
      if (_isPlayerDisposed(player)) {
        print('⚠️ 播放器已被释放，无法生成缩略图 [操作ID: $operationId]');
        return null;
      }

      // 检查是否启用缩略图
      final thumbnailsEnabled = await SettingsService.isThumbnailsEnabled();
      if (!thumbnailsEnabled) {
        print('⚠️ 缩略图功能已禁用');
        return null;
      }

      // 等待播放器准备就绪（改进的检测逻辑，支持缓冲和元数据检查）
      final playerReady = await _waitForPlayerReady(player, timeout: Duration(seconds: 12));
      if (!playerReady) {
        print('⚠️ 播放器未准备就绪，尝试使用播放器状态截图');
        // 即使播放器未完全准备就绪，也尝试截图（可能已加载元数据）
        return await _tryDirectScreenshot(player, videoUrl, width, height);
      }

      // 额外延迟等待视频缓冲
      await Future.delayed(Duration(seconds: 2));

      // 检查播放器是否已被释放
      if (_isPlayerDisposed(player)) {
        print('⚠️ 播放器在延迟期间被释放');
        return null;
      }

      // 检查播放器状态（但不强制要求正在播放）
      final isPlaying = player.state.playing;
      final isBuffering = player.state.buffering;
      print('📊 播放器状态: playing=$isPlaying, buffering=$isBuffering');

      // 延迟等待视频加载和缓冲
      await Future.delayed(delay ?? delayBeforeScreenshot);

      // 再次检查播放器是否已被释放
      if (_isPlayerDisposed(player)) {
        print('⚠️ 播放器在延迟后已被释放');
        return null;
      }

      print('📸 截取视频帧...');
      final imageBytes = await _safeScreenshot(player);
      if (imageBytes == null || imageBytes.isEmpty) {
        print('⚠️ 截图失败：返回空数据或播放器已释放');
        return null;
      }

      // 保存缩略图
      final thumbnailPath = await _saveThumbnail(videoUrl, imageBytes, width, height);
      print('✅ 缩略图保存成功: $thumbnailPath');

      // 更新历史记录
      await _updateHistoryThumbnail(videoUrl, thumbnailPath);

      print('✅ 缩略图生成操作完成 [操作ID: $operationId]');
      return thumbnailPath;
    } catch (e) {
      if (e.toString().contains('Player has been disposed')) {
        print('⚠️ 播放器在缩略图生成过程中被释放 [操作ID: $operationId]');
      } else {
        print('❌ 生成网络视频缩略图失败: $e [操作ID: $operationId]');
      }
      return null;
    } finally {
      _activeOperations.remove(operationId);
    }
  }

  /// 带重试机制的直接截图（即使播放未开始）
  static Future<String?> _tryDirectScreenshot(
    Player player,
    String videoUrl,
    int width,
    int height, {
    int maxRetries = 2,
  }) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          print('🔄 直接截图重试 $attempt/$maxRetries');
          // 重试之间增加延迟
          await Future.delayed(Duration(seconds: attempt * 2));
        }

        // 检查播放器是否已被释放
        if (_isPlayerDisposed(player)) {
          print('⚠️ 播放器已被释放，停止直接截图尝试');
          return null;
        }

        print('🔄 尝试直接截图（第${attempt + 1}次）...');

        // 给播放器一些加载时间
        await Future.delayed(Duration(seconds: 1 + attempt));

        // 再次检查播放器是否已被释放
        if (_isPlayerDisposed(player)) {
          print('⚠️ 播放器在等待期间被释放');
          return null;
        }

        final imageBytes = await _safeScreenshot(player);
        if (imageBytes != null && imageBytes.isNotEmpty) {
          final thumbnailPath = await _saveThumbnail(videoUrl, imageBytes, width, height);
          print('✅ 直接截图成功（第${attempt + 1}次）: $thumbnailPath');
          await _updateHistoryThumbnail(videoUrl, thumbnailPath);
          return thumbnailPath;
        } else {
          print('⚠️ 第${attempt + 1}次直接截图返回空数据');
        }
      } catch (e) {
        if (e.toString().contains('Player has been disposed')) {
          print('⚠️ 直接截图时播放器已被释放（第${attempt + 1}次）');
          return null;
        }
        print('❌ 第${attempt + 1}次直接截图异常: $e');

        // 如果是最后一次尝试，直接返回失败
        if (attempt == maxRetries) {
          print('❌ 所有直接截图重试均失败');
          return null;
        }
      }
    }

    return null;
  }

  /// 等待播放器准备就绪（改进版：不仅检查播放状态，还检查缓冲和元数据）
  static Future<bool> _waitForPlayerReady(Player player, {required Duration timeout}) async {
    final completer = Completer<bool>();
    late StreamSubscription<bool> playingSubscription;
    late StreamSubscription<bool> bufferingSubscription;
    bool hasStartedPlaying = false;

    // 监听播放状态
    playingSubscription = player.stream.playing.listen((playing) {
      if (playing && !completer.isCompleted) {
        hasStartedPlaying = true;
        // 如果正在播放且没有在缓冲，说明播放器已准备就绪
        if (!player.state.buffering) {
          playingSubscription.cancel();
          bufferingSubscription.cancel();
          completer.complete(true);
        }
      }
    });

    // 监听缓冲状态
    bufferingSubscription = player.stream.buffering.listen((buffering) {
      if (!buffering && hasStartedPlaying && !completer.isCompleted) {
        // 如果曾经开始播放，现在不在缓冲中，说明准备就绪
        playingSubscription.cancel();
        bufferingSubscription.cancel();
        completer.complete(true);
      }
    });

    try {
      // 超时保护，但即使超时也尝试检查播放器是否可以截图
      await completer.future.timeout(timeout, onTimeout: () {
        if (!completer.isCompleted) {
          playingSubscription.cancel();
          bufferingSubscription.cancel();
          print('⏰ 等待播放器就绪超时，尝试直接检查播放器状态...');
          // 即使超时，也检查播放器是否准备好截图
          return _checkPlayerReadyForScreenshot(player);
        }
        return false;
      });
    } catch (e) {
      print('❌ 等待播放器就绪时出错: $e');
      return false;
    }

    return completer.future;
  }

  /// 检查播放器是否准备好进行截图
  static Future<bool> _checkPlayerReadyForScreenshot(Player player) async {
    try {
      // 检查是否有有效的时长信息
      if (player.state.duration.inMilliseconds > 0) {
        print('✅ 播放器有时长信息，尝试测试截图...');
        // 尝试获取测试帧（不保存）
        final testBytes = await _safeScreenshot(player);
        final canScreenshot = testBytes != null && testBytes.isNotEmpty;
        print('📸 测试截图结果: ${canScreenshot ? "成功" : "失败"}');
        return canScreenshot;
      } else {
        print('⚠️ 播放器没有有效的时长信息');
        return false;
      }
    } catch (e) {
      print('❌ 检查播放器准备状态时出错: $e');
      if (e.toString().contains('Player has been disposed')) {
        print('⚠️ 播放器已被释放');
      }
      return false;
    }
  }

  /// 安全截图包装器（带超时和状态检查）
  static Future<Uint8List?> _safeScreenshot(Player player) async {
    // 使用互斥锁防止多个截图同时进行
    if (_isScreenshotInProgress) {
      print('⚠️ 另一个截图正在进行中，跳过本次请求');
      return null;
    }

    // 立即检查播放器状态和全局 disposing 状态
    if (_isDisposing || _isPlayerDisposed(player)) {
      print('⚠️ 播放器已被释放或服务正在释放中，取消截图');
      return null;
    }

    _isScreenshotInProgress = true;

    try {
      print('🔄 开始安全截图...');

      // 使用短暂的超时来避免长时间等待
      final imageBytes = await player.screenshot(format: 'image/jpeg')
          .timeout(Duration(milliseconds: 800), onTimeout: () {
        print('⏰ 截图超时（800ms），可能播放器已被释放或正在处理');
        return Uint8List(0); // 返回空数组而不是 null，便于区分超时和其他错误
      });

      // 再次检查播放器状态（截图完成后）
      if (_isDisposing || _isPlayerDisposed(player)) {
        print('⚠️ 截图完成后发现播放器已被释放');
        return null;
      }

      if (imageBytes == null || imageBytes.isEmpty) {
        print('⚠️ 截图返回空数据');
        return null;
      }

      print('✅ 安全截图完成，大小: ${imageBytes.length} bytes');
      return imageBytes;
    } catch (e) {
      if (e.toString().contains('Player has been disposed')) {
        print('⚠️ 截图过程中播放器被释放');
      } else if (e.toString().contains('TimeoutException')) {
        print('⏰ 截图操作超时');
      } else {
        print('❌ 截图操作失败: $e');
      }
      return null;
    } finally {
      _isScreenshotInProgress = false;
    }
  }

  /// 检查播放器是否已被释放
  static bool _isPlayerDisposed(Player player) {
    try {
      // 尝试访问播放器状态，如果已释放会抛出异常
      final _ = player.state.playing;
      return false;
    } catch (e) {
      return true;
    }
  }

  /// 保存缩略图
  static Future<String> _saveThumbnail(
    String videoUrl,
    Uint8List imageBytes,
    int width,
    int height,
  ) async {
    // 获取缩略图目录
    final appDir = await getApplicationSupportDirectory();
    final thumbsDir = Directory(path.join(appDir.path, 'thumbnails'));

    if (!await thumbsDir.exists()) {
      await thumbsDir.create(recursive: true);
    }

    // 生成文件名（基于URL的hash）
    final hash = sha256.convert(utf8.encode(videoUrl)).toString();
    final filename = '$hash.jpg';
    final thumbnailPath = path.join(thumbsDir.path, filename);

    // 写入文件
    final file = File(thumbnailPath);
    await file.writeAsBytes(imageBytes);

    final fileSize = await file.length();
    print('💾 缩略图文件大小: $fileSize bytes');

    return thumbnailPath;
  }

  /// 更新历史记录的缩略图
  static Future<void> _updateHistoryThumbnail(
    String videoUrl,
    String thumbnailPath,
  ) async {
    try {
      final histories = await HistoryService.getHistories();

      // 查找匹配的历史记录
      for (final history in histories) {
        if (history.videoPath == videoUrl ||
            (history.sourceType == 'network' && history.streamUrl == videoUrl)) {
          await HistoryService.updateThumbnailPath(history.id, thumbnailPath);
          print('✅ 已更新历史记录缩略图: ${history.videoName}');
          break;
        }
      }
    } catch (e) {
      print('❌ 更新历史记录缩略图失败: $e');
    }
  }

  /// 检查缩略图是否已存在
  static Future<String?> getExistingThumbnail(String videoUrl) async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final thumbsDir = Directory(path.join(appDir.path, 'thumbnails'));

      final hash = sha256.convert(utf8.encode(videoUrl)).toString();
      final filename = '$hash.jpg';
      final thumbnailPath = path.join(thumbsDir.path, filename);

      if (await File(thumbnailPath).exists()) {
        return thumbnailPath;
      }
    } catch (e) {
      print('⚠️ 检查缩略图是否存在时出错: $e');
    }

    return null;
  }

  /// 清理过期的缩略图
  static Future<void> cleanupOldThumbnails() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final thumbsDir = Directory(path.join(appDir.path, 'thumbnails'));

      if (!await thumbsDir.exists()) return;

      // 获取所有历史记录中有效的缩略图
      final histories = await HistoryService.getHistories();
      final validThumbnails = <String>{};

      for (final history in histories) {
        if (history.thumbnailCachePath != null) {
          validThumbnails.add(history.thumbnailCachePath!);
        }
      }

      // 删除孤立的缩略图文件
      final files = thumbsDir.listSync();
      int deletedCount = 0;

      for (final file in files) {
        if (file is File && !validThumbnails.contains(file.path)) {
          try {
            await file.delete();
            deletedCount++;
          } catch (e) {
            print('⚠️ 删除缩略图文件失败: ${file.path}');
          }
        }
      }

      print('🗑️ 清理完成，删除了 $deletedCount 个过期缩略图');
    } catch (e) {
      print('❌ 清理缩略图失败: $e');
    }
  }

  /// 取消所有进行中的缩略图生成操作（增强版）
  static void cancelAllOperations() {
    if (_activeOperations.isNotEmpty) {
      print('🛑 取消 ${_activeOperations.length} 个进行中的缩略图生成操作');

      // 设置全局 disposing 标志，立即阻止新操作
      _isDisposing = true;

      // 取消所有操作
      for (final entry in _activeOperations.entries) {
        if (!entry.value.isCompleted) {
          entry.value.complete();
        }
      }
      _activeOperations.clear();

      // 等待可能正在进行的截图操作完成，然后重置标志
      Future.delayed(Duration(milliseconds: 100), () {
        _isDisposing = false;
        print('✅ 缩略图服务释放完成，重置 disposing 标志');
      });
    }
  }

  /// 获取当前活跃操作的数量
  static int get activeOperationsCount => _activeOperations.length;
}