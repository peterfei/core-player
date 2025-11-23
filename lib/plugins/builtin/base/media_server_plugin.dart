import 'dart:async';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import '../../core/plugin_system/core_plugin.dart';
import '../../core/plugin_system/media_server_plugin.dart';

/// 媒体服务器插件基类
///
/// 为所有媒体服务器插件提供通用功能和默认实现。
abstract class BaseMediaServerPlugin extends MediaServerPlugin {
  ServerConfig? _currentConfig;
  bool _isConnected = false;

  /// 当前连接的服务器配置
  @override
  ServerConfig? get currentConfig => _currentConfig;

  /// 是否已连接
  @override
  bool get isConnected => _isConnected;

  /// 插件支持的文件扩展名
  List<String> get supportedFileExtensions => const [
    '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm',
    '.m4v', '.3gp', '.ogv', '.ts', '.mts', '.m2ts',
  ];

  /// 默认连接超时时间
  Duration get defaultTimeout => const Duration(seconds: 10);

  /// 默认扫描选项
  ScanOptions get defaultScanOptions => const ScanOptions(
    recursive: true,
    includeHidden: false,
    maxResults: 10000,
  );

  @override
  Future<void> onInitialize() async {
    // 子类可以重写以执行特定的初始化逻辑
    await super.onInitialize();
  }

  @override
  Future<void> onActivate() async {
    // 恢复之前的连接（如果有）
    await _restoreConnection();
    await super.onActivate();
  }

  @override
  Future<void> onDeactivate() async {
    // 断开连接但保留配置
    await disconnect();
    await super.onDeactivate();
  }

  @override
  Future<void> onDispose() async {
    await disconnect();
    _currentConfig = null;
    await super.onDispose();
  }

  // ===== 连接管理 =====

