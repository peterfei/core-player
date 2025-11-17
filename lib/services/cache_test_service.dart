import 'dart:io';
import 'package:flutter/foundation.dart';
import 'video_cache_service.dart';
import 'local_proxy_server.dart';

/// 缓存功能测试服务
class CacheTestService {
  static Future<void> runBasicTests() async {
    try {
      debugPrint('=== 开始缓存功能测试 ===');

      // 测试1: 缓存服务初始化
      debugPrint('1. 测试缓存服务初始化...');
      final cacheService = VideoCacheService.instance;
      await cacheService.initialize();
      debugPrint('✅ 缓存服务初始化成功');

      // 测试2: 配置加载
      debugPrint('2. 测试配置加载...');
      final config = cacheService.config;
      debugPrint('✅ 配置加载成功: 启用=${config.isEnabled}, 最大大小=${config.maxSizeBytes}');

      // 测试3: 缓存统计
      debugPrint('3. 测试缓存统计...');
      final stats = await cacheService.getStats();
      debugPrint('✅ 缓存统计: 总数=${stats.totalEntries}, 大小=${stats.totalSize}');

      // 测试4: 代理服务器
      debugPrint('4. 测试代理服务器...');
      final proxyServer = LocalProxyServer.instance;
      if (!proxyServer.isRunning) {
        await proxyServer.start();
        debugPrint('✅ 代理服务器启动成功，端口=${proxyServer.port}');
      } else {
        debugPrint('✅ 代理服务器已在运行，端口=${proxyServer.port}');
      }

      // 测试5: 代理URL生成
      debugPrint('5. 测试代理URL生成...');
      final testUrl = 'https://example.com/test.mp4';
      final proxyUrl = proxyServer.getProxyUrl(testUrl);
      debugPrint('✅ 代理URL生成成功: $proxyUrl');

      debugPrint('=== 缓存功能测试完成 ===');
    } catch (e, stackTrace) {
      debugPrint('❌ 缓存功能测试失败: $e');
      debugPrint('堆栈跟踪: $stackTrace');
    }
  }

  /// 测试网络连接
  static Future<bool> testNetworkConnection() async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('https://httpbin.org/get'));
      final response = await request.close();

      if (response.statusCode == 200) {
        debugPrint('✅ 网络连接正常');
        return true;
      } else {
        debugPrint('❌ 网络连接异常: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ 网络连接测试失败: $e');
      return false;
    }
  }

  /// 测试简单的HTTP下载
  static Future<bool> testHttpDownload() async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('https://httpbin.org/bytes/1024')); // 1KB测试数据
      final response = await request.close();

      if (response.statusCode == 200) {
        final data = await response.fold<List<int>>([], (list, chunk) => list..addAll(chunk));
        debugPrint('✅ HTTP下载测试成功，下载了${data.length}字节');
        return true;
      } else {
        debugPrint('❌ HTTP下载失败: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ HTTP下载测试失败: $e');
      return false;
    }
  }
}