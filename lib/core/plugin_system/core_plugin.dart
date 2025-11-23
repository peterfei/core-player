import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'plugin_interface.dart';

/// 资源限制配置
@immutable
class ResourceLimits {
  final int maxMemoryMB;
  final Duration maxExecutionTime;
  final int maxStorageMB;
  final int maxNetworkRequestsPerMinute;

  const ResourceLimits({
    this.maxMemoryMB = 512,
    this.maxExecutionTime = const Duration(seconds: 30),
    this.maxStorageMB = 1024,
    this.maxNetworkRequestsPerMinute = 60,
  });
}

/// 插件沙箱
class PluginSandbox {
  final String pluginId;
  final Set<PluginPermission> permissions;
  final ResourceLimits limits;

  late final String _dataPath;
  late final SharedPreferences _prefs;
  bool _isInitialized = false;

  PluginSandbox(this.pluginId, {
    required this.permissions,
    this.limits = const ResourceLimits(),
  });

  /// 初始化沙箱
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 创建独立的数据目录
      final appDir = await getApplicationDocumentsDirectory();
      _dataPath = path.join(appDir.path, 'plugins', pluginId);
      await Directory(_dataPath).create(recursive: true);

      // 获取 SharedPreferences 实例
      _prefs = await SharedPreferences.getInstance();

      _isInitialized = true;
    } catch (e) {
      throw PluginInitializationException(
        'Failed to initialize sandbox for plugin $pluginId',
        pluginId: pluginId,
        originalError: e,
      );
    }
  }

  /// 检查权限
  bool hasPermission(PluginPermission permission) {
    return permissions.contains(permission);
  }

  /// 获取插件数据路径
  String getDataPath([String? subPath]) {
    if (!_isInitialized) {
      throw StateError('PluginSandbox not initialized for $pluginId');
    }
    return subPath != null
        ? path.join(_dataPath, subPath)
        : _dataPath;
  }

  /// 获取插件配置
  String? getString(String key) {
    if (!_isInitialized) {
      throw StateError('PluginSandbox not initialized for $pluginId');
    }
    return _prefs.getString('plugin.$pluginId.$key');
  }

  /// 保存插件配置
  Future<bool> setString(String key, String value) async {
    if (!_isInitialized) {
      throw StateError('PluginSandbox not initialized for $pluginId');
    }
    return await _prefs.setString('plugin.$pluginId.$key', value);
  }

  /// 获取插件配置（布尔值）
  bool? getBool(String key) {
    if (!_isInitialized) {
      throw StateError('PluginSandbox not initialized for $pluginId');
    }
    return _prefs.getBool('plugin.$pluginId.$key');
  }

  /// 保存插件配置（布尔值）
  Future<bool> setBool(String key, bool value) async {
    if (!_isInitialized) {
      throw StateError('PluginSandbox not initialized for $pluginId');
    }
    return await _prefs.setBool('plugin.$pluginId.$key', value);
  }

  /// 获取插件配置（整数）
  int? getInt(String key) {
    if (!_isInitialized) {
      throw StateError('PluginSandbox not initialized for $pluginId');
    }
    return _prefs.getInt('plugin.$pluginId.$key');
  }

  /// 保存插件配置（整数）
  Future<bool> setInt(String key, int value) async {
    if (!_isInitialized) {
      throw StateError('PluginSandbox not initialized for $pluginId');
    }
    return await _prefs.setInt('plugin.$pluginId.$key', value);
  }

  /// 清理插件数据
  Future<void> cleanup() async {
    try {
      if (_isInitialized) {
        final directory = Directory(_dataPath);
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    } catch (e) {
      // 记录错误但不抛出异常
      print('Warning: Failed to cleanup sandbox for plugin $pluginId: $e');
    }
  }
}

/// 核心插件接口
abstract class CorePlugin {
  /// 动态元数据（从配置文件加载）
  PluginMetadata? _dynamicMetadata;

  /// 构造函数,支持可选的动态 metadata
  CorePlugin({PluginMetadata? metadata}) : _dynamicMetadata = metadata;

