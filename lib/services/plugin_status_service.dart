import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/plugin_system/core_plugin.dart';
import '../core/plugin_system/plugin_interface.dart';
import '../core/plugin_system/plugins/media_server/placeholders/media_server_placeholder.dart';
import '../core/plugin_system/plugins/media_server/smb/smb_plugin.dart';
import '../core/plugin_system/plugin_loader.dart';

/// 插件状态服务
///
/// 提供统一的插件状态管理和UI友好的状态信息
class PluginStatusService {
  static final PluginStatusService _instance = PluginStatusService._internal();
  factory PluginStatusService() => _instance;
  PluginStatusService._internal();

  final Map<String, CorePlugin> _plugins = {};
  final StreamController<PluginStatusChangeEvent> _statusController =
      StreamController<PluginStatusChangeEvent>.broadcast();

  /// 状态变化事件流
  Stream<PluginStatusChangeEvent> get statusStream => _statusController.stream;

  /// 获取所有插件
  Map<String, CorePlugin> get plugins => Map.unmodifiable(_plugins);

  /// 获取插件状态摘要
  PluginStatusSummary get statusSummary {
    final total = _plugins.length;
    final active = _plugins.values.where((p) => p.isActive).length;
    final ready = _plugins.values.where((p) => p.isReady).length;
    final errors = _plugins.values.where((p) => p.hasError).length;

    return PluginStatusSummary(
      total: total,
      active: active,
      ready: ready,
      errors: errors,
    );
  }

  /// 初始化插件状态服务
  Future<void> initialize() async {
    try {
      await _loadPlugins();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize plugin status service: $e');
      }
    }
  }

  /// 加载所有插件
  Future<void> _loadPlugins() async {
    _plugins.clear();

    try {
      // 媒体服务器插件
      if (EditionConfig.isCommunityEdition) {
        final communityPlugin = MediaServerPlaceholderPlugin();
        await communityPlugin.initialize();
        _plugins['mediaserver'] = communityPlugin;
      } else {
        final proPlugin = SMBPlugin();
        await proPlugin.initialize();
        _plugins['mediaserver'] = proPlugin;
      }

      if (kDebugMode) {
        print('Loaded ${_plugins.length} plugins');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load plugins: $e');
      }
      rethrow;
    }
  }

  /// 激活插件
  Future<bool> activatePlugin(String pluginId) async {
    final plugin = _plugins[pluginId];
    if (plugin == null) {
      return false;
    }

    try {
      if (!plugin.isReady) {
        await plugin.initialize();
      }
      await plugin.activate();

      _statusController.add(PluginStatusChangeEvent(
        pluginId: pluginId,
        plugin: plugin,
        oldState: PluginState.ready,
        newState: PluginState.active,
      ));

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to activate plugin $pluginId: $e');
      }
      return false;
    }
  }

  /// 停用插件
  Future<bool> deactivatePlugin(String pluginId) async {
    final plugin = _plugins[pluginId];
    if (plugin == null) {
      return false;
    }

    try {
      await plugin.deactivate();

      _statusController.add(PluginStatusChangeEvent(
        pluginId: pluginId,
        plugin: plugin,
        oldState: PluginState.active,
        newState: PluginState.inactive,
      ));

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to deactivate plugin $pluginId: $e');
      }
      return false;
    }
  }

  /// 检查插件健康状态
  Future<bool> checkPluginHealth(String pluginId) async {
    final plugin = _plugins[pluginId];
    if (plugin == null) {
      return false;
    }

    try {
      return await plugin.healthCheck();
    } catch (e) {
      if (kDebugMode) {
        print('Plugin $pluginId health check failed: $e');
      }
      return false;
    }
  }

  /// 重新加载插件
  Future<void> reloadPlugins() async {
    try {
      await _loadPlugins();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to reload plugins: $e');
      }
    }
  }

  /// 获取用户友好的插件状态描述
  String getPluginStatusDescription(CorePlugin plugin) {
    if (plugin.hasError) {
      return '插件运行异常';
    } else if (plugin.isActive) {
      return '插件已激活，正常运行';
    } else if (plugin.isReady) {
      return '插件已就绪，可以激活';
    } else if (plugin.isInitialized) {
      return '插件正在初始化';
    } else {
      return '插件未初始化';
    }
  }

  /// 获取用户友好的状态颜色
  Color getPluginStatusColor(CorePlugin plugin) {
    if (plugin.hasError) {
      return Colors.red;
    } else if (plugin.isActive) {
      return Colors.green;
    } else if (plugin.isReady) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  /// 释放资源
  void dispose() {
    for (final plugin in _plugins.values) {
      plugin.dispose();
    }
    _plugins.clear();
    _statusController.close();
  }
}

/// 插件状态变化事件
class PluginStatusChangeEvent {
  final String pluginId;
  final CorePlugin plugin;
  final PluginState oldState;
  final PluginState newState;
  final DateTime timestamp;

  PluginStatusChangeEvent({
    required this.pluginId,
    required this.plugin,
    required this.oldState,
    required this.newState,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    return 'PluginStatusChangeEvent(${plugin.metadata.name}: $oldState -> $newState)';
  }
}

/// 插件状态摘要
class PluginStatusSummary {
  final int total;
  final int active;
  final int ready;
  final int errors;

  const PluginStatusSummary({
    required this.total,
    required this.active,
    required this.ready,
    required this.errors,
  });

  bool get hasErrors => errors > 0;
  bool get allActive => active == total && total > 0;
  double get activationRate => total > 0 ? active / total : 0.0;

  @override
  String toString() {
    return 'PluginStatusSummary(total: $total, active: $active, ready: $ready, errors: $errors)';
  }
}

/// 插件状态UI组件
class PluginStatusIndicator extends StatelessWidget {
  final CorePlugin plugin;
  final bool showLabel;

  const PluginStatusIndicator({
    super.key,
    required this.plugin,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final service = PluginStatusService();
    final color = service.getPluginStatusColor(plugin);
    final description = service.getPluginStatusDescription(plugin);

    if (showLabel) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              description,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
    }
  }
}

/// 插件状态卡片
class PluginStatusCard extends StatelessWidget {
  final String pluginId;
  final CorePlugin plugin;
  final VoidCallback? onTap;

  const PluginStatusCard({
    super.key,
    required this.pluginId,
    required this.plugin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final service = PluginStatusService();
    final metadata = plugin.metadata;
    final statusColor = service.getPluginStatusColor(plugin);
    final statusDescription = service.getPluginStatusDescription(plugin);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(metadata.icon, color: statusColor, size: 20),
        ),
        title: Text(
          metadata.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          metadata.description,
          style: Theme.of(context).textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PluginStatusIndicator(plugin: plugin),
        onTap: onTap,
      ),
    );
  }
}