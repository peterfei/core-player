import 'dart:io';
import 'package:flutter/material.dart';
import '../models/series.dart';
import '../models/episode.dart';
import '../services/series_service.dart';
import '../services/media_library_service.dart';
import '../services/metadata_store_service.dart';
import '../services/metadata_scraper_service.dart';
import '../theme/design_tokens/design_tokens.dart';
import '../widgets/episode_card.dart';
import '../widgets/smart_image.dart';
import '../services/local_proxy_server.dart';
import '../services/media_server_service.dart';
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
  Map<String, dynamic>? _metadata;
  bool _isScraping = false;


  @override
  void initState() {
    super.initState();
    _loadEpisodes();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    debugPrint('');
    debugPrint('📄 ═══════════════════════════════════════════════════════');
    debugPrint('📄 剧集详情页: 加载元数据');
    debugPrint('📄 剧集: ${widget.series.name}');
    debugPrint('📄 路径: ${widget.series.folderPath}');
    debugPrint('📄 ═══════════════════════════════════════════════════════');
    
    final metadata = MetadataStoreService.getSeriesMetadata(widget.series.folderPath);
    
    if (metadata != null) {
      debugPrint('✅ 元数据已加载:');
      debugPrint('   TMDB ID: ${metadata['tmdbId']}');
      debugPrint('   名称: ${metadata['name']}');
      debugPrint('   评分: ${metadata['rating']}');
      debugPrint('   海报: ${metadata['posterPath'] != null ? "有" : "无"}');
      debugPrint('   背景图: ${metadata['backdropPath'] != null ? "有" : "无"}');
    } else {
      debugPrint('⚠️  未找到元数据');
    }
    debugPrint('📄 ═══════════════════════════════════════════════════════');
    debugPrint('');
    
    if (mounted) {
      setState(() {
        _metadata = metadata;
      });
    }
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

  void _playEpisode(Episode episode) async {
    print('🔍 Debugging Episode:');
    print('   Name: ${episode.name}');
    print('   Path: ${episode.path}');
    print('   SourceId: ${episode.sourceId}');
    print('   Id: ${episode.id}');

    String? effectiveSourceId = episode.sourceId;
    final servers = MediaServerService.getServers();
    
    print('   Available Servers: ${servers.length}');
    for (var s in servers) {
      print('   - ${s.name} (${s.type}): ${s.sharedFolders}');
    }

    // 如果 sourceId 为空，尝试通过路径匹配找到对应的服务器
    if (effectiveSourceId == null) {
      print('⚠️ SourceId is null, attempting to find matching server...');
      
      for (var server in servers) {
        // 检查该服务器的共享文件夹是否包含此文件
        if (server.sharedFolders != null) {
          for (var folder in server.sharedFolders!) {
            if (episode.path.startsWith(folder) || folder == '/') {
              print('✅ Found matching server: ${server.name} (${server.id})');
              effectiveSourceId = server.id;
              break;
            }
          }
        }
        if (effectiveSourceId != null) break;
      }
      
      // 如果还是没找到，尝试使用第一个 SMB 服务器
      if (effectiveSourceId == null) {
        final smbServers = servers.where((s) => s.type.toLowerCase() == 'smb').toList();
        if (smbServers.isNotEmpty) {
          print('⚠️ Fallback: Using first available SMB server: ${smbServers.first.name}');
          effectiveSourceId = smbServers.first.id;
        }
      }
    }

    if (effectiveSourceId != null) {
      // 确保代理服务器已启动
      if (!LocalProxyServer.instance.isRunning) {
        print('⚠️ Proxy server is not running, attempting to start...');
        await LocalProxyServer.instance.start();
        if (!LocalProxyServer.instance.isRunning) {
          print('❌ Failed to start proxy server');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('播放服务启动失败，请重启应用重试'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // 网络视频（SMB等）
      // 使用代理服务器生成播放URL
      final proxyUrl = LocalProxyServer.instance.getProxyUrl(
        episode.path,
        sourceId: effectiveSourceId,
      );
      
      print('▶️ 播放网络视频: ${episode.name}');
      print('   原始路径: ${episode.path}');
      print('   代理URL: $proxyUrl');
      print('   SourceID: $effectiveSourceId');
      
      // 再次检查生成的 URL 是否是代理 URL
      if (!proxyUrl.startsWith('http')) {
        print('❌ Generated URL is not a proxy URL: $proxyUrl');
         if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('播放失败'),
                content: Text('无法生成播放地址。\n\n原始路径: ${episode.path}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('确定'),
                  ),
                ],
              ),
            );
          }
          return;
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen.network(
            videoPath: proxyUrl,
            webVideoName: episode.name,
            episode: episode,
          ),
        ),
      );
    } else {
      // 如果找不到服务器，且路径看起来像网络路径（以/开头），显示错误提示
      if (episode.path.startsWith('/')) {
        print('❌ 无法确定视频源服务器');
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('无法播放'),
              content: Text('无法找到该视频对应的服务器配置。\n\n视频路径: ${episode.path}\n\n请尝试重新扫描媒体库。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 本地视频
      print('▶️ 播放本地视频: ${episode.name}');
      print('   路径: ${episode.path}');
      
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen.local(
            videoFile: File(episode.path),
            webVideoName: episode.name,
            episode: episode,
          ),
        ),
      );
    }
  }

  Future<void> _scrapeSeries() async {
    setState(() => _isScraping = true);

    // 显示进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text('正在刮削 ${widget.series.name}...'),
          ],
        ),
      ),
    );

    final result = await MetadataScraperService.scrapeSeries(
      widget.series,
      forceUpdate: true,
    );

    if (!mounted) return;

    // 关闭进度对话框
    Navigator.of(context).pop();

    // 显示结果
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? '✅ 刮削成功'
              : '❌ 刮削失败: ${result.errorMessage ?? "未知错误"}',
        ),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );

    // 重新加载元数据
    if (result.success) {
      await _loadMetadata();
    }

    setState(() => _isScraping = false);
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
            expandedHeight: (_metadata?['backdropPath'] ?? widget.series.backdropPath) != null ? 320.0 : null,
            flexibleSpace: (_metadata?['backdropPath'] ?? widget.series.backdropPath) != null
                ? FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        SmartImage(
                          path: _metadata?['backdropPath'] ?? widget.series.backdropPath,
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
              // 刮削按钮
              if (!_isScraping)
                IconButton(
                  icon: Icon(
                    _metadata != null ? Icons.refresh : Icons.download,
                    color: AppColors.textPrimary,
                  ),
                  tooltip: _metadata != null ? '重新刮削' : '刮削元数据',
                  onPressed: _scrapeSeries,
                ),
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
                        path: _metadata?['posterPath'] ?? widget.series.thumbnailPath,
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
                        // 标题（使用刮削的名称或原名称）
                        if (_metadata?['name'] != null && _metadata!['name'] != widget.series.name)
                          Text(
                            _metadata!['name'],
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        // 评分和集数
                        Row(
                          children: [
                            if (_metadata?['rating'] != null) ...[
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _metadata!['rating'].toStringAsFixed(1),
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Text(
                              '共 ${_episodes.length} 集',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.medium),
                        if (_metadata?['overview'] != null || widget.series.overview != null) ...[
                          Text(
                            _metadata?['overview'] ?? widget.series.overview!,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.medium),
                        ],
                        // 发布日期
                        if (_metadata?['releaseDate'] != null) ...[
                          Text(
                            '首播: ${_metadata!['releaseDate']}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.small),
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
                            // 从MetadataStoreService加载集数元数据
                            final episodeMetadata = MetadataStoreService.getEpisodeMetadata(episode.id);
                            
                            // 如果有元数据，使用刮削的stillPath更新Episode
                            Episode displayEpisode = episode;
                            if (episodeMetadata != null && episodeMetadata['stillPath'] != null) {
                              displayEpisode = episode.copyWith(
                                stillPath: episodeMetadata['stillPath'] as String,
                                overview: episodeMetadata['overview'] as String?,
                                rating: episodeMetadata['rating'] as double?,
                              );
                            }
                            
                            return EpisodeCard(
                              episode: displayEpisode,
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
