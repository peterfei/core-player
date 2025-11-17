import 'package:flutter/material.dart';
import '../services/enhanced_thumbnail_service.dart';
import '../services/settings_service.dart';

class ThumbnailSettingsWidget extends StatefulWidget {
  const ThumbnailSettingsWidget({super.key});

  @override
  State<ThumbnailSettingsWidget> createState() => _ThumbnailSettingsWidgetState();
}

class _ThumbnailSettingsWidgetState extends State<ThumbnailSettingsWidget> {
  ThumbnailQuality _selectedQuality = ThumbnailQuality.medium;
  ThumbnailPosition _selectedPosition = ThumbnailPosition.start;
  bool _enableGif = false;
  bool _autoGenerate = true;
  bool _useMemoryCache = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // 从设置服务加载当前设置
    // 这里使用默认值，实际项目中应该保存到SharedPreferences
    setState(() {
      _selectedQuality = ThumbnailQuality.medium;
      _selectedPosition = ThumbnailPosition.start;
      _enableGif = false;
      _autoGenerate = true;
      _useMemoryCache = true;
    });
  }

  Future<void> _saveSettings() async {
    // 保存设置到SharedPreferences
    // 实际实现中需要添加相应的保存方法
    print('保存缩略图设置: 质量=$_selectedQuality, 位置=$_selectedPosition, GIF=$_enableGif');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_size_select_actual),
                const SizedBox(width: 8),
                Text(
                  '缩略图设置',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 启用自动生成
            SwitchListTile(
              title: const Text('自动生成缩略图'),
              subtitle: const Text('播放视频时自动生成缩略图'),
              value: _autoGenerate,
              onChanged: (value) {
                setState(() {
                  _autoGenerate = value;
                });
                _saveSettings();
              },
            ),

            // 质量设置
            if (_autoGenerate) ...[
              const SizedBox(height: 8),
              Text(
                '缩略图质量',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...ThumbnailQuality.values.map((quality) => RadioListTile<ThumbnailQuality>(
                title: Text(quality.label),
                value: quality,
                groupValue: _selectedQuality,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedQuality = value;
                    });
                    _saveSettings();
                  }
                },
              )),

              // 截取位置设置
              const SizedBox(height: 16),
              Text(
                '缩略图截取位置',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...ThumbnailPosition.values.map((position) => RadioListTile<ThumbnailPosition>(
                title: Text(position.label),
                value: position,
                groupValue: _selectedPosition,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPosition = value;
                    });
                    _saveSettings();
                  }
                },
              )),

              // GIF设置
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('GIF动图缩略图'),
                subtitle: const Text('生成前3秒的GIF预览（需要更多时间）'),
                value: _enableGif,
                onChanged: (value) {
                  setState(() {
                    _enableGif = value;
                  });
                  _saveSettings();
                },
              ),

              // 内存缓存设置
              SwitchListTile(
                title: const Text('内存缓存'),
                subtitle: const Text('在内存中缓存缩略图以提高性能'),
                value: _useMemoryCache,
                onChanged: (value) {
                  setState(() {
                    _useMemoryCache = value;
                  });
                  if (!value) {
                    EnhancedThumbnailService.clearMemoryCache();
                  }
                  _saveSettings();
                },
              ),
            ],

            const SizedBox(height: 16),

            // 支持的功能信息
            ExpansionTile(
              title: const Text('支持的功能'),
              leading: const Icon(Icons.info),
              children: [
                _buildFeatureInfo(),
              ],
            ),

            const SizedBox(height: 16),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _clearAllCaches,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('清理所有缓存'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _regenerateAll,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重新生成'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureInfo() {
    final features = EnhancedThumbnailService.getSupportedFeatures();

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('当前平台支持的功能：', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...features.entries.map((entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  entry.value ? Icons.check_circle : Icons.cancel,
                  color: entry.value ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getFeatureDisplayName(entry.key),
                    style: TextStyle(
                      color: entry.value ? null : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          )),
          if (_useMemoryCache) ...[
            const SizedBox(height: 8),
            Text('内存缓存: ${EnhancedThumbnailService.memoryCacheSize} 项'),
          ],
        ],
      ),
    );
  }

  String _getFeatureDisplayName(String feature) {
    switch (feature) {
      case 'video_thumbnail_package':
        return 'Video Thumbnail 包（推荐）';
      case 'ffmpeg_kit':
        return 'FFmpegKit（现代FFmpeg接口）';
      case 'system_command':
        return '系统命令（系统FFmpeg）';
      case 'flutter_ffmpeg':
        return 'Flutter FFmpeg 插件';
      case 'gif_generation':
        return 'GIF动图生成';
      case 'memory_cache':
        return '内存缓存';
      case 'file_cache':
        return '文件缓存';
      default:
        return feature;
    }
  }

  Future<void> _clearAllCaches() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清理'),
        content: const Text('这将删除所有缩略图缓存，确认要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // 清理内存缓存
        EnhancedThumbnailService.clearMemoryCache();

        // 清理文件缓存（需要导入ThumbnailService）
        // await ThumbnailService.clearCache();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('缩略图缓存已清理')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('清理失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _regenerateAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认重新生成'),
        content: const Text('这将重新生成所有视频的缩略图，可能需要较长时间，确认要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 这里应该触发批量重新生成
      // 需要从HistoryService获取所有历史记录并重新生成缩略图
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('重新生成功能开发中...')),
        );
      }
    }
  }
}