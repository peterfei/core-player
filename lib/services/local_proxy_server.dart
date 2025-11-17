import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'video_cache_service.dart';
import 'cache_download_service.dart';

class LocalProxyServer {
  static LocalProxyServer? _instance;
  static LocalProxyServer get instance {
    _instance ??= LocalProxyServer._();
    return _instance!;
  }

  LocalProxyServer._();

  HttpServer? _server;
  int _port = 8080;
  bool _isRunning = false;
  final Map<String, String> _urlToProxyUrl = {};

  Future<void> start({int port = 8080}) async {
    if (_isRunning) return;

    _port = port;

    try {
      final router = Router();

      // 处理所有请求
      router.all('/<.*>', _handleRequest);

      // 创建CORS处理器
      final handler = const Pipeline()
          .addMiddleware(corsHeaders())
          .addMiddleware(logRequests())
          .addHandler(router);

      // 启动服务器（带超时）
      _server = await shelf_io.serve(
        handler,
        InternetAddress.loopbackIPv4,
        _port,
      ).timeout(Duration(seconds: 5));

      _isRunning = true;
      print('Local proxy server started on http://localhost:$_port');
    } catch (e) {
      print('Failed to start local proxy server: $e');
      // 代理服务器启动失败不应该阻塞应用
      _isRunning = false;
      _server = null;
    }
  }

  Future<void> stop() async {
    if (!_isRunning || _server == null) return;

    try {
      await _server!.close();
      _server = null;
      _isRunning = false;
      _urlToProxyUrl.clear();
      print('Local proxy server stopped');
    } catch (e) {
      print('Failed to stop local proxy server: $e');
    }
  }

  bool get isRunning => _isRunning;
  int get port => _port;

  String getProxyUrl(String originalUrl) {
    // 生成代理URL
    final encodedUrl = Uri.encodeComponent(originalUrl);
    final proxyUrl = 'http://localhost:$_port/video/$encodedUrl';

    _urlToProxyUrl[originalUrl] = proxyUrl;
    return proxyUrl;
  }

