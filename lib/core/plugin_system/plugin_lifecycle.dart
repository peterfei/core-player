import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'plugin_interface.dart';
import 'core_plugin.dart';

/// 插件生命周期状态
enum LifecycleEvent {
  initializing,
  initialized,
  activating,
  activated,
  deactivating,
  deactivated,
  disposing,
  disposed,
  error,
}

/// 插件生命周期事件
@immutable
class PluginLifecycleEvent {
  final String pluginId;
  final LifecycleEvent event;
  final DateTime timestamp;
  final String? previousState;
  final String? newState;
  final String? error;
  final Map<String, dynamic>? data;

  const PluginLifecycleEvent({
    required this.pluginId,
    required this.event,
    required this.timestamp,
    this.previousState,
    this.newState,
    this.error,
    this.data,
  });

  @override
  String toString() {
    return 'PluginLifecycleEvent(pluginId: $pluginId, event: $event, timestamp: $timestamp)';
  }
}

/// 插件生命周期监听器
typedef PluginLifecycleListener = void Function(PluginLifecycleEvent event);

/// 插件生命周期管理器
///
/// 负责管理插件的生命周期状态转换，提供状态转换验证、生命周期钩子、错误处理等功能。
class PluginLifecycleManager {
  final Map<String, PluginState> _pluginStates = {};
  final Map<String, List<PluginLifecycleListener>> _listeners = {};
  final Map<String, List<PluginLifecycleEvent>> _history = {};
  final StreamController<PluginLifecycleEvent> _eventController =
      StreamController<PluginLifecycleEvent>.broadcast();

  /// 最大历史记录数量
  final int maxHistorySize;

  /// 是否启用详细日志
  final bool verboseLogging;

  /// 生命周期事件流
  Stream<PluginLifecycleEvent> get events => _eventController.stream;

  PluginLifecycleManager({
    this.maxHistorySize = 100,
    this.verboseLogging = kDebugMode,
  });

  /// 获取插件当前状态
  PluginState getState(String pluginId) {
    return _pluginStates[pluginId] ?? PluginState.uninitialized;
  }

  /// 设置插件状态
  Future<bool> setState(
    String pluginId,
    PluginState newState, {
    Map<String, dynamic>? data,
    String? error,
  }) async {
    final previousState = getState(pluginId);

    // 验证状态转换是否合法
    if (!_isValidStateTransition(previousState, newState)) {
      _logError('Invalid state transition for plugin $pluginId: $previousState -> $newState');
      return false;
    }

    try {
      // 记录状态转换
      _pluginStates[pluginId] = newState;

      // 创建生命周期事件
      final event = _createLifecycleEvent(
        pluginId,
        newState,
        previousState,
        data: data,
        error: error,
      );

      // 添加到历史记录
      _addToHistory(pluginId, event);

      // 通知监听器
      _notifyListeners(pluginId, event);

      // 发送到事件流
      if (!_eventController.isClosed) {
        _eventController.add(event);
      }

      _logVerbose('Plugin $pluginId state changed: $previousState -> $newState');

      return true;
    } catch (e) {
      _logError('Failed to set state for plugin $pluginId: $e');
      return false;
    }
  }

  /// 检查状态转换是否有效
  bool isValidStateTransition(String pluginId, PluginState newState) {
    final currentState = getState(pluginId);
    return _isValidStateTransition(currentState, newState);
  }

  /// 获取插件生命周期历史
  List<PluginLifecycleEvent> getHistory(String pluginId) {
    return List.unmodifiable(_history[pluginId] ?? []);
  }

  /// 添加生命周期监听器
  void addListener(String pluginId, PluginLifecycleListener listener) {
    final listeners = _listeners.putIfAbsent(pluginId, () => []);
    listeners.add(listener);
  }

  /// 移除生命周期监听器
  void removeListener(String pluginId, PluginLifecycleListener listener) {
    final listeners = _listeners[pluginId];
    if (listeners != null) {
      listeners.remove(listener);
      if (listeners.isEmpty) {
        _listeners.remove(pluginId);
      }
    }
  }

  /// 添加全局生命周期监听器
  void addGlobalListener(PluginLifecycleListener listener) {
    addListener('*', listener);
  }

  /// 移除全局生命周期监听器
  void removeGlobalListener(PluginLifecycleListener listener) {
    removeListener('*', listener);
  }

  /// 清理插件相关数据
  void cleanupPlugin(String pluginId) {
    _pluginStates.remove(pluginId);
    _listeners.remove(pluginId);
    _history.remove(pluginId);

    _logVerbose('Cleaned up lifecycle data for plugin: $pluginId');
  }

  /// 获取所有插件状态
  Map<String, PluginState> getAllStates() {
    return Map.unmodifiable(_pluginStates);
  }

  /// 获取统计信息
  Map<String, dynamic> getStatistics() {
    final stateCounts = <PluginState, int>{};
    for (final state in PluginState.values) {
      stateCounts[state] = 0;
    }

    for (final state in _pluginStates.values) {
      stateCounts[state] = (stateCounts[state] ?? 0) + 1;
    }

    return {
      'totalPlugins': _pluginStates.length,
      'stateDistribution': stateCounts.map(
        (k, v) => MapEntry(k.name, v),
      ),
      'totalListeners': _listeners.values.fold(
        0,
        (sum, listeners) => sum + listeners.length,
      ),
      'totalHistoryEvents': _history.values.fold(
        0,
        (sum, events) => sum + events.length,
      ),
    };
  }

