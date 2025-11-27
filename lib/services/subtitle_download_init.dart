// 字幕下载插件初始化
// 在应用启动时调用此方法注册所有字幕下载插件

import '../services/subtitle_download_manager.dart';
import '../plugins/builtin/subtitle/local_subtitle_plugin.dart';
import '../plugins/builtin/subtitle/online_subtitle_placeholder.dart';
import '../core/plugin_system/plugin_loader.dart';
import '../plugins/pro/subtitle/opensubtitles_adapter.dart';
import '../plugins/pro/subtitle/subhd_adapter.dart';

/// 初始化字幕下载插件
/// 在应用启动时调用此方法注册所有字幕下载插件
Future<void> initializeSubtitleDownloadPlugins() async {
  final manager = SubtitleDownloadManager.instance;

  print('⏳ Initializing subtitle download plugins...');
  
  // 根据版本注册不同的在线字幕插件(先注册,作为默认插件)
  if (EditionConfig.isCommunityEdition) {
    print('ℹ️ Community Edition detected');
    // 社区版:注册占位符插件
    final placeholderPlugin = OnlineSubtitlePlaceholder();
    await placeholderPlugin.initialize();
    await placeholderPlugin.activate();
    manager.registerPlugin(placeholderPlugin);
    print('✅ OnlineSubtitlePlaceholder registered as default');
  } else {
    print('ℹ️ Pro Edition detected');
    // 专业版:注册实际的在线字幕插件
    try {
      print('⏳ Initializing OpenSubtitlesAdapter...');
      final openSubtitlesPlugin = OpenSubtitlesAdapter();
      await openSubtitlesPlugin.initialize();
      await openSubtitlesPlugin.activate();
      manager.registerPlugin(openSubtitlesPlugin);
      print('✅ OpenSubtitlesAdapter registered as default');
    } catch (e) {
      print('❌ Failed to register OpenSubtitlesAdapter: $e');
    }
    
    try {
      print('⏳ Initializing SubHDAdapter...');
      final subhdPlugin = SubHDAdapter();
      await subhdPlugin.initialize();
      await subhdPlugin.activate();
      manager.registerPlugin(subhdPlugin);
      print('✅ SubHDAdapter registered');
    } catch (e) {
      print('❌ Failed to register SubHDAdapter: $e');
    }
  }

  // 注册本地字幕插件(作为备选)
  print('⏳ Initializing LocalSubtitlePlugin...');
  final localPlugin = LocalSubtitlePlugin();
  await localPlugin.initialize();
  await localPlugin.activate();
  manager.registerPlugin(localPlugin);
  print('✅ LocalSubtitlePlugin registered');

  print('✅ Subtitle download plugins initialized');
}
