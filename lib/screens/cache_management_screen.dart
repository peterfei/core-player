import 'package:flutter/material.dart';
import '../models/cache_config.dart';
import '../models/cache_entry.dart';
import '../services/video_cache_service.dart';

class CacheManagementScreen extends StatefulWidget {
  const CacheManagementScreen({Key? key}) : super(key: key);

  @override
  State<CacheManagementScreen> createState() => _CacheManagementScreenState();
}

class _CacheManagementScreenState extends State<CacheManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CacheConfig _config = const CacheConfig();
  CacheStats _stats = CacheStats.empty();
  List<CacheEntry> _cachedVideos = [];
  List<CacheEntry> _partialDownloads = [];
  bool _isLoading = true;
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final cacheService = VideoCacheService.instance;
      await cacheService.initialize();

      final config = cacheService.config;
      final stats = await cacheService.getStats();
      final cachedVideos = await cacheService.getAllCachedVideos();
      final partialDownloads = await cacheService.getPartialCachedVideos();

      if (mounted) {
        setState(() {
          _config = config;
          _stats = stats;
          _cachedVideos = cachedVideos;
          _partialDownloads = partialDownloads;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _clearAllCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除所有缓存'),
        content: const Text('确定要清除所有缓存吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isClearingCache = true;
      });

      try {
        final cacheService = VideoCacheService.instance;
        await cacheService.clearAllCache();
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('所有缓存已清除'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('清除失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() {
          _isClearingCache = false;
        });
      }
    }
  }

  Future<void> _removeSingleCache(CacheEntry entry) async {
    try {
      final cacheService = VideoCacheService.instance;
      await cacheService.removeCache(entry.url);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('缓存已移除'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('移除失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('缓存管理'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.settings), text: '设置'),
            Tab(icon: Icon(Icons.video_library), text: '已缓存'),
            Tab(icon: Icon(Icons.download), text: '下载中'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '刷新',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSettingsTab(),
          _buildCachedVideosTab(),
          _buildPartialDownloadsTab(),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 缓存状态卡片
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '缓存状态',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStatusRow(
                          '总缓存数量',
                          '${_stats.totalEntries} 个文件',
                        ),
                        _buildStatusRow(
                          '已完成缓存',
                          '${_stats.completedEntries} 个文件',
                        ),
                        _buildStatusRow(
                          '部分下载',
                          '${_stats.partialEntries} 个文件',
                        ),
                        _buildStatusRow(
                          '总缓存大小',
                          _formatFileSize(_stats.totalSize),
                        ),
                        _buildStatusRow(
                          '最大缓存限制',
                          _formatFileSize(_config.maxSizeBytes),
                        ),
                        _buildStatusRow(
                          '命中率',
                          '${(_stats.hitRate * 100).toStringAsFixed(1)}%',
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: _config.maxSizeBytes > 0
                              ? _stats.totalSize / _config.maxSizeBytes
                              : 0.0,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _stats.totalSize / _config.maxSizeBytes > 0.9
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '存储使用率: ${(_config.maxSizeBytes > 0 ? (_stats.totalSize / _config.maxSizeBytes * 100).toStringAsFixed(1) : 0.0)}%',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 缓存设置卡片
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '缓存设置',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 启用缓存开关
                        SwitchListTile(
                          title: const Text('启用视频缓存'),
                          subtitle: const Text('保存已播放的视频到本地存储'),
                          value: _config.isEnabled,
                          onChanged: (value) async {
                            final newConfig =
                                _config.copyWith(isEnabled: value);
                            await VideoCacheService.instance
                                .updateConfig(newConfig);
                            setState(() {
                              _config = newConfig;
                            });
                          },
                        ),

                        // 缓存大小限制滑块
                        Text(
                          '缓存大小限制: ${_formatFileSize(_config.maxSizeBytes)}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: _config.maxSizeBytes.toDouble(),
                          min: 100 * 1024 * 1024, // 100MB
                          max: 10 * 1024 * 1024 * 1024, // 10GB
                          divisions: 20,
                          onChanged: (value) async {
                            final newConfig =
                                _config.copyWith(maxSizeBytes: value.round());
                            await VideoCacheService.instance
                                .updateConfig(newConfig);
                            setState(() {
                              _config = newConfig;
                            });
                          },
                        ),

                        // 缓存策略选择
                        const SizedBox(height: 16),
                        Text(
                          '缓存策略',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        RadioListTile<CacheStrategy>(
                          title: const Text('积极缓存'),
                          subtitle: const Text('尽可能缓存更多视频'),
                          value: CacheStrategy.aggressive,
                          groupValue: _config.strategy,
                          onChanged: (value) async {
                            if (value != null) {
                              final newConfig =
                                  _config.copyWith(strategy: value);
                              await VideoCacheService.instance
                                  .updateConfig(newConfig);
                              setState(() {
                                _config = newConfig;
                              });
                            }
                          },
                        ),
                        RadioListTile<CacheStrategy>(
                          title: const Text('平衡模式'),
                          subtitle: const Text('在性能和存储之间平衡'),
                          value: CacheStrategy.balanced,
                          groupValue: _config.strategy,
                          onChanged: (value) async {
                            if (value != null) {
                              final newConfig =
                                  _config.copyWith(strategy: value);
                              await VideoCacheService.instance
                                  .updateConfig(newConfig);
                              setState(() {
                                _config = newConfig;
                              });
                            }
                          },
                        ),
                        RadioListTile<CacheStrategy>(
                          title: const Text('保守缓存'),
                          subtitle: const Text('仅缓存常播放的视频'),
                          value: CacheStrategy.conservative,
                          groupValue: _config.strategy,
                          onChanged: (value) async {
                            if (value != null) {
                              final newConfig =
                                  _config.copyWith(strategy: value);
                              await VideoCacheService.instance
                                  .updateConfig(newConfig);
                              setState(() {
                                _config = newConfig;
                              });
                            }
                          },
                        ),

                        // 移动网络设置
                        SwitchListTile(
                          title: const Text('允许移动网络缓存'),
                          subtitle: const Text('在移动网络下也会缓存视频'),
                          value: _config.allowCellular,
                          onChanged: (value) async {
                            final newConfig =
                                _config.copyWith(allowCellular: value);
                            await VideoCacheService.instance
                                .updateConfig(newConfig);
                            setState(() {
                              _config = newConfig;
                            });
                          },
                        ),

                        // 自动清理设置
                        SwitchListTile(
                          title: const Text('自动清理过期缓存'),
                          subtitle: Text('自动清理超过${_config.maxAgeDays}天的缓存'),
                          value: _config.autoCleanup,
                          onChanged: (value) async {
                            final newConfig =
                                _config.copyWith(autoCleanup: value);
                            await VideoCacheService.instance
                                .updateConfig(newConfig);
                            setState(() {
                              _config = newConfig;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 操作按钮
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isClearingCache ? null : _clearAllCache,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: _isClearingCache
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          )
                        : const Text('清除所有缓存'),
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildCachedVideosTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _cachedVideos.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.video_library_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '暂无已缓存的视频',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _cachedVideos.length,
                itemBuilder: (context, index) {
                  final entry = _cachedVideos[index];
                  return _buildCacheItemCard(entry, isComplete: true);
                },
              );
  }

  Widget _buildPartialDownloadsTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _partialDownloads.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.download_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '暂无下载中的视频',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _partialDownloads.length,
                itemBuilder: (context, index) {
                  final entry = _partialDownloads[index];
                  return _buildCacheItemCard(entry, isComplete: false);
                },
              );
  }

  Widget _buildCacheItemCard(CacheEntry entry, {required bool isComplete}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isComplete ? Colors.green : Colors.orange,
          child: Icon(
            isComplete ? Icons.offline_bolt : Icons.downloading,
            color: Colors.white,
          ),
        ),
        title: Text(
          entry.title ?? 'Unknown Video',
          style: const TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatFileSize(entry.fileSize),
              style: const TextStyle(fontSize: 12),
            ),
            if (!isComplete) ...[
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: entry.downloadProgress,
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 2),
              Text(
                '${(entry.downloadProgress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '缓存时间: ${_formatDateTime(entry.createdAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'info':
                _showCacheInfo(entry);
                break;
              case 'remove':
                _removeSingleCache(entry);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'info',
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16),
                  SizedBox(width: 8),
                  Text('详情'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('移除', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showCacheInfo(entry),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(value),
        ],
      ),
    );
  }

  void _showCacheInfo(CacheEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.title ?? '缓存详情'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('URL: ${entry.url}'),
              const SizedBox(height: 8),
              Text('本地路径: ${entry.localPath}'),
              const SizedBox(height: 8),
              Text('文件大小: ${_formatFileSize(entry.fileSize)}'),
              const SizedBox(height: 8),
              Text(
                  '下载进度: ${(entry.downloadProgress * 100).toStringAsFixed(1)}%'),
              const SizedBox(height: 8),
              Text('创建时间: ${_formatDateTime(entry.createdAt)}'),
              const SizedBox(height: 8),
              Text('最后访问: ${_formatDateTime(entry.lastAccessedAt)}'),
              const SizedBox(height: 8),
              Text('访问次数: ${entry.accessCount}'),
              const SizedBox(height: 8),
              Text('状态: ${entry.isComplete ? "已完成" : "下载中"}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
          if (!entry.isComplete)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // 可以在这里添加取消下载的逻辑
              },
              child: const Text('取消下载'),
            ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
