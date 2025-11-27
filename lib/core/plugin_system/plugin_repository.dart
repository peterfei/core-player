import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'core_plugin.dart';
import 'plugin_interface.dart';
import 'edition_config.dart';
import '../../plugins/builtin/subtitle/subtitle_plugin.dart';
import '../../plugins/builtin/audio_effects/audio_effects_plugin.dart';
import '../../plugins/builtin/video_processing/video_enhancement_plugin.dart';
import '../../plugins/builtin/metadata/metadata_enhancer_plugin.dart';
import '../../plugins/builtin/ui_themes/theme_plugin.dart';

/// 插件仓库类型
enum PluginRepositoryType {
  builtin,    // 内置插件
  commercial, // 商业插件
  thirdParty, // 第三方插件
}

/// 插件仓库信息
class PluginRepositoryInfo {
  final String id;
  final String name;
  final String description;
  final PluginRepositoryType type;
  final String version;
  final String? author;
  final String? website;
  final bool isCommunityEdition;

  const PluginRepositoryInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.version,
    this.author,
    this.website,
    this.isCommunityEdition = true,
  });
}

/// 插件仓库管理器
///
/// 负责管理不同类型的插件仓库，包括内置、商业和第三方插件
class PluginRepository {
  static final PluginRepository _instance = PluginRepository._internal();
  factory PluginRepository() => _instance;
  PluginRepository._internal();

  final Map<String, PluginRepositoryInfo> _repositories = {};
  final Map<String, CorePlugin> _loadedPlugins = {};

  /// 获取所有可用的插件仓库
  List<PluginRepositoryInfo> getAvailableRepositories() {
    return _repositories.values.where((repo) {
      return repo.isCommunityEdition || !EditionConfig.isCommunityEdition;
    }).toList();
  }

  /// 初始化插件仓库
  Future<void> initialize() async {
    // 注册内置插件
    await _registerBuiltinPlugins();

    if (kDebugMode) {
      print('PluginRepository initialized with ${_repositories.length} repositories');
    }
  }

  /// 注册内置插件
  Future<void> _registerBuiltinPlugins() async {
    // 字幕插件
    _registerPlugin(PluginRepositoryInfo(
      id: 'coreplayer.subtitle',
      name: '字幕处理插件',
      description: '支持多种字幕格式加载、解析和渲染',
      type: PluginRepositoryType.builtin,
      version: '1.0.0',
      author: 'CorePlayer Team',
      isCommunityEdition: true,
    ), () => SubtitlePlugin());

    // 音频效果插件
    _registerPlugin(PluginRepositoryInfo(
      id: 'coreplayer.audio_effects',
      name: '音频效果插件',
      description: '提供均衡器、混响、3D音效等音频处理功能',
      type: PluginRepositoryType.builtin,
      version: '1.0.0',
      author: 'CorePlayer Team',
      isCommunityEdition: false, // 专业版功能
    ), () => AudioEffectsPlugin());

    // 视频增强插件
    _registerPlugin(PluginRepositoryInfo(
      id: 'coreplayer.video_enhancement',
      name: '视频增强插件',
      description: '提供画面增强、色彩校正、降噪等视频处理功能',
      type: PluginRepositoryType.builtin,
      version: '1.0.0',
      author: 'CorePlayer Team',
      isCommunityEdition: false, // 专业版功能
    ), () => VideoEnhancementPlugin());

    // 元数据增强插件
    _registerPlugin(PluginRepositoryInfo(
      id: 'coreplayer.metadata_enhancer',
      name: '元数据增强插件',
      description: '自动获取和丰富视频文件的元数据信息',
      type: PluginRepositoryType.builtin,
      version: '1.0.0',
      author: 'CorePlayer Team',
      isCommunityEdition: true,
    ), () => MetadataEnhancerPlugin());

    // 主题插件
    _registerPlugin(PluginRepositoryInfo(
      id: 'coreplayer.theme_manager',
      name: '主题管理插件',
      description: '提供多套UI主题和个性化定制功能',
      type: PluginRepositoryType.builtin,
      version: '1.0.0',
      author: 'CorePlayer Team',
      isCommunityEdition: true,
    ), () => ThemePlugin());
  }

