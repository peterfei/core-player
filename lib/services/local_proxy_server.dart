import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:path/path.dart' as p;
import 'video_cache_service.dart';
import 'cache_download_service.dart';
import 'media_server_service.dart';
import 'file_source_factory.dart';
import 'file_source/file_source.dart';

// 视频请求缓存
class _VideoRequest {
  final String path;
  final String? sourceId;
  _VideoRequest(this.path, this.sourceId);
}

class LocalProxyServer {
  static LocalProxyServer? _instance;
  static LocalProxyServer get instance {
    _instance ??= LocalProxyServer._();
    return _instance!;
  }

  LocalProxyServer._();

  /// 获取本机的实际 IP 地址（非 loopback）
  /// macOS 沙箱阻止 MPV 访问 localhost，所以必须使用实际网络接口
  Future<String?> _getLocalIPAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final interface in interfaces) {
        // 跳过 loopback 接口
        if (interface.name.toLowerCase().contains('lo')) continue;

        for (final addr in interface.addresses) {
          // 优先使用 192.168.x.x 或 10.x.x.x 网段（内网地址）
          final ip = addr.address;
          if (ip.startsWith('192.168.') || ip.startsWith('10.')) {
            print('   找到内网地址: $ip (${interface.name})');
            return ip;
          }
        }
      }

      // 如果没找到内网地址，使用第一个非 loopback 地址
      for (final interface in interfaces) {
        if (interface.name.toLowerCase().contains('lo')) continue;
        if (interface.addresses.isNotEmpty) {
          final ip = interface.addresses.first.address;
          print('   使用备用地址: $ip (${interface.name})');
          return ip;
        }
      }

      print('   ⚠️ 未找到可用的网络接口，降级使用 0.0.0.0');
      return '0.0.0.0'; // 绑定到所有接口
    } catch (e) {
      print('   ❌ 获取IP地址失败: $e');
      return null;
    }
  }

  HttpServer? _server;
  int _port = 8080;
  bool _isRunning = false;
  String? _serverAddress; // 实际绑定的 IP 地址
  final Map<String, String> _urlToProxyUrl = {};

  // URL 映射：使用短 ID 代替长 URL
  final Map<String, _VideoRequest> _requestCache = {};
  int _requestIdCounter = 0;

  Future<void> start({int port = 8080, bool forceRestart = false}) async {
    print('🚀 LocalProxyServer.start() 被调用');
    print('   当前运行状态: $_isRunning');
    print('   目标端口: $port');
    print('   强制重启: $forceRestart');
    
    // 如果强制重启，先停止现有服务器
    if (forceRestart && _isRunning) {
      print('   🔄 强制重启：先停止现有服务器...');
      await stop();
    }
    
    // 检查真实运行状态：_server不为null才算真正运行
    final actuallyRunning = _isRunning && _server != null;
    print('   真实运行状态: $actuallyRunning (标志=$_isRunning, 服务器=${_server != null})');
    
    if (actuallyRunning) {
      print('   ⚠️ 服务器已在运行，跳过启动');
      return;
    }
    
    // 如果标志不一致，重置状态
    if (_isRunning && _server == null) {
      print('   ⚠️ 检测到状态不一致！重置标志...');
      _isRunning = false;
    }

    _port = port;

    try {
      print('   📝 创建路由器...');
      final router = Router();

      // 处理所有请求
      router.all('/<.*>', _handleRequest);

      // 创建自定义日志中间件
      Middleware customLogger() {
        return (Handler innerHandler) {
          return (Request request) async {
            print('📥 收到HTTP请求:');
            print('   时间: ${DateTime.now()}');
            print('   方法: ${request.method}');
            print('   URL: ${request.requestedUri}');
            print('   路径: ${request.requestedUri.path}');
            print('   查询参数: ${request.requestedUri.queryParameters}');
            print('   Headers: ${request.headers.keys.toList()}');
            
            final response = await innerHandler(request);
            
            print('📤 返回响应:');
            print('   状态码: ${response.statusCode}');
            print('   Headers: ${response.headers.keys.toList()}');
            
            return response;
          };
        };
      }

      // 创建CORS处理器
      print('   📝 创建中间件...');
      final handler = const Pipeline()
          .addMiddleware(corsHeaders())
          .addMiddleware(customLogger())  // 使用自定义日志
          .addHandler(router);

      // 获取实际 IP 地址用于生成 URL（避免 macOS 沙箱对 localhost 的限制）
      print('   📝 查找本机网络地址...');
      final ipAddress = await _getLocalIPAddress();

      if (ipAddress == null) {
        throw Exception('无法获取网络地址');
      }

      // 启动服务器，绑定到所有接口（0.0.0.0）
      // 但在 URL 中使用实际 IP 地址
      print('   📝 启动HTTP服务器...');
      print('   绑定地址: 0.0.0.0（所有接口）');
      print('   URL 使用地址: $ipAddress');

      _server = await shelf_io
          .serve(
            handler,
            InternetAddress.anyIPv4, // 绑定到 0.0.0.0
            _port,
          )
          .timeout(Duration(seconds: 5));

      _isRunning = true;
      _serverAddress = ipAddress; // 保存实际地址用于 URL 生成

      print('✅ Local proxy server started on http://0.0.0.0:$_port');
      print('   对外访问地址: http://$ipAddress:$_port');
      print('   服务器对象: ${_server.hashCode}');
      print('   ⚠️ URL 使用实际网络地址 $ipAddress 以绕过 macOS 沙箱限制');

      // 自测试：验证服务器确实在监听
      _testServerConnectivity();
    } catch (e, stackTrace) {
      print('❌ Failed to start local proxy server: $e');
      print('   堆栈: $stackTrace');
      // 确保状态一致
      _isRunning = false;
      _server = null;
      // 代理服务器启动失败不应该阻塞应用
    }
  }

  /// 测试服务器连接性
  Future<void> _testServerConnectivity() async {
    try {
      print('🧪 测试代理服务器连接性...');
      final client = HttpClient();
      // 使用实际绑定的地址进行测试
      final testUrl = 'http://${_serverAddress ?? '127.0.0.1'}:$_port/health';
      print('   测试 URL: $testUrl');

      final request = await client.getUrl(Uri.parse(testUrl));
      final response = await request.close();

      if (response.statusCode == 200) {
        print('✅ 代理服务器自测试通过！可以正常响应请求');
      } else {
        print('⚠️ 代理服务器自测试异常: 状态码 ${response.statusCode}');
      }
      client.close();
    } catch (e) {
      print('❌ 代理服务器自测试失败: $e');
      print('   这可能导致播放器无法连接!');
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

  String getProxyUrl(String originalUrl, {String? sourceId}) {
    if (_server == null) return originalUrl;

    // 提取文件扩展名
    final extension = originalUrl.split('.').last.split('?').first;
    final validExtension = ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm'].contains(extension.toLowerCase())
        ? extension
        : 'mp4';

    // 使用短 ID 映射，避免 URL 过长
    // 新格式: /video/{id}.{ext}
    final requestId = 'v${_requestIdCounter++}';
    _requestCache[requestId] = _VideoRequest(originalUrl, sourceId);

    // 使用实际绑定的网络地址（避免 macOS 沙箱限制）
    final address = _serverAddress ?? '127.0.0.1';
    final proxyUrl = 'http://$address:$_port/video/$requestId.$validExtension';

    _urlToProxyUrl[originalUrl] = proxyUrl;
    print('🔗 创建短 URL 映射:');
    print('   ID: $requestId');
    print('   原始路径: $originalUrl');
    print('   代理 URL: $proxyUrl');
    print('   使用网络地址: $address (绕过沙箱限制)');
    return proxyUrl;
  }

  String? getOriginalUrl(String proxyUrl) {
    for (final entry in _urlToProxyUrl.entries) {
      if (entry.value == proxyUrl) {
        return entry.key;
      }
    }

    // 如果在映射中找不到，尝试从URL解析
    // 新格式: /video/stream.{ext}?path={encodedPath}&sourceId={id}
    try {
      final uri = Uri.parse(proxyUrl);
      final pathParam = uri.queryParameters['path'];
      if (pathParam != null) {
        return Uri.decodeComponent(pathParam);
      }
    } catch (e) {
      return null;
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

    // 简单的测试端点 - 返回简单的MP4响应头
    if (path == '/test.mp4') {
      print('📥 收到测试请求: /test.mp4');
      return Response.ok(
        'TEST DATA',
        headers: {
          'content-type': 'video/mp4',
          'content-length': '9',
          'accept-ranges': 'bytes',
        },
      );
    }

    // 缓存状态端点
    if (path == '/cache/status') {
      return _handleCacheStatusRequest();
    }

    return Response.notFound('Not Found');
  }


  Future<Response> _handleVideoRequest(Request request) async {
    try {
      print('📥 收到视频请求: ${request.requestedUri}');

      // 新的 URL 结构：/video/{id}.{ext}
      // 从路径段提取 ID
      final pathSegments = request.requestedUri.pathSegments;
      if (pathSegments.length < 2) {
        return Response.badRequest(body: 'Invalid video URL: missing video ID');
      }

      // 提取 ID (例如: v0.mp4 -> v0)
      final fileNameWithExt = pathSegments[1];
      final requestId = fileNameWithExt.split('.').first;

      print('   请求 ID: $requestId');

      // 从缓存查找原始路径
      final videoRequest = _requestCache[requestId];
      if (videoRequest == null) {
        print('   ❌ 未找到请求映射');
        return Response.notFound('Video request not found');
      }

      final originalUrl = videoRequest.path;
      final sourceId = videoRequest.sourceId;

      print('   解码路径: $originalUrl');
      print('   源ID: $sourceId');

      if (originalUrl.isEmpty) {
        return Response.badRequest(body: 'Invalid video URL: empty path');
      }

      // 如果有 sourceId，说明是来自特定源（如SMB）的请求
      if (sourceId != null) {
        print('   ✅ 路由到 FileSource 处理器');
        return await _handleFileSourceRequest(request, originalUrl, sourceId);
      }

      print('   ✅ 路由到本地缓存处理器');
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

  Future<Response> _handleFileSourceRequest(
    Request request,
    String path,
    String sourceId,
  ) async {
    try {
      print('🔍 LocalProxyServer: 处理FileSource请求');
      print('   路径: $path');
      print('   源ID: $sourceId');
      
      // 获取服务器配置
      final servers = await MediaServerService.getServers();
      final config = servers.firstWhere(
        (s) => s.id == sourceId,
        orElse: () => throw Exception('Source not found: $sourceId'),
      );
      
      print('   服务器: ${config.name} (${config.type})');

      // 创建 FileSource
      final source = FileSourceFactory.createFromConfig(config);
      if (source == null) {
        throw Exception('Failed to create file source for type: ${config.type}');
      }

      // 连接到源
      await source.connect();
      print('   ✅ 已连接到源');

      // 获取文件大小
      int fileSize = 0;
      try {
        // 尝试通过列出父目录来获取文件信息
        final parentPath = p.dirname(path);
        final fileName = p.basename(path);
        
        print('   尝试获取文件大小...');
        print('     父目录: $parentPath');
        print('     文件名: $fileName');
        
        final files = await source.listFiles(parentPath);
        print('     父目录包含 ${files.length} 个项目');
        
        final fileItem = files.firstWhere(
          (f) {
            // 尝试多种匹配方式
            final matches = f.path == path || 
                           f.name == fileName ||
                           f.path.endsWith(fileName);
            if (matches) {
              print('     ✅ 找到匹配文件: ${f.name} (${f.size} bytes)');
            }
            return matches;
          },
          orElse: () {
            print('     ⚠️ 未找到文件，尝试直接使用路径');
            // 如果找不到，返回一个占位符，稍后会尝试直接读取
            return FileItem(
              name: fileName,
              path: path,
              isDirectory: false,
              size: 0,
            );
          },
        );
        
        fileSize = fileItem.size;
        print('   文件大小: $fileSize bytes');
      } catch (e) {
        print('   ⚠️ 无法获取文件大小: $e');
        print('   将尝试流式传输（可能影响seek功能）');
      }

      // 解析范围请求
      final rangeHeader = request.headers['range'];
      int start = 0;
      int? end;

      if (rangeHeader != null) {
        print('   📊 范围请求: $rangeHeader');
        if (fileSize > 0) {
          final ranges = _parseRangeHeader(rangeHeader, fileSize);
          if (ranges.isNotEmpty) {
            start = ranges.first['start']!;
            end = ranges.first['end'];
            print('     范围: $start-${end ?? "end"}');
          }
        } else {
          print('     ⚠️ 文件大小未知，无法精确处理范围请求');
        }
      }

      // 打开文件流
      print('   📖 开始读取文件流...');
      final stream = source.openRead(path, start, end);

      // 构建响应头
      final headers = <String, String>{
        'content-type': 'video/mp4',
        'accept-ranges': 'bytes',
        'access-control-allow-origin': '*',
      };

      if (rangeHeader != null && fileSize > 0) {
        // 返回206 Partial Content
        final actualEnd = end ?? (fileSize - 1);
        final contentLength = actualEnd - start + 1;
        
        headers['content-range'] = 'bytes $start-$actualEnd/$fileSize';
        headers['content-length'] = contentLength.toString();
        
        print('   ✅ 返回部分内容 (206)');
        print('     Content-Range: bytes $start-$actualEnd/$fileSize');
        print('     Content-Length: $contentLength');
        
        return Response(206, body: stream, headers: headers);
      } else {
        // 返回200 OK
        if (fileSize > 0) {
          headers['content-length'] = fileSize.toString();
        }
        
        print('   ✅ 返回完整内容 (200)');
        if (fileSize > 0) {
          print('     Content-Length: $fileSize');
        }
        
        return Response.ok(stream, headers: headers);
      }
    } catch (e, stackTrace) {
      print('❌ LocalProxyServer: FileSource请求失败');
      print('   错误: $e');
      print('   堆栈: $stackTrace');
      return Response.internalServerError(body: 'Error: $e');
    }
  }

  Future<Response> _handleRemoteDownloadWithCache(
      Request request, String originalUrl) async {
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

  Future<Response> _handleRangeRequest(
      File file, String rangeHeader, int fileSize) async {
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
      final activeDownloads =
          CacheDownloadService.instance.getActiveDownloads();

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
            'access-control-allow-headers':
                'Content-Type, Authorization, Range',
            'access-control-max-age': '86400',
          },
        );
      };
    };
  }
}
