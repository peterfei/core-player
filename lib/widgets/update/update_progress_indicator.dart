import 'package:flutter/material.dart';
import '../../models/update/update_models.dart';

/// 更新进度指示器
class UpdateProgressIndicator extends StatelessWidget {
  final DownloadProgress? progress;
  final String stage;
  final VoidCallback? onCancel;

  const UpdateProgressIndicator({
    Key? key,
    this.progress,
    required this.stage,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _getStageText(),
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            if (progress != null && progress!.percentage > 0)
              Text(
                '${progress!.percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress?.percentage != null ? progress!.percentage / 100 : null,
          backgroundColor: Colors.grey[200],
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        if (progress != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                progress!.formattedSpeed,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              if (progress!.formattedTimeRemaining != null)
                Text(
                  '剩余: ${progress!.formattedTimeRemaining}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
        if (onCancel != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onCancel,
              child: const Text('取消'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: EdgeInsets.zero,
                minimumSize: const Size(50, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _getStageText() {
    switch (stage) {
      case 'checking':
        return '正在检查更新...';
      case 'downloading':
        return '正在下载...';
      case 'installing':
        return '正在安装...';
      case 'verifying':
        return '正在验证...';
      case 'backing_up':
        return '正在备份...';
      case 'restoring':
        return '正在恢复...';
      default:
        return '处理中...';
    }
  }
}
