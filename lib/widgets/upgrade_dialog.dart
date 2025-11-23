import 'package:flutter/material.dart';

class UpgradeDialog extends StatelessWidget {
  const UpgradeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 28),
          const SizedBox(width: 12),
          const Text('升级到专业版'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '解锁完整的媒体服务器功能',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          const Text('专业版包含以下功能：'),
          const SizedBox(height: 12),
          _buildFeatureItem('SMB/CIFS 网络共享访问'),
          _buildFeatureItem('FTP/SFTP 安全文件传输'),
          _buildFeatureItem('NFS 网络文件系统支持'),
          _buildFeatureItem('WebDAV 协议支持'),
          _buildFeatureItem('HEVC/H.265 专业解码器'),
          _buildFeatureItem('AI 智能字幕'),
          _buildFeatureItem('多设备同步'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '社区版仅包含基础插件功能',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('暂不升级'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('升级功能即将推出，敬请期待！'),
                backgroundColor: Colors.blue,
              ),
            );
          },
          icon: const Icon(Icons.upgrade),
          label: const Text('立即升级'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feature,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
