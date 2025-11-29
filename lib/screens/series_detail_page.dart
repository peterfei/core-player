import 'dart:ui';
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
import '../core/plugin_system/plugin_loader.dart';
import '../core/plugin_system/edition_config.dart';
import '../widgets/upgrade_dialog.dart';
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


  Future<void> _loadSeriesDetails() async {
    await _loadMetadata();
    await _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 尝试获取已持久化的集数数据
      var episodes = await SeriesService.getSavedEpisodesForSeries(widget.series.id);
      
      // 2. 如果持久化数据为空，则实时计算
      if (episodes.isEmpty) {
        final allVideos = MediaLibraryService.getAllVideos();
        episodes = SeriesService.getEpisodesForSeries(widget.series, allVideos);
      }
      
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
      // 检查是否为 SMB 且为社区版
      try {
        final serverConfig = servers.firstWhere(
          (s) => s.id == effectiveSourceId,
        );

        if (serverConfig.type.toLowerCase() == 'smb' && 
            EditionConfig.isCommunityEdition) {
          print('🔒 SMB playback restricted in Community Edition');
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const UpgradeDialog(),
            );
          }
          return;
        }
      } catch (e) {
        print('⚠️ Failed to check server config: $e');
      }

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
            originalVideoPath: episode.path,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate target height for 16:9 backdrop
    final targetHeight = screenWidth * 9 / 16;
    // Clamp height: at least 420, at most 65% of screen height
    final expandedHeight = targetHeight.clamp(420.0, screenHeight * 0.65);

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true, // Allow body to extend behind app bar for transparency
      body: CustomScrollView(
        slivers: [
          // 1. 沉浸式背景墙 (SliverAppBar)
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            expandedHeight: expandedHeight, // Responsive height
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.refresh, color: Colors.white),
                ),
                onPressed: _loadSeriesDetails,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sort, color: Colors.white),
                  ),
                  offset: const Offset(0, 50),
                  onSelected: (value) {
                    setState(() {
                      _sortBy = value; // Changed from _sortOption to _sortBy to match existing code
                      _filterAndSortEpisodes();
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'number_asc', child: Text('集数 (正序)')), // Changed from 'default'
                    const PopupMenuItem(value: 'number_desc', child: Text('集数 (倒序)')), // Added
                    const PopupMenuItem(value: 'name_asc', child: Text('名称 (A-Z)')),
                    const PopupMenuItem(value: 'name_desc', child: Text('名称 (Z-A)')),
                  ],
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.none, // Disable parallax so poster scrolls with body
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. 背景图 (模糊底层)
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: SmartImage(
                      path: _metadata?['backdropPath'] ?? widget.series.backdropPath,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // 2. 黑色遮罩 (让背景变暗，突出前景)
                  Container(
                    color: Colors.black.withOpacity(0.4),
                  ),
                  // 3. 前景图 (完整显示)
                  SmartImage(
                    path: _metadata?['backdropPath'] ?? widget.series.backdropPath,
                    fit: BoxFit.contain,
                  ),
                  // 4. 渐变遮罩 (Top to Bottom)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.6), // Top darkening
                          Colors.transparent,
                          AppColors.background.withOpacity(0.8), // Fade to background
                          AppColors.background, // Solid background at bottom
                        ],
                        stops: const [0.0, 0.4, 0.8, 1.0],
                      ),
                    ),
                  ),
                  // 5. 内容区域 (Poster + Info) - Moved inside FlexibleSpaceBar for correct Z-order
                  Positioned(
                    left: AppSpacing.large,
                    right: AppSpacing.large,
                    bottom: AppSpacing.large, // Align to bottom of expanded area
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 悬浮海报
                        Material(
                          elevation: 12,
                          color: Colors.transparent,
                          shadowColor: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                          child: Container(
                            width: 160,
                            height: 240,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(AppRadius.medium),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.medium),
                              child: SmartImage(
                                key: ValueKey('poster_v3_${_metadata?['posterPath'] ?? widget.series.thumbnailPath}'),
                                path: _metadata?['posterPath'] ?? widget.series.thumbnailPath,
                                width: 160,
                                height: 240,
                                fit: BoxFit.contain,
                                alignment: Alignment.topCenter,
                                placeholder: _buildPlaceholder(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.large),
                        
                        // 标题和基本信息
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // 标题
                              Text(
                                _metadata?['name'] ?? widget.series.name,
                                style: AppTextStyles.headlineMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.8),
                                      offset: const Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppSpacing.small),
                              
                              // 评分和标签
                              Row(
                                children: [
                                  if (_metadata?['rating'] != null) ...[
                                    _buildInfoChip(
                                      icon: Icons.star,
                                      label: _metadata!['rating'].toStringAsFixed(1),
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: AppSpacing.small),
                                  ],
                                  _buildInfoChip(
                                    label: '${_episodes.length} 集',
                                    backgroundColor: AppColors.surfaceVariant,
                                  ),
                                  if (_metadata?['releaseDate'] != null) ...[
                                    const SizedBox(width: AppSpacing.small),
                                    _buildInfoChip(
                                      label: _metadata!['releaseDate'].toString().substring(0, 4),
                                      backgroundColor: AppColors.surfaceVariant,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. 内容区域 (Overview + Buttons + List)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Removed Poster Row from here
                  
                  const SizedBox(height: AppSpacing.large),

                    // 简介
                    if (_metadata?['overview'] != null || widget.series.overview != null)
                      Text(
                        _metadata?['overview'] ?? widget.series.overview!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    
                    const SizedBox(height: AppSpacing.large),

                    // 操作按钮栏
                    Row(
                      children: [
                        if (_filteredEpisodes.isNotEmpty)
                          Expanded(
                            flex: 2, // Give more space to Play button
                            child: ElevatedButton.icon(
                              onPressed: () => _playEpisode(_filteredEpisodes.first),
                              icon: const Icon(Icons.play_arrow_rounded, size: 28),
                              label: const Text('播放第一集', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.medium),
                                ),
                                elevation: 8,
                                shadowColor: AppColors.primary.withOpacity(0.5),
                              ),
                            ),
                          ),
                        const SizedBox(width: AppSpacing.medium),
                        // 搜索框
                        Expanded(
                          flex: 1,
                          child: TextField(
                            style: TextStyle(color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: '搜索...',
                              hintStyle: TextStyle(color: AppColors.textSecondary),
                              prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                              filled: true,
                              fillColor: AppColors.surface.withOpacity(0.8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.medium),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.medium),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.medium),
                                borderSide: BorderSide(color: AppColors.primary.withOpacity(0.5), width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.medium,
                                vertical: 16,
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
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // 3. 集数列表
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
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.large,
                        0, // Top padding handled by Transform
                        AppSpacing.large,
                        AppSpacing.xxLarge,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final episode = _filteredEpisodes[index];
                            final episodeMetadata = MetadataStoreService.getEpisodeMetadata(episode.id);
                            
                            Episode displayEpisode = episode;
                            
                            // 1. 尝试使用集数特有的元数据
                            if (episodeMetadata != null && episodeMetadata['stillPath'] != null) {
                              displayEpisode = episode.copyWith(
                                stillPath: episodeMetadata['stillPath'] as String,
                                overview: episodeMetadata['overview'] as String?,
                                rating: episodeMetadata['rating'] as double?,
                              );
                            } else {
                              // 2. 如果没有集数元数据，回退使用剧集(Series)的元数据
                              // 用户需求：如果单集没有刮削成功，使用成功刮削的封面做为子集的封面和标题
                              
                              String? fallbackImage = _metadata?['posterPath'] ?? widget.series.thumbnailPath;
                              String? fallbackName = _metadata?['name'] ?? widget.series.name;
                              
                              // 构建回退后的名称
                              String newName = episode.name;
                              
                              // 如果是单集文件（通常是电影识别为剧集），直接使用剧集名称
                              if (_episodes.length == 1) {
                                newName = fallbackName ?? episode.name;
                              } else {
                                // 如果是多集，尝试保留集数信息
                                // 如果能解析出集数，显示 "剧集名称 - 第X集"
                                if (episode.episodeNumber != null && fallbackName != null) {
                                  newName = '$fallbackName - 第${episode.episodeNumber}集';
                                } else {
                                  // 否则，如果文件名很乱，可能还是显示剧集名称比较好，或者保持原样
                                  // 这里我们选择：如果有剧集名称，就用剧集名称（虽然会重复，但比乱码好）
                                  // 或者我们可以尝试只用 NameParser 清理一下原文件名
                                  // 但根据用户 "使用成功刮削的...标题" 的要求，倾向于使用 fallbackName
                                  newName = fallbackName ?? episode.name;
                                }
                              }
                              
                              displayEpisode = episode.copyWith(
                                stillPath: fallbackImage, // 使用剧集封面
                                name: newName,           // 使用剧集标题
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
        ],
      ),
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Widget? child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: child ?? IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildInfoChip({
    IconData? icon,
    required String label,
    Color? color,
    Color backgroundColor = Colors.transparent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor == Colors.transparent 
            ? AppColors.surfaceVariant.withOpacity(0.5) 
            : backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: backgroundColor == Colors.transparent 
            ? Border.all(color: AppColors.surfaceVariant) 
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color ?? AppColors.textPrimary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color ?? AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
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
