import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stream_info.dart';

/// 网络流媒体服务
class NetworkStreamService {
  static const String _urlHistoryKey = 'network_url_history';
  static const int _maxHistoryCount = 20;

  static final NetworkStreamService _instance = NetworkStreamService._internal();
  factory NetworkStreamService() => _instance;
  NetworkStreamService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  /// 网络状态流
  Stream<ConnectivityResult> get connectivityStream {
    return _connectivity.onConnectivityChanged;
  }

  /// 当前网络状态
  Future<ConnectivityResult> get currentConnectivity async {
    return await _connectivity.checkConnectivity();
  }

  /// 是否有网络连接
  Future<bool> get isConnected async {
    final result = await currentConnectivity;
    return result != ConnectivityResult.none;
  }

  /// 检查网络连接
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (result == ConnectivityResult.none) {
        return false;
      }

      // 额外检查：尝试连接到 Google 或 Cloudflare DNS
      final testUrls = [
        'https://www.google.com',
        'https://www.cloudflare.com',
      ];

      for (final url in testUrls) {
        try {
          final response = await http.get(
            Uri.parse(url),
          ).timeout(const Duration(seconds: 5));
          if (response.statusCode == 200) {
            return true;
          }
        } catch (e) {
          continue;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// 验证URL格式
  bool isValidUrl(String url) {
    if (url.trim().isEmpty) return false;

    try {
      final uri = Uri.parse(url.trim());
      return (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) ||
             url.trim().endsWith('.m3u8') ||
             url.trim().endsWith('.mpd');
    } catch (e) {
      return false;
    }
  }

  /// 获取流信息
  Future<StreamInfo?> getStreamInfo(String url) async {
    try {
      final protocol = _detectProtocol(url);
      final streamInfo = StreamInfo.fromUrl(url);

      if (protocol == 'http' && !url.endsWith('.m3u8') && !url.endsWith('.mpd')) {
        // 尝试获取HTTP流的基本信息
        final response = await http.head(
          Uri.parse(url),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final contentLength = response.headers['content-length'];
          final contentType = response.headers['content-type'];

          final fileSize = contentLength != null ? int.tryParse(contentLength) : null;
          final mimeType = contentType ?? _guessMimeType(url);

          return streamInfo.copyWith(
            fileSize: fileSize,
            mimeType: mimeType,
          );
        }
      }

      return streamInfo;
    } catch (e) {
      // 即使获取信息失败，也返回基本的StreamInfo
      return StreamInfo.fromUrl(url);
    }
  }

  /// 检测协议类型
  String _detectProtocol(String url) {
    if (url.toLowerCase().contains('.m3u8')) {
      return 'hls';
    } else if (url.toLowerCase().contains('.mpd')) {
      return 'dash';
    } else if (url.toLowerCase().startsWith('http://') ||
               url.toLowerCase().startsWith('https://')) {
      return 'http';
    } else {
      return 'unknown';
    }
  }

  /// 猜测MIME类型
  String _guessMimeType(String url) {
    final extension = url.split('.').last.toLowerCase();
    switch (extension) {
      case 'mp4':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'mkv':
        return 'video/x-matroska';
      case 'avi':
        return 'video/x-msvideo';
      case 'mov':
        return 'video/quicktime';
      case 'flv':
        return 'video/x-flv';
      case 'wmv':
        return 'video/x-ms-wmv';
      case 'm4v':
        return 'video/x-m4v';
      case 'm3u8':
        return 'application/vnd.apple.mpegurl';
      case 'mpd':
        return 'application/dash+xml';
      default:
        return 'video/*';
    }
  }

  /// 添加URL到历史记录
  Future<void> addUrlToHistory(String url) async {
    if (!isValidUrl(url)) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getUrlHistory();

      // 移除重复项
      history.removeWhere((item) => item['url'] == url);

      // 添加到开头
      history.insert(0, {
        'url': url,
        'addedAt': DateTime.now().toIso8601String(),
        'protocol': _detectProtocol(url),
      });

      // 限制历史记录数量
      if (history.length > _maxHistoryCount) {
        history.removeRange(_maxHistoryCount, history.length);
      }

      await prefs.setString(_urlHistoryKey, jsonEncode(history));
    } catch (e) {
      // 忽略错误，历史记录保存失败不应该影响主要功能
    }
  }

  /// 获取URL历史记录
  Future<List<Map<String, dynamic>>> getUrlHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_urlHistoryKey);

      if (historyJson == null) return [];

      final List<dynamic> decoded = jsonDecode(historyJson);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// 清除URL历史记录
  Future<void> clearUrlHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_urlHistoryKey);
    } catch (e) {
      // 忽略错误
    }
  }

  /// 从历史记录中删除特定URL
  Future<void> removeUrlFromHistory(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getUrlHistory();
      history.removeWhere((item) => item['url'] == url);
      await prefs.setString(_urlHistoryKey, jsonEncode(history));
    } catch (e) {
      // 忽略错误
    }
  }

  /// 测试URL是否可访问
  Future<bool> testUrlAccessibility(String url) async {
    try {
      final response = await http.head(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      // HEAD请求失败，尝试GET请求（只获取少量数据）
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {'Range': 'bytes=0-1023'}, // 只请求前1KB
        ).timeout(const Duration(seconds: 15));

        return response.statusCode == 200 || response.statusCode == 206;
      } catch (e) {
        return false;
      }
    }
  }

  /// 获取网络状态描述
  String getConnectivityDescription(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return '移动网络';
      case ConnectivityResult.ethernet:
        return '有线网络';
      case ConnectivityResult.bluetooth:
        return '蓝牙网络';
      case ConnectivityResult.none:
        return '无网络连接';
      case ConnectivityResult.other:
        return '其他网络';
      default:
        return '未知网络';
    }
  }

  /// 开始监听网络状态
  void startConnectivityMonitoring() {
    if (_connectivitySubscription != null) return;

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((_) {
      // 网络状态变化的处理逻辑可以在调用方实现
    });
  }

  /// 停止监听网络状态
  void stopConnectivityMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// 获取URL的域名
  String? getDomainFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return null;
    }
  }

  /// 判断URL是否为HTTPS
  bool isHttpsUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.scheme == 'https';
    } catch (e) {
      return false;
    }
  }

  /// 释放资源
  void dispose() {
    stopConnectivityMonitoring();
  }
}