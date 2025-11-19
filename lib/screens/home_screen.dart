import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:yinghe_player/screens/player_screen.dart';
import 'package:yinghe_player/screens/settings_screen.dart';
import 'package:yinghe_player/widgets/history_list.dart';
import 'package:yinghe_player/widgets/url_input_dialog.dart';
import 'package:yinghe_player/widgets/modern_sidebar.dart';
import 'package:yinghe_player/widgets/responsive_grid.dart';
import 'package:yinghe_player/widgets/modern_video_card.dart';
import 'package:yinghe_player/services/history_service.dart';
import 'package:yinghe_player/services/cache_test_service.dart';
import 'package:yinghe_player/theme/design_tokens/design_tokens.dart';
import 'package:yinghe_player/screens/animation_demo.dart';

import 'package:yinghe_player/services/cache_test_service.dart';
import 'package:yinghe_player/models/playback_history.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedSidebarIndex = 0;
  bool _isSidebarCollapsed = false;
  final GlobalKey<HistoryListWidgetRefreshableState> _historyListKey =
      GlobalKey<HistoryListWidgetRefreshableState>();

  List<PlaybackHistory> _histories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final histories = await HistoryService.getHistories();
      if (mounted) {
        setState(() {
          _histories = histories;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading history: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleSidebarItemSelected(int index) {
    setState(() {
      _selectedSidebarIndex = index;
    });
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  Future<void> _playNetworkVideo() async {
    final url = await showUrlInputDialog(context);
    if (url != null) {
      // 导航到播放器播放网络视频
      Navigator.of(context)
          .push(
        MaterialPageRoute(
          builder: (context) => PlayerScreen.network(videoPath: url),
        ),
      )
          .then((_) {
        // 播放完成后刷新历史列表
        _historyListKey.currentState?.refreshHistories();
        _loadData(); // 刷新主页数据
      });
    }
  }

  Future<void> _pickAndPlayVideo() async {
    // Pick a file
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true, // 重要：确保获取文件数据
    );

    if (result != null) {
      if (!kIsWeb && result.files.single.path != null) {
        // 非 Web 平台：使用文件路径
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerScreen(
                videoFile: File(result.files.single.path!),
              ),
            ),
          ).then((_) {
            // 播放完成后刷新历史列表
            _historyListKey.currentState?.refreshHistories();
            _loadData(); // 刷新主页数据
          });
        }
      } else if (kIsWeb && result.files.single.bytes != null) {
        // Web 平台：使用文件字节数据
        if (mounted) {
          // 对于 Web 平台，我们需要创建一个临时 URL
          final blob = Uri.dataFromBytes(
            result.files.single.bytes!,
            mimeType: result.files.single.extension != null
                ? 'video/${result.files.single.extension}'
                : 'video/mp4',
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerScreen(
                videoFile: File(''), // 传入空文件，我们将在播放器中处理 Web 情况
                webVideoUrl: blob.toString(),
                webVideoName: result.files.single.name,
              ),
            ),
          ).then((_) {
            // 播放完成后刷新历史列表
            _historyListKey.currentState?.refreshHistories();
            _loadData(); // 刷新主页数据
          });
        }
      }
    }
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    ).then((_) {
      // 返回时刷新历史列表
      _historyListKey.currentState?.refreshHistories();
      _loadData(); // 刷新主页数据
    });
  }

  void _navigateToAnimationDemo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AnimationDemo(),
      ),
    );
  }

  void _runCacheTests() async {
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('缓存测试'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在运行缓存功能测试...'),
          ],
        ),
      ),
    );

    try {
      await CacheTestService.runBasicTests();

      if (mounted) {
        Navigator.of(context).pop(); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('缓存功能测试完成！请查看控制台输出。'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('测试失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // 左侧侧边栏
          ModernSidebar(
            selectedIndex: _selectedSidebarIndex,
            onItemSelected: _handleSidebarItemSelected,
            isCollapsed: _isSidebarCollapsed,
          ),

          // 右侧内容区域
          Expanded(
            child: _buildCurrentPage(),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  Widget _buildCurrentPage() {
    switch (_selectedSidebarIndex) {
      case 0:
        return _buildMediaLibraryPage();
      case 1:
        return const HistoryListWidgetRefreshable();
      case 2:
        return _buildFavoritesPage();
      case 3:
        return const SettingsScreen();
      default:
        return _buildMediaLibraryPage();
    }
  }

  Widget _buildMediaLibraryPage() {
    return CustomScrollView(
      slivers: [
        // 顶部标题区域
        SliverAppBar(
          floating: true,
          backgroundColor: AppColors.background,
          elevation: 0,
          title: Text(
            '媒体库',
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.bug_report, color: AppColors.primary),
              onPressed: _runCacheTests,
              tooltip: '测试缓存功能',
            ),
          ],
        ),

        // 继续观看部分
        SliverToBoxAdapter(
          child: _buildSection('继续观看', _getContinueWatchingVideos()),
        ),

        // 最近添加部分
        SliverToBoxAdapter(
          child: _buildSection('最近添加', _getRecentVideos()),
        ),

        // 全部视频部分
        SliverToBoxAdapter(
          child: _buildSection('全部视频', _getAllVideos()),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<VideoCardData> videos) {
    if (videos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分组标题
        Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Row(
            children: [
              Text(
                title,
                style: AppTextStyles.headlineLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.small),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.small,
                  vertical: AppSpacing.micro,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Text(
                  '${videos.length}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              if (videos.length > 6)
                TextButton(
                  onPressed: () {
                    // 查看全部功能
                  },
                  child: Text(
                    '查看全部',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 视频网格
        Container(
          margin: const EdgeInsets.only(
            left: AppSpacing.large,
            right: AppSpacing.large,
            bottom: AppSpacing.large,
          ),
          child: AdaptiveVideoGrid(
            videos: videos.length > 6 ? videos.take(6).toList() : videos,
            onTap: (video) => _playVideo(video),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ),
        ),
      ],
    );
  }

  Widget _buildFavoritesPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_outline,
            size: 80,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.large),
          Text(
            '收藏夹为空',
            style: AppTextStyles.headlineSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(
            '点击视频卡片上的爱心图标添加收藏',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 网络视频按钮
        FloatingActionButton(
          heroTag: 'network',
          onPressed: _playNetworkVideo,
          tooltip: '播放网络视频',
          backgroundColor: AppColors.secondary,
          child: const Icon(Icons.link),
        ),
        const SizedBox(height: AppSpacing.standard),
        // 本地视频按钮
        FloatingActionButton(
          heroTag: 'local',
          onPressed: _pickAndPlayVideo,
          tooltip: '选择本地视频',
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add),
        ),
        const SizedBox(height: AppSpacing.standard),
        // 动画演示按钮
        FloatingActionButton(
          heroTag: 'animation_demo',
          onPressed: _navigateToAnimationDemo,
          tooltip: '动画演示',
          backgroundColor: AppColors.surfaceVariant,
          child: const Icon(Icons.animation),
        ),
      ],
    );
  }

  List<VideoCardData> _getContinueWatchingVideos() {
    // 返回有播放进度的视频，且未播放完成
    final continueWatching = _histories.where((h) => 
      h.currentPosition > 0 && 
      h.currentPosition < h.totalDuration &&
      !h.isCompleted
    ).toList();
    
    return continueWatching.map(_mapHistoryToVideoCard).toList();
  }

  List<VideoCardData> _getRecentVideos() {
    // 返回最近添加的视频（这里简单返回前几个）
    // 假设 _histories 已经是按时间排序的
    return _histories.take(4).map(_mapHistoryToVideoCard).toList();
  }
  
  List<VideoCardData> _getAllVideos() {
    return _histories.map(_mapHistoryToVideoCard).toList();
  }

  VideoCardData _mapHistoryToVideoCard(PlaybackHistory history) {
    // 计算进度
    double progress = 0.0;
    if (history.totalDuration > 0) {
      progress = history.currentPosition / history.totalDuration;
    }
    
    // 确定类型
    String type = history.isNetworkVideo ? '网络' : '本地';
    
    return VideoCardData(
      title: history.videoName,
      subtitle: history.isNetworkVideo ? '网络视频' : '本地视频',
      progress: progress,
      type: type,
      duration: Duration(milliseconds: history.totalDuration),
      thumbnailUrl: history.thumbnailPath ?? history.thumbnailCachePath,
      url: history.isNetworkVideo ? history.videoPath : null,
      localPath: !history.isNetworkVideo ? history.videoPath : null,
    );
  }

  void _playVideo(VideoCardData video) {
    if (video.localPath != null) {
      // 播放本地视频
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerScreen(
              videoFile: File(video.localPath!),
            ),
          ),
        ).then((_) {
          _historyListKey.currentState?.refreshHistories();
          _loadData(); // 刷新主页数据
        });
      }
    } else if (video.url != null) {
      // 播放网络视频
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerScreen.network(videoPath: video.url!),
          ),
        ).then((_) {
          _historyListKey.currentState?.refreshHistories();
          _loadData(); // 刷新主页数据
        });
      }
    }
  }
}
