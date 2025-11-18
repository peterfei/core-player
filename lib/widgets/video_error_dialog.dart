import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 视频播放错误对话框
/// 提供详细的错误信息和解决建议
class VideoErrorDialog extends StatelessWidget {
  final String title;
  final String error;
  final VideoErrorType errorType;
  final String? videoPath;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;

  const VideoErrorDialog({
    super.key,
    required this.title,
    required this.error,
    required this.errorType,
    this.videoPath,
    this.onRetry,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _getErrorIcon(),
            color: _getErrorColor(),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 错误描述
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(
                error,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 错误类型说明
            _buildErrorDescription(),
            const SizedBox(height: 16),

            // 解决方案建议
            _buildSolutionsSection(context),
            const SizedBox(height: 16),

            // 技术详情（可选）
            if (videoPath != null) _buildTechnicalDetails(),
          ],
        ),
      ),
      actions: [
        // 取消按钮
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),

        // 重试按钮
        if (onRetry != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry!();
            },
            child: const Text('重试'),
          ),

        // 设置按钮
        if (onOpenSettings != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onOpenSettings!();
            },
            child: const Text('打开设置'),
          ),

        // 获取帮助按钮
        TextButton(
          onPressed: () => _openHelp(),
          child: const Text('获取帮助'),
        ),
      ],
    );
  }

  Widget _buildErrorDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '错误类型',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              _getErrorIcon(),
              size: 16,
              color: _getErrorColor(),
            ),
            const SizedBox(width: 6),
            Text(
              _getErrorTypeName(),
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: _getErrorColor(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _getErrorDescription(),
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildSolutionsSection(BuildContext context) {
    final solutions = _getSolutions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '解决方案',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        ...solutions.asMap().entries.map((entry) {
          final index = entry.key;
          final solution = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    solution,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTechnicalDetails() {
    return ExpansionTile(
      title: Text(
        '技术详情',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('文件路径', videoPath!),
              _buildDetailRow('错误类型', errorType.toString()),
              if (errorType == VideoErrorType.codecNotSupported)
                _buildDetailRow('建议编解码器', 'H.264, HEVC, VP9'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getErrorIcon() {
    switch (errorType) {
      case VideoErrorType.fileNotFound:
        return Icons.insert_drive_file;
      case VideoErrorType.codecNotSupported:
        return Icons.video_settings;
      case VideoErrorType.hardwareAccelerationFailed:
        return Icons.speed;
      case VideoErrorType.networkError:
        return Icons.wifi_off;
      case VideoErrorType.permissionDenied:
        return Icons.no_encryption;
      case VideoErrorType.corruptedFile:
        return Icons.broken_image;
      case VideoErrorType.memoryError:
        return Icons.memory;
      case VideoErrorType.unknown:
        return Icons.error;
    }
  }

  Color _getErrorColor() {
    switch (errorType) {
      case VideoErrorType.fileNotFound:
      case VideoErrorType.permissionDenied:
        return Colors.orange;
      case VideoErrorType.codecNotSupported:
      case VideoErrorType.hardwareAccelerationFailed:
        return Colors.red;
      case VideoErrorType.networkError:
        return Colors.blue;
      case VideoErrorType.corruptedFile:
        return Colors.purple;
      case VideoErrorType.memoryError:
        return Colors.amber;
      case VideoErrorType.unknown:
        return Colors.grey;
    }
  }

  String _getErrorTypeName() {
    switch (errorType) {
      case VideoErrorType.fileNotFound:
        return '文件未找到';
      case VideoErrorType.codecNotSupported:
        return '编解码器不支持';
      case VideoErrorType.hardwareAccelerationFailed:
        return '硬件加速失败';
      case VideoErrorType.networkError:
        return '网络错误';
      case VideoErrorType.permissionDenied:
        return '权限不足';
      case VideoErrorType.corruptedFile:
        return '文件损坏';
      case VideoErrorType.memoryError:
        return '内存不足';
      case VideoErrorType.unknown:
        return '未知错误';
    }
  }

  String _getErrorDescription() {
    switch (errorType) {
      case VideoErrorType.fileNotFound:
        return '无法找到指定的视频文件，可能是文件被移动、删除或路径不正确。';
      case VideoErrorType.codecNotSupported:
        return '视频使用了不支持的编解码器，需要安装相应的解码器或转换格式。';
      case VideoErrorType.hardwareAccelerationFailed:
        return '硬件加速初始化失败，已自动切换到软件解码模式。';
      case VideoErrorType.networkError:
        return '无法连接到网络视频源，请检查网络连接或URL是否正确。';
      case VideoErrorType.permissionDenied:
        return '没有足够权限访问该文件或目录。';
      case VideoErrorType.corruptedFile:
        return '视频文件可能已损坏或格式不正确。';
      case VideoErrorType.memoryError:
        return '系统内存不足，无法加载或播放该视频。';
      case VideoErrorType.unknown:
        return '发生了未知的错误，请重试或联系技术支持。';
    }
  }

  List<String> _getSolutions() {
    switch (errorType) {
      case VideoErrorType.fileNotFound:
        return [
          '检查文件是否存在于指定路径',
          '确认文件没有被重命名或移动',
          '检查文件路径是否包含特殊字符',
          '重新选择视频文件'
        ];
      case VideoErrorType.codecNotSupported:
        return [
          '安装相应的编解码器包',
          '使用视频转换工具转换为支持的格式',
          '在设置中查看支持的格式列表',
          '尝试使用其他播放器转换格式'
        ];
      case VideoErrorType.hardwareAccelerationFailed:
        return [
          '在设置中禁用硬件加速',
          '更新显卡驱动程序',
          '检查系统是否支持硬件解码',
          '重启应用程序'
        ];
      case VideoErrorType.networkError:
        return [
          '检查网络连接是否正常',
          '确认URL地址是否正确',
          '尝试使用其他网络',
          '检查防火墙设置'
        ];
      case VideoErrorType.permissionDenied:
        return [
          '以管理员身份运行应用',
          '检查文件和目录的访问权限',
          '将文件移动到有权限的位置',
          '在文件属性中修改权限'
        ];
      case VideoErrorType.corruptedFile:
        return [
          '尝试使用视频修复工具',
          '重新下载或复制文件',
          '检查文件完整性',
          '尝试播放其他视频测试播放器'
        ];
      case VideoErrorType.memoryError:
        return [
          '关闭其他应用程序释放内存',
          '重启设备',
          '尝试播放较小的视频文件',
          '在设置中降低缓冲大小'
        ];
      case VideoErrorType.unknown:
        return [
          '重启应用程序',
          '检查系统更新',
          '尝试播放其他视频文件',
          '联系技术支持'
        ];
    }
  }

  Future<void> _openHelp() async {
    final url = Uri.parse('https://github.com/anthropics/claude-code/issues');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  /// 显示错误对话框的静态方法
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String error,
    required VideoErrorType errorType,
    String? videoPath,
    VoidCallback? onRetry,
    VoidCallback? onOpenSettings,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return VideoErrorDialog(
          title: title,
          error: error,
          errorType: errorType,
          videoPath: videoPath,
          onRetry: onRetry,
          onOpenSettings: onOpenSettings,
        );
      },
    );
  }
}

/// 视频错误类型枚举
enum VideoErrorType {
  fileNotFound,
  codecNotSupported,
  hardwareAccelerationFailed,
  networkError,
  permissionDenied,
  corruptedFile,
  memoryError,
  unknown,
}