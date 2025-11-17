import 'package:flutter/material.dart';

/// 缓冲状态指示器
class BufferingIndicator extends StatefulWidget {
  final bool isBuffering;
  final String? message;
  final double? progress;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const BufferingIndicator({
    Key? key,
    required this.isBuffering,
    this.message,
    this.progress,
    this.backgroundColor,
    this.foregroundColor,
  }) : super(key: key);

  @override
  State<BufferingIndicator> createState() => _BufferingIndicatorState();
}

class _BufferingIndicatorState extends State<BufferingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    if (widget.isBuffering) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(BufferingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isBuffering != oldWidget.isBuffering) {
      if (widget.isBuffering) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isBuffering) {
      return const SizedBox.shrink();
    }

    return Container(
      color: widget.backgroundColor ?? Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 旋转图标
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value * 2 * 3.14159,
                  child: Icon(
                    Icons.sync,
                    size: 48,
                    color: widget.foregroundColor ?? Colors.white,
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // 缓冲消息
            Text(
              widget.message ?? '缓冲中...',
              style: TextStyle(
                color: widget.foregroundColor ?? Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),

            if (widget.progress != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: 200,
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: widget.progress,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.foregroundColor ?? Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(widget.progress! * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: widget.foregroundColor ?? Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 小型缓冲指示器（显示在角落）
class MiniBufferingIndicator extends StatelessWidget {
  final bool isBuffering;
  final Color? color;
  final double size;

  const MiniBufferingIndicator({
    Key? key,
    required this.isBuffering,
    this.color,
    this.size = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isBuffering) {
      return const SizedBox.shrink();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.6,
          height: size * 0.6,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(color ?? Colors.white),
          ),
        ),
      ),
    );
  }
}

/// 网络状态指示器
class NetworkStatusIndicator extends StatelessWidget {
  final String status;
  final Color? color;

  const NetworkStatusIndicator({
    Key? key,
    required this.status,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(),
            size: 16,
            color: color ?? Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (status.toLowerCase()) {
      case '已连接':
      case 'connected':
      case '播放中':
        return Icons.wifi;
      case '缓冲中':
      case 'buffering':
        return Icons.hourglass_empty;
      case '离线':
      case 'offline':
        return Icons.signal_wifi_off;
      case '错误':
      case 'error':
        return Icons.error_outline;
      default:
        return Icons.help_outline;
    }
  }
}

/// 带网络状态的缓冲指示器
class NetworkBufferingIndicator extends StatelessWidget {
  final bool isBuffering;
  final String networkStatus;
  final String? bufferingMessage;
  final double? bufferingProgress;

  const NetworkBufferingIndicator({
    Key? key,
    required this.isBuffering,
    required this.networkStatus,
    this.bufferingMessage,
    this.bufferingProgress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 缓冲指示器
        BufferingIndicator(
          isBuffering: isBuffering,
          message: bufferingMessage,
          progress: bufferingProgress,
        ),

        // 网络状态指示器
        Positioned(
          top: 16,
          left: 16,
          child: NetworkStatusIndicator(
            status: networkStatus,
          ),
        ),

        // 网络断开时的提示
        if (networkStatus == '离线')
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '网络连接已断开，请检查网络设置',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}