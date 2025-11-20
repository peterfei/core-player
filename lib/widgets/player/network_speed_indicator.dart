import 'package:flutter/material.dart';
import '../../services/traffic_monitor_service.dart';

/// 网速指示器（左上角显示实时网络速度）
class NetworkSpeedIndicator extends StatelessWidget {
  const NetworkSpeedIndicator({super.key});

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '$bytesPerSecond B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      final kbs = (bytesPerSecond / 1024).toStringAsFixed(0);
      return '$kbs KB/s';
    } else {
      final mbs = (bytesPerSecond / (1024 * 1024)).toStringAsFixed(1);
      return '$mbs MB/s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: TrafficMonitorService.instance.speedStream,
      initialData: 0,
      builder: (context, snapshot) {
        final speed = snapshot.data ?? 0;
        
        // 只在有流量时显示
        if (speed == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _formatSpeed(speed),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
