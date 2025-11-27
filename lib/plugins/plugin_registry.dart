import '../core/plugin_system/plugin_interface.dart';
import '../core/plugin_system/plugin_repository.dart';
import '../core/plugin_system/core_plugin.dart';

/// 插件注册表
///
/// 负责管理所有插件的注册、初始化和生命周期管理
class PluginRegistry {
  static PluginRegistry? _instance;
  static PluginRegistry get instance => _instance ??= PluginRegistry._();

  PluginRegistry._();

  /// 插件仓库
  final PluginRepository _repository = PluginRepository();

  /// 已加载的插件实例
  final Map<String, CorePlugin> _loadedPlugins = {};

  /// 初始化插件系统
  Future<void> initialize() async {
    try {
      print('Initializing plugin system...');

      // 初始化插件仓库
      await _repository.initialize();

      print('Plugin system initialized successfully');
    } catch (e) {
      print('Failed to initialize plugin system: $e');
      rethrow;
    }
  }

  /// 获取插件实例
  CorePlugin? getPlugin(String pluginId) {
    return _loadedPlugins[pluginId] ?? _repository.getLoadedPlugins()[pluginId];
  }

  /// 加载插件
  Future<CorePlugin?> loadPlugin(String pluginId) async {
    // 检查是否已加载
    if (_loadedPlugins.containsKey(pluginId)) {
      return _loadedPlugins[pluginId];
    }

    // 使用仓库加载插件
    final plugin = await _repository.loadPlugin(pluginId);
    if (plugin != null) {
      _loadedPlugins[pluginId] = plugin;
    }

    return plugin;
  }

  /// 卸载插件
  Future<void> unloadPlugin(String pluginId) async {
    _loadedPlugins.remove(pluginId);
    await _repository.unloadPlugin(pluginId);
  }

  /// 获取所有可用插件信息
  List<PluginRepositoryInfo> getAllAvailablePlugins() {
    return _repository.getAvailableRepositories();
  }

  /// 获取已加载的插件
  Map<String, CorePlugin> getAllPlugins() {
    return Map.unmodifiable(_loadedPlugins);
  }

  /// 获取插件信息
  PluginRepositoryInfo? getPluginInfo(String pluginId) {
    return _repository.getRepositoryInfo(pluginId);
  }

  /// 按类别获取插件（简化实现）
  List<PluginRepositoryInfo> getPluginsByCategory(String category) {
    // 简化实现：返回所有插件
    // 实际应用中可以根据 metadata 中的分类信息过滤
    return _repository.getAvailableRepositories();
  }

  /// 搜索插件
  List<PluginRepositoryInfo> searchPlugins(String query) {
    return _repository.searchPlugins(query);
  }

  /// 获取插件统计信息
  PluginRegistryStats getStats() {
    final loadedPlugins = _repository.getLoadedPlugins();
    final repositories = _repository.getAvailableRepositories();

    return PluginRegistryStats(
      totalRegistered: repositories.length,
      builtinCount: repositories.where((r) => r.type == PluginRepositoryType.builtin).length,
      commercialCount: repositories.where((r) => r.type == PluginRepositoryType.commercial).length,
      thirdPartyCount: repositories.where((r) => r.type == PluginRepositoryType.thirdParty).length,
      activeCount: loadedPlugins.values.where((p) => p.state == PluginState.active).length,
    );
  }

  /// 激活插件
  Future<bool> activatePlugin(String pluginId) async {
    try {
      final plugin = await loadPlugin(pluginId);
      if (plugin == null) {
        print('Plugin not found: $pluginId');
        return false;
      }

      if (plugin.state != PluginState.active) {
        await plugin.activate();
      }

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
      final plugin = getPlugin(pluginId);
      if (plugin == null) {
        print('Plugin not found: $pluginId');
        return false;
      }

      await plugin.deactivate();
      print('Plugin deactivated: $pluginId');
      return true;
    } catch (e) {
      print('Failed to deactivate plugin $pluginId: $e');
      return false;
    }
  }

  /// 重新加载插件
  Future<bool> reloadPlugin(String pluginId) async {
    try {
      await unloadPlugin(pluginId);
      final plugin = await loadPlugin(pluginId);
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
    for (final pluginId in _loadedPlugins.keys.toList()) {
      await unloadPlugin(pluginId);
    }
    _loadedPlugins.clear();
    await _repository.dispose();
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
