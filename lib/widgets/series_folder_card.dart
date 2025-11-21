import 'package:flutter/material.dart';
import '../models/series.dart';
import '../services/metadata_store_service.dart';
import '../theme/design_tokens/design_tokens.dart';
import 'smart_image.dart';

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
    _loadMetadata();
  }

  void _loadMetadata() {
    final metadata = MetadataStoreService.getSeriesMetadata(widget.series.folderPath);
    debugPrint('🃏 SeriesFolderCard: ${widget.series.name}');
    debugPrint('   路径: ${widget.series.folderPath}');
    debugPrint('   元数据: ${metadata != null ? "已加载" : "无"}');
    if (metadata != null && metadata['posterPath'] != null) {
      debugPrint('   海报路径: ${metadata['posterPath']}');
    }
    
    if (mounted) {
      setState(() {
        _metadata = metadata;
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
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 封面图区域
                Expanded(
                  flex: 4, // Reduced from 3 to 4 (relative to info) to adjust ratio, wait, 4:3 is 57:43. 3:2 is 60:40. So 4:3 gives MORE space to info.
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppRadius.medium),
                        topRight: Radius.circular(AppRadius.medium),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppRadius.medium),
                        topRight: Radius.circular(AppRadius.medium),
                      ),
                      child: SmartImage(
                        path: _metadata?['posterPath'] ?? widget.series.thumbnailPath,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        placeholder: _buildPlaceholder(),
                      ),
                    ),
                  ),
                ),

                // 信息区域
                Expanded(
                  flex: 3, // Increased from 2 to 3 to give more space for text
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.medium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 剧集名称
                        Text(
                          widget.series.name,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.small),

                        // 集数统计
                        Row(
                          children: [
                            Icon(
                              Icons.movie,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.micro),
                            Text(
                              '共 ${widget.series.episodeCount} 集',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // 添加时间
                        Text(
                          _formatDate(widget.series.addedAt),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.folder_special,
        size: 64,
        color: AppColors.primary.withOpacity(0.3),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
