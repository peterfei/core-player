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

import 'package:yinghe_player/services/cache_test_service.dart';

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

  // 示例视频数据
  late List<VideoCardData> _sampleVideos;

  @override
  void initState() {
    super.initState();
    _initializeSampleData();
  }

  void _initializeSampleData() {
    _sampleVideos = [
      VideoCardData(
        title: '示例视频 1 - 本地高清视频',
        subtitle: '2024年制作的技术演示视频',
        progress: 0.75,
        type: '本地',
        duration: const Duration(minutes: 15, seconds: 30),
      ),
      VideoCardData(
        title: '示例视频 2 - 网络流媒体',
        subtitle: '高质量网络视频流测试',
        progress: 0.30,
        type: '网络',
        duration: const Duration(minutes: 8, seconds: 45),
      ),
      VideoCardData(
        title: '示例视频 3 - 4K超高清',
        subtitle: '4K分辨率视频演示',
        progress: 1.0,
        type: '4K',
        duration: const Duration(minutes: 12, seconds: 20),
      ),
      VideoCardData(
        title: '示例视频 4 - HDR高动态范围',
        subtitle: 'HDR视频技术展示',
        progress: 0.0,
        type: 'HDR',
        duration: const Duration(minutes: 6, seconds: 15),
      ),
      VideoCardData(
        title: '示例视频 5 - 本地录制',
        subtitle: '设备录制的高质量视频',
        progress: 0.60,
        type: '本地',
        duration: const Duration(minutes: 10, seconds: 50),
      ),
      VideoCardData(
        title: '示例视频 6 - 网络直播录制',
        subtitle: '直播内容录制剪辑',
        progress: 0.20,
        type: '网络',
        duration: const Duration(minutes: 25, seconds: 18),
      ),
    ];
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
    });
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
          child: _buildSection('全部视频', _sampleVideos),
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
      ],
    );
  }

  List<VideoCardData> _getContinueWatchingVideos() {
    // 返回有播放进度的视频
    return _sampleVideos.where((video) => video.progress > 0 && video.progress < 1).toList();
  }

  List<VideoCardData> _getRecentVideos() {
    // 返回最近添加的视频（这里简单返回前几个）
    return _sampleVideos.take(4).toList();
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
        });
      }
    }
  }
}
