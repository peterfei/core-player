import '../services/update/update_services.dart';
import '../models/update/update_models.dart';
import 'package:yinghe_player/core/plugin_system/plugin_registry.dart';
import 'package:yinghe_player/core/plugin_system/core_plugin.dart';

// 内置插件
import 'builtin/subtitle/subtitle_plugin.dart';
import 'builtin/audio_effects/audio_effects_plugin.dart';
import 'builtin/video_processing/video_enhancement_plugin.dart';
import 'builtin/ui_themes/theme_plugin.dart';
import 'builtin/metadata/metadata_enhancer_plugin.dart';

// 商业插件
import 'commercial/media_server/smb/smb_plugin.dart';

// 第三方插件示例
import 'third_party/examples/youtube_plugin/youtube_plugin.dart';
import 'third_party/examples/bilibili_plugin/bilibili_plugin.dart';
import 'third_party/examples/vlc_plugin/vlc_plugin.dart';

/// PluginRegistry更新功能扩展
/// 
/// 为PluginRegistry添加插件热更新功能
extension PluginRegistryUpdateExtension on PluginRegistry {
  /// 获取UpdateService实例
  static final UpdateService _updateService = UpdateService();
  
  /// 初始化更新服务
  Future<void> initializeUpdateService() async {
    await _updateService.initialize();
    
    // 设置插件卸载回调
    _updateService.setPluginUnloadCallback((pluginId) async {
      await deactivateWithDependents(pluginId);
      await unregister(pluginId);
    });
    
    // 设置插件加载回调
    _updateService.setPluginLoadCallback((pluginId, pluginPath) async {
      // 重新创建并激活插件
      final plugin = await createPlugin(pluginId);
      if (plugin != null) {
        await register(plugin);
        await activateWithDependencies(pluginId);
      }
    });
    
    print('✅ 插件更新服务已初始化');
  }
  
  /// 检查单个插件更新
  Future<UpdateInfo?> checkPluginUpdate(String pluginId) async {
    final pluginInfo = getMetadata(pluginId);
    if (pluginInfo == null) {
      print('⚠️ 插件不存在: $pluginId');
      return null;
    }
    
    return await _updateService.checkUpdate(
      pluginId: pluginId,
      currentVersion: pluginInfo.version,
    );
  }
  
  /// 检查所有插件更新
  Future<List<UpdateInfo>> checkAllPluginUpdates() async {
    final allPlugins = listAllMetadata();
    final pluginVersions = <String, String>{};
    
    for (final plugin in allPlugins) {
      pluginVersions[plugin.id] = plugin.version;
    }
    
    return await _updateService.checkAllUpdates(
      plugins: pluginVersions,
    );
  }
  
  /// 下载插件更新
  Future<String> downloadPluginUpdate({
    required UpdateInfo updateInfo,
    void Function(DownloadProgress)? onProgress,
  }) async {
    return await _updateService.downloadUpdate(
      updateInfo: updateInfo,
      onProgress: onProgress,
    );
  }
  
  /// 安装插件更新
  Future<InstallResult> installPluginUpdate({
    required String pluginId,
    required String version,
    required String packagePath,
  }) async {
    final pluginInfo = getMetadata(pluginId);
    if (pluginInfo == null) {
      return InstallResult.failed(
        pluginId: pluginId,
        version: version,
        error: '插件不存在',
      );
    }
    
    // 获取插件安装路径
    final pluginInstallPath = _getPluginInstallPath(pluginId);
    
    return await _updateService.installUpdate(
      pluginId: pluginId,
      version: version,
      packagePath: packagePath,
      pluginInstallPath: pluginInstallPath,
      createBackup: true,
    );
  }
  
  /// 执行完整更新流程
  Future<InstallResult> performPluginUpdate({
    required String pluginId,
    void Function(String stage, double progress)? onProgress,
  }) async {
    final pluginInfo = getMetadata(pluginId);
    if (pluginInfo == null) {
      return InstallResult.failed(
        pluginId: pluginId,
        version: '0.0.0',
        error: '插件不存在',
      );
    }
    
    final pluginInstallPath = _getPluginInstallPath(pluginId);
    
    return await _updateService.performFullUpdate(
      pluginId: pluginId,
      currentVersion: pluginInfo.version,
      pluginInstallPath: pluginInstallPath,
      onProgress: onProgress,
    );
  }
  
  /// 批量更新插件
  Future<Map<String, InstallResult>> batchUpdatePlugins({
    required List<UpdateInfo> updates,
    void Function(String pluginId, String stage, double progress)? onProgress,
  }) async {
    final pluginInstallPaths = <String, String>{};
    
    for (final update in updates) {
      pluginInstallPaths[update.pluginId] = _getPluginInstallPath(update.pluginId);
    }
    
    return await _updateService.batchUpdate(
      updates: updates,
      pluginInstallPaths: pluginInstallPaths,
      onProgress: onProgress,
    );
  }
  
  /// 回滚插件版本
  Future<InstallResult> rollbackPluginVersion({
    required String pluginId,
    required BackupInfo backupInfo,
  }) async {
    final pluginInstallPath = _getPluginInstallPath(pluginId);
    
    return await _updateService.rollbackVersion(
      pluginId: pluginId,
      backupInfo: backupInfo,
      pluginInstallPath: pluginInstallPath,
    );
  }
  
  /// 列出插件备份
  Future<List<BackupInfo>> listPluginBackups(String pluginId) async {
    return await _updateService.listBackups(pluginId);
  }
  
  /// 获取插件安装路径
  String _getPluginInstallPath(String pluginId) {
    // 根据插件类型返回不同的路径
    if (pluginId.startsWith('builtin.')) {
      return 'lib/plugins/builtin/${pluginId.replaceFirst('builtin.', '')}';
    } else if (pluginId.startsWith('commercial.')) {
      return 'lib/plugins/commercial/${pluginId.replaceFirst('commercial.', '')}';
    } else if (pluginId.startsWith('third_party.')) {
      return 'lib/plugins/third_party/${pluginId.replaceFirst('third_party.', '')}';
    } else {
      return 'lib/plugins/custom/$pluginId';
    }
  }

  /// 创建插件实例
  Future<CorePlugin?> createPlugin(String pluginId) async {
    try {
      switch (pluginId) {
        // 内置插件
        case 'builtin.subtitle':
          return Future.value(SubtitlePlugin());
        case 'builtin.audio_effects':
          return Future.value(AudioEffectsPlugin());
        case 'builtin.video_enhancement':
          return Future.value(VideoEnhancementPlugin());
        case 'builtin.theme_manager':
          return Future.value(ThemePlugin());
        case 'builtin.metadata_enhancer':
          return Future.value(MetadataEnhancerPlugin());

        // 商业插件
        case 'commercial.smb':
          return Future.value(SMBPlugin());

        // 第三方插件
        case 'third_party.youtube':
          return Future.value(YouTubePlugin());
        case 'third_party.bilibili':
          return Future.value(BilibiliPlugin());
        case 'third_party.vlc':
          return Future.value(VLCPlugin());

        default:
          print('Unknown plugin: $pluginId');
          return null;
      }
    } catch (e) {
      print('Failed to instantiate plugin $pluginId: $e');
      return null;
    }
  }
}
