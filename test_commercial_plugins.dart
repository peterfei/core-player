/// 商业插件集成测试
/// 测试CorePlayer Pro商业插件包在主项目中的集成

import 'package:flutter_test/flutter_test.dart';
import 'package:coreplayer_pro_plugins/coreplayer_pro_plugins.dart';

void main() {
  group('CorePlayer Pro商业插件集成测试', () {
    test('HEVC解码器插件应该可以正确导入和初始化', () async {
      print('🧪 测试HEVC解码器插件...');

      // 创建HEVC插件实例
      final hevcPlugin = HEVCDecoderPlugin();
      expect(hevcPlugin, isNotNull);
      expect(hevcPlugin.metadata.id, equals('coreplayer.pro.decoder.hevc'));
      expect(hevcPlugin.metadata.name, equals('HEVC/H.265 高级解码器'));

      // 测试插件状态
      expect(hevcPlugin.state, equals(PluginState.uninitialized));

      // 测试初始化
      await hevcPlugin.onInitialize();
      expect(hevcPlugin.state, equals(PluginState.initialized));

      // 测试激活
      await hevcPlugin.onActivate();
      expect(hevcPlugin.state, equals(PluginState.active));

      print('✅ HEVC解码器插件测试通过');
    });

    test('智能字幕插件应该可以正确导入和初始化', () async {
      print('🧪 测试智能字幕插件...');

      // 创建智能字幕插件实例
      final subtitlePlugin = IntelligentSubtitlePlugin();
      expect(subtitlePlugin, isNotNull);
      expect(subtitlePlugin.metadata.id, equals('coreplayer.pro.ai.subtitle'));
      expect(subtitlePlugin.metadata.name, equals('智能字幕插件'));

      // 测试插件状态
      expect(subtitlePlugin.state, equals(PluginState.uninitialized));

      // 测试初始化
      await subtitlePlugin.onInitialize();
      expect(subtitlePlugin.state, equals(PluginState.initialized));

      // 测试支持的语言
      final languages = subtitlePlugin.getSupportedLanguages();
      expect(languages, isNotEmpty);
      print('📝 支持的语言数量: ${languages.length}');

      print('✅ 智能字幕插件测试通过');
    });

    test('多设备同步插件应该可以正确导入和初始化', () async {
      print('🧪 测试多设备同步插件...');

      // 创建多设备同步插件实例
      final syncPlugin = MultiDeviceSyncPlugin();
      expect(syncPlugin, isNotNull);
      expect(syncPlugin.metadata.id, equals('coreplayer.pro.cloud.sync'));
      expect(syncPlugin.metadata.name, equals('多设备云同步插件'));

      // 测试插件状态
      expect(syncPlugin.state, equals(PluginState.uninitialized));

      // 测试初始化
      await syncPlugin.onInitialize();
      expect(syncPlugin.state, equals(PluginState.initialized));

      // 测试健康检查
      final isHealthy = await syncPlugin.healthCheck();
      expect(isHealthy, isTrue);

      // 测试配置
      await syncPlugin.setConfig('enable_auto_sync', 'true');
      final config = await syncPlugin.getConfig('enable_auto_sync');
      expect(config, equals('true'));

      print('✅ 多设备同步插件测试通过');
    });

    test('所有插件应该正确导出', () {
      print('🧪 测试插件包导出...');

      // 验证核心接口导出
      // 这里我们只能验证基本类型是否可用
      expect(PluginState.uninitialized, isNotNull);
      expect(PluginLicense.proprietary, isNotNull);

      print('✅ 插件包导出测试通过');
    });

    test('插件性能统计应该正常工作', () async {
      print('🧪 测试插件性能统计...');

      final hevcPlugin = HEVCDecoderPlugin();
      await hevcPlugin.onInitialize();
      await hevcPlugin.onActivate();

      // 获取性能统计
      final stats = hevcPlugin.getPerformanceStats();
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('averageDecodingTime'), isTrue);
      expect(stats.containsKey('hardwareAccelerationStatus'), isTrue);

      print('📊 性能统计: $stats');
      print('✅ 性能统计测试通过');
    });

    test('插件配置管理应该正常工作', () async {
      print('🧪 测试插件配置管理...');

      final syncPlugin = MultiDeviceSyncPlugin();
      await syncPlugin.onInitialize();
      await syncPlugin.onActivate();

      // 测试配置设置和获取
      await syncPlugin.setConfig('sync_interval_minutes', '10');
      final interval = await syncPlugin.getConfig('sync_interval_minutes');
      expect(interval, equals('10'));

      await syncPlugin.setConfig('enable_auto_sync', 'false');
      final autoSync = await syncPlugin.getConfig('enable_auto_sync');
      expect(autoSync, equals('false'));

      print('⚙️ 配置管理测试通过');
    });
  });

  group('插件系统集成测试', () {
    test('插件生命周期应该完整', () async {
      print('🧪 测试插件完整生命周期...');

      final hevcPlugin = HEVCDecoderPlugin();

      // 完整的生命周期测试
      expect(hevcPlugin.state, PluginState.uninitialized);

      await hevcPlugin.onInitialize();
      expect(hevcPlugin.state, PluginState.initialized);

      await hevcPlugin.onActivate();
      expect(hevcPlugin.state, PluginState.active);

      await hevcPlugin.onDeactivate();
      expect(hevcPlugin.state, PluginState.ready);

      await hevcPlugin.onDispose();
      expect(hevcPlugin.state, PluginState.disposed);

      print('🔄 插件生命周期测试完成');
    });
  });

  print('🎉 所有商业插件集成测试完成！');
  print('📦 CorePlayer Pro商业插件包集成成功！');
}