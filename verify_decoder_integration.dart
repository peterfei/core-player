/// 验证解码器插件集成
/// 
/// 检查 plugin_loader.dart 的修改是否正确
import 'dart:io';

void main() {
  print('🔍 验证解码器插件集成...\n');
  
  final loaderFile = File('/Users/mac/project/vidhub/lib/core/plugin_system/plugin_loader.dart');
  
  if (!loaderFile.existsSync()) {
    print('❌ 文件不存在: plugin_loader.dart');
    exit(1);
  }
  
  final content = loaderFile.readAsStringSync();
  
  // 检查导入
  final checks = {
    '导入 coreplayer_pro_plugins': content.contains("import 'package:coreplayer_pro_plugins/coreplayer_pro_plugins.dart';"),
    '注册 HEVCDecoderPlugin': content.contains('HEVCDecoderPlugin()'),
    '注册 VP9DecoderPlugin': content.contains('VP9DecoderPlugin()'),
    '注册 AV1DecoderPlugin': content.contains('AV1DecoderPlugin()'),
    '默认激活 HEVC': content.contains("'coreplayer.pro.decoder.hevc'"),
    '默认激活 VP9': content.contains("'coreplayer.pro.decoder.vp9'"),
    '默认激活 AV1': content.contains("'coreplayer.pro.decoder.av1'"),
  };
  
  print('📋 检查结果:\n');
  
  var allPassed = true;
  checks.forEach((name, passed) {
    final icon = passed ? '✅' : '❌';
    print('  $icon $name');
    if (!passed) allPassed = false;
  });
  
  print('');
  
  if (allPassed) {
    print('✅ 所有检查通过！');
    print('');
    print('📝 预期结果:');
    print('  - 插件管理界面应显示 4 个插件（SMB + 3个解码器）');
    print('  - 控制台应输出类似:');
    print('    🔧 Pro Edition: Loading 4 plugins from PluginRegistry...');
    print('    ✅ Loaded plugin from registry: com.coreplayer.smb');
    print('    ✅ Loaded plugin from registry: coreplayer.pro.decoder.hevc');
    print('    ✅ Loaded plugin from registry: coreplayer.pro.decoder.vp9');
    print('    ✅ Loaded plugin from registry: coreplayer.pro.decoder.av1');
    exit(0);
  } else {
    print('❌ 部分检查失败！');
    exit(1);
  }
}
