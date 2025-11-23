import 'lib/core/plugin_system/plugin_loader.dart';
import 'lib/core/plugin_system/plugin_interface.dart';
import 'lib/core/plugin_system/core_plugin.dart';

/// 插件系统测试脚本
void main() async {
  print('=== 插件系统测试 ===\n');

  try {
    // 初始化插件系统
    print('1. 初始化插件系统...');
    await initializePluginSystem(config: PluginLoadConfig(
      autoActivate: false, // 不自动激活，手动测试
      enableLazyLoading: false,
      loadTimeout: Duration(seconds: 5),
    ));
    print('✅ 插件系统初始化成功\n');

    // 获取当前版本
    print('2. 当前版本信息:');
    print('   版本: ${pluginLoader.config}');
    print('   是社区版: ${pluginLoader.isInitialized}');
    print('   已加载插件数量: ${pluginLoader.loadedPluginIds.length}');
    print('');

    // 列出已加载的插件
    print('3. 已加载的插件:');
    for (final pluginId in pluginLoader.loadedPluginIds) {
      print('   - $pluginId');
    }
    print('');

    // 获取插件统计信息
    print('4. 插件统计信息:');
    final stats = pluginLoader.getStatistics();
    stats.forEach((key, value) {
      print('   $key: $value');
    });
    print('');

    print('=== 测试完成 ===');

  } catch (e, stackTrace) {
    print('❌ 测试失败: $e');
    print('Stack trace: $stackTrace');
  } finally {
    // 清理资源
    if (pluginLoader.isInitialized) {
      await pluginLoader.dispose();
      print('✅ 插件系统资源已清理');
    }
  }
}