import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meta/meta.dart';
import 'plugin_interface.dart';
import 'core_plugin.dart';
import 'plugin_registry.dart';
import 'media_server_plugin.dart';
import 'plugins/media_server/placeholders/media_server_placeholder.dart';
import 'plugins/media_server/smb/smb_plugin.dart';

/// 应用版本配置
class EditionConfig {
  static const String community = 'community';
  static const String pro = 'pro';

  static String get currentEdition {
    const edition = String.fromEnvironment('EDITION', defaultValue: community);
    return edition;
  }

  static bool get isCommunityEdition => currentEdition == community;
  static bool get isProEdition => currentEdition == pro;

  /// 检查特定版本是否可用
  static bool isEditionAvailable(String edition) {
    return currentEdition == edition;
  }
}

/// 插件加载配置
class PluginLoadConfig {
  final bool autoActivate;
  final bool enableLazyLoading;
  final Duration loadTimeout;
  final int maxConcurrentLoads;
  final List<String> disabledPlugins;
  final Map<String, dynamic> pluginSettings;

  const PluginLoadConfig({
    this.autoActivate = true,
    this.enableLazyLoading = true,
    this.loadTimeout = const Duration(seconds: 30),
    this.maxConcurrentLoads = 3,
    this.disabledPlugins = const [],
    this.pluginSettings = const {},
  });

  factory PluginLoadConfig.fromJson(Map<String, dynamic> json) {
    return PluginLoadConfig(
      autoActivate: json['autoActivate'] as bool? ?? true,
      enableLazyLoading: json['enableLazyLoading'] as bool? ?? true,
      loadTimeout: Duration(
        milliseconds: json['loadTimeout'] as int? ?? 30000,
      ),
      maxConcurrentLoads: json['maxConcurrentLoads'] as int? ?? 3,
      disabledPlugins: (json['disabledPlugins'] as List<dynamic>?)?.cast<String>() ?? [],
      pluginSettings: json['pluginSettings'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'autoActivate': autoActivate,
      'enableLazyLoading': enableLazyLoading,
      'loadTimeout': loadTimeout.inMilliseconds,
      'maxConcurrentLoads': maxConcurrentLoads,
      'disabledPlugins': disabledPlugins,
      'pluginSettings': pluginSettings,
    };
  }
}

/// 插件加载器
///
/// 负责插件的发现、加载、初始化和管理。支持社区版和专业版的条件编译。
class PluginLoader {
  final PluginRegistry _registry = PluginRegistry();
  final PluginLoadConfig _config;

  bool _isInitialized = false;
  final Map<String, Future<CorePlugin>> _lazyPlugins = {};
  final List<String> _loadedPluginIds = [];

  PluginLoader({PluginLoadConfig? config})
      : _config = config ?? const PluginLoadConfig() {
    _setupLogging();
  }

  /// 获取加载配置
  PluginLoadConfig get config => _config;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 已加载的插件ID列表
  List<String> get loadedPluginIds => List.unmodifiable(_loadedPluginIds);

  /// 初始化插件系统
  Future<void> initialize() async {
    if (_isInitialized) {
      _log('PluginLoader already initialized');
      return;
    }

    try {
      _log('Initializing plugin system...');

      // 加载内置插件
      await _loadBuiltInPlugins();

      // 自动激活插件
      if (_config.autoActivate) {
        await _autoActivatePlugins();
      }

      _isInitialized = true;
      _log('✅ Plugin system initialized successfully');
    } catch (e) {
      _log('❌ Failed to initialize plugin system: $e');
      rethrow;
    }
  }

  /// 加载所有内置插件
  Future<void> loadBuiltInPlugins() async {
    if (!_isInitialized) {
      await initialize();
    } else {
      await _loadBuiltInPlugins();
    }
  }

  /// 动态加载插件（未来扩展）
  Future<void> loadDynamicPlugin(String path) async {
    throw UnimplementedError('Dynamic plugin loading not yet supported');
  }

  /// 激活指定插件
  Future<void> activatePlugin(String pluginId) async {
    try {
      final plugin = _registry.get<CorePlugin>(pluginId);
      if (plugin == null) {
        throw PluginActivationException('Plugin $pluginId not found');
      }

      if (!plugin.isInitialized) {
        await plugin.initialize();
      }

      if (!plugin.isActive) {
        await _registry.activateWithDependencies(pluginId);
      }

      _log('✅ Plugin activated: $pluginId');
    } catch (e) {
      _log('❌ Failed to activate plugin $pluginId: $e');
      rethrow;
    }
  }