  /// 注册插件
  void _registerPlugin(PluginRepositoryInfo info, CorePlugin Function() factory) {
    _repositories[info.id] = info;
  }

  /// 加载插件
  Future<CorePlugin?> loadPlugin(String repositoryId) async {
    // 检查插件是否已加载
    if (_loadedPlugins.containsKey(repositoryId)) {
      return _loadedPlugins[repositoryId];
    }

    // 获取仓库信息
    final repoInfo = _repositories[repositoryId];
    if (repoInfo == null) {
      return null;
    }

    // 版本检查
    if (!repoInfo.isCommunityEdition && EditionConfig.isCommunityEdition) {
      throw Exception('插件 "${repoInfo.name}" 仅在专业版中可用');
    }

    try {
      // 这里简化处理，实际应该根据类型加载
      CorePlugin plugin;
      switch (repositoryId) {
        case 'coreplayer.subtitle':
          plugin = SubtitlePlugin();
          break;
        case 'coreplayer.audio_effects':
          plugin = AudioEffectsPlugin();
          break;
        case 'coreplayer.video_enhancement':
          plugin = VideoEnhancementPlugin();
          break;
        case 'coreplayer.metadata_enhancer':
          plugin = MetadataEnhancerPlugin();
          break;
        case 'coreplayer.theme_manager':
          plugin = ThemePlugin();
          break;
        default:
          throw Exception('未知的插件仓库: $repositoryId');
      }

      await plugin.initialize();
      _loadedPlugins[repositoryId] = plugin;

      if (kDebugMode) {
        print('Loaded plugin: ${repoInfo.name} (${repoInfo.version})');
      }

      return plugin;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load plugin $repositoryId: $e');
      }
      return null;
    }
  }

  /// 卸载插件
  Future<void> unloadPlugin(String repositoryId) async {
    final plugin = _loadedPlugins.remove(repositoryId);
    if (plugin != null) {
      await plugin.deactivate();
      plugin.dispose();

      if (kDebugMode) {
        print('Unloaded plugin: $repositoryId');
      }
    }
  }

  /// 获取已加载的插件
  Map<String, CorePlugin> getLoadedPlugins() {
    return Map.unmodifiable(_loadedPlugins);
  }

  /// 获取插件仓库信息
  PluginRepositoryInfo? getRepositoryInfo(String repositoryId) {
    return _repositories[repositoryId];
  }

  /// 检查插件是否可用
  bool isPluginAvailable(String repositoryId) {
    final repo = _repositories[repositoryId];
    if (repo == null) return false;

    return repo.isCommunityEdition || !EditionConfig.isCommunityEdition;
  }

  /// 清理所有插件
  Future<void> dispose() async {
    for (final plugin in _loadedPlugins.values) {
      try {
        await plugin.deactivate();
        plugin.dispose();
      } catch (e) {
        if (kDebugMode) {
          print('Error disposing plugin: $e');
        }
      }
    }
    _loadedPlugins.clear();
    _repositories.clear();
  }

  /// 获取插件统计信息
  Map<String, int> getPluginStats() {
    final stats = <String, int>{};

    for (final repo in _repositories.values) {
      final typeKey = repo.type.toString().split('.').last;
      stats[typeKey] = (stats[typeKey] ?? 0) + 1;
    }

    return stats;
  }

  /// 搜索插件
  List<PluginRepositoryInfo> searchPlugins(String query) {
    if (query.isEmpty) {
      return getAvailableRepositories();
    }

    final lowerQuery = query.toLowerCase();
    return getAvailableRepositories().where((repo) =>
      repo.name.toLowerCase().contains(lowerQuery) ||
      repo.description.toLowerCase().contains(lowerQuery)
    ).toList();
  }
}