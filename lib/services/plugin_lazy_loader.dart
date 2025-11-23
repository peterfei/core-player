import 'dart:async';
import 'dart:developer' as developer;
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../core/plugin_system/core_plugin.dart';
import '../core/plugin_system/plugin_interface.dart';
import '../core/plugin_system/plugins/media_server/placeholders/media_server_placeholder.dart';
import '../core/plugin_system/plugins/media_server/smb/smb_plugin.dart';
import '../core/plugin_system/plugin_loader.dart';
import 'plugin_performance_service.dart';

/// 插件加载状态
enum PluginLoadState {
  notLoaded,
  loading,
  loaded,
  failed,
}

/// 插件懒加载管理器
///
/// 提供按需加载、预加载、缓存管理等功能，优化插件启动性能
class PluginLazyLoader {
  static final PluginLazyLoader _instance = PluginLazyLoader._internal();
  factory PluginLazyLoader() => _instance;
  PluginLazyLoader._internal();

  /// 插件工厂函数映射
  final Map<String, Future<CorePlugin> Function()> _pluginFactories = {};

  /// 已加载的插件缓存
  final Map<String, CorePlugin> _loadedPlugins = {};

  /// 插件加载状态
  final Map<String, PluginLoadState> _loadStates = {};

  /// 加载操作的 Future 缓存
  final Map<String, Future<CorePlugin>> _loadingFutures = {};

  /// 预加载队列
  final Queue<String> _preloadQueue = Queue();

  /// 是否正在预加载
  bool _isPreloading = false;

  /// 性能监控服务
  final PluginPerformanceService _performanceService = PluginPerformanceService();

  /// 初始化懒加载器
  Future<void> initialize() async {
    _performanceService.initialize();

    // 注册插件工厂
    await _registerPluginFactories();

    // 开始预加载关键插件
    _startPreloading();

    if (kDebugMode) {
      developer.log('PluginLazyLoader initialized with ${_pluginFactories.length} plugin factories');
    }
  }

  /// 注册插件工厂函数
  Future<void> _registerPluginFactories() async {
    // 媒体服务器插件
    if (EditionConfig.isCommunityEdition) {
      _pluginFactories['mediaserver'] = () async {
        final plugin = MediaServerPlaceholderPlugin();
        await _performanceService.startMonitoring('mediaserver', plugin);
        return plugin;
      };
    } else {
      _pluginFactories['mediaserver'] = () async {
        final plugin = SMBPlugin();
        await _performanceService.startMonitoring('mediaserver', plugin);
        return plugin;
      };
    }

    // 可以在这里注册更多插件
    // _pluginFactories['decoder'] = () async => DecoderPlugin();
    // _pluginFactories['subtitle'] = () async => SubtitlePlugin();
  }

  /// 按需加载插件
  Future<CorePlugin?> loadPlugin(String pluginId, {bool forceReload = false}) async {
    if (forceReload) {
      _unloadPlugin(pluginId);
    }

    // 如果已经加载，直接返回
    if (_loadedPlugins.containsKey(pluginId)) {
      return _loadedPlugins[pluginId];
    }

    // 如果正在加载，等待加载完成
    if (_loadingFutures.containsKey(pluginId)) {
      return await _loadingFutures[pluginId]!;
    }

    // 检查插件是否存在
    if (!_pluginFactories.containsKey(pluginId)) {
      _loadStates[pluginId] = PluginLoadState.failed;
      return null;
    }

    // 开始加载
    _loadStates[pluginId] = PluginLoadState.loading;

    final loadFuture = _loadPluginWithMetrics(pluginId);
    _loadingFutures[pluginId] = loadFuture;

    try {
      final plugin = await loadFuture;
      _loadedPlugins[pluginId] = plugin;
      _loadStates[pluginId] = PluginLoadState.loaded;
      return plugin;
    } catch (e) {
      _loadStates[pluginId] = PluginLoadState.failed;
      if (kDebugMode) {
        developer.log('Failed to load plugin $pluginId: $e');
      }
      return null;
    } finally {
      _loadingFutures.remove(pluginId);
    }
  }

  /// 带性能监控的插件加载
  Future<CorePlugin> _loadPluginWithMetrics(String pluginId) async {
    final factory = _pluginFactories[pluginId]!;

    _performanceService.recordInitStart(pluginId);

    try {
      final plugin = await factory();

      // 异步初始化，不阻塞主线程
      _initializePluginAsync(plugin, pluginId);

      _performanceService.recordInitComplete(pluginId, success: true);
      return plugin;
    } catch (e) {
      _performanceService.recordInitComplete(pluginId, success: false);
      rethrow;
    }
  }

  /// 异步初始化插件
  Future<void> _initializePluginAsync(CorePlugin plugin, String pluginId) async {
    try {
      await plugin.initialize();
    } catch (e) {
      if (kDebugMode) {
        developer.log('Async initialization failed for plugin $pluginId: $e');
      }
      // 初始化失败不应该阻止插件加载
    }
  }

  /// 卸载插件
  void _unloadPlugin(String pluginId) {
    final plugin = _loadedPlugins.remove(pluginId);
    if (plugin != null) {
      _performanceService.stopMonitoring(pluginId);
      plugin.dispose();
    }
    _loadStates[pluginId] = PluginLoadState.notLoaded;
  }

