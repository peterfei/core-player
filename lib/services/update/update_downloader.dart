import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../models/update/update_models.dart';

/// 下载任务
class _DownloadTask {
  final String pluginId;
  final String url;
  final String savePath;
  final StreamController<DownloadProgress> progressController;
  CancelToken? cancelToken;
  
  _DownloadTask({
    required this.pluginId,
    required this.url,
    required this.savePath,
  }) : progressController = StreamController<DownloadProgress>.broadcast();
  
  void dispose() {
    progressController.close();
  }
}

/// 更新下载器
/// 
/// 负责下载插件更新包,支持断点续传
class UpdateDownloader {
  /// 单例实例
  static final UpdateDownloader _instance = UpdateDownloader._internal();
  factory UpdateDownloader() => _instance;
  UpdateDownloader._internal();

  /// Dio实例
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 10),
    sendTimeout: const Duration(minutes: 5),
  ));

  /// 下载目录
  Directory? _downloadDir;

  /// 活跃的下载任务
  final Map<String, _DownloadTask> _activeTasks = {};

  /// 下载队列
  final List<String> _downloadQueue = [];

  /// 最大并发下载数
  int _maxConcurrentDownloads = 3;

  /// 初始化
  Future<void> initialize() async {
    if (_downloadDir != null) return;
    
    final appDir = await getApplicationDocumentsDirectory();
    _downloadDir = Directory(path.join(appDir.path, 'plugin_updates'));
    
    if (!await _downloadDir!.exists()) {
      await _downloadDir!.create(recursive: true);
    }
    
    print('📁 下载目录: ${_downloadDir!.path}');
  }

  /// 设置最大并发下载数
  void setMaxConcurrentDownloads(int max) {
    _maxConcurrentDownloads = max;
    print('⚙️ 最大并发下载数设置为: $max');
  }

  /// 下载更新
  /// 
  /// [updateInfo] 更新信息
  /// [onProgress] 进度回调
  Future<String> downloadUpdate({
    required UpdateInfo updateInfo,
    void Function(DownloadProgress)? onProgress,
  }) async {
    await initialize();
    
    final pluginId = updateInfo.pluginId;
    
    // 检查是否已在下载
    if (_activeTasks.containsKey(pluginId)) {
      print('⚠️ 插件已在下载队列中: $pluginId');
      return _activeTasks[pluginId]!.savePath;
    }
    
    // 生成保存路径
    final fileName = '${pluginId}_${updateInfo.latestVersion}.zip';
    final savePath = path.join(_downloadDir!.path, fileName);
    
    // 创建下载任务
    final task = _DownloadTask(
      pluginId: pluginId,
      url: updateInfo.downloadUrl,
      savePath: savePath,
    );
    
    _activeTasks[pluginId] = task;
    
    // 监听进度
    if (onProgress != null) {
      task.progressController.stream.listen(onProgress);
    }
    
    try {
      // 检查是否需要排队
      if (_activeTasks.length > _maxConcurrentDownloads) {
        print('⏳ 下载队列已满,加入等待队列: $pluginId');
        _downloadQueue.add(pluginId);
        
        // 等待轮到自己
        await _waitForTurn(pluginId);
      }
      
      print('📥 开始下载: $pluginId');
      print('   URL: ${updateInfo.downloadUrl}');
      print('   保存路径: $savePath');
      
      // 执行下载
      await _performDownload(task, updateInfo);
      
      // 验证签名
      if (updateInfo.signature != null) {
        print('🔐 验证文件签名...');
        final isValid = await _verifySignature(savePath, updateInfo.signature!);
        if (!isValid) {
          throw Exception('文件签名验证失败');
        }
        print('✅ 签名验证通过');
      }
      
      print('✅ 下载完成: $pluginId');
      
      return savePath;
    } catch (e) {
      print('❌ 下载失败: $e');
      
      // 发送错误进度
      task.progressController.add(DownloadProgress(
        pluginId: pluginId,
        downloadedBytes: 0,
        totalBytes: updateInfo.packageSize,
        status: DownloadStatus.failed,
        error: e.toString(),
      ));
      
      rethrow;
    } finally {
      // 清理任务
      _activeTasks.remove(pluginId);
      task.dispose();
      
      // 处理下一个排队的任务
      _processNextInQueue();
    }
  }

  /// 暂停下载
  Future<void> pauseDownload(String pluginId) async {
    final task = _activeTasks[pluginId];
    if (task == null) {
      print('⚠️ 未找到下载任务: $pluginId');
      return;
    }
    
    task.cancelToken?.cancel('用户暂停');
    print('⏸️ 已暂停下载: $pluginId');
    
    // 发送暂停状态
    task.progressController.add(DownloadProgress(
      pluginId: pluginId,
      downloadedBytes: 0,
      totalBytes: 0,
      status: DownloadStatus.paused,
    ));
  }

  /// 恢复下载
  Future<String> resumeDownload(String pluginId, UpdateInfo updateInfo) async {
    print('▶️ 恢复下载: $pluginId');
    return downloadUpdate(updateInfo: updateInfo);
  }

  /// 取消下载
  Future<void> cancelDownload(String pluginId) async {
    final task = _activeTasks[pluginId];
    if (task == null) {
      print('⚠️ 未找到下载任务: $pluginId');
      return;
    }
    
    task.cancelToken?.cancel('用户取消');
    print('❌ 已取消下载: $pluginId');
    
    // 删除部分下载的文件
    final file = File(task.savePath);
    if (await file.exists()) {
      await file.delete();
    }
    
    // 发送取消状态
    task.progressController.add(DownloadProgress(
      pluginId: pluginId,
      downloadedBytes: 0,
      totalBytes: 0,
      status: DownloadStatus.cancelled,
    ));
    
    _activeTasks.remove(pluginId);
    task.dispose();
  }

  /// 获取下载进度流
  Stream<DownloadProgress>? getProgressStream(String pluginId) {
    return _activeTasks[pluginId]?.progressController.stream;
  }

  /// 清理下载目录
  Future<void> cleanupDownloads() async {
    await initialize();
    
    if (await _downloadDir!.exists()) {
      await _downloadDir!.delete(recursive: true);
      await _downloadDir!.create();
    }
    
    print('🧹 下载目录已清理');
  }

  // ==================== 私有方法 ====================

  /// 执行下载
  Future<void> _performDownload(_DownloadTask task, UpdateInfo updateInfo) async {
    final file = File(task.savePath);
    int downloadedBytes = 0;
    
    // 检查是否支持断点续传
    if (await file.exists()) {
      downloadedBytes = await file.length();
      print('📦 发现部分下载文件,已下载: ${downloadedBytes} bytes');
    }
    
    task.cancelToken = CancelToken();
    final startTime = DateTime.now();
    
    try {
      await _dio.download(
        task.url,
        task.savePath,
        cancelToken: task.cancelToken,
        options: Options(
          headers: downloadedBytes > 0
              ? {'Range': 'bytes=$downloadedBytes-'}
              : null,
        ),
        onReceiveProgress: (received, total) {
          final currentBytes = downloadedBytes + received;
          final totalBytes = total > 0 ? total : updateInfo.packageSize;
          
          // 计算下载速度
          final elapsed = DateTime.now().difference(startTime).inSeconds;
          final speed = elapsed > 0 ? currentBytes / elapsed : 0.0;
          
          // 发送进度
          final progress = DownloadProgress(
            pluginId: task.pluginId,
            downloadedBytes: currentBytes,
            totalBytes: totalBytes,
            status: DownloadStatus.downloading,
            speed: speed,
            startTime: startTime,
          );
          
          task.progressController.add(progress);
        },
      );
      
      // 发送完成状态
      task.progressController.add(DownloadProgress(
        pluginId: task.pluginId,
        downloadedBytes: updateInfo.packageSize,
        totalBytes: updateInfo.packageSize,
        status: DownloadStatus.completed,
        startTime: startTime,
        completedTime: DateTime.now(),
      ));
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        print('⏸️ 下载被取消');
      } else {
        print('❌ 下载错误: ${e.message}');
        rethrow;
      }
    }
  }

  /// 验证文件签名
  Future<bool> _verifySignature(String filePath, String expectedSignature) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      final actualSignature = digest.toString();
      
      return actualSignature == expectedSignature;
    } catch (e) {
      print('❌ 签名验证失败: $e');
      return false;
    }
  }

  /// 等待轮到自己
  Future<void> _waitForTurn(String pluginId) async {
    while (_downloadQueue.contains(pluginId) && 
           _downloadQueue.first != pluginId) {
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  /// 处理下一个排队的任务
  void _processNextInQueue() {
    if (_downloadQueue.isNotEmpty) {
      _downloadQueue.removeAt(0);
    }
  }
}
