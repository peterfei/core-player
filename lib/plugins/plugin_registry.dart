import 'package:flutter/material.dart';
import 'core/plugin_system/plugin_interface.dart';
import 'core/plugin_system/plugin_repository.dart';
import 'core/plugin_system/plugin_manager.dart';
import 'core/plugin_system/core_plugin.dart';

// 内置插件
import 'builtin/base/media_server_plugin.dart';
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

/// 插件注册表
///
/// 负责管理所有插件的注册、初始化和生命周期管理
class PluginRegistry {
  static PluginRegistry? _instance;
  static PluginRegistry get instance => _instance ??= PluginRegistry._();

  PluginRegistry._();

  /// 插件仓库
  final PluginRepository _repository = PluginRepository();

  /// 插件管理器
  final PluginManager _manager = PluginManager();

  /// 已注册的插件
  final Map<String, CorePlugin> _registeredPlugins = {};

  /// 插件依赖关系
  final Map<String, List<String>> _pluginDependencies = {};

  /// 初始化插件系统
  Future<void> initialize() async {
    try {
      print('Initializing plugin system...');

      // 注册内置插件
      await _registerBuiltinPlugins();

      // 注册商业插件
      await _registerCommercialPlugins();

      // 注册第三方插件
      await _registerThirdPartyPlugins();

      // 初始化插件仓库
      await _repository.initialize();

      print('Plugin system initialized successfully');
    } catch (e) {
      print('Failed to initialize plugin system: $e');
      rethrow;
    }
  }

  /// 注册内置插件
  Future<void> _registerBuiltinPlugins() async {
    final builtinPlugins = [
      PluginRepositoryInfo(
        id: 'builtin.subtitle',
        name: '字幕插件',
        version: '1.0.0',
        description: '多格式字幕支持和显示功能',
        path: 'builtin/subtitle',
        pluginClass: 'SubtitlePlugin',
        repositoryType: PluginRepositoryType.builtin,
        isCommunityEdition: true,
        author: 'CorePlayer Team',
        category: 'media',
        tags: ['subtitle', 'accessibility'],
        dependencies: [],
        minCoreVersion: '1.0.0',
        lastUpdated: DateTime.now(),
      ),
      PluginRepositoryInfo(
        id: 'builtin.audio_effects',
        name: '音频效果插件',
        version: '1.0.0',
        description: '专业音频处理和效果功能',
        path: 'builtin/audio_effects',
        pluginClass: 'AudioEffectsPlugin',
        repositoryType: PluginRepositoryType.builtin,
        isCommunityEdition: true,
        author: 'CorePlayer Team',
        category: 'audio',
        tags: ['audio', 'effects', 'equalizer'],
        dependencies: [],
        minCoreVersion: '1.0.0',
        lastUpdated: DateTime.now(),
      ),
      PluginRepositoryInfo(
        id: 'builtin.video_enhancement',
        name: '视频增强插件',
        version: '1.0.0',
        description: '视频画面增强和优化功能',
        path: 'builtin/video_processing',
        pluginClass: 'VideoEnhancementPlugin',
        repositoryType: PluginRepositoryType.builtin,
        isCommunityEdition: false,
        author: 'CorePlayer Team',
        category: 'video',
        tags: ['video', 'enhancement', 'processing'],
        dependencies: [],
        minCoreVersion: '1.0.0',
        lastUpdated: DateTime.now(),
      ),
      PluginRepositoryInfo(
        id: 'builtin.theme_manager',
        name: '主题管理插件',
        version: '1.0.0',
        description: 'UI主题管理和个性化定制',
        path: 'builtin/ui_themes',
        pluginClass: 'ThemePlugin',
        repositoryType: PluginRepositoryType.builtin,
        isCommunityEdition: true,
        author: 'CorePlayer Team',
        category: 'ui',
        tags: ['theme', 'ui', 'customization'],
        dependencies: [],
        minCoreVersion: '1.0.0',
        lastUpdated: DateTime.now(),
      ),
      PluginRepositoryInfo(
        id: 'builtin.metadata_enhancer',
        name: '元数据增强插件',
        version: '1.0.0',
        description: '媒体元数据获取和管理功能',
        path: 'builtin/metadata',
        pluginClass: 'MetadataEnhancerPlugin',
        repositoryType: PluginRepositoryType.builtin,
        isCommunityEdition: false,
        author: 'CorePlayer Team',
        category: 'media',
        tags: ['metadata', 'media', 'search'],
        dependencies: [],
        minCoreVersion: '1.0.0',
        lastUpdated: DateTime.now(),
      ),
      PluginRepositoryInfo(
        id: 'builtin.media_server',
        name: '媒体服务器插件',
        version: '1.0.0',
        description: '媒体服务器连接和基础功能',
        path: 'builtin/base',
        pluginClass: 'MediaServerPlugin',
        repositoryType: PluginRepositoryType.builtin,
        isCommunityEdition: true,
        author: 'CorePlayer Team',
        category: 'network',
        tags: ['media', 'server', 'network'],
        dependencies: [],
        minCoreVersion: '1.0.0',
        lastUpdated: DateTime.now(),
      ),
    ];

    for (final pluginInfo in builtinPlugins) {
      _repository.registerRepository(pluginInfo);
    }
  }