  /// 插件元数据 - 优先使用动态 metadata，否则使用静态默认值
  PluginMetadata get metadata => _dynamicMetadata ?? staticMetadata;

  /// 静态元数据（子类实现的默认值）
  @protected
  PluginMetadata get staticMetadata;

  /// 更新元数据（用于热更新）
  void updateMetadata(PluginMetadata newMetadata) {
    _dynamicMetadata = newMetadata;
  }

  /// 当前状态
  PluginState get state;

  /// 状态变化控制器
  StreamController<PluginState>? _stateController;

  /// 状态流
  Stream<PluginState> get stateStream {
    _stateController ??= StreamController<PluginState>.broadcast();
    return _stateController!.stream;
  }

  /// 插件是否已激活
  bool get isActive => state == PluginState.active;

  /// 插件是否就绪
  bool get isReady => state == PluginState.ready || state == PluginState.active;

  /// 插件是否有错误
  bool get hasError => state == PluginState.error;

  /// 插件是否已初始化
  bool get isInitialized => state != PluginState.uninitialized;

  /// 更新状态（受保护方法）
  @protected
  void updateState(PluginState newState) {
    if (state == newState) return;

    final oldState = state;
    setStateInternal(newState);
    _stateController?.add(newState);

    print('Plugin ${metadata.id} state changed: $oldState -> $newState');
  }

  /// 内部状态设置
  @protected
  void setStateInternal(PluginState state);

  /// 插件沙箱
  PluginSandbox? _sandbox;

  /// 获取插件沙箱
  PluginSandbox? get sandbox => _sandbox;

  /// 初始化插件
  Future<void> initialize() async {
    if (isInitialized) {
      throw PluginInitializationException(
        'Plugin ${metadata.id} is already initialized',
        pluginId: metadata.id,
      );
    }

    try {
      updateState(PluginState.initializing);

      // 创建沙箱
      _sandbox = PluginSandbox(
        metadata.id,
        permissions: Set.from(metadata.permissions),
      );
      await _sandbox!.initialize();

      // 调用子类初始化
      await onInitialize();

      updateState(PluginState.ready);
      print('Plugin ${metadata.name} initialized successfully');
    } catch (e) {
      updateState(PluginState.error);
      throw PluginInitializationException(
        'Failed to initialize plugin ${metadata.id}: $e',
        pluginId: metadata.id,
        originalError: e,
      );
    }
  }

  /// 子类初始化回调
  @protected
  Future<void> onInitialize() async {
    // 子类可以重写此方法
  }

  /// 激活插件
  Future<void> activate() async {
    if (state == PluginState.active) {
      return; // 已经激活
    }

    if (state != PluginState.ready && state != PluginState.inactive) {
      throw PluginActivationException(
        'Cannot activate plugin ${metadata.id} in state $state',
        pluginId: metadata.id,
      );
    }

    try {
      // 调用子类激活
      await onActivate();
      updateState(PluginState.active);
      print('Plugin ${metadata.name} activated successfully');
    } catch (e) {
      throw PluginActivationException(
        'Failed to activate plugin ${metadata.id}: $e',
        pluginId: metadata.id,
        originalError: e,
      );
    }
  }

  /// 子类激活回调
  @protected
  Future<void> onActivate() async {
    // 子类可以重写此方法
  }

  /// 停用插件
  Future<void> deactivate() async {
    if (state != PluginState.active) {
      return; // 已经停用
    }

    try {
      // 调用子类停用
      await onDeactivate();
      updateState(PluginState.inactive);
      print('Plugin ${metadata.name} deactivated successfully');
    } catch (e) {
      throw PluginActivationException(
        'Failed to deactivate plugin ${metadata.id}: $e',
        pluginId: metadata.id,
        originalError: e,
      );
    }
  }

  /// 子类停用回调
  @protected
  Future<void> onDeactivate() async {
    // 子类可以重写此方法
  }

