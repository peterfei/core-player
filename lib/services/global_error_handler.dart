import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/plugin_system/plugin_interface.dart';
import '../core/plugin_system/plugin_loader.dart';
import '../core/plugin_system/edition_config.dart';

/// 全局错误处理服务
///
/// 专门用于处理插件系统中的错误，提供用户友好的错误提示
class GlobalErrorHandler {
  static final GlobalErrorHandler _instance = GlobalErrorHandler._internal();
  factory GlobalErrorHandler() => _instance;
  GlobalErrorHandler._internal();

  /// 错误事件流
  final StreamController<GlobalErrorEvent> _errorController =
      StreamController<GlobalErrorEvent>.broadcast();

  /// 获取错误事件流
  Stream<GlobalErrorEvent> get errorStream => _errorController.stream;

  /// 初始化全局错误处理
  void initialize() {
    // 设置全局错误处理
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
    };

    // 设置未捕获异常处理
    PlatformDispatcher.instance.onError = (error, stack) {
      _handleUncaughtException(error, stack);
      return true;
    };
  }

  /// 处理Flutter错误
  void _handleFlutterError(FlutterErrorDetails details) {
    final error = details.exception;

    // 检查是否是插件相关的错误
    if (_isPluginRelatedError(error)) {
      _handlePluginError(error, details.stack);
    } else {
      // 其他Flutter错误的处理
      if (kDebugMode) {
        debugPrint('Flutter Error: ${details.toString()}');
      }
    }
  }

  /// 处理未捕获异常
  void _handleUncaughtException(Object error, StackTrace stack) {
    if (_isPluginRelatedError(error)) {
      _handlePluginError(error, stack);
    } else {
      if (kDebugMode) {
        debugPrint('Uncaught Exception: $error\n$stack');
      }
    }
  }

  /// 检查是否是插件相关错误
  bool _isPluginRelatedError(Object error) {
    final errorString = error.toString().toLowerCase();

    // 检查SMB相关错误
    if (errorString.contains('smb') ||
        errorString.contains('smbexception') ||
        errorString.contains('streamsink is closed')) {
      return true;
    }

    // 检查插件相关错误
    if (errorString.contains('plugin') ||
        errorString.contains('featurenotavailable')) {
      return true;
    }

    return false;
  }

  /// 处理插件相关错误
  void _handlePluginError(Object error, StackTrace? stack) {
    String userMessage = '发生未知错误';
    String? actionUrl;

    // 分析错误类型并生成用户友好的消息
    if (error.toString().contains('smb') ||
        error.toString().contains('smbexception')) {
      if (EditionConfig.isCommunityEdition) {
        userMessage = 'SMB网络功能仅在专业版中可用。\n\n升级到专业版即可访问网络共享中的视频文件。';
        actionUrl = 'https://coreplayer.example.com/upgrade';
      } else {
        userMessage = 'SMB网络连接出现问题。\n\n请检查网络连接或服务器配置。';
      }
    } else if (error is FeatureNotAvailableException) {
      userMessage = error.message;
      actionUrl = error.upgradeUrl;
    } else if (error.toString().contains('StreamSink is closed')) {
      if (EditionConfig.isCommunityEdition) {
        userMessage = '网络连接已断开，可能是由于社区版功能限制。\n\n升级到专业版获得稳定的网络访问功能。';
        actionUrl = 'https://coreplayer.example.com/upgrade';
      } else {
        userMessage = '网络连接已断开，请重试。';
      }
    }

    // 发送错误事件
    final errorEvent = GlobalErrorEvent(
      type: GlobalErrorType.pluginError,
      originalError: error,
      stackTrace: stack,
      userMessage: userMessage,
      actionUrl: actionUrl,
      timestamp: DateTime.now(),
    );

    _errorController.add(errorEvent);

    if (kDebugMode) {
      debugPrint('Plugin Error Handled: $userMessage');
      debugPrint('Original Error: $error');
      if (stack != null) {
        debugPrint('Stack Trace: $stack');
      }
    }
  }

  /// 手动报告错误
  void reportError({
    required String userMessage,
    required Object originalError,
    String? actionUrl,
  }) {
    final errorEvent = GlobalErrorEvent(
      type: GlobalErrorType.manualReport,
      originalError: originalError,
      userMessage: userMessage,
      actionUrl: actionUrl,
      timestamp: DateTime.now(),
    );

    _errorController.add(errorEvent);

    if (kDebugMode) {
      debugPrint('Manual Error Report: $userMessage');
      debugPrint('Original Error: $originalError');
    }
  }

  /// 释放资源
  void dispose() {
    _errorController.close();
  }
}

/// 全局错误事件
class GlobalErrorEvent {
  final GlobalErrorType type;
  final Object originalError;
  final StackTrace? stackTrace;
  final String userMessage;
  final String? actionUrl;
  final DateTime timestamp;