  /// 停用指定插件
  Future<void> deactivatePlugin(String pluginId) async {
    try {
      final plugin = _registry.get<CorePlugin>(pluginId);
      if (plugin == null) {
        throw PluginActivationException('Plugin $pluginId not found');
      }

      if (plugin.isActive) {
        await _registry.deactivateWithDependents(pluginId);
      }

      _log('✅ Plugin deactivated: $pluginId');
    } catch (e) {
      _log('❌ Failed to deactivate plugin $pluginId: $e');
      rethrow;
    }
  }

  /// 重新加载插件
  Future<void> reloadPlugin(String pluginId) async {
    try {
      // 先停用
      await deactivatePlugin(pluginId);

      // 重新激活
      await activatePlugin(pluginId);

      _log('✅ Plugin reloaded: $pluginId');
    } catch (e) {
      _log('❌ Failed to reload plugin $pluginId: $e');
      rethrow;
    }
  }

  /// 预加载常用插件
  Future<void> preloadCommonPlugins() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentPlugins = prefs.getStringList('recent_plugins') ?? [];

      // 预加载前3个常用插件
      for (final pluginId in recentPlugins.take(3)) {
        final plugin = _registry.get<CorePlugin>(pluginId);
        if (plugin != null && !plugin.isActive) {
          _log('Preloading plugin: $pluginId');
          unawaited(activatePlugin(pluginId));
        }
      }
    } catch (e) {
      _log('Warning: Failed to preload common plugins: $e');
    }
  }

  /// 获取插件统计信息
  Map<String, dynamic> getStatistics() {
    final registryStats = _registry.getStatistics();

    return {
      ...registryStats,
      'loader': {
        'initialized': _isInitialized,
        'config': _config.toJson(),
        'loadedPlugins': _loadedPluginIds.length,
        'lazyPluginsCount': _lazyPlugins.length,
      },
    };
  }

  /// 导出加载配置
  Map<String, dynamic> exportConfiguration() {
    return {
      'version': '1.0.0',
      'edition': EditionConfig.currentEdition,
      'loaderConfig': _config.toJson(),
      'loadedPlugins': _loadedPluginIds,
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  /// 保存插件配置
  Future<void> savePluginConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 保存加载配置
      await prefs.setString(
        'plugin_loader_config',
        jsonEncode(_config.toJson()),
      );

      // 保存已加载插件列表
      await prefs.setStringList(
        'loaded_plugins',
        _loadedPluginIds,
      );

      _log('Plugin configuration saved');
    } catch (e) {
      _log('Failed to save plugin configuration: $e');
    }
  }

  /// 恢复插件配置
  Future<void> restorePluginConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 恢复加载配置
      final configJson = prefs.getString('plugin_loader_config');
      if (configJson != null) {
        final configMap = jsonDecode(configJson) as Map<String, dynamic>;
        // 注意：这里不能直接修改 _config，因为它是一个 final 字段
        // 在实际使用中，可能需要重新创建 PluginLoader 实例
      }

      // 恢复已加载插件列表
      final loadedPlugins = prefs.getStringList('loaded_plugins');
      if (loadedPlugins != null) {
        _loadedPluginIds.clear();
        _loadedPluginIds.addAll(loadedPlugins);
      }

      _log('Plugin configuration restored');
    } catch (e) {
      _log('Failed to restore plugin configuration: $e');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    _log('Disposing PluginLoader...');

    // 清理懒加载插件
    _lazyPlugins.clear();

    // 释放注册表
    await _registry.dispose();

    // 保存配置
    await savePluginConfiguration();

    _log('✅ PluginLoader disposed');
  }

  // ===== 私有方法 =====

  /// 设置日志记录
  void _setupLogging() {
    if (kDebugMode) {
      _registry.setLogger((message) => print('[PluginLoader] $message'));
    }
  }

  /// 记录日志
  void _log(String message) {
    if (kDebugMode) {
      print('[PluginLoader] $message');
    }
  }

  /// 加载内置插件
  Future<void> _loadBuiltInPlugins() async {
    _log('Loading built-in plugins for edition: ${EditionConfig.currentEdition}');

    try {
      final plugins = _getBuiltInPlugins();
      final semaphore = _createSemaphore(_config.maxConcurrentLoads);

      final futures = plugins.map((plugin) async {
        await semaphore.acquire();
        try {
          await _loadPlugin(plugin);
        } finally {
          semaphore.release();
        }
      });

      await Future.wait(futures);

      _log('✅ Built-in plugins loaded: ${plugins.length}');
    } catch (e) {
      _log('❌ Failed to load built-in plugins: $e');
      rethrow;
    }
  }

  /// 获取内置插件列表
  List<CorePlugin> _getBuiltInPlugins() {
    final plugins = <CorePlugin>[];

    // 根据编译配置返回不同的插件列表
    if (EditionConfig.isCommunityEdition) {
      // 社区版：仅占位符
      plugins.addAll(_getCommunityEditionPlugins());
    } else {
      // 专业版：实际插件
      plugins.addAll(_getProEditionPlugins());
    }

    // 过滤禁用的插件
    return plugins
        .where((plugin) => !_config.disabledPlugins.contains(plugin.metadata.id))
        .toList();
  }

  /// 社区版插件列表
  List<CorePlugin> _getCommunityEditionPlugins() {
    return [
      MediaServerPlaceholderPlugin(),
    ];
  }

  /// 专业版插件列表
  List<CorePlugin> _getProEditionPlugins() {
    return [
      SMBPlugin(),
      // 未来可以添加 Emby、Jellyfin 等插件
    ];
  }

  /// 加载单个插件
  Future<void> _loadPlugin(CorePlugin plugin) async {
    final pluginId = plugin.metadata.id;

    try {
      _log('Loading plugin: ${plugin.metadata.name}');

      // 注册插件
      await _registry.register(plugin);

      // 初始化插件（如果不是懒加载）
      if (!_config.enableLazyLoading) {
        await plugin.initialize();
      }

      _loadedPluginIds.add(pluginId);

      _log('✅ Plugin loaded: $pluginId');
    } catch (e) {
      _log('❌ Failed to load plugin $pluginId: $e');
      throw PluginInitializationException(
        'Failed to load plugin $pluginId: $e',
        pluginId: pluginId,
        originalError: e,
      );
    }
  }

  /// 自动激活插件
  Future<void> _autoActivatePlugins() async {
    try {
      _log('Auto-activating plugins...');

      final prefs = await SharedPreferences.getInstance();
      final activePlugins = prefs.getStringList('active_plugins') ?? [];

      // 如果没有保存的活跃插件列表，激活所有默认插件
      if (activePlugins.isEmpty) {
        await _activateDefaultPlugins();
      } else {
        await _activateSavedPlugins(activePlugins);
      }

      _log('✅ Auto-activation completed');
    } catch (e) {
      _log('❌ Auto-activation failed: $e');
    }
  }

  /// 激活默认插件
  Future<void> _activateDefaultPlugins() async {
    // 根据版本激活相应的默认插件
    final defaultPlugins = EditionConfig.isCommunityEdition
        ? ['com.coreplayer.mediaserver.placeholder']
        : ['com.coreplayer.smb', 'com.coreplayer.emby', 'com.coreplayer.jellyfin'];

    for (final pluginId in defaultPlugins) {
      final plugin = _registry.get<CorePlugin>(pluginId);
      if (plugin != null && !plugin.isActive) {
        try {
          await activatePlugin(pluginId);
        } catch (e) {
          _log('Warning: Failed to activate default plugin $pluginId: $e');
        }
      }
    }
  }

  /// 激活保存的插件
  Future<void> _activateSavedPlugins(List<String> pluginIds) async {
    for (final pluginId in pluginIds) {
      final plugin = _registry.get<CorePlugin>(pluginId);
      if (plugin != null && !plugin.isActive) {
        try {
          await activatePlugin(pluginId);
        } catch (e) {
          _log('Warning: Failed to activate saved plugin $pluginId: $e');
        }
      }
    }
  }

  /// 创建信号量
  Semaphore _createSemaphore(int maxCount) {
    return Semaphore(maxCount);
  }

  /// 更新最近使用的插件
  Future<void> _updateRecentPlugins(String pluginId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentPlugins = prefs.getStringList('recent_plugins') ?? [];

      // 移除旧的记录
      recentPlugins.remove(pluginId);

      // 添加到最前面
      recentPlugins.insert(0, pluginId);

      // 保持最多10个记录
      if (recentPlugins.length > 10) {
        recentPlugins.removeRange(10, recentPlugins.length);
      }

      await prefs.setStringList('recent_plugins', recentPlugins);
    } catch (e) {
      _log('Warning: Failed to update recent plugins: $e');
    }
  }
}

/// 简单的信号量实现
class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Semaphore(this.maxCount) : _currentCount = maxCount;

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}

/// 不等待的Future执行
void unawaited(Future<void> future) {
  // Intentionally not awaiting the future
}

/// 插件加载器单例
late final PluginLoader pluginLoader;

/// 初始化插件系统
Future<void> initializePluginSystem({
  PluginLoadConfig? config,
}) async {
  pluginLoader = PluginLoader(config: config);
  await pluginLoader.initialize();
}