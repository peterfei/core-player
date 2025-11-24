import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'plugin_interface.dart';
import 'core_plugin.dart';
import 'plugin_metadata_loader.dart';

/// 插件注册表
///
/// 负责管理所有已注册的插件，提供插件的注册、注销、查询等功能。
class PluginRegistry {
  static final PluginRegistry _instance = PluginRegistry._internal();
  factory PluginRegistry() => _instance;
  PluginRegistry._internal() {
    _initializeLogging();
  }

  /// 已注册的插件映射 (pluginId -> plugin)
  final Map<String, CorePlugin> _plugins = {};

  /// 插件元数据映射 (pluginId -> metadata)
  final Map<String, PluginMetadata> _metadata = {};

  /// 插件依赖关系映射 (pluginId -> [dependencyIds])
  final Map<String, List<String>> _dependencies = {};

  /// 事件流控制器
  final StreamController<PluginEvent> _eventController =
      StreamController<PluginEvent>.broadcast();

  /// 插件状态变化监听器
  final Map<String, StreamSubscription> _stateSubscriptions = {};

  /// 日志记录器
  void Function(String message)? _logger;

  /// 获取所有插件事件流
  Stream<PluginEvent> get events => _eventController.stream;

  /// 注册插件
  Future<void> register(CorePlugin plugin) async {
    try {
      final pluginId = plugin.metadata.id;

      if (_plugins.containsKey(pluginId)) {
        throw PluginActivationException(
          'Plugin with ID $pluginId already registered',
          pluginId: pluginId,
        );
      }

      // 验证插件元数据
      _validateMetadata(plugin.metadata);

      // 记录插件注册开始
      _log('Registering plugin: ${plugin.metadata.name} v${plugin.metadata.version}');

      // 注册插件
      _plugins[pluginId] = plugin;
      _metadata[pluginId] = plugin.metadata;
      _dependencies[pluginId] = plugin.metadata.dependencies;

      // 监听插件状态变化
      _setupStateListener(plugin);

      // 发送注册事件
      _emitEvent(PluginEvent.registered(pluginId));

      _log('✅ Plugin registered successfully: $pluginId');
    } catch (e) {
      _log('❌ Failed to register plugin ${plugin.metadata.id}: $e');
      rethrow;
    }
  }

  /// 注销插件
  Future<void> unregister(String pluginId, {bool force = false}) async {
    try {
      final plugin = _plugins[pluginId];
      if (plugin == null) {
        throw PluginActivationException(
          'Plugin with ID $pluginId not found',
          pluginId: pluginId,
        );
      }

      _log('Unregistering plugin: $pluginId');

      // 检查依赖关系
      if (!force) {
        final dependents = _getDependents(pluginId);
        if (dependents.isNotEmpty) {
          throw PluginDependencyException(
            'Cannot unregister plugin $pluginId: it has dependent plugins: ${dependents.join(', ')}',
            pluginId: pluginId,
          );
        }
      }

      // 停止监听状态变化
      await _removeStateListener(pluginId);

      // 释放插件资源
      await plugin.dispose();

      // 从注册表中移除
      _plugins.remove(pluginId);
      _metadata.remove(pluginId);
      _dependencies.remove(pluginId);

      // 发送注销事件
      _emitEvent(PluginEvent.unregistered(pluginId));

      _log('✅ Plugin unregistered successfully: $pluginId');
    } catch (e) {
      _log('❌ Failed to unregister plugin $pluginId: $e');
      rethrow;
    }
  }

  /// 获取插件
  T? get<T extends CorePlugin>(String pluginId) {
    final plugin = _plugins[pluginId];
    if (plugin == null) return null;

    if (plugin is! T) {
      throw PluginActivationException(
        'Plugin $pluginId is not of type $T',
        pluginId: pluginId,
      );
    }

    return plugin;
  }

