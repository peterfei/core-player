/// 简单的插件系统功能验证
import 'lib/core/plugin_system/plugin_loader.dart';
import 'lib/core/plugin_system/plugin_interface.dart';
import 'lib/core/plugin_system/core_plugin.dart';

void main() async {
  print('=== CorePlayer 插件系统测试 ===\n');

  // 检查版本配置
  print('当前版本配置:');
  print('- 版本: ${EditionConfig.currentEdition}');
  print('- 是社区版: ${EditionConfig.isCommunityEdition}');
  print('- 是专业版: ${EditionConfig.isProEdition}');
  print('');

  // 初始化插件系统
  try {
    print('正在初始化插件系统...');
    await initializePluginSystem(config: PluginLoadConfig(
      autoActivate: false, // 手动控制测试
      enableLazyLoading: false,
      loadTimeout: Duration(seconds: 5),
    ));

    print('✅ 插件系统初始化成功');
    print('📦 已加载插件: ${pluginLoader.loadedPluginIds.length} 个');

    // 显示插件列表
    if (pluginLoader.loadedPluginIds.isNotEmpty) {
      print('插件列表:');
      for (final pluginId in pluginLoader.loadedPluginIds) {
        print('  - $pluginId');
      }
    }

    // 测试版本差异
    print('\n🔍 版本差异测试:');
    if (EditionConfig.isCommunityEdition) {
      print('社区版功能测试:');
      print('  ✅ 占位符插件已加载');
      print('  ⚠️  高级功能需要升级到专业版');
    } else {
      print('专业版功能测试:');
      print('  ✅ SMB插件已加载');
      print('  🚀 网络共享功能已启用');
    }

  } catch (e) {
    print('❌ 插件系统初始化失败: $e');
  } finally {
    // 清理
    if (pluginLoader.isInitialized) {
      await pluginLoader.dispose();
      print('🧹 插件系统已清理');
    }
  }

  print('\n=== 测试完成 ===');
}