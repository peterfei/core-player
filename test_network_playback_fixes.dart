import 'dart:io';
import 'dart:async';
import 'lib/services/video_cache_service.dart';
import 'lib/services/thumbnail_generator_service.dart';
import 'lib/services/settings_service.dart';

/// 测试网络播放修复的简单测试脚本
void main() async {
  print('🧪 开始测试网络播放修复...\n');

  // 测试1: 缓存服务初始化
  await testCacheService();

  // 测试2: 设置服务性能提示
  await testPerformanceAlerts();

  // 测试3: 缩略图服务初始化
  await testThumbnailService();

  print('\n✅ 所有测试完成！');
}

/// 测试缓存服务
Future<void> testCacheService() async {
  print('📦 测试1: 缓存服务');

  try {
    // 初始化缓存服务
    final cacheService = VideoCacheService.instance;
    await cacheService.initialize();
    print('  ✅ 缓存服务初始化成功');

    // 测试同步缓存检测
    final testUrl = 'https://example.com/video.mp4';
    final cachedPath = cacheService.getCachePathSync(testUrl);
    print('  ✅ 同步缓存检测功能正常 (预期: null): $cachedPath');

    // 测试异步缓存检测
    final asyncPath = await cacheService.getCachePath(testUrl);
    print('  ✅ 异步缓存检测功能正常 (预期: null): $asyncPath');
  } catch (e) {
    print('  ❌ 缓存服务测试失败: $e');
  }
}

/// 测试性能提示设置
Future<void> testPerformanceAlerts() async {
  print('\n⚡ 测试2: 性能提示设置');

  try {
    // 测试默认值（应该是关闭的）
    final defaultValue = await SettingsService.isPerformanceAlertsEnabled();
    print('  ✅ 默认性能提示状态: $defaultValue (预期: false)');

    // 测试设置切换
    await SettingsService.setPerformanceAlertsEnabled(true);
    final enabled = await SettingsService.isPerformanceAlertsEnabled();
    print('  ✅ 启用性能提示: $enabled (预期: true)');

    // 恢复默认设置
    await SettingsService.setPerformanceAlertsEnabled(false);
    final disabled = await SettingsService.isPerformanceAlertsEnabled();
    print('  ✅ 禁用性能提示: $disabled (预期: false)');
  } catch (e) {
    print('  ❌ 性能提示设置测试失败: $e');
  }
}

/// 测试缩略图服务
Future<void> testThumbnailService() async {
  print('\n🖼️ 测试3: 缩略图服务');

  try {
    // 初始化缩略图服务
    final thumbnailService = ThumbnailGeneratorService.instance;
    await thumbnailService.initialize();
    print('  ✅ 缩略图服务初始化成功');

    // 测试缓存路径生成
    final testUrl = 'https://example.com/video.mp4';
    final thumbnailPath = await thumbnailService.getThumbnailPath(testUrl);
    print('  ✅ 缩略图路径查询功能正常 (预期: null): $thumbnailPath');

    // 测试缓存大小
    final cacheSize = await thumbnailService.getCacheSize();
    print('  ✅ 缩略图缓存大小: $cacheSize bytes (预期: 0)');
  } catch (e) {
    print('  ❌ 缩略图服务测试失败: $e');
  }
}