import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/cache_config.dart';
import '../models/cache_entry.dart';
import 'video_cache_service.dart';

class DownloadTask {
  final String url;
  final String filePath;
  final Completer<void> completer;
  final StreamController<DownloadProgress> progressController;
  bool isCancelled = false;
  int downloadedBytes = 0;
  int totalBytes = 0;

  DownloadTask({
    required this.url,
    required this.filePath,
    required this.completer,
    required this.progressController,
  });
}

class CacheDownloadService {
  static CacheDownloadService? _instance;
  static CacheDownloadService get instance {
    _instance ??= CacheDownloadService._();
    return _instance!;
  }

  CacheDownloadService._();

  final Map<String, DownloadTask> _activeDownloads = {};
  final StreamController<DownloadProgress> _globalProgressController =
      StreamController<DownloadProgress>.broadcast();

  Stream<DownloadProgress> get globalProgressStream =>
      _globalProgressController.stream;

  Stream<List<int>> downloadAndCache(String url, {String? title, String? cacheKey}) async* {
    final key = cacheKey ?? url;
    // 检查是否已有缓存
    final cacheService = VideoCacheService.instance;
    final cachePath = await cacheService.getCachePath(key);

    if (cachePath != null) {
      // 已有完整缓存，直接读取本地文件
      final file = File(cachePath);
      final bytes = await file.readAsBytes();
      yield bytes;
      return;
    }

    // 检查是否已有部分缓存
    final partialEntry = await cacheService.getCacheEntry(key);
    final resumeFromByte = partialEntry?.downloadedBytes ?? 0;

    // 创建或获取缓存文件路径
    final filePath = partialEntry?.localPath ??
        await cacheService.createCacheFile(key, title: title);

    // 如果已在下载中，等待其完成
    if (_activeDownloads.containsKey(key)) {
      final task = _activeDownloads[key]!;
      yield* _streamFromFileWithProgress(filePath, task);
      return;
    }

    // 开始新的下载任务
    final task = DownloadTask(
      url: url, // Download URL
      filePath: filePath,
      completer: Completer<void>(),
      progressController: StreamController<DownloadProgress>.broadcast(),
    );

    _activeDownloads[key] = task;
    task.downloadedBytes = resumeFromByte;

    try {
      // 并行下载和流式读取
      final downloadFuture = _downloadFile(url, filePath, resumeFromByte, task, key);

      yield* _streamFromFileWithProgress(filePath, task);

      await downloadFuture;
    } finally {
      _activeDownloads.remove(key);
      await task.progressController.close();
    }
  }