  /// 注册商业插件
  Future<void> _registerCommercialPlugins() async {
    final commercialPlugins = [
      PluginRepositoryInfo(
        id: 'commercial.smb',
        name: 'SMB网络存储插件',
        version: '1.0.0',
        description: 'SMB/CIFS网络存储协议支持',
        path: 'commercial/media_server/smb',
        pluginClass: 'SMBPlugin',
        repositoryType: PluginRepositoryType.commercial,
        isCommunityEdition: false,
        author: 'CorePlayer Team',
        category: 'network',
        tags: ['smb', 'network', 'storage'],
        dependencies: ['builtin.media_server'],
        minCoreVersion: '1.0.0',
        lastUpdated: DateTime.now(),
        price: '\$19.99',
        licenseType: 'Commercial',
      ),
    ];

    for (final pluginInfo in commercialPlugins) {
      _repository.registerRepository(pluginInfo);
    }
  }

  /// 注册第三方插件
  Future<void> _registerThirdPartyPlugins() async {
    final thirdPartyPlugins = [
      PluginRepositoryInfo(
        id: 'third_party.youtube',
        name: 'YouTube 插件',
        version: '2.1.0',
        description: 'YouTube视频播放和功能集成',
        path: 'third_party/examples/youtube_plugin',
        pluginClass: 'YouTubePlugin',
        repositoryType: PluginRepositoryType.thirdParty,
        isCommunityEdition: true,
        author: 'CorePlayer Community',
        category: 'streaming',
        tags: ['youtube', 'video', 'streaming'],
        dependencies: [],
        minCoreVersion: '1.0.0',
        lastUpdated: DateTime.now(),
        downloadUrl: 'https://github.com/coreplayer/youtube-plugin',
        rating: 4.5,
        downloadCount: 15000,
      ),
      PluginRepositoryInfo(
        id: 'third_party.bilibili',
        name: 'Bilibili 插件',
        version: '1.8.0',
        description: 'Bilibili视频播放和弹幕功能',
        path: 'third_party/examples/bilibili_plugin',
        pluginClass: 'BilibiliPlugin',
        repositoryType: PluginRepositoryType.thirdParty,
        isCommunityEdition: true,
        author: 'CorePlayer Community',
        category: 'streaming',
        tags: ['bilibili', 'video', 'danmaku'],
        dependencies: [],
        minCoreVersion: '1.0.0',
        lastUpdated: DateTime.now(),
        downloadUrl: 'https://github.com/coreplayer/bilibili-plugin',
        rating: 4.8,
        downloadCount: 8500,
      ),
      PluginRepositoryInfo(
        id: 'third_party.vlc',
        name: 'VLC 插件',
        version: '1.5.0',
        description: 'VLC播放器集成和多格式支持',
        path: 'third_party/examples/vlc_plugin',
        pluginClass: 'VLCPlugin',
        repositoryType: PluginRepositoryType.thirdParty,
        isCommunityEdition: true,
        author: 'CorePlayer Community',
        category: 'player',
        tags: ['vlc', 'player', 'multimedia'],
        dependencies: [],
        minCoreVersion: '1.0.0',
        lastUpdated: DateTime.now(),
        downloadUrl: 'https://github.com/coreplayer/vlc-plugin',
        rating: 4.3,
        downloadCount: 6200,
      ),
    ];

    for (final pluginInfo in thirdPartyPlugins) {
      _repository.registerRepository(pluginInfo);
    }
  }

  /// 创建插件实例
  Future<CorePlugin?> createPlugin(String pluginId) async {
    try {
      final pluginInfo = _repository.getPluginInfo(pluginId);
      if (pluginInfo == null) {
        print('Plugin not found: $pluginId');
        return null;
      }

      // 检查版本兼容性
      if (!_isVersionCompatible(pluginInfo.minCoreVersion)) {
        print('Plugin version incompatible: $pluginId');
        return null;
      }

      // 检查依赖关系
      if (!_areDependenciesSatisfied(pluginInfo.dependencies)) {
        print('Plugin dependencies not satisfied: $pluginId');
        return null;
      }

      // 创建插件实例
      final plugin = await _instantiatePlugin(pluginInfo);
      if (plugin != null) {
        _registeredPlugins[pluginId] = plugin;
        print('Plugin created: $pluginId');
      }

      return plugin;
    } catch (e) {
      print('Failed to create plugin $pluginId: $e');
      return null;
    }
  }

