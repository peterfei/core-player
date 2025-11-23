/// 插件系统功能验证（仅编译测试）
import 'lib/core/plugin_system/plugin_interface.dart';
import 'lib/core/plugin_system/core_plugin.dart';
import 'lib/core/plugin_system/plugins/media_server/placeholders/media_server_placeholder.dart';
import 'lib/core/plugin_system/plugins/media_server/smb/smb_plugin.dart';

void main() async {
  print('=== CorePlayer 插件系统验证 ===\n');

  // 1. 检查版本配置
  print('✅ 当前版本配置: ${EditionConfig.currentEdition}');

  // 2. 测试插件实例化（编译时验证）
  try {
    // 社区版插件实例化测试
    final communityPlugin = MediaServerPlaceholderPlugin();
    print('✅ 社区版插件实例化成功: ${communityPlugin.metadata.name}');

    // 专业版插件实例化测试
    final proPlugin = SMBPlugin();
    print('✅ 专业版插件实例化成功: ${proPlugin.metadata.name}');

    // 3. 测试插件元数据
    print('\n📋 插件元数据:');
    print('  社区版插件: ${communityPlugin.metadata.id} - ${communityPlugin.metadata.description}');
    print('  专业版插件: ${proPlugin.metadata.id} - ${proPlugin.metadata.description}');

    // 4. 测试状态管理
    print('\n🔄 状态管理测试:');
    print('  社区版插件初始状态: ${communityPlugin.state}');
    print('  专业版插件初始状态: ${proPlugin.state}');

    // 5. 版本功能差异
    print('\n🔍 版本功能差异:');
    if (EditionConfig.isCommunityEdition) {
      print('  社区版: 媒体服务器功能占位符');
      print('  升级提示: ${communityPlugin.getUpgradeMessage()}');
    } else {
      print('  专业版: SMB/CIFS网络共享功能');
      print('  支持协议: ${proPlugin.supportedProtocols}');
    }

    print('\n✅ 所有插件系统组件验证通过!');

  } catch (e) {
    print('❌ 插件系统验证失败: $e');
  }

  print('\n=== 验证完成 ===');
}