  GlobalErrorEvent({
    required this.type,
    required this.originalError,
    this.stackTrace,
    required this.userMessage,
    this.actionUrl,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'GlobalErrorEvent(type: $type, message: $userMessage, timestamp: $timestamp)';
  }
}

/// 全局错误类型
enum GlobalErrorType {
  pluginError,
  networkError,
  manualReport,
  flutterError,
}

/// 用户友好的错误显示对话框
class GlobalErrorDialog extends StatelessWidget {
  final GlobalErrorEvent errorEvent;
  final VoidCallback? onDismiss;

  const GlobalErrorDialog({
    super.key,
    required this.errorEvent,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _getErrorIcon(errorEvent.type),
            color: _getErrorColor(errorEvent.type),
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(_getErrorTitle(errorEvent.type)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(errorEvent.userMessage),
          if (errorEvent.actionUrl != null) ...[
            const SizedBox(height: 12),
            const Text('了解更多：',
              style: TextStyle(fontWeight: FontWeight.w600)),
            Text(
              errorEvent.actionUrl!,
              style: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('技术详情 (调试模式)'),
              children: [
                Container(
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      '错误类型: ${errorEvent.type}\n'
                      '原始错误: ${errorEvent.originalError}\n'
                      '时间: ${errorEvent.timestamp}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        if (errorEvent.actionUrl != null)
          ElevatedButton(
            onPressed: () {
              // 升级按钮：关闭当前对话框
              Navigator.of(context).pop();
              // 显示升级对话框
              _showUpgradeDialog(context, errorEvent.actionUrl!);
            },
            child: const Text('升级到专业版'),
          ),
        TextButton(
          onPressed: () {
            if (onDismiss != null) onDismiss!();
          },
          child: const Text('知道了'),
        ),
      ],
    );
  }

  IconData _getErrorIcon(GlobalErrorType type) {
    switch (type) {
      case GlobalErrorType.pluginError:
        return Icons.extension_off;
      case GlobalErrorType.networkError:
        return Icons.wifi_off;
      case GlobalErrorType.manualReport:
        return Icons.error_outline;
      case GlobalErrorType.flutterError:
        return Icons.bug_report;
    }
  }

  Color _getErrorColor(GlobalErrorType type) {
    switch (type) {
      case GlobalErrorType.pluginError:
        return Colors.orange;
      case GlobalErrorType.networkError:
        return Colors.red;
      case GlobalErrorType.manualReport:
        return Colors.purple;
      case GlobalErrorType.flutterError:
        return Colors.blueGrey;
    }
  }

  String _getErrorTitle(GlobalErrorType type) {
    switch (type) {
      case GlobalErrorType.pluginError:
        return '插件功能限制';
      case GlobalErrorType.networkError:
        return '网络连接错误';
      case GlobalErrorType.manualReport:
        return '用户报告错误';
      case GlobalErrorType.flutterError:
        return '系统错误';
    }
  }

  void _showUpgradeDialog(BuildContext context, String upgradeUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('升级到专业版'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.upgrade, size: 48, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              '升级到专业版，解锁以下功能：',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Column(
              children: [
                _FeatureItem(Icons.share, 'SMB/CIFS 网络共享'),
                _FeatureItem(Icons.cloud, 'Emby/Jellyfin/Plex 支持'),
                _FeatureItem(Icons.hd, '4K/8K 超高清播放'),
                _FeatureItem(Icons.subtitles, '高级字幕支持'),
                _FeatureItem(Icons.equalizer, '专业音效处理'),
              ],
            ),
            const SizedBox(height: 16),
            Text('升级链接：$upgradeUrl',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('稍后'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // 这里可以添加打开链接的逻辑
              // 使用 url_launcher 或者复制到剪贴板
            },
            child: const Text('立即升级'),
          ),
        ],
      ),
    );
  }
}

/// 全局错误监听器Widget
class GlobalErrorListener extends StatefulWidget {
  final Widget child;

  const GlobalErrorListener({super.key, required this.child});

  @override
  State<GlobalErrorListener> createState() => _GlobalErrorListenerState();
}

class _GlobalErrorListenerState extends State<GlobalErrorListener> {
  late final GlobalErrorHandler _errorHandler;
  StreamSubscription<GlobalErrorEvent>? _errorSubscription;

  @override
  void initState() {
    super.initState();
    _errorHandler = GlobalErrorHandler();
    _errorSubscription = _errorHandler.errorStream.listen(_showErrorDialog);
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    super.dispose();
  }

  void _showErrorDialog(GlobalErrorEvent errorEvent) {
    // 防止重复显示相同的错误
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => GlobalErrorDialog(
          errorEvent: errorEvent,
          onDismiss: () => Navigator.of(context).pop(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// 功能项显示组件
class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureItem(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}