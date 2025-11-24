import 'dart:async';
import 'dart:developer' as developer;
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/plugin_system/core_plugin.dart';
import '../core/plugin_system/plugin_interface.dart';

// 已实现的内置插件
import '../plugins/builtin/subtitle/subtitle_plugin.dart';
import '../plugins/builtin/audio_effects/audio_effects_plugin.dart';
import '../plugins/builtin/ui_themes/theme_plugin.dart';

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
    if (EditionConfig.isCommunityEdition) {
      // 🔧 社区版：只注册已实现的插件
      if (kDebugMode) {
        developer.log('🔧 Community Edition: Registering 3 plugin factories');
      }

      // 字幕插件 - 已实现
      _pluginFactories['coreplayer.subtitle'] = () async {
        final plugin = SubtitlePlugin();
        await _performanceService.startMonitoring('coreplayer.subtitle', plugin);
        return plugin;
      };

      // 音频效果插件 - 已实现
      _pluginFactories['coreplayer.audio_effects'] = () async {
        final plugin = AudioEffectsPlugin();
        await _performanceService.startMonitoring('coreplayer.audio_effects', plugin);
        return plugin;
      };

      // 主题管理插件 - 已实现
      _pluginFactories['coreplayer.theme_manager'] = () async {
        final plugin = ThemePlugin();
        await _performanceService.startMonitoring('coreplayer.theme_manager', plugin);
        return plugin;
      };
    } else {
      // 🔧 专业版：不使用懒加载器，由PluginLoader直接管理
      if (kDebugMode) {
        developer.log('🔧 Professional Edition: Plugins managed by PluginLoader');
      }
    }
  }

  /// 注册商业插件包中的插件
  Future<void> _registerCommercialPlugins() async {
    try {
      // 尝试导入商业插件包
      // 注意：这是动态导入，实际实现可能需要依赖注入或反射

      // HEVC 解码器插件
      _pluginFactories['hevc_decoder'] = () async {
        // 由于商业插件在独立包中，这里需要特殊处理
        // 暂时创建一个占位符，实际应该加载商业插件
        final plugin = _createCommercialPlaceholder(
          id: 'coreplayer.pro.decoder.hevc',
          name: 'HEVC 专业解码器',
          description: '专业级 HEVC/H.265 解码器，支持硬件加速',
          capabilities: ['video-decoding', 'hevc', 'hardware-acceleration'],
          icon: Icons.video_settings,
        );
        await _performanceService.startMonitoring('hevc_decoder', plugin);
        return plugin;
      };

      // AI 字幕插件
      _pluginFactories['ai_subtitle'] = () async {
        final plugin = _createCommercialPlaceholder(
          id: 'coreplayer.pro.subtitle.ai',
          name: 'AI 智能字幕',
          description: '基于人工智能的字幕生成和翻译',
          capabilities: ['subtitle-generation', 'translation', 'ai-processing'],
          icon: Icons.subtitles,
        );
        await _performanceService.startMonitoring('ai_subtitle', plugin);
        return plugin;
      };

      // 多设备同步插件
      _pluginFactories['multi_device_sync'] = () async {
        final plugin = _createCommercialPlaceholder(
          id: 'coreplayer.pro.sync.multi_device',
          name: '多设备同步',
          description: '跨设备播放进度、收藏和历史记录同步',
          capabilities: ['sync', 'cloud-storage', 'multi-device'],
          icon: Icons.sync,
        );
        await _performanceService.startMonitoring('multi_device_sync', plugin);
        return plugin;
      };

      // SMB 媒体服务器插件
      _pluginFactories['smb_media_server'] = () async {
        final plugin = _createCommercialPlaceholder(
          id: 'coreplayer.pro.media_server.smb',
          name: 'SMB/CIFS 媒体服务器',
          description: '企业级 SMB/CIFS 网络存储访问',
          capabilities: ['smb', 'cifs', 'network-storage', 'file-streaming'],
          icon: Icons.storage,
        );
        await _performanceService.startMonitoring('smb_media_server', plugin);
        return plugin;
      };

      // FTP 媒体服务器插件
      _pluginFactories['ftp_media_server'] = () async {
        final plugin = _createCommercialPlaceholder(
          id: 'coreplayer.pro.media_server.ftp',
          name: 'FTP/SFTP 媒体服务器',
          description: '安全的 FTP/SFTP 文件传输和流媒体',
          capabilities: ['ftp', 'sftp', 'secure-transfer', 'file-streaming'],
          icon: Icons.cloud_upload,
        );
        await _performanceService.startMonitoring('ftp_media_server', plugin);
        return plugin;
      };

      // NFS 媒体服务器插件
      _pluginFactories['nfs_media_server'] = () async {
        final plugin = _createCommercialPlaceholder(
          id: 'coreplayer.pro.media_server.nfs',
          name: 'NFS 网络文件系统',
          description: '高性能 NFS 网络文件系统支持',
          capabilities: ['nfs', 'network-file-system', 'high-performance'],
          icon: Icons.network_check,
        );
        await _performanceService.startMonitoring('nfs_media_server', plugin);
        return plugin;
      };

      if (kDebugMode) {
        developer.log('Registered ${_pluginFactories.length} commercial plugin factories');
      }
    } catch (e) {
      if (kDebugMode) {
        developer.log('Warning: Failed to register some commercial plugins: $e');
      }
    }
  }

  /// 创建商业插件占位符
  CorePlugin _createCommercialPlaceholder({
    required String id,
    required String name,
    required String description,
    required List<String> capabilities,
    required IconData icon,
  }) {
    // 创建一个简单的占位符插件，实际应该从商业包加载
    return _CommercialPluginPlaceholder(
      id: id,
      name: name,
      description: description,
      capabilities: capabilities,
      icon: icon,
    );
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
    // Timer(const Duration(milliseconds: 500), () {
    //   preloadPlugin('mediaserver');
    // });
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

/// 商业插件占位符
/// 用于在专业版中显示商业插件，但实际功能需要从商业包加载
class _CommercialPluginPlaceholder extends CorePlugin {
  final String _id;
  final String _name;
  final String _description;
  final List<String> _capabilities;
  final IconData _icon;
  PluginState _state = PluginState.uninitialized;

  _CommercialPluginPlaceholder({
    required String id,
    required String name,
    required String description,
    required List<String> capabilities,
    required IconData icon,
  })  : _id = id,
        _name = name,
        _description = description,
        _capabilities = capabilities,
        _icon = icon;

  @override
  PluginState get state => _state;

  @override
  void setStateInternal(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get staticMetadata => PluginMetadata(
        id: _id,
        name: _name,
        version: '1.0.0',
        description: _description,
        author: 'CorePlayer Team',
        icon: _icon,
        capabilities: _capabilities,
        permissions: const [],
        license: PluginLicense.proprietary,
      );

  @override
  Future<void> initialize() async {
    setStateInternal(PluginState.initializing);
    // 商业插件的实际初始化逻辑应该从商业包加载
    if (kDebugMode) {
      developer.log('Commercial plugin placeholder initialized: $_id');
    }
    setStateInternal(PluginState.ready);
  }

  @override
  Future<void> activate() async {
    // 商业插件的实际激活逻辑应该从商业包加载
    if (kDebugMode) {
      developer.log('Commercial plugin placeholder activated: $_id');
    }
    setStateInternal(PluginState.active);
  }

  @override
  Future<void> deactivate() async {
    // 商业插件的实际停用逻辑应该从商业包加载
    if (kDebugMode) {
      developer.log('Commercial plugin placeholder deactivated: $_id');
    }
    setStateInternal(PluginState.inactive);
  }

  @override
  Future<bool> healthCheck() async {
    // 商业插件的健康检查
    return true;
  }

  @override
  Widget? buildSettingsScreen(BuildContext context) {
    // 商业插件的设置界面
    return null;
  }
}