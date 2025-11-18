import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
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

  Stream<List<int>> downloadAndCache(String url, {String? title}) async* {
    // 检查是否已有缓存
    final cacheService = VideoCacheService.instance;
    final cachePath = await cacheService.getCachePath(url);

    if (cachePath != null) {
      // 已有完整缓存，直接读取本地文件
      final file = File(cachePath);
      final bytes = await file.readAsBytes();
      yield bytes;
      return;
    }

    // 检查是否已有部分缓存
    final partialEntry = await cacheService.getCacheEntry(url);
    final resumeFromByte = partialEntry?.downloadedBytes ?? 0;

    // 创建或获取缓存文件路径
    final filePath = partialEntry?.localPath ??
        await cacheService.createCacheFile(url, title: title);

    // 如果已在下载中，等待其完成
    if (_activeDownloads.containsKey(url)) {
      final task = _activeDownloads[url]!;
      yield* _streamFromFileWithProgress(filePath, task);
      return;
    }

    // 开始新的下载任务
    final task = DownloadTask(
      url: url,
      filePath: filePath,
      completer: Completer<void>(),
      progressController: StreamController<DownloadProgress>.broadcast(),
    );

    _activeDownloads[url] = task;
    task.downloadedBytes = resumeFromByte;

    try {
      // 并行下载和流式读取
      final downloadFuture = _downloadFile(url, filePath, resumeFromByte, task);

      yield* _streamFromFileWithProgress(filePath, task);

      await downloadFuture;
    } finally {
      _activeDownloads.remove(url);
      await task.progressController.close();
    }
  }

  Stream<List<int>> _streamFromFileWithProgress(
      String filePath, DownloadTask task) async* {
    final file = File(filePath);
    int lastReportedSize = 0;

    while (!task.completer.isCompleted && !task.isCancelled) {
      try {
        if (await file.exists()) {
          final currentSize = await file.length();

          // 只有当文件大小有变化时才读取新数据
          if (currentSize > lastReportedSize) {
            final bytes = await file.readAsBytes();
            yield bytes.sublist(lastReportedSize, currentSize);
            lastReportedSize = currentSize;
          }

          // 更新进度
          final progress = DownloadProgress(
            url: task.url,
            downloadedBytes: currentSize,
            totalBytes: 0, // 未知总大小
            speed: 0, // 速度计算需要在下载器中完成
            timestamp: DateTime.now(),
          );

          task.progressController.add(progress);
          _globalProgressController.add(progress);
        }

        await Future.delayed(Duration(milliseconds: 100));
      } catch (e) {
        break;
      }
    }

    // 最终完整读取
    if (await file.exists() && task.completer.isCompleted) {
      final bytes = await file.readAsBytes();
      yield bytes.sublist(lastReportedSize);
    }
  }

  Future<void> _downloadFile(
    String url,
    String filePath,
    int resumeFromByte,
    DownloadTask task,
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

        final request = http.Request('GET', Uri.parse(url));
        if (resumeFromByte > 0) {
          request.headers.addAll({'Range': 'bytes=$resumeFromByte-'});
        }

        final client = http.Client();
        final streamedResponse = await client.send(request);

        if (streamedResponse.statusCode != 206 && resumeFromByte > 0) {
          // 服务器不支持范围请求，重新开始
          await randomAccessFile.setPosition(0);
          final newRequest = http.Request('GET', Uri.parse(url));
          final newResponse = await client.send(newRequest);
          if (newResponse.statusCode != 200) {
            throw Exception(
                'HTTP ${newResponse.statusCode}: Failed to download');
          }
          await _processStreamedResponse(
              newResponse, randomAccessFile, task, url, 0);
        } else if (streamedResponse.statusCode != 200 && resumeFromByte == 0) {
          throw Exception(
              'HTTP ${streamedResponse.statusCode}: Failed to download');
        } else {
          await _processStreamedResponse(
              streamedResponse, randomAccessFile, task, url, resumeFromByte);
        }

        client.close();
        task.completer.complete();
      } finally {
        await randomAccessFile.close();
      }

      // 获取文件大小并标记缓存完成
      final fileSize = await file.length();
      await cacheService.markCacheComplete(url, fileSize);
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
    http.StreamedResponse response,
    RandomAccessFile randomAccessFile,
    DownloadTask task,
    String url,
    int initialBytes,
  ) async {
    final contentLength = response.contentLength ?? 0;
    final startTime = DateTime.now();
    int lastProgressTime = startTime.millisecondsSinceEpoch;

    await for (final chunk in response.stream) {
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
        final speed =
            elapsedTime > 0 ? task.downloadedBytes / elapsedTime : 0.0;

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
          url,
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