  Stream<List<int>> _streamFromFileWithProgress(
      String filePath, DownloadTask task) async* {
    final file = File(filePath);
    int offset = 0;
    RandomAccessFile? raf;

    try {
      while (!task.completer.isCompleted && !task.isCancelled) {
        if (await file.exists()) {
          if (raf == null) {
            raf = await file.open(mode: FileMode.read);
          }

          final length = await raf.length();
          if (length > offset) {
            await raf.setPosition(offset);
            // Read in chunks to avoid memory spikes if a large chunk was written
            const chunkSize = 64 * 1024; // 64KB chunks
            while (offset < length) {
              final readSize = (length - offset) > chunkSize
                  ? chunkSize
                  : (length - offset);
              final bytes = await raf.read(readSize);
              if (bytes.isEmpty) break;
              
              yield bytes;
              offset += bytes.length;
            }
          }

          // Update progress for the task listener (e.g. player)
          // Note: We do NOT emit to global controller here to avoid conflict with downloader
          final progress = DownloadProgress(
            url: task.url,
            downloadedBytes: offset,
            totalBytes: task.totalBytes,
            speed: 0, // Playback stream doesn't calculate download speed
            timestamp: DateTime.now(),
          );
          task.progressController.add(progress);
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Final check to ensure we read everything
      if (await file.exists() && task.completer.isCompleted) {
        if (raf == null) {
          raf = await file.open(mode: FileMode.read);
        }
        final length = await raf.length();
        if (length > offset) {
          await raf.setPosition(offset);
          while (offset < length) {
             // Read remaining data
             final bytes = await raf.read(length - offset); // Should be small now
             if (bytes.isEmpty) break;
             yield bytes;
             offset += bytes.length;
          }
        }
      }
    } catch (e) {
      print('Error streaming file: $e');
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
  }

  Future<void> _downloadFile(
    String url,
    String filePath,
    int resumeFromByte,
    DownloadTask task,
    String cacheKey,
  ) async {
    try {
      final cacheService = VideoCacheService.instance;
      final config = cacheService.config;

      // 检查网络连接
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.mobile && !config.allowCellular) {
        throw Exception('Cellular downloads are disabled');
      }

      final file = File(filePath);
      final randomAccessFile = await file.open(mode: FileMode.write);

      try {
        // 如果是续传，定位到指定位置
        if (resumeFromByte > 0) {
          await randomAccessFile.setPosition(resumeFromByte);
        }

        // 尝试下载，带重试机制
        int retryCount = 0;
        const maxRetries = 3;
        
        while (true) {
          HttpClient? httpClient;
          try {
            // 使用 HttpClient 直接控制代理设置
            httpClient = HttpClient();
            // 强制绕过系统代理，直接连接
            // 这对于连接本地代理服务器 (127.0.0.1 或 192.168.x.x) 至关重要
            // 避免被 Privoxy 或其他 VPN 代理拦截导致 500 错误
            httpClient.findProxy = (uri) => 'DIRECT';
            
            final request = await httpClient.getUrl(Uri.parse(url));
            
            if (resumeFromByte > 0) {
              request.headers.add('Range', 'bytes=$resumeFromByte-');
            }

            final response = await request.close();

            if (response.statusCode == 200 || response.statusCode == 206) {
               // 如果是新下载且有Content-Length，更新缓存条目的文件大小
              if (resumeFromByte == 0 && response.contentLength > 0) {
                 await VideoCacheService.instance.updateCacheFileSize(cacheKey, response.contentLength);
              }

              await _processStreamedResponse(
                  response, randomAccessFile, task, cacheKey, resumeFromByte);
              
              break; // 下载成功，退出重试循环
            } else {
              // 读取错误响应体
              // HttpClientResponse 也是 Stream<List<int>>
              final body = await response.transform(SystemEncoding().decoder).join();
              print('❌ Download failed: HTTP ${response.statusCode}');
              print('   Response body: $body');
              
              if (response.statusCode == 416) {
                 print('⚠️ Range not satisfiable, checking file size...');
                 throw Exception('HTTP 416: Range not satisfiable');
              }
              
              if (retryCount < maxRetries) {
                retryCount++;
                print('⚠️ Download failed, retrying ($retryCount/$maxRetries) in 2s...');
                await Future.delayed(const Duration(seconds: 2));
                continue;
              }
              
              throw Exception(
                  'HTTP ${response.statusCode}: Failed to download. Body: $body');
            }
          } catch (e) {
            if (e.toString().contains('HTTP 416')) rethrow;
            
            if (retryCount < maxRetries) {
              retryCount++;
              print('⚠️ Download exception: $e');
              print('   Retrying ($retryCount/$maxRetries) in 2s...');
              await Future.delayed(const Duration(seconds: 2));
              continue;
            }
            rethrow;
          } finally {
            httpClient?.close();
          }
        }
        
        task.completer.complete();
      } finally {
        await randomAccessFile.close();
      }

      // 获取文件大小并标记缓存完成
      final fileSize = await file.length();
      await cacheService.markCacheComplete(cacheKey, fileSize);
    } catch (e) {
      task.completer.completeError(e);

      // 发送错误进度
      final errorProgress = DownloadProgress(
        url: task.url,
        downloadedBytes: task.downloadedBytes,
        totalBytes: 0,
        speed: 0,
        timestamp: DateTime.now(),
        error: e.toString(),
      );

      task.progressController.add(errorProgress);
      _globalProgressController.add(errorProgress);
    }
  }

  Future<void> _processStreamedResponse(
    HttpClientResponse response,
    RandomAccessFile randomAccessFile,
    DownloadTask task,
    String cacheKey,
    int initialBytes,
  ) async {
    // 尝试获取总大小：优先使用响应头，如果未知则尝试从缓存条目获取
    int totalBytes = response.contentLength;
    if (totalBytes > 0) {
      task.totalBytes = totalBytes; // Update task's totalBytes
    }
    if (totalBytes <= 0) {
      final entry = await VideoCacheService.instance.getCacheEntry(cacheKey);
      totalBytes = entry?.fileSize ?? 0;
      if (totalBytes > 0) {
        task.totalBytes = totalBytes; // Update task's totalBytes if from cache
      }
    }
    
    final contentLength = totalBytes; // This is the final determined total size for progress calculation
    final startTime = DateTime.now();
    int lastProgressTime = startTime.millisecondsSinceEpoch;

    // HttpClientResponse 本身就是 Stream<List<int>>
    await for (final chunk in response) {
      if (task.isCancelled) {
        throw Exception('Download cancelled');
      }

      await randomAccessFile.writeFrom(chunk);
      task.downloadedBytes += chunk.length;

      final currentTime = DateTime.now().millisecondsSinceEpoch;

      // 每500ms更新一次进度
      if (currentTime - lastProgressTime >= 500) {
        final elapsedTime =
            (currentTime - startTime.millisecondsSinceEpoch) / 1000;
        final downloadedSinceStart = task.downloadedBytes - initialBytes;
        final speed =
            elapsedTime > 0 ? downloadedSinceStart / elapsedTime : 0.0;

        final progress = DownloadProgress(
          url: task.url,
          downloadedBytes: task.downloadedBytes,
          totalBytes: contentLength,
          speed: speed.toDouble(),
          timestamp: DateTime.now(),
        );

        task.progressController.add(progress);
        _globalProgressController.add(progress);

        // 更新缓存服务中的进度
        await VideoCacheService.instance.updateCacheProgress(
          cacheKey,
          task.downloadedBytes,
          totalBytes: contentLength,
        );

        lastProgressTime = currentTime;
      }
    }
  }

  Stream<DownloadProgress> getDownloadProgress(String url) {
    final task = _activeDownloads[url];
    if (task != null) {
      return task.progressController.stream;
    }

    // 如果没有正在下载，返回空流
    return Stream.empty();
  }

  Future<void> cancelDownload(String url) async {
    final task = _activeDownloads[url];
    if (task != null) {
      task.isCancelled = true;
      task.completer.completeError(Exception('Download cancelled'));
      _activeDownloads.remove(url);
    }
  }

  Future<void> pauseDownload(String url) async {
    // 暂停下载实际上就是取消，因为HTTP下载难以真正暂停
    await cancelDownload(url);
  }

  Future<void> resumeDownload(String url) async {
    // 重新开始下载会自动从断点继续
    final cacheService = VideoCacheService.instance;
    final cacheEntry = await cacheService.getCacheEntry(url);

    if (cacheEntry != null && !cacheEntry.isComplete) {
      // 通过重新调用下载方法来恢复
      downloadAndCache(url, title: cacheEntry.title);
    }
  }

  List<String> getActiveDownloads() {
    return _activeDownloads.keys.toList();
  }

  bool isDownloading(String url) {
    return _activeDownloads.containsKey(url);
  }

  Future<void> dispose() async {
    // 取消所有正在下载的任务
    for (final task in _activeDownloads.values) {
      task.isCancelled = true;
      task.completer.completeError(Exception('Service disposed'));
    }
    _activeDownloads.clear();

    await _globalProgressController.close();
  }
}
