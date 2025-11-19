import 'package:flutter/material.dart';
import '../services/history_service.dart';
import '../services/thumbnail_service.dart';
import '../services/settings_service.dart';
import '../services/video_cache_service.dart';
import '../models/cache_entry.dart';
import 'cache_management_screen.dart';
import 'format_support_screen.dart';
import 'video_playback_settings_screen.dart';
import 'metadata_settings_screen.dart';
import 'metadata_management_page.dart';

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
            leading: const Icon(Icons.tune),
            title: const Text('播放设置'),
            subtitle: const Text('调整视频播放质量和性能设置'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VideoPlaybackSettingsScreen(),
                ),
              );
            },
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
          ListTile(
            leading: const Icon(Icons.movie_filter),
            title: const Text('元数据设置'),
            subtitle: const Text('配置 TMDB API Key 以获取在线元数据'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MetadataSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.manage_search),
            title: const Text('元数据管理'),
            subtitle: const Text('查看和管理已刮削的元数据'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MetadataManagementPage(),
                ),
              );
            },
          ),
          FutureBuilder<bool>(
            future: SettingsService.getAutoScrapeEnabled(),
            builder: (context, snapshot) {
              final autoScrapeEnabled = snapshot.data ?? true;
              return SwitchListTile(
                secondary: const Icon(Icons.auto_fix_high),
                title: const Text('自动刮削元数据'),
                subtitle: const Text('扫描视频后自动从 TMDB 获取元数据'),
                value: autoScrapeEnabled,
                onChanged: (value) async {
                  await SettingsService.setAutoScrapeEnabled(value);
                  // Force rebuild
                  (context as Element).markNeedsBuild();
                },
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('缓存管理'),
            subtitle: const Text('管理视频缓存和存储设置'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CacheManagementScreen(),
                ),
              );
            },
          ),
          FutureBuilder<CacheStats>(
            future: VideoCacheService.instance.getStats(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData) {
                return const ListTile(
                  leading: Icon(Icons.error),
                  title: Text('无法加载缓存统计'),
                );
              }

              final stats = snapshot.data!;
              return ExpansionTile(
                leading: const Icon(Icons.storage),
                title: const Text('缓存统计'),
                subtitle: Text('总计 ${stats.totalEntries} 个缓存文件'),
                children: [
                  ListTile(
                    title: Text('总缓存大小: ${_formatFileSize(stats.totalSize)}'),
                    subtitle: Text('已完成: ${stats.completedEntries} 个'),
                  ),
                  ListTile(
                    title: Text('部分下载: ${stats.partialEntries} 个'),
                  ),
                  ListTile(
                    title: Text(
                        '缓存命中率: ${(stats.hitRate * 100).toStringAsFixed(1)}%'),
                  ),
                ],
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
                    title: Text(
                        '总观看时长: ${_formatWatchTime(stats['totalWatchTime'])}'),
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
          ListTile(
            leading: const Icon(Icons.video_file),
            title: const Text('格式支持'),
            subtitle: const Text('查看支持的视频格式和编解码器'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FormatSupportScreen(),
                ),
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class HistorySettingsScreen extends StatefulWidget {
  const HistorySettingsScreen({super.key});

  @override
  State<HistorySettingsScreen> createState() => _HistorySettingsScreenState();
}

class _HistorySettingsScreenState extends State<HistorySettingsScreen> {
  bool _historyEnabled = true;
  int _maxHistoryCount = 50;
  int _autoCleanDays = 30;
  bool _thumbnailsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _historyEnabled = await SettingsService.isHistoryEnabled();
    _maxHistoryCount = await SettingsService.getMaxHistoryCount();
    _autoCleanDays = await SettingsService.getAutoCleanDays();
    _thumbnailsEnabled = await SettingsService.isThumbnailsEnabled();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('播放历史设置'),
        actions: [
          TextButton(
            onPressed: _resetSettings,
            child: const Text('重置'),
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _buildSectionHeader('基本设置'),
          SwitchListTile(
            secondary: const Icon(Icons.history),
            title: const Text('启用历史记录'),
            subtitle: const Text('记录视频观看进度和历史'),
            value: _historyEnabled,
            onChanged: (value) async {
              await SettingsService.setHistoryEnabled(value);
              setState(() {
                _historyEnabled = value;
              });
            },
          ),
          if (_historyEnabled) ...[
            ListTile(
              leading: const Icon(Icons.format_list_numbered),
              title: const Text('最大历史记录数量'),
              subtitle:
                  Text(SettingsService.formatMaxHistoryCount(_maxHistoryCount)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showMaxHistoryCountDialog,
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('自动清理时间'),
              subtitle:
                  Text(SettingsService.formatAutoCleanDays(_autoCleanDays)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showAutoCleanDaysDialog,
            ),
          ],
          const SizedBox(height: 24),
          _buildSectionHeader('缩略图设置'),
          SwitchListTile(
            secondary: const Icon(Icons.image),
            title: const Text('生成缩略图'),
            subtitle: const Text('为视频生成预览缩略图'),
            value: _thumbnailsEnabled,
            onChanged: _historyEnabled
                ? (value) async {
                    await SettingsService.setThumbnailsEnabled(value);
                    setState(() {
                      _thumbnailsEnabled = value;
                    });
                  }
                : null,
          ),
          if (_thumbnailsEnabled)
            ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('缩略图缓存'),
              subtitle: const Text('管理缩略图缓存'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showThumbnailCacheDialog,
            ),
          const SizedBox(height: 24),
          _buildSectionHeader('数据管理'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('历史记录说明'),
            subtitle: Text('最多保存 $_maxHistoryCount 条记录，$_autoCleanDays 天后自动清理'),
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('历史统计'),
            subtitle: const Text('查看播放统计信息'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showStatisticsDialog,
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.red),
            title: const Text('清空所有历史'),
            subtitle: const Text('删除所有播放历史记录'),
            onTap: _showClearAllDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Future<void> _resetSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置设置'),
        content: const Text('确定要重置所有设置为默认值吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('重置'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SettingsService.resetToDefaults();
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置已重置为默认值')),
        );
      }
    }
  }

  Future<void> _showMaxHistoryCountDialog() async {
    final controller = TextEditingController(text: _maxHistoryCount.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('最大历史记录数量'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '记录数量',
            hintText: '1-200',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null &&
                  SettingsService.isValidMaxHistoryCount(value)) {
                Navigator.of(context).pop(value);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null) {
      await SettingsService.setMaxHistoryCount(result);
      setState(() {
        _maxHistoryCount = result;
      });
    }
  }

  Future<void> _showAutoCleanDaysDialog() async {
    final options = [7, 30, 90, 180, 365];
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自动清理时间'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map((days) => RadioListTile<int>(
                    title: Text(SettingsService.formatAutoCleanDays(days)),
                    value: days,
                    groupValue: _autoCleanDays,
                    onChanged: (value) => Navigator.of(context).pop(value),
                  ))
              .toList(),
        ),
      ),
    );

    if (result != null) {
      await SettingsService.setAutoCleanDays(result);
      setState(() {
        _autoCleanDays = result;
      });
    }
  }

  Future<void> _showThumbnailCacheDialog() async {
    final cacheStats = await ThumbnailService.getCacheStats();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('缩略图缓存'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('缓存文件数量: ${cacheStats['fileCount']}'),
            Text('占用空间: ${cacheStats['formattedSize']}'),
            const SizedBox(height: 16),
            const Text('清理缓存将删除所有缩略图文件'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ThumbnailService.clearCache();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('缩略图缓存已清理')),
                );
              }
            },
            child: const Text('清理缓存'),
          ),
        ],
      ),
    );
  }

  Future<void> _showStatisticsDialog() async {
    final stats = await HistoryService.getStatistics();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('播放统计'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('总视频数: ${stats['totalCount']}'),
            Text('总观看次数: ${stats['totalWatchCount']}'),
            Text('总观看时长: ${_formatWatchTime(stats['totalWatchTime'])}'),
            Text('已完成: ${stats['completedCount']}'),
            Text('最近观看: ${stats['recentCount']}'),
            Text('今天观看: ${stats['todayCount']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _showClearAllDialog() async {
    // 先获取清理统计信息
    final cleanupStats = await HistoryService.getCleanupStats();

    bool clearHistory = true;
    bool clearThumbnails = false;
    bool clearVideoCache = false;
    bool clearNetworkCache = true;

    final clearOptions = await showDialog<Map<String, bool>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('选择要清理的内容：'),
                const SizedBox(height: 16),

                // 播放历史（总是显示）
                CheckboxListTile(
                  title: const Text('播放历史记录'),
                  subtitle: Text('${cleanupStats['histories']?['total'] ?? 0} 条记录'),
                  value: clearHistory,
                  onChanged: (value) {
                    clearHistory = value ?? false;
                    setState(() {});
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),

                // 网络视频缓存
                CheckboxListTile(
                  title: const Text('网络视频缓存'),
                  subtitle: Text('${cleanupStats['histories']?['network'] ?? 0} 个网络视频'),
                  value: clearNetworkCache,
                  onChanged: (value) {
                    clearNetworkCache = value ?? false;
                    setState(() {});
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),

                // 缩略图缓存
                CheckboxListTile(
                  title: const Text('缩略图缓存'),
                  subtitle: Text('${cleanupStats['thumbnails']?['networkThumbnails'] ?? 0} 个网络缩略图'),
                  value: clearThumbnails,
                  onChanged: (value) {
                    clearThumbnails = value ?? false;
                    setState(() {});
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),

                const SizedBox(height: 8),
                const Text(
                  '注意：此操作不可恢复',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop({
                'clearHistory': clearHistory,
                'clearThumbnails': clearThumbnails,
                'clearVideoCache': clearVideoCache,
                'clearNetworkCache': clearNetworkCache,
              });
            },
            child: const Text('确定清空'),
          ),
        ],
      ),
    );

    if (clearOptions != null) {
      // 显示清理进度对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在清理...'),
            ],
          ),
        ),
      );

      try {
        // 执行清理
        await HistoryService.clearAllHistories(
          clearThumbnails: clearOptions['clearThumbnails'] ?? false,
          clearVideoCache: clearOptions['clearVideoCache'] ?? false,
          clearNetworkCache: clearOptions['clearNetworkCache'] ?? false,
        );

        // 关闭进度对话框
        if (mounted) Navigator.of(context).pop();

        // 显示成功消息
        if (mounted) {
          final clearedItems = <String>[];
          if (clearOptions['clearHistory'] == true) clearedItems.add('播放历史');
          if (clearOptions['clearNetworkCache'] == true) clearedItems.add('网络视频缓存');
          if (clearOptions['clearThumbnails'] == true) clearedItems.add('缩略图缓存');
          if (clearOptions['clearVideoCache'] == true) clearedItems.add('本地视频缓存');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已清理：${clearedItems.join('、')}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          // 如果清理了播放历史，返回上一级
          if (clearOptions['clearHistory'] == true) {
            Navigator.of(context).pop();
          }
        }
      } catch (e) {
        // 关闭进度对话框
        if (mounted) Navigator.of(context).pop();

        // 显示错误消息
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('清理失败：$e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
