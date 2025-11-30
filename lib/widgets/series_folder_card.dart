import 'package:flutter/material.dart';
import '../models/series.dart';
import '../services/metadata_store_service.dart';
import '../services/excluded_paths_service.dart';
import '../theme/design_tokens/design_tokens.dart';
import 'smart_image.dart';
import '../services/cover_fallback_service.dart';
import '../core/scraping/name_parser.dart';

/// 剧集文件夹卡片组件
/// 用于在列表或网格中展示剧集
class SeriesFolderCard extends StatefulWidget {
  final Series series;
  final VoidCallback? onTap;
  final VoidCallback? onExcluded; // 排除后的回调

  const SeriesFolderCard({
    Key? key,
    required this.series,
    this.onTap,
    this.onExcluded,
  }) : super(key: key);

  @override
  State<SeriesFolderCard> createState() => _SeriesFolderCardState();
}

class _SeriesFolderCardState extends State<SeriesFolderCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  Map<String, dynamic>? _metadata;
  String? _coverPath;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    _loadCover();
  }

  Future<void> _loadCover() async {
    final metadata = MetadataStoreService.getSeriesMetadata(widget.series.folderPath);
    
    // 构造包含元数据的对象，确保优先使用已有的元数据封面
    final source = {
      'posterPath': metadata?['posterPath'] ?? widget.series.thumbnailPath,
      'name': widget.series.name,
      'path': widget.series.folderPath,
      'id': widget.series.id,
    };

    // 优先使用 CoverFallbackService 获取最佳封面
    final coverPath = await CoverFallbackService.getCoverPath(source);
    
    if (mounted) {
      setState(() {
        _metadata = metadata;
        _coverPath = coverPath;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleHoverChange(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
      if (_isHovered) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  /// 显示排除确认对话框
  void _showExcludeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('排除此剧集'),
        content: Text(
          '确定要隐藏 "${_cleanTitle(widget.series.name)}" 吗？\n\n排除后可在设置中恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _excludeSeries();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 排除剧集
  Future<void> _excludeSeries() async {
    try {
      // 添加所有folderPaths到排除列表（处理合并的Series）
      for (final folderPath in widget.series.folderPaths) {
        await ExcludedPathsService.addPath(folderPath);
      }
      
      // 立即调用回调，让父组件刷新列表
      widget.onExcluded?.call();
      
      if (mounted) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        
        ScaffoldMessenger.of(context).hideCurrentSnackBar(); // 清除当前显示的SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Expanded(
                  child: Text(
                    '已排除 "${_cleanTitle(widget.series.name)}"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorScheme.onInverseSurface),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    for (final folderPath in widget.series.folderPaths) {
                      await ExcludedPathsService.removePath(folderPath);
                    }
                    // 撤销后也需要刷新
                    widget.onExcluded?.call();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.inversePrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(48, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('撤销'),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: colorScheme.onInverseSurface,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  tooltip: '关闭',
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
              ],
            ),
            duration: const Duration(milliseconds: 2500), // 设置显示时长
            behavior: SnackBarBehavior.floating, // 悬浮样式
            width: 400, // 限制宽度，避免在宽屏上太长
          ),
        );
      }
    } catch (e) {
      print('排除剧集失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return MouseRegion(
      onEnter: (_) => _handleHoverChange(true),
      onExit: (_) => _handleHoverChange(false),
      cursor: SystemMouseCursors.click,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: _showExcludeDialog,
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. 全屏封面图
                  SmartImage(
                    path: _coverPath,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    placeholder: _buildPlaceholder(),
                  ),

                  // 2. 渐变遮罩 (底部)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 120, // 遮罩高度
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                          stops: const [0.0, 0.9],
                        ),
                      ),
                    ),
                  ),

                  // 3. 悬停遮罩 (全屏变暗)
                  if (_isHovered)
                    Container(
                      color: Colors.black.withOpacity(0.1),
                    ),

                  // 4. 文字信息 (浮动在底部)
                  Positioned(
                    left: AppSpacing.medium,
                    right: AppSpacing.medium,
                    bottom: AppSpacing.medium,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 剧集名称
                        Text(
                          _metadata != null && _metadata!['name'] != null
                              ? _metadata!['name']
                              : _cleanTitle(widget.series.name),
                          style: AppTextStyles.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.8),
                                offset: const Offset(0, 1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // 集数统计和年份
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${widget.series.episodeCount} 集',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDateYear(widget.series.addedAt),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white.withOpacity(0.8),
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.8),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.folder_special,
          size: 64,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
      ),
    );
  }

  String _cleanTitle(String title) {
    // 使用 NameParser 进行更智能的标题清理
    // 这确保即使刮削失败，显示的标题也是经过反混淆处理的 (e.g. "n来b往" -> "来往")
    return NameParser.parse(title).query;
  }

  String _formatDateYear(DateTime date) {
    return '${date.year}';
  }
}
