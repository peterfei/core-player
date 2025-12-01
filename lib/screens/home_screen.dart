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
import 'package:yinghe_player/services/history_service.dart';
import 'package:yinghe_player/services/cache_test_service.dart';
import 'package:yinghe_player/theme/design_tokens/design_tokens.dart';
import 'package:yinghe_player/screens/animation_demo.dart';
import 'package:yinghe_player/screens/media_server_list_page.dart';
import 'package:yinghe_player/services/media_library_service.dart';
import 'package:yinghe_player/services/series_service.dart';
import 'package:yinghe_player/models/series.dart';
import 'package:yinghe_player/widgets/series_folder_card.dart';
import 'package:yinghe_player/screens/series_detail_page.dart';
import 'package:yinghe_player/widgets/video_list_tile.dart';
import 'package:yinghe_player/widgets/video_poster_card.dart';
import 'package:yinghe_player/models/playback_history.dart';
import 'package:path/path.dart' as p;
import '../services/metadata_store_service.dart';
import '../services/excluded_paths_service.dart';

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
  List<VideoCardData> _libraryVideos = [];
  List<Series> _seriesList = []; // 剧集列表
  Map<String, Series> _folderToSeriesMap = {}; // folderPath -> Series 映射，用于快速查找
  
  bool _isSeriesView = true; // 默认为剧集视图
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final histories = await HistoryService.getHistories();
      final scanned = MediaLibraryService.getAllVideos();
      
      // 加载剧集数据 (包含合并逻辑)
      final series = await SeriesService.getSeriesListFromVideos(scanned);
      
      // 构建folderPath到Series的映射，用于快速查找
      final folderMap = <String, Series>{};
      for (var s in series) {
        for (var folderPath in s.folderPaths) {
          folderMap[folderPath] = s;
        }
      }
      
      if (mounted) {
        setState(() {
          _histories = histories;
          _seriesList = series;
          _folderToSeriesMap = folderMap; // 更新映射
          _libraryVideos = scanned.map(_mapScannedToVideoCard).toList();
        });
      }
    } catch (e) {
      print('Error loading history: $e');
    }
  }

  void _handleSidebarItemSelected(int index) {
    // 处理"关于"按钮点击 (index == -1)
    if (index == -1) {
      _showAboutDialog();
      return;
    }

    setState(() {
      _selectedSidebarIndex = index;
    });
    
    // 切换到媒体库标签时刷新数据
    if (index == 0) {
      _loadData();
    }
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'CorePlayer',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2025 CorePlayer By Peterfei',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              Color(0xFF0066CC),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: const Icon(
          Icons.play_arrow,
          color: Colors.white,
          size: 32,
        ),
      ),
      children: [
        const SizedBox(height: 16),
        const Text(
          'CorePlayer 是一个现代化的视频播放器，支持多种格式和网络流媒体播放。',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 8),
        const Text(
          '基于 Flutter 和 media_kit 构建，提供极致的播放体验。',
          style: TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Future<void> _playNetworkVideo() async {
    final url = await showUrlInputDialog(context);
    if (url != null) {
      if (!mounted) return;
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
        return const MediaServerListPage();
      case 4:
        return const SettingsScreen();
      default:
        return _buildMediaLibraryPage();
    }
  }

  Widget _buildMediaLibraryPage() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // 过滤剧集列表（如果需要搜索）
    List<Series> displaySeries = _seriesList;
    if (_searchQuery.isNotEmpty) {
      displaySeries = SeriesService.searchSeries(_seriesList, _searchQuery);
    }

    return CustomScrollView(
      slivers: [
        // 顶部标题区域
        SliverAppBar(
          floating: true,
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          title: Text(
            '媒体库',
            style: AppTextStyles.headlineLarge.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.bug_report, color: colorScheme.primary),
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

        // 媒体库视图切换和搜索栏
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: Column(
              children: [
                Row(
                  children: [
                    // 视图切换按钮
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          _buildViewToggleButton(
                            icon: Icons.folder,
                            label: '剧集',
                            isSelected: _isSeriesView,
                            onTap: () => setState(() => _isSeriesView = true),
                          ),
                          _buildViewToggleButton(
                            icon: Icons.grid_view,
                            label: '全部',
                            isSelected: !_isSeriesView,
                            onTap: () => setState(() => _isSeriesView = false),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.medium),
                    
                    // 搜索框
                    Expanded(
                      child: TextField(
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: _isSeriesView ? '搜索剧集...' : '搜索视频...',
                          hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                          prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.medium),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.medium,
                            vertical: AppSpacing.small,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 剧集视图或全部视频视图
        if (_isSeriesView)
          _buildSeriesGrid(displaySeries)
        else
          SliverToBoxAdapter(
            child: _buildSection('全部视频', _getAllVideos()),
          ),
          
        // 底部留白
        const SliverToBoxAdapter(
          child: SizedBox(height: AppSpacing.xxLarge),
        ),
      ],
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.small),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: AppSpacing.small,
        ),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.small),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeriesGrid(List<Series> series) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (series.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxLarge),
            child: Text(
              '没有找到剧集',
              style: AppTextStyles.bodyLarge.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.65,
          crossAxisSpacing: AppSpacing.large,
          mainAxisSpacing: AppSpacing.large,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = series[index];
            return SeriesFolderCard(
              key: ValueKey(item.folderPath),
              series: item,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SeriesDetailPage(series: item),
                  ),
                );
              },
              onExcluded: () {
                // 直接从当前列表中过滤掉被排除的series
                setState(() {
                  _seriesList = _seriesList.where((s) {
                    // 检查该series的所有folderPaths是否都被排除
                    return !s.folderPaths.every((path) => ExcludedPathsService.isExcluded(path));
                  }).toList();
                });
              },
            );
          },
          childCount: series.length,
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<VideoCardData> videos) {
    if (videos.isEmpty) return const SizedBox.shrink();
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: AppSpacing.small),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.small,
                  vertical: AppSpacing.micro,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Text(
                  '${videos.length}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              if (videos.length > 6)
                TextButton(
                  onPressed: () {
                    // 查看全部功能 - 导航到显示所有视频的页面
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => _AllVideosPage(
                          title: title,
                          videos: videos,
                          onVideoTap: _playVideo,
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    textStyle: AppTextStyles.labelMedium,
                  ),
                  child: const Text('查看全部'),
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

      final theme = Theme.of(context);

      final colorScheme = theme.colorScheme;

      

      return Center(

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            Icon(

              Icons.favorite_outline,

              size: 80,

              color: colorScheme.outline, // Using outline instead of tertiary for better M3 compliance

            ),

            const SizedBox(height: AppSpacing.large),

            Text(

              '收藏夹为空',

              style: AppTextStyles.headlineSmall.copyWith(

                color: colorScheme.onSurfaceVariant,

              ),

            ),

            const SizedBox(height: AppSpacing.medium),

            Text(

              '点击视频卡片上的爱心图标添加收藏',

              style: AppTextStyles.bodyMedium.copyWith(

                color: colorScheme.outline,

              ),

            ),

          ],

        ),

      );

    }

    

    Widget _buildFloatingActionButtons() {

      final theme = Theme.of(context);

      final colorScheme = theme.colorScheme;

      

      return Column(

        mainAxisSize: MainAxisSize.min,

        children: [

          // 网络视频按钮

          FloatingActionButton(

            heroTag: 'network',

            onPressed: _playNetworkVideo,

            tooltip: '播放网络视频',

            backgroundColor: colorScheme.secondary,

            foregroundColor: colorScheme.onSecondary,

            child: const Icon(Icons.link),

          ),

          const SizedBox(height: AppSpacing.standard),

          // 本地视频按钮

          FloatingActionButton(

            heroTag: 'local',

            onPressed: _pickAndPlayVideo,

            tooltip: '选择本地视频',

            backgroundColor: colorScheme.primary,

            foregroundColor: colorScheme.onPrimary,

            child: const Icon(Icons.add),

          ),

          const SizedBox(height: AppSpacing.standard),

          // 动画演示按钮

          FloatingActionButton(

            heroTag: 'animation_demo',

            onPressed: _navigateToAnimationDemo,

            tooltip: '动画演示',

            backgroundColor: colorScheme.surfaceContainerHighest,

            foregroundColor: colorScheme.onSurfaceVariant,

            child: const Icon(Icons.animation),

          ),

        ],

      );

    }

  

    List<VideoCardData> _getContinueWatchingVideos() {
      // 返回有播放进度的视频，且未播放完成
      // _histories 已经按 lastPlayedAt 降序排序，所以最近播放的会在前面
      final continueWatching = _histories.where((h) => 
        h.currentPosition > 0 && 
        h.currentPosition < h.totalDuration &&
        !h.isCompleted
      ).toList();
      
      // 返回最近观看的6个未完成视频
      return continueWatching.take(6).map(_mapHistoryToVideoCard).toList();
    }

  

    List<VideoCardData> _getRecentVideos() {
      // 按创建时间降序排序，获取最近添加的视频
      final sortedByCreated = List<PlaybackHistory>.from(_histories);
      sortedByCreated.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // 返回最近添加的6个视频
      return sortedByCreated.take(6).map(_mapHistoryToVideoCard).toList();
    }

    

    List<VideoCardData> _getAllVideos() {

      // 返回媒体库中的所有视频

      // 如果媒体库为空（未扫描），则显示历史记录作为后备，或者可以合并两者

      if (_libraryVideos.isNotEmpty) {

        return _libraryVideos;

      }

      return _histories.map(_mapHistoryToVideoCard).toList();

    }

  

    VideoCardData _mapHistoryToVideoCard(PlaybackHistory history) {
      // 尝试找到该视频所属的Series，以便使用刮削后的元数据
      String? seriesPosterPath = history.effectiveThumbnailPath != null ? 'file://${history.effectiveThumbnailPath}' : null;
      String displayTitle = history.videoName;
      
      // 使用优化的查找：从缓存的映射中查找
      if (history.videoPath != null) {
        final videoFolder = p.dirname(history.videoPath!);
        final series = _folderToSeriesMap[videoFolder];
        
        if (series != null) {
          // 找到所属Series，尝试获取元数据
          final metadata = MetadataStoreService.getSeriesMetadata(series.folderPath);
          if (metadata != null) {
            seriesPosterPath = metadata['posterPath'];
            displayTitle = metadata['name'] ?? history.videoName;
          }
        }
      }

      // 计算进度
      return VideoCardData(
        title: displayTitle,
        subtitle: '上次观看: ${_formatDate(history.lastPlayedAt)}',
        progress: history.currentPosition / (history.totalDuration == 0 ? 1 : history.totalDuration),
        type: history.sourceType == 'network' ? '网络' : '本地',
        duration: Duration(seconds: history.totalDuration),
        thumbnailUrl: seriesPosterPath,
        // 关键修复：网络视频使用 streamUrl，本地视频使用 videoPath
        localPath: history.sourceType == 'network' ? null : history.videoPath,
        url: history.sourceType == 'network' ? history.streamUrl : null,
      );
    }

  VideoCardData _mapScannedToVideoCard(ScannedVideo video) {
    // 尝试找到该视频所属的Series，以便使用刮削后的元数据
    String? seriesPosterPath;
    String displayTitle = video.name; // 默认使用video.name，确保非空
    
    // 使用优化的查找：从缓存的映射中查找
    final videoFolder = p.dirname(video.path);
    final series = _folderToSeriesMap[videoFolder];
    
    if (series != null) {
      // 找到所属Series，尝试获取元数据
      final metadata = MetadataStoreService.getSeriesMetadata(series.folderPath);
      if (metadata != null) {
        seriesPosterPath = metadata['posterPath'];
        displayTitle = metadata['name'] ?? video.name;
      }
    }
    
    return VideoCardData(
      title: displayTitle,
      subtitle: '添加于: ${_formatDate(video.addedAt ?? DateTime.now())}',
      progress: 0.0,
      type: 'SMB', // Assuming SMB for now
      duration: null,
      thumbnailUrl: seriesPosterPath, // 使用Series的封面
      localPath: video.path, // This is the remote path
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}


/// 显示某个分类所有视频的页面
class _AllVideosPage extends StatefulWidget {
  final String title;
  final List<VideoCardData> videos;
  final Function(VideoCardData) onVideoTap;

  const _AllVideosPage({
    required this.title,
    required this.videos,
    required this.onVideoTap,
  });

  @override
  State<_AllVideosPage> createState() => _AllVideosPageState();
}

class _AllVideosPageState extends State<_AllVideosPage> {
  String _searchQuery = '';
  String _sortBy = 'name_asc'; // 'name_asc', 'name_desc'
  bool _groupByFolder = true; // 默认启用按文件夹分组
  bool _isListView = false; // 视图模式：false=封面(网格), true=列表
  int _currentPage = 0;
  static const int _itemsPerPage = 20;
  
  // ... getters omitted for brevity ...
  List<VideoCardData> get _filteredVideos {
    var videos = widget.videos;
    
    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      videos = videos.where((v) => 
        v.title.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    // 排序
    if (_sortBy == 'name_asc') {
      videos.sort((a, b) => a.title.compareTo(b.title));
    } else if (_sortBy == 'name_desc') {
      videos.sort((a, b) => b.title.compareTo(a.title));
    }
    
    return videos;
  }
  
  List<VideoCardData> get _pagedVideos {
    final start = _currentPage * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, _filteredVideos.length);
    return _filteredVideos.sublist(start, end);
  }
  
  int get _totalPages => (_filteredVideos.length / _itemsPerPage).ceil();
  
  Map<String, List<VideoCardData>> get _groupedVideos {
    final groups = <String, List<VideoCardData>>{};
    
    for (var video in _filteredVideos) {
      String groupName = '未分类';
      
      // 从路径中提取文件夹名
      if (video.localPath != null && video.localPath!.isNotEmpty) {
        final path = video.localPath!;
        final parts = path.split('/');
        if (parts.length > 2) {
          groupName = parts[parts.length - 2]; // 倒数第二部分是文件夹名
        }
      }
      
      if (!groups.containsKey(groupName)) {
        groups[groupName] = [];
      }
      groups[groupName]!.add(video);
    }
    
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: AppTextStyles.headlineMedium.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: Column(
        children: [
          // 搜索和筛选栏
          _buildSearchBar(),
          _buildFilterBar(),
          
          // 视频列表
          Expanded(
            child: _groupByFolder 
              ? _buildGroupedList()
              : _buildFlatList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: TextField(
        style: TextStyle(color: colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: '搜索视频...',
          hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
          prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            borderSide: BorderSide.none,
          ),
          suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, color: colorScheme.onSurfaceVariant),
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }
  
  Widget _buildFilterBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
      child: Row(
        children: [
          // 分组切换
          TextButton.icon(
            onPressed: () {
              setState(() {
                _groupByFolder = !_groupByFolder;
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.primary,
            ),
            icon: Icon(
              _groupByFolder ? Icons.folder : Icons.grid_view,
              size: 18,
            ),
            label: Text(
              _groupByFolder ? '按文件夹' : '全部',
            ),
          ),
          const SizedBox(width: AppSpacing.small),
          
          // 视图切换 (列表/封面)
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.grid_view, 
                    size: 18,
                    color: !_isListView ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                  tooltip: '封面模式',
                  onPressed: () => setState(() => _isListView = false),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
                Container(width: 1, height: 20, color: theme.dividerColor),
                IconButton(
                  icon: Icon(
                    Icons.view_list, 
                    size: 18,
                    color: _isListView ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                  tooltip: '列表模式',
                  onPressed: () => setState(() => _isListView = true),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.small),

          // 排序选择
          DropdownButton<String>(
            value: _sortBy,
            dropdownColor: colorScheme.surface,
            style: TextStyle(color: colorScheme.onSurface),
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'name_asc', child: Text('A-Z')),
              DropdownMenuItem(value: 'name_desc', child: Text('Z-A')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _sortBy = value;
                });
              }
            },
          ),
          
          const Spacer(),
          
          // 视频数量
          Text(
            '${_filteredVideos.length} 个视频',
            style: AppTextStyles.bodyMedium.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGroupedList() {
    final groups = _groupedVideos;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (groups.isEmpty) {
      return Center(
        child: Text(
          '没有找到视频',
          style: AppTextStyles.bodyLarge.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }
    
    final sortedKeys = groups.keys.toList()..sort();
    
    return ListView.builder(
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final groupName = sortedKeys[index];
        final videos = groups[groupName];
        
        if (videos == null || videos.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return _buildGroupSection(groupName, videos);
      },
    );
  }
  
  Widget _buildGroupSection(String groupName, List<VideoCardData> videos) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分组标题
        Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Row(
            children: [
              Icon(Icons.folder, color: colorScheme.primary, size: 20),
              const SizedBox(width: AppSpacing.small),
              Expanded(
                child: Text(
                  groupName,
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.small),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.small,
                  vertical: AppSpacing.micro,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Text(
                  '${videos.length}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // 视频列表/网格
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
          child: _isListView 
            ? Column(
                children: videos.map((video) => VideoListTile(
                  video: video,
                  onTap: () => widget.onVideoTap(video),
                )).toList(),
              )
            : ResponsiveGrid(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.65, // 调整为竖向封面比例
                children: videos.map((video) => VideoPosterCard(
                  video: video,
                  onTap: () => widget.onVideoTap(video),
                )).toList(),
              ),
        ),
        
        const SizedBox(height: AppSpacing.large),
      ],
    );
  }
  
  Widget _buildFlatList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      children: [
        // 视频网格/列表
        Expanded(
          child: _pagedVideos.isEmpty
            ? Center(
                child: Text(
                  '没有找到视频',
                  style: AppTextStyles.bodyLarge.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(AppSpacing.large),
                child: _isListView
                  ? ListView.builder(
                      itemCount: _pagedVideos.length,
                      itemBuilder: (context, index) {
                        return VideoListTile(
                          video: _pagedVideos[index],
                          onTap: () => widget.onVideoTap(_pagedVideos[index]),
                        );
                      },
                    )
                  : ResponsiveGrid(
                      childAspectRatio: 0.65, // 竖向封面比例
                      children: _pagedVideos.map((video) => VideoPosterCard(
                        video: video,
                        onTap: () => widget.onVideoTap(video),
                      )).toList(),
                    ),
              ),
        ),
        
        // 分页控件
        if (_totalPages > 1) _buildPagination(),
      ],
    );
  }
  
  Widget _buildPagination() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 上一页
          IconButton(
            onPressed: _currentPage > 0
                ? () => setState(() => _currentPage--)
                : null,
            icon: const Icon(Icons.chevron_left),
            color: colorScheme.primary,
            disabledColor: colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          
          const SizedBox(width: AppSpacing.medium),
          
          // 页码信息
          Text(
            '${_currentPage + 1} / $_totalPages',
            style: AppTextStyles.bodyMedium.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          
          Text(
            '  (${_pagedVideos.length} / ${_filteredVideos.length})',
            style: AppTextStyles.bodySmall.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          
          const SizedBox(width: AppSpacing.medium),
          
          // 下一页
          IconButton(
            onPressed: _currentPage < _totalPages - 1
                ? () => setState(() => _currentPage++)
                : null,
            icon: const Icon(Icons.chevron_right),
            color: colorScheme.primary,
            disabledColor: colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}