  /// 释放资源
  Future<void> dispose() async {
    if (state == PluginState.disposed) {
      return; // 已经释放
    }

    try {
      // 先停用
      if (state == PluginState.active) {
        await deactivate();
      }

      // 调用子类释放
      await onDispose();

      // 清理沙箱
      await _sandbox?.cleanup();
      _sandbox = null;

      // 关闭状态流
      await _stateController?.close();

      setStateInternal(PluginState.disposed);
      print('Plugin ${metadata.name} disposed successfully');
    } catch (e) {
      print('Warning: Error disposing plugin ${metadata.id}: $e');
    }
  }

  /// 子类释放回调
  @protected
  Future<void> onDispose() async {
    // 子类可以重写此方法
  }

  /// 健康检查
  Future<bool> healthCheck() async {
    try {
      if (!isInitialized) return false;
      return await onHealthCheck();
    } catch (e) {
      print('Health check failed for plugin ${metadata.id}: $e');
      return false;
    }
  }

  /// 子类健康检查回调
  @protected
  Future<bool> onHealthCheck() async {
    // 子类可以重写此方法
    return true;
  }

  /// 获取插件配置UI（可选）
  Widget? buildSettingsScreen() => null;

  /// 处理深度链接（可选）
  Future<bool> handleDeepLink(Uri uri) async => false;

  /// 获取插件特定配置
  String? getConfig(String key) => _sandbox?.getString(key);

  /// 保存插件配置
  Future<bool> setConfig(String key, String value) async {
    return await _sandbox?.setString(key, value) ?? false;
  }

  /// 获取插件配置（布尔值）
  bool? getConfigBool(String key) => _sandbox?.getBool(key);

  /// 保存插件配置（布尔值）
  Future<bool> setConfigBool(String key, bool value) async {
    return await _sandbox?.setBool(key, value) ?? false;
  }

  /// 获取插件配置（整数）
  int? getConfigInt(String key) => _sandbox?.getInt(key);

  /// 保存插件配置（整数）
  Future<bool> setConfigInt(String key, int value) async {
    return await _sandbox?.setInt(key, value) ?? false;
  }

  @override
  String toString() {
    return 'CorePlugin(id: ${metadata.id}, name: ${metadata.name}, state: $state)';
  }
}

/// 延迟加载插件
class LazyPlugin extends CorePlugin {
  final Future<CorePlugin> Function() _loader;
  CorePlugin? _actualPlugin;
  bool _loaded = false;
  PluginState _internalState = PluginState.uninitialized;

  LazyPlugin(this._loader) : super();

  Future<CorePlugin> _ensureLoaded() async {
    if (!_loaded) {
      _actualPlugin = await _loader();
      _loaded = true;
    }
    return _actualPlugin!;
  }

  @override
  PluginMetadata get staticMetadata => PluginMetadata(
    id: 'lazy.wrapper',
    name: 'Lazy Loading Plugin',
    version: '1.0.0',
    description: 'Wrapper for lazy loaded plugin',
    author: 'CorePlayer Team',
    icon: Icons.extension,
  );

  @override
  PluginState get state {
    if (!_loaded) return _internalState;
    return _actualPlugin!.state;
  }

  @override
  void setStateInternal(PluginState newState) {
    if (_loaded && _actualPlugin != null) {
      _actualPlugin!.setStateInternal(newState);
    } else {
      _internalState = newState;
    }
  }

  @override
  Future<void> onInitialize() async {
    final plugin = await _ensureLoaded();
    await plugin.initialize();
  }

  @override
  Future<void> onActivate() async {
    final plugin = await _ensureLoaded();
    await plugin.activate();
  }

  @override
  Future<void> onDeactivate() async {
    if (_loaded && _actualPlugin != null) {
      await _actualPlugin!.deactivate();
    }
  }

  @override
  Future<void> onDispose() async {
    if (_loaded && _actualPlugin != null) {
      await _actualPlugin!.dispose();
    }
  }

  @override
  Future<bool> onHealthCheck() async {
    if (!_loaded) return true;
    return await _actualPlugin!.healthCheck();
  }

  @override
  Widget? buildSettingsScreen() {
    if (!_loaded) return null;
    return _actualPlugin!.buildSettingsScreen();
  }

  @override
  Future<bool> handleDeepLink(Uri uri) async {
    if (!_loaded) return false;
    return await _actualPlugin!.handleDeepLink(uri);
  }
}