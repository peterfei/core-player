import 'package:flutter/material.dart';
import '../models/buffer_config.dart';
import '../models/network_stats.dart';

/// 增强版缓冲指示器
class EnhancedBufferingIndicator extends StatelessWidget {
  final bool isBuffering;
  final double bufferProgress; // 0-100%
  final Duration bufferedDuration;
  final double downloadSpeed; // 当前下载速度
  final BufferHealth health; // 缓冲健康状态
  final NetworkQuality networkQuality;
  final String? message;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const EnhancedBufferingIndicator({
    Key? key,
    required this.isBuffering,
    required this.bufferProgress,
    required this.bufferedDuration,
    required this.downloadSpeed,
    required this.health,
    required this.networkQuality,
    this.message,
    this.backgroundColor,
    this.foregroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isBuffering) {
      return const SizedBox.shrink();
    }

    final colors = _getHealthColors(Theme.of(context));

    return Container(
      color: backgroundColor ?? Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 主缓冲进度
            _buildBufferProgress(context, colors),
            const SizedBox(height: 20),

            // 缓冲状态信息
            _buildBufferInfo(colors),

            // 网络状态信息
            if (downloadSpeed > 0) ...[
              const SizedBox(height: 12),
              _buildNetworkInfo(colors),
            ],

            // 自定义消息
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBufferProgress(BuildContext context, HealthColors colors) {
    return Container(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 背景圆环
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              strokeWidth: 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(colors.background),
            ),
          ),

          // 进度圆环
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              strokeWidth: 8,
              value: bufferProgress / 100,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),

          // 中心信息
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getHealthIcon(),
                size: 32,
                color: colors.primary,
              ),
              const SizedBox(height: 8),
              Text(
                '${bufferProgress.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${bufferedDuration.inSeconds}s',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBufferInfo(HealthColors colors) {
    final healthStatus = _getHealthDescription();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.background.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            healthStatus,
            style: TextStyle(
              color: colors.text,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkInfo(HealthColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.speed,
            size: 20,
            color: colors.secondary,
          ),
          const SizedBox(width: 8),
          Text(
            formatSpeed(downloadSpeed),
            style: TextStyle(
              color: colors.text,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 16),
          Icon(
            _getNetworkQualityIcon(),
            size: 20,
            color: colors.secondary,
          ),
          const SizedBox(width: 4),
          Text(
            networkQuality.name,
            style: TextStyle(
              color: colors.text,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  HealthColors _getHealthColors(ThemeData theme) {
    switch (health) {
      case BufferHealth.excellent:
        return HealthColors(
          primary: Colors.blue,
          secondary: Colors.blue.shade300,
          background: Colors.blue.withOpacity(0.2),
          text: Colors.white,
        );
      case BufferHealth.healthy:
        return HealthColors(
          primary: Colors.green,
          secondary: Colors.green.shade300,
          background: Colors.green.withOpacity(0.2),
          text: Colors.white,
        );
      case BufferHealth.warning:
        return HealthColors(
          primary: Colors.orange,
          secondary: Colors.orange.shade300,
          background: Colors.orange.withOpacity(0.2),
          text: Colors.white,
        );
      case BufferHealth.critical:
        return HealthColors(
          primary: Colors.red,
          secondary: Colors.red.shade300,
          background: Colors.red.withOpacity(0.2),
          text: Colors.white,
        );
    }
  }

  IconData _getHealthIcon() {
    switch (health) {
      case BufferHealth.excellent:
        return Icons.sentiment_very_satisfied;
      case BufferHealth.healthy:
        return Icons.sentiment_satisfied;
      case BufferHealth.warning:
        return Icons.sentiment_neutral;
      case BufferHealth.critical:
        return Icons.sentiment_very_dissatisfied;
    }
  }

  String _getHealthDescription() {
    switch (health) {
      case BufferHealth.excellent:
        return '缓冲优秀';
      case BufferHealth.healthy:
        return '缓冲良好';
      case BufferHealth.warning:
        return '缓冲偏低';
      case BufferHealth.critical:
        return '缓冲严重不足';
    }
  }

  IconData _getNetworkQualityIcon() {
    switch (networkQuality) {
      case NetworkQuality.excellent:
        return Icons.signal_cellular_alt;
      case NetworkQuality.good:
        return Icons.signal_cellular_alt_2_bar;
      case NetworkQuality.moderate:
        return Icons.signal_cellular_alt_1_bar;
      case NetworkQuality.poor:
      case NetworkQuality.critical:
        return Icons.signal_cellular_off;
    }
  }
}

/// 健康状态颜色配置
class HealthColors {
  final Color primary;
  final Color secondary;
  final Color background;
  final Color text;

  const HealthColors({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.text,
  });
}

/// 小型增强缓冲指示器
class MiniEnhancedBufferingIndicator extends StatelessWidget {
  final bool isBuffering;
  final BufferHealth health;
  final double bufferProgress;
  final double size;
  final Color? color;

  const MiniEnhancedBufferingIndicator({
    Key? key,
    required this.isBuffering,
    required this.health,
    required this.bufferProgress,
    this.size = 40,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isBuffering) {
      return const SizedBox.shrink();
    }

    final healthColor = _getHealthColor();

    return Container(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 背景圆环
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.4)),
            ),
          ),

          // 进度圆环
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: bufferProgress / 100,
              valueColor: AlwaysStoppedAnimation<Color>(healthColor),
            ),
          ),

          // 健康状态点
          if (health != BufferHealth.healthy &&
              health != BufferHealth.excellent)
            Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                color: healthColor,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Color _getHealthColor() {
    switch (health) {
      case BufferHealth.excellent:
        return Colors.blue;
      case BufferHealth.healthy:
        return Colors.green;
      case BufferHealth.warning:
        return Colors.orange;
      case BufferHealth.critical:
        return Colors.red;
    }
  }
}

/// 缓冲健康状态面板
class BufferHealthPanel extends StatelessWidget {
  final BufferHealth health;
  final Duration bufferedDuration;
  final Duration targetDuration;
  final double downloadSpeed;
  final NetworkStats networkStats;

  const BufferHealthPanel({
    Key? key,
    required this.health,
    required this.bufferedDuration,
    required this.targetDuration,
    required this.downloadSpeed,
    required this.networkStats,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final healthColor = _getHealthColor();
    final healthIcon = _getHealthIcon();
    final healthDescription = _getHealthDescription();

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Icon(healthIcon, color: healthColor),
                const SizedBox(width: 8),
                Text(
                  '缓冲状态',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: healthColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 健康状态
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: healthColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: healthColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    healthDescription,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: healthColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '已缓冲: ${bufferedDuration.inSeconds} / ${targetDuration.inSeconds} 秒',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 网络信息
            _buildNetworkInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '网络信息',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                '下载速度',
                formatSpeed(downloadSpeed),
                Icons.speed,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildInfoCard(
                '网络质量',
                networkStats.quality.name,
                _getNetworkQualityIcon(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                '稳定性',
                '${(networkStats.stability * 100).toStringAsFixed(0)}%',
                Icons.network_check,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildInfoCard(
                '延迟',
                '${networkStats.latency}ms',
                Icons.timer,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getHealthColor() {
    switch (health) {
      case BufferHealth.excellent:
        return Colors.blue;
      case BufferHealth.healthy:
        return Colors.green;
      case BufferHealth.warning:
        return Colors.orange;
      case BufferHealth.critical:
        return Colors.red;
    }
  }

  IconData _getHealthIcon() {
    switch (health) {
      case BufferHealth.excellent:
        return Icons.sentiment_very_satisfied;
      case BufferHealth.healthy:
        return Icons.sentiment_satisfied;
      case BufferHealth.warning:
        return Icons.sentiment_neutral;
      case BufferHealth.critical:
        return Icons.sentiment_very_dissatisfied;
    }
  }

  String _getHealthDescription() {
    switch (health) {
      case BufferHealth.excellent:
        return '缓冲状态极佳，播放流畅';
      case BufferHealth.healthy:
        return '缓冲状态良好，可以正常播放';
      case BufferHealth.warning:
        return '缓冲偏低，可能出现卡顿';
      case BufferHealth.critical:
        return '缓冲严重不足，即将卡顿';
    }
  }

  IconData _getNetworkQualityIcon() {
    switch (networkStats.quality) {
      case NetworkQuality.excellent:
        return Icons.signal_cellular_alt;
      case NetworkQuality.good:
        return Icons.signal_cellular_alt_2_bar;
      case NetworkQuality.moderate:
        return Icons.signal_cellular_alt_1_bar;
      case NetworkQuality.poor:
      case NetworkQuality.critical:
        return Icons.signal_cellular_off;
    }
  }
}
