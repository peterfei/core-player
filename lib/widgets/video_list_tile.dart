import 'package:flutter/material.dart';
import '../theme/design_tokens/design_tokens.dart';
import 'smart_image.dart';
import 'responsive_grid.dart'; // For VideoCardData

class VideoListTile extends StatefulWidget {
  final VideoCardData video;
  final VoidCallback? onTap;

  const VideoListTile({
    Key? key,
    required this.video,
    this.onTap,
  }) : super(key: key);

  @override
  State<VideoListTile> createState() => _VideoListTileState();
}

class _VideoListTileState extends State<VideoListTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 100,
          margin: const EdgeInsets.only(bottom: AppSpacing.medium),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceVariant.withOpacity(0.5) : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(
              color: _isHovered ? AppColors.primary.withOpacity(0.3) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // 缩略图
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppRadius.medium),
                        bottomLeft: Radius.circular(AppRadius.medium),
                      ),
                      child: SmartImage(
                        path: widget.video.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: _buildPlaceholder(),
                      ),
                    ),
                    // 进度条
                    if (widget.video.progress > 0)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: widget.video.progress,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                          minHeight: 3,
                        ),
                      ),
                    // 播放按钮 (Hover时显示)
                    if (_isHovered)
                      Center(
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 信息区域
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 标题
                      Text(
                        widget.video.title,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.small),

                      // 详情行
                      Row(
                        children: [
                          if (widget.video.type != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.video.type!,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.small),
                          ],
                          
                          if (widget.video.duration != null) ...[
                            Icon(Icons.access_time, size: 12, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Text(
                              _formatDuration(widget.video.duration!),
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.medium),
                          ],

                          if (widget.video.subtitle != null)
                            Expanded(
                              child: Text(
                                widget.video.subtitle!,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // 右侧操作区 (可选)
              if (_isHovered)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.medium),
                  child: Icon(
                    Icons.play_circle_outline,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.movie_outlined,
        size: 24,
        color: AppColors.primary.withOpacity(0.3),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
