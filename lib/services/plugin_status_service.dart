import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/plugin_system/core_plugin.dart';
import '../core/plugin_system/plugin_interface.dart';
import '../core/plugin_system/plugins/media_server/placeholders/media_server_placeholder.dart';
import '../core/plugin_system/plugins/media_server/smb/smb_plugin.dart';
import '../core/plugin_system/plugin_loader.dart';
import 'plugin_performance_service.dart';
import 'plugin_lazy_loader.dart';

/// 插件状态服务
///
/// 提供统一的插件状态管理和UI友好的状态信息
/// 集成了性能监控和懒加载功能
class PluginStatusService {
  static final PluginStatusService _instance = PluginStatusService._internal();
  factory PluginStatusService() => _instance;
  PluginStatusService._internal();

  final Map<String, CorePlugin> _plugins = {};
  final StreamController<PluginStatusChangeEvent> _statusController =
      StreamController<PluginStatusChangeEvent>.broadcast();

  /// 懒加载管理器
  final PluginLazyLoader _lazyLoader = PluginLazyLoader();

  /// 性能监控服务
  final PluginPerformanceService _performanceService = PluginPerformanceService();

  /// 内存清理定时器
  Timer? _memoryCleanupTimer;

  /// 状态变化事件流
  Stream<PluginStatusChangeEvent> get statusStream => _statusController.stream;

  /// 获取所有插件（包括懒加载的）
  Map<String, CorePlugin> get plugins => Map.unmodifiable(_plugins);

  /// 获取性能服务
  PluginPerformanceService get performanceService => _performanceService;

  /// 获取懒加载器
  PluginLazyLoader get lazyLoader => _lazyLoader;

  /// 获取插件状态摘要（包含性能数据）
  PluginStatusSummary get statusSummary {
    final total = _lazyLoader.getAvailablePluginIds().length;
    final loaded = _plugins.length;
    final active = _plugins.values.where((p) => p.isActive).length;
    final ready = _plugins.values.where((p) => p.isReady).length;
    final errors = _plugins.values.where((p) => p.hasError).length;
    final loadStats = _lazyLoader.getLoadStats();
    final perfSummary = _performanceService.getPerformanceSummary();

    return PluginStatusSummary(
      total: total,
      loaded: loaded,
      active: active,
      ready: ready,
      errors: errors,
      loadStats: loadStats,
      performanceSummary: perfSummary,
    );
  }

  /// 初始化插件状态服务
  Future<void> initialize() async {
    try {
      // 初始化懒加载器
      await _lazyLoader.initialize();

      // 初始化性能监控
      _performanceService.initialize();

      // 启动内存清理定时器
      _startMemoryCleanupTimer();

      if (kDebugMode) {
        print('PluginStatusService initialized with lazy loading and performance monitoring');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize plugin status service: $e');
      }
    }
  }

  /// 启动内存清理定时器
  void _startMemoryCleanupTimer() {
    _memoryCleanupTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _performMemoryCleanup(),
    );
  }

  /// 执行内存清理
  void _performMemoryCleanup() {
    _lazyLoader.unloadUnusedPlugins();
  }

  /// 激活插件（使用懒加载）
  Future<bool> activatePlugin(String pluginId) async {
    try {
      // 懒加载插件
      final plugin = await _lazyLoader.loadPluginWithTimeout(pluginId);
      if (plugin == null) {
        return false;
      }

      // 添加到已加载插件列表
      _plugins[pluginId] = plugin;

      // 激活插件
      if (!plugin.isReady) {
        await plugin.initialize();
      }
      await plugin.activate();

      // 记录性能指标
      _performanceService.recordActivation(pluginId, success: true);

      // 发送状态变化事件
      _statusController.add(PluginStatusChangeEvent(
        pluginId: pluginId,
        plugin: plugin,
        oldState: PluginState.ready,
        newState: PluginState.active,
      ));

      return true;
    } catch (e) {
      // 记录性能指标
      _performanceService.recordActivation(pluginId, success: false);

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
      final availablePlugins = _lazyLoader.getAvailablePluginIds();
      for (final pluginId in availablePlugins) {
        await _lazyLoader.loadPlugin(pluginId, forceReload: true);
      }
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
    // 停止内存清理定时器
    _memoryCleanupTimer?.cancel();

    // 释放所有插件
    for (final plugin in _plugins.values) {
      plugin.dispose();
    }

    // 释放懒加载器和性能监控服务
    _lazyLoader.dispose();
    _performanceService.dispose();

    // 清理数据
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
  final int loaded;
  final int active;
  final int ready;
  final int errors;
  final PluginLoadStats? loadStats;
  final PluginPerformanceSummary? performanceSummary;

  const PluginStatusSummary({
    required this.total,
    required this.loaded,
    required this.active,
    required this.ready,
    required this.errors,
    this.loadStats,
    this.performanceSummary,
  });

  bool get hasErrors => errors > 0;
  bool get allActive => active == total && total > 0;
  bool get allLoaded => loaded == total && total > 0;
  double get activationRate => loaded > 0 ? active / loaded : 0.0;
  double get loadProgress => total > 0 ? loaded / total : 0.0;

  /// 获取性能评级
  String get performanceGrade {
    if (performanceSummary == null) return 'Unknown';

    final avgInitTime = performanceSummary!.averageInitTimeMs;
    final avgMemory = performanceSummary!.averageMemoryUsageMB;

    if (avgInitTime < 1000 && avgMemory < 50) return 'A+';
    if (avgInitTime < 2000 && avgMemory < 100) return 'A';
    if (avgInitTime < 3000 && avgMemory < 150) return 'B';
    if (avgInitTime < 5000 && avgMemory < 200) return 'C';
    return 'D';
  }

  /// 获取性能状态文本
  String get performanceStatus {
    if (performanceSummary == null) return '性能数据不可用';

    final avgInitTime = performanceSummary!.averageInitTimeMs;
    final avgMemory = performanceSummary!.averageMemoryUsageMB;

    return '平均初始化: ${avgInitTime}ms, 平均内存: ${avgMemory}MB';
  }

  @override
  String toString() {
    return 'PluginStatusSummary(total: $total, loaded: $loaded, active: $active, ready: $ready, errors: $errors)';
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