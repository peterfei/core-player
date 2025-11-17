import 'dart:io';
import 'package:flutter/material.dart';
import '../models/playback_history.dart';
import '../services/history_service.dart';
import '../services/thumbnail_service.dart';
import '../services/simple_thumbnail_service.dart';
import '../screens/player_screen.dart';
import 'search_history_widget.dart';
import 'video_thumbnail.dart';

class HistoryListWidget extends StatefulWidget {
  const HistoryListWidget({super.key});

  @override
  State<HistoryListWidget> createState() => _HistoryListWidgetState();
}

class _HistoryListWidgetState extends State<HistoryListWidget> {
  List<PlaybackHistory> _allHistories = [];
  List<PlaybackHistory> _displayedHistories = [];
  bool _isLoading = true;
  bool _isSearchMode = false;
  final Set<String> _selectedHistories = <String>{};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadHistories();
  }

  void _loadHistories() async {
    final histories = await HistoryService.getHistories();
    if (mounted) {
      setState(() {
        _allHistories = histories;
        _displayedHistories = histories;
        _isLoading = false;
      });
    }
  }

  void _onSearchResultsChanged(List<PlaybackHistory> results) {
    setState(() {
      _displayedHistories = results;
      _isSearchMode = true;
    });
  }

  void _onFilterChanged(List<PlaybackHistory> results) {
    setState(() {
      _displayedHistories = results;
      _isSearchMode = true;
    });
  }

  void _clearSearch() {
    setState(() {
      _displayedHistories = _allHistories;
      _isSearchMode = false;
    });
  }

  void _toggleSelection(String historyId) {
    setState(() {
      if (_selectedHistories.contains(historyId)) {
        _selectedHistories.remove(historyId);
        if (_selectedHistories.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedHistories.add(historyId);
        if (!_isSelectionMode) {
          _isSelectionMode = true;
        }
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedHistories.length == _displayedHistories.length) {
        _selectedHistories.clear();
        _isSelectionMode = false;
      } else {
        _selectedHistories.clear();
        _selectedHistories.addAll(_displayedHistories.map((h) => h.id));
        _isSelectionMode = true;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedHistories.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _batchDelete() async {
    if (_selectedHistories.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${_selectedHistories.length} 条播放历史吗？\n此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await HistoryService.batchDeleteHistories(_selectedHistories.toList());
      _exitSelectionMode();
      _loadHistories();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除 ${_selectedHistories.length} 条记录'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  
  void _clearAllHistories() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空所有历史'),
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
              _loadHistories();
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  void _navigateToPlayer(PlaybackHistory history) {
    // 检查是否需要询问继续位置
    if (!history.isCompleted) {
      _showResumeDialog(history);
    } else {
      // 直接从开头播放已看完的视频
      _playVideo(history, seekTo: 0);
    }
  }

  void _showResumeDialog(PlaybackHistory history) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('继续播放'),
        content: Text(
          '上次观看到 ${history.formattedProgress}\n'
          '是否从上次位置继续观看？',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _playVideo(history, seekTo: 0); // 重新开始
            },
            child: const Text('重新开始'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _playVideo(history, seekTo: history.currentPosition); // 继续
            },
            child: const Text('继续观看'),
          ),
        ],
      ),
    );
  }

  void _playVideo(PlaybackHistory history, {int? seekTo}) async {
    // 判断是否是 Web 平台的视频 URL
    final isWebVideo = history.videoPath.startsWith('blob:') ||
                       history.videoPath.startsWith('data:');

    if (isWebVideo) {
      // Web 平台：使用 URL 方式播放
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            videoFile: File(''), // 传入空文件
            webVideoUrl: history.videoPath,
            webVideoName: history.videoName,
            seekTo: seekTo,
            fromHistory: true,
          ),
        ),
      ).then((_) {
        _loadHistories();
      });
    } else {
      // 桌面/移动平台：使用文件路径播放
      final videoFile = File(history.videoPath);
      if (await videoFile.exists()) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerScreen(
              videoFile: videoFile,
              seekTo: seekTo,
              fromHistory: true,
            ),
          ),
        ).then((_) {
          _loadHistories();
        });
      } else {
        // 文件不存在，提示用户
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('文件不存在'),
              content: Text(
                '视频文件 "${history.videoName}" 不存在或已被移动。\n'
                '是否要从历史记录中删除？',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('保留'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    HistoryService.deleteHistory(history.id);
                    _loadHistories();
                  },
                  child: const Text('删除'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        // 搜索和过滤界面
        Expanded(
          child: CustomScrollView(
            slivers: [
              // 标题栏
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isSearchMode ? '搜索结果 (${_displayedHistories.length})' : '播放历史',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_isSelectionMode)
                        Row(
                          children: [
                            TextButton(
                              onPressed: _toggleSelectAll,
                              child: Text(_selectedHistories.length == _displayedHistories.length ? '取消全选' : '全选'),
                            ),
                            IconButton(
                              onPressed: _batchDelete,
                              icon: const Icon(Icons.delete),
                              color: Colors.red,
                            ),
                            IconButton(
                              onPressed: _exitSelectionMode,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        )
                      else if (_allHistories.isNotEmpty)
                        TextButton.icon(
                          onPressed: _clearAllHistories,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('清空'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 搜索功能
              SliverToBoxAdapter(
                child: SearchHistoryWidget(
                  onResultsChanged: _onSearchResultsChanged,
                  onClearSearch: _clearSearch,
                ),
              ),

              // 过滤选项
              SliverToBoxAdapter(
                child: FilterOptionsWidget(
                  onFilterChanged: _onFilterChanged,
                ),
              ),

              // 历史记录列表或空状态
              if (_displayedHistories.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final history = _displayedHistories[index];
                      return EnhancedHistoryItemWidget(
                        history: history,
                        isSelected: _selectedHistories.contains(history.id),
                        isSelectionMode: _isSelectionMode,
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(history.id);
                          } else {
                            _navigateToPlayer(history);
                          }
                        },
                        onLongPress: () {
                          _toggleSelection(history.id);
                        },
                      );
                    },
                    childCount: _displayedHistories.length,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    if (_isSearchMode) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '没有找到匹配的视频',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '尝试使用不同的关键词',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无播放历史',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角的 + 按钮添加视频',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryItemWidget extends StatelessWidget {
  final PlaybackHistory history;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const HistoryItemWidget({
    super.key,
    required this.history,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 视频缩略图占位符
              Container(
                width: 80,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.play_circle_outline,
                  size: 32,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 12),

              // 视频信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      history.videoName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          history.formattedLastPlayedAt,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (history.isCompleted) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '已看完',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 进度条
                    LinearProgressIndicator(
                      value: history.progressPercentage,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        history.isCompleted ? Colors.green : Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      history.formattedProgress,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // 播放按钮
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EnhancedHistoryItemWidget extends StatelessWidget {
  final PlaybackHistory history;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const EnhancedHistoryItemWidget({
    super.key,
    required this.history,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isSelected ? Colors.blue[50] : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 选择框（选择模式下）
              if (isSelectionMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                  activeColor: Colors.blue[600],
                ),
                const SizedBox(width: 8),
              ],

              // 视频缩略图
              FutureBuilder<String?>(
                future: SimpleThumbnailService.generateThumbnail(
                  videoPath: history.videoPath,
                  width: 320, // 中等质量
                  height: 180,
                  seekSeconds: 1.0,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    // 显示实际缩略图
                    return VideoThumbnail(
                      thumbnailPath: snapshot.data,
                      width: 80,
                      height: 45,
                      borderRadius: BorderRadius.circular(8),
                      placeholder: _buildThumbnailPlaceholder(),
                    );
                  } else {
                    // 显示占位符
                    return _buildThumbnailPlaceholder();
                  }
                },
              ),
              const SizedBox(width: 12),

              // 视频信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      history.videoName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          history.formattedLastPlayedAt,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          history.formattedWatchCount,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (history.isCompleted) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '已看完',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (history.fileSize != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        history.formattedFileSize,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    // 进度条
                    LinearProgressIndicator(
                      value: history.progressPercentage,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        history.isCompleted ? Colors.green : Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      history.formattedProgress,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // 播放按钮
              if (!isSelectionMode)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailPlaceholder() {
    return Container(
      width: 80,
      height: 45,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.play_circle_outline,
        size: 32,
        color: Colors.grey[600],
      ),
    );
  }
}