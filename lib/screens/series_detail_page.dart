import 'dart:io';
import 'package:flutter/material.dart';
import '../models/series.dart';
import '../models/episode.dart';
import '../services/series_service.dart';
import '../services/media_library_service.dart';
import '../theme/design_tokens/design_tokens.dart';
import '../widgets/episode_card.dart';
import '../widgets/smart_image.dart';
import 'player_screen.dart';

class SeriesDetailPage extends StatefulWidget {
  final Series series;

  const SeriesDetailPage({
    Key? key,
    required this.series,
  }) : super(key: key);

  @override
  State<SeriesDetailPage> createState() => _SeriesDetailPageState();
}

class _SeriesDetailPageState extends State<SeriesDetailPage> {
  List<Episode> _episodes = [];
  List<Episode> _filteredEpisodes = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'number_asc'; // 'number_asc', 'number_desc', 'name_asc', 'name_desc'

  @override
  void initState() {
    super.initState();
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取所有扫描的视频
      final allVideos = MediaLibraryService.getAllVideos();
      
      // 获取该剧集的集数
      final episodes = SeriesService.getEpisodesForSeries(widget.series, allVideos);
      
      if (mounted) {
        setState(() {
          _episodes = episodes;
          _filterAndSortEpisodes();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading episodes: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterAndSortEpisodes() {
    var result = List<Episode>.from(_episodes);
    
    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((e) => e.name.toLowerCase().contains(query)).toList();
    }
    
    // 排序
    switch (_sortBy) {
      case 'number_asc':
        result.sort((a, b) {
          if (a.episodeNumber != null && b.episodeNumber != null) {
            return a.episodeNumber!.compareTo(b.episodeNumber!);
          }
          return a.name.compareTo(b.name);
        });
        break;
      case 'number_desc':
        result.sort((a, b) {
          if (a.episodeNumber != null && b.episodeNumber != null) {
            return b.episodeNumber!.compareTo(a.episodeNumber!);
          }
          return b.name.compareTo(a.name);
        });
        break;
      case 'name_asc':
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'name_desc':
        result.sort((a, b) => b.name.compareTo(a.name));
        break;
    }
    
    setState(() {
      _filteredEpisodes = result;
    });
  }

  void _playEpisode(Episode episode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen.local(
          videoFile: File(episode.path),
          webVideoName: episode.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // 顶部应用栏
          SliverAppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            pinned: true,
            expandedHeight: widget.series.backdropPath != null ? 200.0 : null,
            flexibleSpace: widget.series.backdropPath != null
                ? FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        SmartImage(
                          path: widget.series.backdropPath,
                          fit: BoxFit.cover,
                        ),
                        // 渐变遮罩，确保标题可见
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.3),
                                Colors.transparent,
                                AppColors.background,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              widget.series.name,
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            actions: [
              // 排序按钮
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort, color: AppColors.textPrimary),
                color: AppColors.surface,
                onSelected: (value) {
                  setState(() {
                    _sortBy = value;
                    _filterAndSortEpisodes();
                  });
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'number_asc',
                    child: Text('集数 (正序)'),
                  ),
                  const PopupMenuItem(
                    value: 'number_desc',
                    child: Text('集数 (倒序)'),
                  ),
                  const PopupMenuItem(
                    value: 'name_asc',
                    child: Text('名称 (A-Z)'),
                  ),
                  const PopupMenuItem(
                    value: 'name_desc',
                    child: Text('名称 (Z-A)'),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.small),
            ],
          ),

          // 剧集信息头部
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 封面图
                  Container(
                    width: 120,
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      child: SmartImage(
                        path: widget.series.thumbnailPath,
                        fit: BoxFit.cover,
                        placeholder: _buildPlaceholder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.large),
                  
                  // 详细信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '共 ${_episodes.length} 集',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.medium),
                        if (widget.series.overview != null) ...[
                          Text(
                            widget.series.overview!,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.medium),
                        ],
                        Text(
                          '路径: ${widget.series.folderPath}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.large),
                        // 播放按钮
                        if (_filteredEpisodes.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: () => _playEpisode(_filteredEpisodes.first),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('播放第一集'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.large,
                                vertical: AppSpacing.medium,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 搜索栏
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
              child: TextField(
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: '搜索集数...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surface,
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
                    _filterAndSortEpisodes();
                  });
                },
              ),
            ),
          ),

          // 间距
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.medium),
          ),

          // 集数列表
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _filteredEpisodes.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Text(
                          '没有找到集数',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final episode = _filteredEpisodes[index];
                            return EpisodeCard(
                              episode: episode,
                              onTap: () => _playEpisode(episode),
                            );
                          },
                          childCount: _filteredEpisodes.length,
                        ),
                      ),
                    ),
                    
          // 底部留白
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.xxLarge),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.tv,
        size: 48,
        color: AppColors.primary.withOpacity(0.3),
      ),
    );
  }
}