  @override
  Future<void> connect(ServerConfig config) async {
    if (_isConnected && _currentConfig?.serverId == config.serverId) {
      return; // 已经连接到相同服务器
    }

    try {
      // 验证配置
      final validationError = validateConfig(config);
      if (validationError != null) {
        throw ArgumentError(validationError);
      }

      // 如果已经连接到其他服务器，先断开
      if (_isConnected) {
        await disconnect();
      }

      // 执行实际连接
      await doConnect(config);

      // 更新状态
      _currentConfig = config;
      _isConnected = true;

      // 保存连接配置
      await _saveConnectionConfig(config);

      print('Connected to server: ${config.name}');
    } catch (e) {
      _isConnected = false;
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    if (!_isConnected) return;

    try {
      await doDisconnect();
      _isConnected = false;
      print('Disconnected from server');
    } catch (e) {
      print('Error disconnecting: $e');
    }
  }

  @override
  Map<String, dynamic> getConnectionInfo() {
    return {
      'connected': _isConnected,
      'serverType': serverType,
      'config': _currentConfig?.toJson(),
      'supportedProtocols': supportedProtocols,
      'connectedAt': _isConnected ? DateTime.now().toIso8601String() : null,
    };
  }

  // ===== 媒体库操作 =====

  @override
  Future<List<VideoItem>> scanVideos({
    MediaFolder? folder,
    ScanOptions? options,
  }) async {
    _ensureConnected();

    final scanOptions = options ?? defaultScanOptions;
    return await doScanVideos(folder, scanOptions);
  }

  @override
  Future<VideoMetadata?> getVideoMetadata(String videoId) async {
    _ensureConnected();
    return await doGetVideoMetadata(videoId);
  }

  @override
  Future<List<VideoItem>> searchVideos(String query, {ScanOptions? options}) async {
    _ensureConnected();

    final scanOptions = options ?? defaultScanOptions;
    return await doSearchVideos(query, scanOptions);
  }

  @override
  Future<void> refreshLibrary({MediaFolder? folder}) async {
    _ensureConnected();
    await doRefreshLibrary(folder);
  }

  // ===== 流媒体 =====

  @override
  Future<VideoStreamInfo> getVideoStream(String videoId, {VideoQuality? quality}) async {
    _ensureConnected();
    return await doGetVideoStream(videoId, quality ?? VideoQuality.auto);
  }

  @override
  Future<String?> getThumbnailUrl(String videoId) async {
    _ensureConnected();
    return await doGetThumbnailUrl(videoId);
  }

  @override
  Future<List<SubtitleTrack>> getSubtitleTracks(String videoId) async {
    _ensureConnected();
    return await doGetSubtitleTracks(videoId);
  }

  @override
  Future<String?> getSubtitleContent(String videoId, String subtitleId) async {
    _ensureConnected();
    return await doGetSubtitleContent(videoId, subtitleId);
  }

  // ===== 配置UI =====

  @override
  String? validateConfig(ServerConfig config) {
    if (config.name.isEmpty) {
      return '服务器名称不能为空';
    }

    return doValidateConfig(config);
  }

  // ===== 抽象方法（子类必须实现） =====

  /// 执行实际的连接操作
  Future<void> doConnect(ServerConfig config);

  /// 执行实际的断开连接操作
  Future<void> doDisconnect();

  /// 执行实际的视频扫描
  Future<List<VideoItem>> doScanVideos(MediaFolder? folder, ScanOptions options);

  /// 获取视频元数据
  Future<VideoMetadata?> doGetVideoMetadata(String videoId);

  /// 搜索视频
  Future<List<VideoItem>> doSearchVideos(String query, ScanOptions options);

  /// 刷新媒体库
  Future<void> doRefreshLibrary(MediaFolder? folder);

  /// 获取视频流
  Future<VideoStreamInfo> doGetVideoStream(String videoId, VideoQuality quality);

  /// 获取缩略图URL
  Future<String?> doGetThumbnailUrl(String videoId);

  /// 获取字幕轨道
  Future<List<SubtitleTrack>> doGetSubtitleTracks(String videoId);

  /// 获取字幕内容
  Future<String?> doGetSubtitleContent(String videoId, String subtitleId);

  /// 验证服务器配置
  String? doValidateConfig(ServerConfig config);

  // ===== 受保护的辅助方法 =====

  /// 确保已连接
  @protected
  void _ensureConnected() {
    if (!_isConnected || _currentConfig == null) {
      throw StateError('Not connected to any media server');
    }
  }

  /// 保存连接配置
  @protected
  Future<void> _saveConnectionConfig(ServerConfig config) async {
    await setConfig('last_connection', config.serverId);
    await setConfig('last_connection_data', _encodeConfig(config));
  }

  /// 恢复连接
  @protected
  Future<void> _restoreConnection() async {
    try {
      final lastConnectionId = getConfig('last_connection');
      final lastConnectionData = getConfig('last_connection_data');

      if (lastConnectionId != null && lastConnectionData != null) {
        final config = _decodeConfig(lastConnectionData);
        await connect(config);
      }
    } catch (e) {
      print('Warning: Failed to restore connection: $e');
    }
  }

  /// 编码配置
  @protected
  String _encodeConfig(ServerConfig config) {
    // 使用简单的JSON编码
    return config.toString();
  }

  /// 解码配置
  @protected
  ServerConfig _decodeConfig(String data) {
    // 子类需要实现具体的解码逻辑
    throw UnimplementedError('Subclass must implement _decodeConfig');
  }

  /// 创建默认的视频元数据
  @protected
  VideoMetadata createDefaultMetadata(VideoItem videoItem) {
    return VideoMetadata(
      id: videoItem.id,
      title: videoItem.title,
    );
  }

  /// 根据文件扩展名判断是否为视频文件
  @protected
  bool isVideoFile(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    return supportedFileExtensions.contains('.$extension');
  }

  /// 格式化文件大小
  @protected
  String formatFileSize(int? bytes) {
    if (bytes == null) return 'Unknown';

    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = bytes.toDouble();
    int unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  /// 从文件路径提取文件名
  @protected
  String extractFileName(String path) {
    return path.split('/').last;
  }

  /// 从文件路径提取目录
  @protected
  String extractDirectory(String path) {
    final parts = path.split('/');
    parts.removeLast();
    return parts.join('/');
  }

  /// 创建唯一的视频ID
  @protected
  String createVideoId(String path, {String? prefix}) {
    final baseId = path.hashCode.toString();
    return prefix != null ? '${prefix}_$baseId' : baseId;
  }

  /// 创建唯一的文件夹ID
  @protected
  String createFolderId(String path, {String? prefix}) {
    final baseId = path.hashCode.toString();
    return prefix != null ? '${prefix}_$baseId' : baseId;
  }

  /// 执行HTTP请求（带超时和重试）
  @protected
  Future<Map<String, dynamic>> executeHttpRequest(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
    int maxRetries = 3,
  }) async {
    final requestTimeout = timeout ?? defaultTimeout;
    int retryCount = 0;

    while (retryCount <= maxRetries) {
      try {
        // 这里应该使用 http 包，暂时返回空Map
        // 实际实现需要根据具体的HTTP客户端来实现

        // 模拟HTTP请求延迟
        await Future.delayed(Duration(milliseconds: 100));

        return {};
      } catch (e) {
        retryCount++;
        if (retryCount > maxRetries) {
          rethrow;
        }

        // 等待一段时间后重试
        await Future.delayed(Duration(seconds: retryCount));
      }
    }

    throw TimeoutException('HTTP request failed after $maxRetries retries', requestTimeout);
  }

  /// 处理网络错误
  @protected
  ConnectionTestResult handleNetworkError(dynamic error, [String? context]) {
    if (error is TimeoutException) {
      return ConnectionTestResult.timeout(
        message: context != null
          ? '$context timeout'
          : 'Connection timeout',
        suggestion: 'Please check your network connection and try again',
      );
    } else if (error is SocketException) {
      return ConnectionTestResult.networkError(
        message: context != null
          ? '$context network error: ${error.message}'
          : 'Network error: ${error.message}',
        suggestion: 'Please verify the server address is correct',
      );
    } else {
      return ConnectionTestResult.unknownError(
        message: context != null
          ? '$context unknown error: $error'
          : 'Unknown error: $error',
      );
    }
  }

  /// 记录插件日志
  @protected
  void log(String message) {
    print('[$serverType Plugin] $message');
  }

  /// 记录插件错误
  @protected
  void logError(String message, [dynamic error]) {
    print('[$serverType Plugin] ERROR: $message');
    if (error != null) {
      print('  Caused by: $error');
    }
  }
}