  /// 获取插件（或抛出异常）
  T getOrFail<T extends CorePlugin>(String pluginId) {
    final plugin = get<T>(pluginId);
    if (plugin == null) {
      throw PluginActivationException(
        'Plugin with ID $pluginId not found or not of type $T',
        pluginId: pluginId,
      );
    }
    return plugin;
  }

  /// 获取指定类型的所有插件
  List<T> getByType<T extends CorePlugin>() {
    return _plugins.values
        .whereType<T>()
        .toList(growable: false);
  }

  /// 检查插件是否存在
  bool hasPlugin(String pluginId) {
    return _plugins.containsKey(pluginId);
  }

  /// 检查插件是否已激活
  bool isPluginActive(String pluginId) {
    final plugin = _plugins[pluginId];
    return plugin?.isActive ?? false;
  }

  /// 列出所有插件
  List<CorePlugin> listAll() {
    return UnmodifiableListView(_plugins.values);
  }

  /// 列出所有插件元数据
  List<PluginMetadata> listAllMetadata() {
    return UnmodifiableListView(_metadata.values);
  }

  /// 获取插件元数据
  PluginMetadata? getMetadata(String pluginId) {
    return _metadata[pluginId];
  }

  /// 根据能力获取插件
  List<CorePlugin> getByCapability(String capability) {
    return _plugins.values
        .where((plugin) => plugin.metadata.capabilities.contains(capability))
        .toList(growable: false);
  }

  /// 检查插件依赖
  Future<bool> checkDependencies(String pluginId) async {
    final dependencies = _dependencies[pluginId] ?? [];

    for (final depId in dependencies) {
      if (!_plugins.containsKey(depId)) {
        return false; // 依赖插件未注册
      }

      final depPlugin = _plugins[depId]!;
      if (!depPlugin.isActive) {
        return false; // 依赖插件未激活
      }
    }

    return true;
  }

  /// 获取插件的所有依赖
  List<String> getDependencies(String pluginId) {
    return List.unmodifiable(_dependencies[pluginId] ?? []);
  }

  /// 获取依赖于指定插件的所有插件
  List<String> getDependents(String pluginId) {
    return List.unmodifiable(_getDependents(pluginId));
  }

  /// 激活插件及其依赖
  Future<void> activateWithDependencies(String pluginId) async {
    await _activatePluginWithDependencies(pluginId, <String>{});
  }

  /// 停用插件及其依赖者
  Future<void> deactivateWithDependents(String pluginId) async {
    final dependents = _getDependents(pluginId);

    // 先停用所有依赖者
    for (final dependent in dependents) {
      if (isPluginActive(dependent)) {
        final dependentPlugin = _plugins[dependent]!;
        await dependentPlugin.deactivate();
      }
    }

    // 然后停用目标插件
    if (isPluginActive(pluginId)) {
      final plugin = _plugins[pluginId]!;
      await plugin.deactivate();
    }
  }

  /// 清空所有插件
  Future<void> clear({bool force = false}) async {
    _log('Clearing all plugins...');

    final pluginIds = List<String>.from(_plugins.keys);

    // 按依赖顺序反向注销
    for (final pluginId in pluginIds) {
      try {
        await unregister(pluginId, force: force);
      } catch (e) {
        _log('Warning: Failed to unregister plugin $pluginId during clear: $e');
      }
    }

    _log('✅ All plugins cleared');
  }