  /// 实例化插件
  Future<CorePlugin?> _instantiatePlugin(PluginRepositoryInfo pluginInfo) async {
    try {
      switch (pluginInfo.id) {
        // 内置插件
        case 'builtin.subtitle':
          return SubtitlePlugin();
        case 'builtin.audio_effects':
          return AudioEffectsPlugin();
        case 'builtin.video_enhancement':
          return VideoEnhancementPlugin();
        case 'builtin.theme_manager':
          return ThemePlugin();
        case 'builtin.metadata_enhancer':
          return MetadataEnhancerPlugin();
        case 'builtin.media_server':
          return MediaServerPlugin();

        // 商业插件
        case 'commercial.smb':
          return SMBPlugin();

        // 第三方插件
        case 'third_party.youtube':
          return YouTubePlugin();
        case 'third_party.bilibili':
          return BilibiliPlugin();
        case 'third_party.vlc':
          return VLCPlugin();

        default:
          print('Unknown plugin: ${pluginInfo.id}');
          return null;
      }
    } catch (e) {
      print('Failed to instantiate plugin ${pluginInfo.id}: $e');
      return null;
    }
  }

  /// 检查版本兼容性
  bool _isVersionCompatible(String minVersion) {
    // 简化的版本检查，实际应用中需要更完整的版本比较
    return true;
  }

  /// 检查依赖关系是否满足
  bool _areDependenciesSatisfied(List<String> dependencies) {
    for (final dependency in dependencies) {
      if (!_registeredPlugins.containsKey(dependency)) {
        return false;
      }
    }
    return true;
  }

  /// 获取插件
  CorePlugin? getPlugin(String pluginId) {
    return _registeredPlugins[pluginId];
  }

  /// 获取所有已注册的插件
  Map<String, CorePlugin> getAllPlugins() {
    return Map.unmodifiable(_registeredPlugins);
  }

  /// 获取插件仓库信息
  PluginRepositoryInfo? getPluginInfo(String pluginId) {
    return _repository.getPluginInfo(pluginId);
  }

  /// 获取所有可用插件
  List<PluginRepositoryInfo> getAllAvailablePlugins() {
    return _repository.getAllPlugins();
  }

  /// 按类别获取插件
  List<PluginRepositoryInfo> getPluginsByCategory(String category) {
    return _repository.getPluginsByCategory(category);
  }

  /// 搜索插件
  List<PluginRepositoryInfo> searchPlugins(String query) {
    return _repository.searchPlugins(query);
  }

  /// 获取插件统计信息
  PluginRegistryStats getStats() {
    return PluginRegistryStats(
      totalRegistered: _registeredPlugins.length,
      builtinCount: _registeredPlugins.values
          .where((plugin) => plugin.metadata.id.startsWith('builtin.'))
          .length,
      commercialCount: _registeredPlugins.values
          .where((plugin) => plugin.metadata.id.startsWith('commercial.'))
          .length,
      thirdPartyCount: _registeredPlugins.values
          .where((plugin) => plugin.metadata.id.startsWith('third_party.'))
          .length,
      activeCount: _registeredPlugins.values
          .where((plugin) => plugin.state == PluginState.active)
          .length,
    );
  }

  /// 启动插件
  Future<bool> activatePlugin(String pluginId) async {
    try {
      final plugin = _registeredPlugins[pluginId];
      if (plugin == null) {
        print('Plugin not found: $pluginId');
        return false;
      }

      await _manager.activatePlugin(plugin);
      print('Plugin activated: $pluginId');
      return true;
    } catch (e) {
      print('Failed to activate plugin $pluginId: $e');
      return false;
    }
  }

  /// 停用插件
  Future<bool> deactivatePlugin(String pluginId) async {
    try {
      final plugin = _registeredPlugins[pluginId];
      if (plugin == null) {
        print('Plugin not found: $pluginId');
        return false;
      }

      await _manager.deactivatePlugin(plugin);
      print('Plugin deactivated: $pluginId');
      return true;
    } catch (e) {
      print('Failed to deactivate plugin $pluginId: $e');
      return false;
    }
  }

  /// 卸载插件
  Future<bool> unloadPlugin(String pluginId) async {
    try {
      final plugin = _registeredPlugins.remove(pluginId);
      if (plugin != null) {
        await _manager.unloadPlugin(plugin);
        print('Plugin unloaded: $pluginId');
        return true;
      }
      return false;
    } catch (e) {
      print('Failed to unload plugin $pluginId: $e');
      return false;
    }
  }

  /// 重新加载插件
  Future<bool> reloadPlugin(String pluginId) async {
    try {
      await unloadPlugin(pluginId);
      final plugin = await createPlugin(pluginId);
      if (plugin != null) {
        await activatePlugin(pluginId);
        print('Plugin reloaded: $pluginId');
        return true;
      }
      return false;
    } catch (e) {
      print('Failed to reload plugin $pluginId: $e');
      return false;
    }
  }

  /// 清理所有插件
  Future<void> dispose() async {
    for (final pluginId in _registeredPlugins.keys.toList()) {
      await unloadPlugin(pluginId);
    }
    _registeredPlugins.clear();
    _pluginDependencies.clear();
    print('Plugin registry disposed');
  }
}

/// 插件注册表统计信息
class PluginRegistryStats {
  final int totalRegistered;
  final int builtinCount;
  final int commercialCount;
  final int thirdPartyCount;
  final int activeCount;

  const PluginRegistryStats({
    required this.totalRegistered,
    required this.builtinCount,
    required this.commercialCount,
    required this.thirdPartyCount,
    required this.activeCount,
  });
}