  /// 预加载插件
  Future<void> preloadPlugin(String pluginId) async {
    if (_loadStates[pluginId] == PluginLoadState.notLoaded) {
      _preloadQueue.add(pluginId);
      _processPreloadQueue();
    }
  }

  /// 预加载多个插件
  Future<void> preloadPlugins(List<String> pluginIds) async {
    for (final pluginId in pluginIds) {
      await preloadPlugin(pluginId);
    }
  }

  /// 处理预加载队列
  Future<void> _processPreloadQueue() async {
    if (_isPreloading || _preloadQueue.isEmpty) return;

    _isPreloading = true;

    while (_preloadQueue.isNotEmpty) {
      final pluginId = _preloadQueue.removeFirst();

      try {
        await loadPlugin(pluginId);
      } catch (e) {
        if (kDebugMode) {
          developer.log('Preload failed for plugin $pluginId: $e');
        }
      }
    }

    _isPreloading = false;
  }

  /// 开始关键插件预加载
  void _startPreloading() {
    // 预加载关键插件
    Timer(const Duration(milliseconds: 500), () {
      preloadPlugin('mediaserver');
    });
  }

  /// 获取插件状态
  PluginLoadState getPluginState(String pluginId) {
    return _loadStates[pluginId] ?? PluginLoadState.notLoaded;
  }

  /// 检查插件是否已加载
  bool isPluginLoaded(String pluginId) {
    return _loadedPlugins.containsKey(pluginId);
  }

  /// 获取已加载的插件
  CorePlugin? getPlugin(String pluginId) {
    return _loadedPlugins[pluginId];
  }

  /// 获取所有已加载的插件
  Map<String, CorePlugin> getLoadedPlugins() {
    return Map.unmodifiable(_loadedPlugins);
  }

  /// 获取可用的插件ID列表
  List<String> getAvailablePluginIds() {
    return _pluginFactories.keys.toList();
  }

  /// 卸载未使用的插件以释放内存
  void unloadUnusedPlugins({Duration unusedThreshold = const Duration(minutes: 5)}) {
    final now = DateTime.now();
    final pluginsToUnload = <String>[];

    for (final entry in _loadedPlugins.entries) {
      final pluginId = entry.key;
      final plugin = entry.value;

      // 如果插件未激活且超过阈值时间，则卸载
      if (!plugin.isActive &&
          _performanceService.metrics[pluginId]?.runtime != null &&
          _performanceService.metrics[pluginId]!.runtime! > unusedThreshold) {
        pluginsToUnload.add(pluginId);
      }
    }

    for (final pluginId in pluginsToUnload) {
      _unloadPlugin(pluginId);
      if (kDebugMode) {
        developer.log('Unloaded unused plugin: $pluginId');
      }
    }
  }

  /// 获取加载统计信息
  PluginLoadStats getLoadStats() {
    final totalPlugins = _pluginFactories.length;
    final loadedPlugins = _loadedPlugins.length;
    final loadingPlugins = _loadingFutures.length;
    final failedPlugins = _loadStates.values
        .where((state) => state == PluginLoadState.failed)
        .length;

    return PluginLoadStats(
      totalPlugins: totalPlugins,
      loadedPlugins: loadedPlugins,
      loadingPlugins: loadingPlugins,
      failedPlugins: failedPlugins,
    );
  }

  /// 批量加载插件
  Future<Map<String, CorePlugin>> loadMultiplePlugins(List<String> pluginIds) async {
    final results = <String, CorePlugin>{};

    // 并行加载多个插件
    final futures = pluginIds.map((pluginId) async {
      final plugin = await loadPlugin(pluginId);
      if (plugin != null) {
        return MapEntry(pluginId, plugin);
      }
      return null;
    }).where((result) => result != null);

    final entries = await Future.wait(futures.cast<Future<MapEntry<String, CorePlugin>>>());

    for (final entry in entries) {
      results[entry.key] = entry.value;
    }

    return results;
  }

  /// 重新加载插件
  Future<CorePlugin?> reloadPlugin(String pluginId) async {
    return await loadPlugin(pluginId, forceReload: true);
  }

  /// 清理所有插件
  Future<void> dispose() async {
    // 卸载所有插件
    for (final pluginId in _loadedPlugins.keys.toList()) {
      _unloadPlugin(pluginId);
    }

    // 清理资源
    _pluginFactories.clear();
    _loadedPlugins.clear();
    _loadStates.clear();
    _loadingFutures.clear();
    _preloadQueue.clear();
    _performanceService.dispose();

    if (kDebugMode) {
      developer.log('PluginLazyLoader disposed');
    }
  }

  /// 设置插件加载超时
  Future<CorePlugin?> loadPluginWithTimeout(
    String pluginId, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      return await loadPlugin(pluginId).timeout(timeout);
    } catch (e) {
      if (kDebugMode) {
        developer.log('Plugin load timeout for $pluginId: $e');
      }
      _loadStates[pluginId] = PluginLoadState.failed;
      return null;
    }
  }
}

/// 插件加载统计
class PluginLoadStats {
  final int totalPlugins;
  final int loadedPlugins;
  final int loadingPlugins;
  final int failedPlugins;

  const PluginLoadStats({
    required this.totalPlugins,
    required this.loadedPlugins,
    required this.loadingPlugins,
    required this.failedPlugins,
  });

  double get loadProgress => totalPlugins > 0 ? loadedPlugins / totalPlugins : 0.0;
  double get failureRate => totalPlugins > 0 ? failedPlugins / totalPlugins : 0.0;
}