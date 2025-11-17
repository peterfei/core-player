import 'dart:io';
import 'package:flutter/material.dart';
import '../models/playback_history.dart';
import '../services/history_service.dart';
import '../screens/player_screen.dart';

class HistoryListWidget extends StatefulWidget {
  const HistoryListWidget({super.key});

  @override
  State<HistoryListWidget> createState() => _HistoryListWidgetState();
}

class _HistoryListWidgetState extends State<HistoryListWidget> {
  List<PlaybackHistory> _histories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistories();
  }

  void _loadHistories() async {
    final histories = await HistoryService.getHistories();
    if (mounted) {
      setState(() {
        _histories = histories;
        _isLoading = false;
      });
    }
  }

  void _deleteHistory(PlaybackHistory history) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除历史记录'),
        content: Text('确定要删除"${history.videoName}"的播放历史吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await HistoryService.deleteHistory(history.id);
              _loadHistories();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
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

    if (_histories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
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

    return Column(
      children: [
        // 标题栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '最近播放',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_histories.isNotEmpty)
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

        // 历史记录列表
        Expanded(
          child: ListView.builder(
            itemCount: _histories.length,
            itemBuilder: (context, index) {
              final history = _histories[index];
              return HistoryItemWidget(
                history: history,
                onTap: () => _navigateToPlayer(history),
                onLongPress: () => _deleteHistory(history),
              );
            },
          ),
        ),
      ],
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