import 'dart:io';
import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../theme/design_tokens/design_tokens.dart';

/// 集数卡片组件
/// 用于在剧集详情页中展示单个集数
class EpisodeCard extends StatefulWidget {
  final Episode episode;
  final VoidCallback? onTap;

  const EpisodeCard({
    Key? key,
    required this.episode,
    this.onTap,
  }) : super(key: key);

  @override
  State<EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<EpisodeCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: AppSpacing.medium),
          padding: const EdgeInsets.all(AppSpacing.medium),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.surfaceVariant
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(
              color: _isHovered
                  ? AppColors.primary.withOpacity(0.5)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              // 缩略图或集数编号
              _buildThumbnail(),
              
              const SizedBox(width: AppSpacing.medium),
              
              // 集数信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 集数名称
                    Text(
                      widget.episode.name,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.micro),
                    
                    // 文件信息
                    Row(
                      children: [
                        if (widget.episode.duration != null) ...[
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.micro),
                          Text(
                            _formatDuration(widget.episode.duration!),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.small),
                        ],
                        Icon(
                          Icons.storage,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.micro),
                        Text(
                          _formatFileSize(widget.episode.size),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    
                    // 播放进度条
                    if (widget.episode.playbackPosition != null &&
                        widget.episode.playbackPosition! > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.small),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: widget.episode.progress,
                                backgroundColor: AppColors.surfaceVariant,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                                minHeight: 4,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.micro),
                            Text(
                              '已观看 ${(widget.episode.progress * 100).toInt()}%',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              
              // 播放图标
              Icon(
                widget.episode.isCompleted
                    ? Icons.check_circle
                    : Icons.play_circle_outline,
                color: widget.episode.isCompleted
                    ? AppColors.success
                    : AppColors.primary,
                size: 32,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return Container(
      width: 120,
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: widget.episode.stillPath != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: Image.file(
                File(widget.episode.stillPath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholder(),
              ),
            )
          : _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: widget.episode.episodeNumber != null
          ? Text(
              '第${widget.episode.episodeNumber}集',
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            )
          : Icon(
              Icons.video_library,
              size: 32,
              color: AppColors.primary.withOpacity(0.3),
            ),
    );
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '$hours小时${minutes}分钟';
    } else {
      return '$minutes分钟';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
