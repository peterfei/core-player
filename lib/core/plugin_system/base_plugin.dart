import 'dart:async';
import 'package:flutter/foundation.dart';
import 'plugin_interface.dart';
import 'core_plugin.dart';

/// 基础插件实现类
///
/// 提供CorePlugin的具体实现，避免子类需要处理复杂的抽象方法
abstract class BasePlugin extends CorePlugin {
  /// 插件状态（内部字段）
  PluginState _internalState = PluginState.uninitialized;

  /// 插件沙箱
  PluginSandbox? _sandbox;

  /// 状态变化控制器
  final StreamController<PluginState> _stateController =
      StreamController<PluginState>.broadcast();

  @override
  PluginState get _state => _internalState;

  void _setStateInternal(PluginState state) {
    _internalState = state;
  }

  @override
  Stream<PluginState> get stateStream => _stateController.stream;

  @override
  PluginSandbox? get sandbox => _sandbox;

  @override
  String? getConfig(String key) => _sandbox?.getString(key);

  @override
  Future<bool> setConfig(String key, String value) async {
    return await _sandbox?.setString(key, value) ?? false;
  }

  @override
  bool? getConfigBool(String key) => _sandbox?.getBool(key);

  @override
  Future<bool> setConfigBool(String key, bool value) async {
    return await _sandbox?.setBool(key, value) ?? false;
  }

  @override
  int? getConfigInt(String key) => _sandbox?.getInt(key);

  @override
  Future<bool> setConfigInt(String key, int value) async {
    return await _sandbox?.setInt(key, value) ?? false;
  }

  @override
  Future<void> dispose() async {
    if (_state == PluginState.disposed) {
      return;
    }

    try {
      if (_state == PluginState.active) {
        await deactivate();
      }

      await onDispose();

      await _sandbox?.cleanup();
      _sandbox = null;

      await _stateController.close();
      _setStateInternal(PluginState.disposed);

      if (kDebugMode) {
        print('Plugin ${metadata.name} disposed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Warning: Error disposing plugin ${metadata.id}: $e');
      }
    }
  }
}