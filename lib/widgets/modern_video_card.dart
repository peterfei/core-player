import 'package:flutter/material.dart';
import '../theme/design_tokens/design_tokens.dart';
import '../animations/animations.dart';

/// 现代化视频卡片组件
/// 基于openspec/changes/modernize-ui-design规格
class ModernVideoCard extends StatefulWidget {
  final String? thumbnailUrl;
  final String title;
  final String? subtitle;
  final double progress; // 0.0 - 1.0
  final VoidCallback? onTap;
  final String? videoType; // '本地', '网络', '4K', 'HDR'
  final Duration? duration;
  final bool showPlayButton;
  final double? width;
  final double? height;
  final Widget? placeholder;

  const ModernVideoCard({
    Key? key,
    this.thumbnailUrl,
    required this.title,
    this.subtitle,
    this.progress = 0.0,
    this.onTap,
    this.videoType,
    this.duration,
    this.showPlayButton = true,
    this.width,
    this.height,
    this.placeholder,
  }) : super(key: key);

  @override
  State<ModernVideoCard> createState() => _ModernVideoCardState();
}

class _ModernVideoCardState extends State<ModernVideoCard> {
  // 动画现在由新的动画系统处理，不再需要手动管理

  @override
  Widget build(BuildContext context) {
    return HoverAnimatedWidget(
      config: const HoverAnimationConfig(
        type: HoverAnimationType.combined,
        scaleEnd: MicroInteractions.cardHoverScale,
        elevationEnd: MicroInteractions.cardHoverElevation,
        brightnessEnd: 1.05,
      ),
      child: TapAnimatedWidget(
        config: const TapAnimationConfig(
          type: TapAnimationType.scale,
          scaleEnd: MicroInteractions.cardPressScale,
        ),
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.large),
            boxShadow: AppShadows.cardDefault,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.large),
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: Stack(
                children: [
                  // 背景容器
                  _buildBackground(),

                  // 渐变叠加层
                  _buildGradientOverlay(),

                  // 进度条
                  if (widget.progress > 0) _buildProgressBar(),

                  // 顶部徽章
                  if (widget.videoType != null) _buildTopBadges(),

                  // 播放时长
                  if (widget.duration != null) _buildDuration(),

                  // 底部标题区域
                  _buildTitleArea(),

                  // 悬停时显示的播放按钮
                  if (widget.showPlayButton) _buildPlayButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    if (widget.thumbnailUrl != null) {
      return Image.network(
        widget.thumbnailUrl!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder();
        },
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.surfaceVariant,
      child: Icon(
        Icons.movie_outlined,
        size: 48,
        color: AppColors.textTertiary,
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.5, 1.0],
            colors: [
              Colors.transparent,
              Color(0xB3000000), // 70%黑色
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: LinearProgressIndicator(
        value: widget.progress,
        backgroundColor: Colors.white.withOpacity(0.2),
        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
        minHeight: 3,
      ),
    );
  }

  Widget _buildTopBadges() {
    return Positioned(
      top: AppSpacing.small,
      left: AppSpacing.small,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBadge(widget.videoType!, _getBadgeColor(widget.videoType!)),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: AppSpacing.micro,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Text(
        text,
        style: AppTextStyles.badgeText,
      ),
    );
  }

  Color _getBadgeColor(String videoType) {
    switch (videoType.toLowerCase()) {
      case '本地':
      case 'local':
        return AppColors.localVideo;
      case '网络':
      case 'network':
        return AppColors.networkVideo;
      case '4k':
        return AppColors.resolution4K;
      case 'hdr':
        return AppColors.hdr;
      default:
        return AppColors.primary;
    }
  }

  Widget _buildDuration() {
    final minutes = widget.duration!.inMinutes;
    final seconds = widget.duration!.inSeconds % 60;
    final durationText = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Positioned(
      bottom: AppSpacing.small + 3, // 避免与进度条重叠
      right: AppSpacing.small,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.small,
          vertical: AppSpacing.micro,
        ),
        decoration: BoxDecoration(
          color: AppColors.badgeBackground,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Text(
          durationText,
          style: AppTextStyles.badgeText,
        ),
      ),
    );
  }

  Widget _buildTitleArea() {
    return Positioned(
      bottom: AppSpacing.small + 3, // 避免与进度条重叠
      left: AppSpacing.small,
      right: widget.duration != null ? 80 : AppSpacing.small,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            style: AppTextStyles.videoCardTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: AppSpacing.micro),
            Text(
              widget.subtitle!,
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white.withOpacity(0.8),
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.5),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.center,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.3),
            ],
          ),
        ),
        child: Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.badgeBackground,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow,
              size: 32,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// 视频卡片包装器 - 用于响应式布局
class ModernVideoCardWrapper extends StatelessWidget {
  final String? thumbnailUrl;
  final String title;
  final String? subtitle;
  final double progress;
  final VoidCallback? onTap;
  final String? videoType;
  final Duration? duration;
  final bool showPlayButton;
  final Widget? placeholder;
  final double? maxWidth;

  const ModernVideoCardWrapper({
    Key? key,
    this.thumbnailUrl,
    required this.title,
    this.subtitle,
    this.progress = 0.0,
    this.onTap,
    this.videoType,
    this.duration,
    this.showPlayButton = true,
    this.placeholder,
    this.maxWidth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = maxWidth != null
            ? (maxWidth! < constraints.maxWidth ? maxWidth! : constraints.maxWidth)
            : constraints.maxWidth;

        final cardHeight = cardWidth * 9 / 16; // 16:9宽高比

        return ModernVideoCard(
          width: cardWidth,
          height: cardHeight,
          thumbnailUrl: thumbnailUrl,
          title: title,
          subtitle: subtitle,
          progress: progress,
          onTap: onTap,
          videoType: videoType,
          duration: duration,
          showPlayButton: showPlayButton,
          placeholder: placeholder,
        );
      },
    );
  }
}