  /// 导出生命周期数据
  Map<String, dynamic> exportData() {
    return {
      'version': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'states': _pluginStates.map((k, v) => MapEntry(k, v.name)),
      'history': _history.map((k, v) => MapEntry(
        k,
        v.map((e) => {
          'pluginId': e.pluginId,
          'event': e.event.name,
          'timestamp': e.timestamp.toIso8601String(),
          'previousState': e.previousState,
          'newState': e.newState,
          'error': e.error,
          'data': e.data,
        }).toList(),
      )),
    };
  }

  /// 释放资源
  Future<void> dispose() async {
    _pluginStates.clear();
    _listeners.clear();
    _history.clear();

    await _eventController.close();

    _logVerbose('PluginLifecycleManager disposed');
  }

  // ===== 私有方法 =====

  /// 验证状态转换是否合法
  bool _isValidStateTransition(PluginState from, PluginState to) {
    // 相同状态不需要转换
    if (from == to) return false;

    // 根据当前状态判断允许的转换
    switch (from) {
      case PluginState.uninitialized:
        return to == PluginState.initializing;

      case PluginState.initializing:
        return to == PluginState.ready || to == PluginState.error;

      case PluginState.ready:
        return to == PluginState.active || to == PluginState.error || to == PluginState.disposed;

      case PluginState.active:
        return to == PluginState.inactive || to == PluginState.error;

      case PluginState.inactive:
        return to == PluginState.active || to == PluginState.disposed;

      case PluginState.error:
        return to == PluginState.ready || to == PluginState.disposed;

      case PluginState.disposed:
        // disposed 是最终状态，不能再转换
        return false;
    }
  }

  /// 创建生命周期事件
  PluginLifecycleEvent _createLifecycleEvent(
    String pluginId,
    PluginState state,
    PluginState previousState, {
    Map<String, dynamic>? data,
    String? error,
  }) {
    final event = _mapStateToLifecycleEvent(state);

    return PluginLifecycleEvent(
      pluginId: pluginId,
      event: event,
      timestamp: DateTime.now(),
      previousState: previousState.name,
      newState: state.name,
      error: error,
      data: data,
    );
  }

  /// 将插件状态映射到生命周期事件
  LifecycleEvent _mapStateToLifecycleEvent(PluginState state) {
    switch (state) {
      case PluginState.uninitialized:
        return LifecycleEvent.disposed; // 不常用，映射为disposed
      case PluginState.initializing:
        return LifecycleEvent.initializing;
      case PluginState.ready:
        return LifecycleEvent.initialized;
      case PluginState.active:
        return LifecycleEvent.activated;
      case PluginState.inactive:
        return LifecycleEvent.deactivated;
      case PluginState.error:
        return LifecycleEvent.error;
      case PluginState.disposed:
        return LifecycleEvent.disposed;
    }
  }

  /// 添加到历史记录
  void _addToHistory(String pluginId, PluginLifecycleEvent event) {
    final history = _history.putIfAbsent(pluginId, () => []);
    history.add(event);

    // 限制历史记录大小
    if (history.length > maxHistorySize) {
      history.removeAt(0);
    }
  }

  /// 通知监听器
  void _notifyListeners(String pluginId, PluginLifecycleEvent event) {
    // 通知特定插件的监听器
    final specificListeners = _listeners[pluginId];
    if (specificListeners != null) {
      for (final listener in specificListeners) {
        try {
          listener(event);
        } catch (e) {
          _logError('Error in lifecycle listener for plugin $pluginId: $e');
        }
      }
    }

    // 通知全局监听器
    final globalListeners = _listeners['*'];
    if (globalListeners != null) {
      for (final listener in globalListeners) {
        try {
          listener(event);
        } catch (e) {
          _logError('Error in global lifecycle listener: $e');
        }
      }
    }
  }

  /// 记录详细日志
  void _logVerbose(String message) {
    if (verboseLogging) {
      print('[PluginLifecycle] $message');
    }
  }

  /// 记录错误日志
  void _logError(String message) {
    if (kDebugMode) {
      print('[PluginLifecycle] ERROR: $message');
    }
  }
}

/// 插件生命周期管理器单例
final pluginLifecycleManager = PluginLifecycleManager();

/// 插件生命周期异常
class PluginLifecycleException implements Exception {
  final String message;
  final String? pluginId;
  final PluginState? fromState;
  final PluginState? toState;
  final dynamic originalError;

  PluginLifecycleException(
    this.message, {
    this.pluginId,
    this.fromState,
    this.toState,
    this.originalError,
  });

  @override
  String toString() {
    final buffer = StringBuffer('PluginLifecycleException: $message');
    if (pluginId != null) buffer.write(' (Plugin: $pluginId)');
    if (fromState != null && toState != null) {
      buffer.write(' (Transition: $fromState -> $toState)');
    }
    if (originalError != null) {
      buffer.write('\nCaused by: $originalError');
    }
    return buffer.toString();
  }
}

/// 状态转换验证器
class StateTransitionValidator {
  static final Map<PluginState, Set<PluginState>> _allowedTransitions = {
    PluginState.uninitialized: {PluginState.initializing},
    PluginState.initializing: {PluginState.ready, PluginState.error},
    PluginState.ready: {PluginState.active, PluginState.disposed, PluginState.error},
    PluginState.active: {PluginState.inactive, PluginState.error},
    PluginState.inactive: {PluginState.active, PluginState.disposed},
    PluginState.error: {PluginState.ready, PluginState.disposed},
    PluginState.disposed: {}, // 终态
  };

  static bool isValid(PluginState from, PluginState to) {
    final allowedStates = _allowedTransitions[from];
    return allowedStates?.contains(to) ?? false;
  }

  static Set<PluginState> getAllowedNextStates(PluginState from) {
    return Set.unmodifiable(_allowedTransitions[from] ?? {});
  }

  static bool isFinalState(PluginState state) {
    return _allowedTransitions[state]?.isEmpty ?? false;
  }
}