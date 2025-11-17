import 'package:flutter/material.dart';
import '../services/history_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.color_lens),
            title: Text('外观设置'),
            subtitle: Text('更改应用的外观和感觉'),
            enabled: false,
          ),
          const ListTile(
            leading: Icon(Icons.notifications),
            title: Text('通知设置'),
            subtitle: Text('管理通知偏好设置'),
            enabled: false,
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('播放历史设置'),
            subtitle: const Text('管理播放历史记录'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HistorySettingsScreen(),
                ),
              );
            },
          ),
          const Divider(),
          FutureBuilder<Map<String, dynamic>>(
            future: HistoryService.getStatistics(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData) {
                return const ListTile(
                  leading: Icon(Icons.error),
                  title: Text('无法加载统计信息'),
                );
              }

              final stats = snapshot.data!;
              return ExpansionTile(
                leading: const Icon(Icons.analytics),
                title: const Text('播放统计'),
                subtitle: Text('总计 ${stats['totalCount']} 个视频'),
                children: [
                  ListTile(
                    title: Text('总观看时长: ${_formatWatchTime(stats['totalWatchTime'])}'),
                    subtitle: Text('已完成: ${stats['completedCount']} 个'),
                  ),
                  ListTile(
                    title: Text('最近一周观看: ${stats['recentCount']} 个'),
                  ),
                ],
              );
            },
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('关于应用'),
            subtitle: Text('应用版本和相关信息'),
          ),
        ],
      ),
    );
  }

  String _formatWatchTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '$hours小时$minutes分钟';
    } else {
      return '$minutes分钟';
    }
  }
}

class HistorySettingsScreen extends StatelessWidget {
  const HistorySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('播放历史设置'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('历史记录说明'),
            subtitle: const Text('最多保存50条记录，30天后自动清理'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text('清空所有历史'),
            subtitle: const Text('删除所有播放历史记录'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('确认清空'),
                  content: const Text('确定要清空所有播放历史记录吗？此操作不可恢复。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await HistoryService.clearAllHistories();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已清空所有历史记录')),
                          );
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('确定清空'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