  /// 获取插件统计信息
  Map<String, dynamic> getStatistics() {
    final totalPlugins = _plugins.length;
    final activePlugins = _plugins.values.where((p) => p.isActive).length;
    final errorPlugins = _plugins.values.where((p) => p.hasError).length;

    final typeStats = <String, int>{};
    for (final plugin in _plugins.values) {
      final type = plugin.runtimeType.toString();
      typeStats[type] = (typeStats[type] ?? 0) + 1;
    }

    return {
      'total': totalPlugins,
      'active': activePlugins,
      'inactive': totalPlugins - activePlugins,
      'error': errorPlugins,
      'types': typeStats,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  /// 导出插件配置
  Map<String, dynamic> exportConfiguration() {
    final config = {
      'version': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'plugins': <String, dynamic>{},
    };

    for (final entry in _metadata.entries) {
      final pluginId = entry.key;
      final metadata = entry.value;
      final plugin = _plugins[pluginId];

      (config['plugins'] as Map<String, dynamic>)[pluginId] = {
        'metadata': metadata.toJson(),
        'active': plugin?.isActive ?? false,
        'dependencies': _dependencies[pluginId] ?? [],
      };
    }

    return config;
  }

  /// 设置日志记录器
  void setLogger(void Function(String message) logger) {
    _logger = logger;
  }

  // ===== 私有方法 =====

  /// 初始化日志记录
  void _initializeLogging() {
    if (kDebugMode) {
      _logger = (message) => print('[PluginRegistry] $message');
    }
  }

  /// 记录日志
  void _log(String message) {
    _logger?.call(message);
  }

  /// 发送事件
  void _emitEvent(PluginEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// 验证插件元数据
  void _validateMetadata(PluginMetadata metadata) {
    if (metadata.id.isEmpty) {
      throw PluginActivationException('Plugin ID cannot be empty');
    }

    if (metadata.name.isEmpty) {
      throw PluginActivationException('Plugin name cannot be empty');
    }

    if (metadata.version.isEmpty) {
      throw PluginActivationException('Plugin version cannot be empty');
    }

    // 验证版本格式
    final versionPattern = RegExp(r'^\d+\.\d+\.\d+$');
    if (!versionPattern.hasMatch(metadata.version)) {
      throw PluginActivationException(
        'Invalid version format: ${metadata.version}. Expected format: x.y.z',
      );
    }
  }

  /// 设置插件状态监听器
  void _setupStateListener(CorePlugin plugin) {
    final subscription = plugin.stateStream.listen((state) {
      if (state == PluginState.error) {
        _emitEvent(PluginEvent.error(
          plugin.metadata.id,
          'Plugin entered error state',
        ));
      } else if (state == PluginState.active) {
        _emitEvent(PluginEvent.activated(plugin.metadata.id));
      } else if (state == PluginState.inactive) {
        _emitEvent(PluginEvent.deactivated(plugin.metadata.id));
      }
    });

    _stateSubscriptions[plugin.metadata.id] = subscription;
  }

  /// 移除插件状态监听器
  Future<void> _removeStateListener(String pluginId) async {
    final subscription = _stateSubscriptions.remove(pluginId);
    if (subscription != null) {
      await subscription.cancel();
    }
  }

  /// 获取依赖于指定插件的所有插件（私有方法）
  List<String> _getDependents(String pluginId) {
    final dependents = <String>[];

    for (final entry in _dependencies.entries) {
      if (entry.value.contains(pluginId)) {
        dependents.add(entry.key);
      }
    }

    return dependents;
  }

  /// 递归激活插件及其依赖（私有方法）
  Future<void> _activatePluginWithDependencies(String pluginId, Set<String> visited) async {
    if (visited.contains(pluginId)) {
      throw PluginDependencyException(
        'Circular dependency detected: $pluginId',
        pluginId: pluginId,
      );
    }

    final plugin = _plugins[pluginId];
    if (plugin == null) {
      throw PluginActivationException(
        'Plugin with ID $pluginId not found',
        pluginId: pluginId,
      );
    }

    if (plugin.isActive) {
      return; // 已经激活
    }

    visited.add(pluginId);

    try {
      // 先激活所有依赖
      final dependencies = _dependencies[pluginId] ?? [];
      for (final depId in dependencies) {
        await _activatePluginWithDependencies(depId, visited);
      }

      // 初始化插件（如果还未初始化）
      if (!plugin.isInitialized) {
        await plugin.initialize();
      }

      // 激活插件
      await plugin.activate();

      _log('✅ Plugin activated: $pluginId');
    } finally {
      visited.remove(pluginId);
    }
  }

  /// 更新插件元数据
  ///
  /// [pluginId] 插件ID
  /// [pluginPath] 插件路径
  Future<void> updateMetadata(String pluginId, String pluginPath) async {
    try {
      final loader = PluginMetadataLoader();
      final newMetadata = await loader.loadFromFile(pluginPath);

      // 检查插件是否已注册
      final existingPlugin = _plugins[pluginId];
      if (existingPlugin == null) {
        _log('⚠️ Plugin not found for metadata update: $pluginId');
        return;
      }

      // 更新元数据
      _metadata[pluginId] = newMetadata;
      _log('✅ Updated metadata for $pluginId to v${newMetadata.version}');

      // 获取当前元数据用于比较
      final currentMetadata = getMetadata(pluginId);
      final oldVersion = currentMetadata?.version ?? 'unknown';

      // 发送元数据更新事件
      _eventController.add(PluginEvent.updated(
        pluginId,
        data: {
          'pluginName': newMetadata.name,
          'oldVersion': oldVersion,
          'newVersion': newMetadata.version,
          'path': pluginPath,
        },
      ));
    } catch (e) {
      _log('❌ Failed to update metadata for $pluginId: $e');
      throw PluginRegistryException(
        'Failed to update metadata',
        pluginId: pluginId,
      );
    }
  }

  void updateMetadataDirectly(String pluginId, PluginMetadata newMetadata) {
    try {
      // 检查插件是否已注册
      final existingPlugin = _plugins[pluginId];
      if (existingPlugin == null) {
        _log('⚠️ Plugin not found for metadata update: $pluginId');
        return;
      }

      final oldVersion = _metadata[pluginId]?.version ?? 'unknown';

      // 更新注册表中的元数据
      _metadata[pluginId] = newMetadata;
      
      // 🔧 关键:同时更新插件实例的元数据,这样UI才能显示新版本
      existingPlugin.updateMetadata(newMetadata);
      
      _log('✅ Updated metadata for $pluginId: v$oldVersion → v${newMetadata.version}');

      // 发送元数据更新事件
      _eventController.add(PluginEvent.updated(
        pluginId,
        data: {
          'pluginName': newMetadata.name,
          'oldVersion': oldVersion,
          'newVersion': newMetadata.version,
        },
      ));
    } catch (e) {
      _log('❌ Failed to update metadata for $pluginId: $e');
    }
  }

  /// 验证插件更新是否成功
  ///
  /// [pluginId] 插件ID
  /// [expectedVersion] 期望的版本号
  /// 返回是否验证成功
  Future<bool> verifyPluginUpdate(String pluginId, String expectedVersion) async {
    try {
      final currentMetadata = getMetadata(pluginId);
      if (currentMetadata == null) {
        _log('❌ Cannot verify update - plugin not found: $pluginId');
        return false;
      }

      final isUpdated = currentMetadata.version == expectedVersion;
      _log('Plugin $pluginId verification: v${currentMetadata.version} (expected: v$expectedVersion) - ${isUpdated ? '✅' : '❌'}');

      return isUpdated;
    } catch (e) {
      _log('❌ Failed to verify plugin update for $pluginId: $e');
      return false;
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    _log('Disposing PluginRegistry...');

    await _eventController.close();

    for (final subscription in _stateSubscriptions.values) {
      await subscription.cancel();
    }
    _stateSubscriptions.clear();

    await clear();

    _log('✅ PluginRegistry disposed');
  }
}

/// 插件注册表单例
final pluginRegistry = PluginRegistry();

/// 插件注册异常
class PluginRegistryException extends PluginException {
  PluginRegistryException(String message, {String? pluginId})
      : super(message, pluginId: pluginId);
}

/// 插件依赖冲突异常
class PluginDependencyConflictException extends PluginDependencyException {
  PluginDependencyConflictException(String message, {String? pluginId})
      : super(message, pluginId: pluginId);
}