  String? getOriginalUrl(String proxyUrl) {
    for (final entry in _urlToProxyUrl.entries) {
      if (entry.value == proxyUrl) {
        return entry.key;
      }
    }

    // 如果在映射中找不到，尝试从URL解析
    if (proxyUrl.contains('/video/')) {
      final encodedUrl = proxyUrl.split('/video/').last;
      try {
        return Uri.decodeComponent(encodedUrl);
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  Future<Response> _handleRequest(Request request) async {
    final path = request.requestedUri.path;

    if (path.startsWith('/video/')) {
      return _handleVideoRequest(request);
    }

    // 健康检查端点
    if (path == '/health') {
      return Response.ok('OK');
    }

    // 缓存状态端点
    if (path == '/cache/status') {
      return _handleCacheStatusRequest();
    }

    return Response.notFound('Not Found');
  }

  Future<Response> _handleVideoRequest(Request request) async {
    try {
      final encodedUrl = request.requestedUri.pathSegments.last;
      final originalUrl = Uri.decodeComponent(encodedUrl);

      if (originalUrl.isEmpty) {
        return Response.badRequest(body: 'Invalid video URL');
      }

      final cacheService = VideoCacheService.instance;

      // 检查是否有本地缓存
      final cachePath = await cacheService.getCachePath(originalUrl);

      if (cachePath != null) {
        // 从本地缓存提供文件
        final file = File(cachePath);

        if (!await file.exists()) {
          return Response.notFound('Cached file not found');
        }

        final fileSize = await file.length();
        final rangeHeader = request.headers['range'];

        // 支持范围请求（用于seek功能）
        if (rangeHeader != null) {
          return _handleRangeRequest(file, rangeHeader, fileSize);
        }

        // 返回完整文件
        final fileStream = file.openRead();

        return Response.ok(
          fileStream,
          headers: {
            'content-type': 'video/mp4',
            'content-length': fileSize.toString(),
            'accept-ranges': 'bytes',
            'cache-control': 'public, max-age=3600',
          },
        );
      } else {
        // 没有缓存，从远程下载并缓存
        return await _handleRemoteDownloadWithCache(request, originalUrl);
      }
    } catch (e) {
      print('Error handling video request: $e');
      return Response.internalServerError(body: 'Internal server error');
    }
  }

  Future<Response> _handleRemoteDownloadWithCache(Request request, String originalUrl) async {
    try {
      final cacheService = VideoCacheService.instance;
      final config = cacheService.config;

      // 如果缓存被禁用，直接代理请求
      if (!config.isEnabled) {
        return await _proxyRequest(request, originalUrl);
      }

      // 开始下载并缓存
      final downloadService = CacheDownloadService.instance;
      final streamController = StreamController<List<int>>();

      // 在后台启动下载
      downloadService.downloadAndCache(originalUrl).listen(
        (chunk) {
          streamController.add(chunk);
        },
        onError: (error) {
          streamController.addError(error);
          streamController.close();
        },
        onDone: () {
          streamController.close();
        },
      );

      // 返回流式响应
      return Response.ok(
        streamController.stream,
        headers: {
          'content-type': 'video/mp4',
          'cache-control': 'no-cache',
          'transfer-encoding': 'chunked',
        },
      );
    } catch (e) {
      print('Error handling remote download: $e');
      return Response.internalServerError(body: 'Download error');
    }
  }

  Future<Response> _proxyRequest(Request request, String originalUrl) async {
    try {
      final uri = Uri.parse(originalUrl);

      // 创建HTTP请求
      final client = HttpClient();

      final proxyRequest = await client.getUrl(uri);

      // 复制请求头（除了一些特定的头）
      for (final entry in request.headers.entries) {
        if (!_shouldSkipHeader(entry.key)) {
          proxyRequest.headers.set(entry.key, entry.value);
        }
      }

      // 发送请求
      final proxyResponse = await proxyRequest.close();

      // 创建响应
      final headers = <String, String>{};

      // 复制响应头
      proxyResponse.headers.forEach((name, values) {
        if (!_shouldSkipHeader(name)) {
          headers[name] = values.join(', ');
        }
      });

      return Response(
        proxyResponse.statusCode,
        body: proxyResponse,
        headers: headers,
      );
    } catch (e) {
      print('Error proxying request: $e');
      return Response.internalServerError(body: 'Proxy error');
    }
  }

  Future<Response> _handleRangeRequest(File file, String rangeHeader, int fileSize) async {
    try {
      // 解析范围头
      final ranges = _parseRangeHeader(rangeHeader, fileSize);

      if (ranges.isEmpty) {
        return Response.badRequest(body: 'Invalid range header');
      }

      final range = ranges.first;
      final start = range['start'] as int;
      final end = range['end'] as int;
      final contentLength = end - start + 1;

      // 读取指定范围的数据
      final randomAccessFile = await file.open();
      await randomAccessFile.setPosition(start);
      final data = await randomAccessFile.read(contentLength);
      await randomAccessFile.close();

      return Response(
        206, // Partial Content
        body: data,
        headers: {
          'content-type': 'video/mp4',
          'content-length': contentLength.toString(),
          'content-range': 'bytes $start-$end/$fileSize',
          'accept-ranges': 'bytes',
          'cache-control': 'public, max-age=3600',
        },
      );
    } catch (e) {
      print('Error handling range request: $e');
      return Response.internalServerError(body: 'Range request error');
    }
  }

  List<Map<String, int>> _parseRangeHeader(String rangeHeader, int fileSize) {
    final ranges = <Map<String, int>>[];

    try {
      // 解析 "bytes=start-end" 格式
      final rangePart = rangeHeader.substring(6); // 移除 "bytes="
      final rangeValues = rangePart.split('-');

      if (rangeValues.length == 2) {
        final startStr = rangeValues[0].trim();
        final endStr = rangeValues[1].trim();

        int start = startStr.isEmpty ? 0 : int.parse(startStr);
        int end = endStr.isEmpty ? fileSize - 1 : int.parse(endStr);

        // 确保范围有效
        start = start.clamp(0, fileSize - 1);
        end = end.clamp(start, fileSize - 1);

        ranges.add({'start': start, 'end': end});
      }
    } catch (e) {
      print('Error parsing range header: $e');
    }

    return ranges;
  }

  bool _shouldSkipHeader(String headerName) {
    final skipHeaders = [
      'host',
      'connection',
      'keep-alive',
      'proxy-authenticate',
      'proxy-authorization',
      'te',
      'trailers',
      'transfer-encoding',
      'upgrade',
    ];

    return skipHeaders.contains(headerName.toLowerCase());
  }

  Future<Response> _handleCacheStatusRequest() async {
    try {
      final cacheService = VideoCacheService.instance;
      final stats = await cacheService.getStats();
      final activeDownloads = CacheDownloadService.instance.getActiveDownloads();

      final statusData = {
        'cacheStats': stats.toJson(),
        'activeDownloads': activeDownloads,
        'proxyRunning': _isRunning,
        'proxyPort': _port,
      };

      return Response.ok(
        statusData.toString(),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: 'Failed to get cache status');
    }
  }

  Middleware corsHeaders() {
    return (Handler innerHandler) {
      return (Request request) async {
        final response = await innerHandler(request);

        return response.change(
          headers: {
            'access-control-allow-origin': '*',
            'access-control-allow-methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'access-control-allow-headers': 'Content-Type, Authorization, Range',
            'access-control-max-age': '86400',
          },
        );
      };
    };
  }
}