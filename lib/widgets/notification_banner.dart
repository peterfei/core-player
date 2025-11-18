import 'package:flutter/material.dart';

/// 通知横幅组件
/// 用于显示系统状态、警告和用户提示
class NotificationBanner extends StatefulWidget {
  final String title;
  final String? message;
  final NotificationType type;
  final VoidCallback? onDismiss;
  final VoidCallback? onAction;
  final String? actionText;
  final bool autoDismiss;
  final Duration? duration;

  const NotificationBanner({
    super.key,
    required this.title,
    this.message,
    this.type = NotificationType.info,
    this.onDismiss,
    this.onAction,
    this.actionText,
    this.autoDismiss = true,
    this.duration,
  });

  @override
  State<NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<NotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    if (widget.autoDismiss) {
      _scheduleAutoDismiss();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scheduleAutoDismiss() {
    final dismissDuration = widget.duration ?? _getDefaultDuration();
    Future.delayed(dismissDuration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  Duration _getDefaultDuration() {
    switch (widget.type) {
      case NotificationType.success:
        return const Duration(seconds: 3);
      case NotificationType.warning:
        return const Duration(seconds: 5);
      case NotificationType.error:
        return const Duration(seconds: 10);
      case NotificationType.info:
      default:
        return const Duration(seconds: 4);
    }
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 100),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getBorderColor(),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 图标
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getIconColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    _getIcon(),
                    color: _getIconColor(),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // 内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: _getTextColor(),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (widget.message != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.message!,
                          style: TextStyle(
                            color: _getTextColor().withOpacity(0.8),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // 操作按钮
                if (widget.actionText != null && widget.onAction != null)
                  TextButton(
                    onPressed: widget.onAction,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      widget.actionText!,
                      style: TextStyle(
                        color: _getTextColor(),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),

                // 关闭按钮
                if (widget.onDismiss != null)
                  GestureDetector(
                    onTap: _dismiss,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        color: _getTextColor().withOpacity(0.6),
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case NotificationType.success:
        return Colors.green.withOpacity(0.9);
      case NotificationType.warning:
        return Colors.orange.withOpacity(0.9);
      case NotificationType.error:
        return Colors.red.withOpacity(0.9);
      case NotificationType.info:
      default:
        return Colors.blue.withOpacity(0.9);
    }
  }

  Color _getBorderColor() {
    switch (widget.type) {
      case NotificationType.success:
        return Colors.green;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.error:
        return Colors.red;
      case NotificationType.info:
      default:
        return Colors.blue;
    }
  }

  Color _getIconColor() {
    switch (widget.type) {
      case NotificationType.success:
        return Colors.green.shade700;
      case NotificationType.warning:
        return Colors.orange.shade700;
      case NotificationType.error:
        return Colors.red.shade700;
      case NotificationType.info:
      default:
        return Colors.blue.shade700;
    }
  }

  Color _getTextColor() {
    switch (widget.type) {
      case NotificationType.success:
      case NotificationType.warning:
      case NotificationType.error:
        return Colors.white;
      case NotificationType.info:
      default:
        return Colors.white;
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.error:
        return Icons.error;
      case NotificationType.info:
      default:
        return Icons.info;
    }
  }
}

/// 通知类型枚举
enum NotificationType {
  info,
  success,
  warning,
  error,
}

/// 通知管理器
class NotificationManager {
  static OverlayEntry? _overlayEntry;

  static void show({
    required BuildContext context,
    required String title,
    String? message,
    NotificationType type = NotificationType.info,
    VoidCallback? onDismiss,
    VoidCallback? onAction,
    String? actionText,
    bool autoDismiss = true,
    Duration? duration,
  }) {
    // 移除之前的通知
    _dismiss();

    // 创建新的通知
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
        left: 8,
        right: 8,
        child: NotificationBanner(
          title: title,
          message: message,
          type: type,
          onDismiss: () {
            _dismiss();
            onDismiss?.call();
          },
          onAction: onAction,
          actionText: actionText,
          autoDismiss: autoDismiss,
          duration: duration,
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  static void _dismiss() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  static void dismiss() {
    _dismiss();
  }

  // 便捷方法
  static void showInfo(BuildContext context, String message, {String? title}) {
    show(
      context: context,
      title: title ?? '提示',
      message: message,
      type: NotificationType.info,
    );
  }

  static void showSuccess(BuildContext context, String message,
      {String? title}) {
    show(
      context: context,
      title: title ?? '成功',
      message: message,
      type: NotificationType.success,
    );
  }

  static void showWarning(BuildContext context, String message,
      {String? title}) {
    show(
      context: context,
      title: title ?? '警告',
      message: message,
      type: NotificationType.warning,
    );
  }

  static void showError(BuildContext context, String message, {String? title}) {
    show(
      context: context,
      title: title ?? '错误',
      message: message,
      type: NotificationType.error,
      autoDismiss: false,
    );
  }
}
