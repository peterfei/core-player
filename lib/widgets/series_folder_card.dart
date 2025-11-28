import 'package:flutter/material.dart';
import '../models/series.dart';
import '../services/metadata_store_service.dart';
import '../theme/design_tokens/design_tokens.dart';
import 'smart_image.dart';
import '../services/cover_fallback_service.dart';

/// 剧集文件夹卡片组件
/// 用于在列表或网格中展示剧集
class SeriesFolderCard extends StatefulWidget {
  final Series series;
  final VoidCallback? onTap;

  const SeriesFolderCard({
    Key? key,
    required this.series,
    this.onTap,
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
    });
    if (isHovered) {
      _animationController.forward();
    } else {
      _animationController.reverse();
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
                          _cleanTitle(widget.series.name),
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
    // 1. 替换点号为为空格
    var cleaned = title.replaceAll('.', ' ');
    
    // 2. 移除常见的发布信息标签 (不区分大小写)
    final regex = RegExp(
      r'(S\d+.*|1080p.*|2160p.*|4k.*|WEBRip.*|BluRay.*|HDTV.*)', 
      caseSensitive: false,
    );
    
    if (regex.hasMatch(cleaned)) {
      cleaned = cleaned.split(regex).first;
    }

    return cleaned.trim();
  }

  String _formatDateYear(DateTime date) {
    return '${date.year}';
  }
}
