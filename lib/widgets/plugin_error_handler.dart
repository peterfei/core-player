import 'package:flutter/material.dart';
import '../services/plugin_status_service.dart';
import '../core/plugin_system/core_plugin.dart';
import '../core/plugin_system/plugin_interface.dart';

/// 插件错误处理器
///
/// 提供统一的插件错误处理和用户友好的提示
class PluginErrorHandler {
  static const Map<String, String> _errorMessages = {
    'FeatureNotAvailableException': '此功能仅专业版可用，请升级到专业版',
    'PluginInitializationException': '插件初始化失败，请检查插件配置',
    'PluginActivationException': '插件激活失败，请重试或联系技术支持',
    'NetworkException': '网络连接失败，请检查网络设置',
    'PermissionDeniedException': '权限不足，请检查应用权限设置',
    'TimeoutException': '操作超时，请重试',
    'FormatException': '数据格式错误，请检查输入',
    'FileSystemException': '文件系统错误，请检查存储空间和权限',
  };

  /// 获取用户友好的错误消息
  static String getUserFriendlyMessage(dynamic error, [CorePlugin? plugin]) {
    String errorType = error.runtimeType.toString();
    String errorMessage = error.toString();

    // 移除异常类名前缀，只保留消息部分
    if (errorMessage.contains(':')) {
      errorMessage = errorMessage.split(':').sublist(1).join(':').trim();
    }

    // 查找预定义的错误消息
    for (final entry in _errorMessages.entries) {
      if (errorMessage.contains(entry.key) || errorType.contains(entry.key)) {
        return entry.value;
      }
    }

    // 特殊错误处理
    if (errorMessage.toLowerCase().contains('permission')) {
      return '权限不足，请在设置中授予必要权限';
    }

    if (errorMessage.toLowerCase().contains('network') ||
        errorMessage.toLowerCase().contains('connection')) {
      return '网络连接失败，请检查网络设置后重试';
    }

    if (errorMessage.toLowerCase().contains('timeout')) {
      return '操作超时，请稍后重试';
    }

    if (errorMessage.toLowerCase().contains('file') ||
        errorMessage.toLowerCase().contains('directory')) {
      return '文件操作失败，请检查存储空间和权限';
    }

    // 如果是特定插件的错误，添加插件名称
    if (plugin != null) {
      return '插件"${plugin.metadata.name}"发生错误：$errorMessage';
    }

    // 默认错误消息
    if (errorMessage.isNotEmpty && errorMessage != errorType) {
      return errorMessage;
    }

    return '操作失败，请重试或联系技术支持';
  }

  /// 获取错误操作建议
  static List<String> getErrorSuggestions(dynamic error, [CorePlugin? plugin]) {
    final errorType = error.runtimeType.toString();
    final suggestions = <String>[];

    // 基础建议
    suggestions.add('请重试操作');

    // 根据错误类型添加特定建议
    if (errorType.contains('FeatureNotAvailableException') ||
        (plugin != null && plugin.metadata.id.contains('placeholder'))) {
      suggestions.add('升级到专业版以解锁此功能');
      suggestions.add('查看功能对比了解专业版优势');
    }

    if (errorType.contains('Network') ||
        error.toString().toLowerCase().contains('network')) {
      suggestions.add('检查网络连接');
      suggestions.add('确认服务器地址和端口正确');
      suggestions.add('检查防火墙设置');
    }

    if (errorType.contains('Permission')) {
      suggestions.add('检查应用权限设置');
      suggestions.add('重启应用以应用权限更改');
    }

    if (errorType.contains('Initialization')) {
      suggestions.add('重启应用');
      suggestions.add('清理应用缓存');
      suggestions.add('检查应用更新');
    }

    // 通用建议
    if (suggestions.length == 1) {
      suggestions.add('如果问题持续，请联系技术支持');
    }

    return suggestions;
  }

  /// 显示错误对话框
  static Future<void> showErrorDialog(
    BuildContext context, {
    required dynamic error,
    CorePlugin? plugin,
    String? title,
    List<Widget>? actions,
  }) async {
    final message = getUserFriendlyMessage(error, plugin);
    final suggestions = getErrorSuggestions(error, plugin);

    await showDialog(
      context: context,
      builder: (context) => PluginErrorDialog(
        title: title ?? '操作失败',
        message: message,
        suggestions: suggestions,
        actions: actions,
      ),
    );
  }

  /// 显示错误SnackBar
  static void showErrorSnackBar(
    BuildContext context, {
    required dynamic error,
    CorePlugin? plugin,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? action,
  }) {
    final message = getUserFriendlyMessage(error, plugin);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: duration,
        action: action != null
            ? SnackBarAction(
                label: '重试',
                textColor: Colors.white,
                onPressed: action,
              )
            : null,
      ),
    );
  }
}

/// 插件错误对话框
class PluginErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final List<String> suggestions;
  final List<Widget>? actions;

  const PluginErrorDialog({
    super.key,
    required this.title,
    required this.message,
    required this.suggestions,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '建议操作：',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...suggestions.map((suggestion) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        suggestion,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
      actions: actions ?? [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// 插件错误边界组件
class PluginErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext, dynamic, VoidCallback)? errorBuilder;
  final VoidCallback? onError;

  const PluginErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
  });

  @override
  State<PluginErrorBoundary> createState() => _PluginErrorBoundaryState();
}

class _PluginErrorBoundaryState extends State<PluginErrorBoundary> {
  dynamic _error;

  @override
  void initState() {
    super.initState();
    _resetError();
  }

  void _resetError() {
    setState(() {
      _error = null;
    });
  }

  void _handleError(dynamic error) {
    setState(() {
      _error = error;
    });
    widget.onError?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _error, _resetError);
      }

      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              '插件组件发生错误',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              PluginErrorHandler.getUserFriendlyMessage(_error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _resetError,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return widget.child;
  }
}

/// 插件状态指示器（带错误处理）
class PluginStatusIndicator extends StatelessWidget {
  final CorePlugin plugin;
  final bool showLabel;
  final VoidCallback? onTap;

  const PluginStatusIndicator({
    super.key,
    required this.plugin,
    this.showLabel = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final service = PluginStatusService();
    final color = service.getPluginStatusColor(plugin);
    final description = service.getPluginStatusDescription(plugin);

    Widget indicator = showLabel
        ? Row(
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
          )
        : Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: indicator,
      );
    }

    return indicator;
  }
}