/// 动画系统演示页面
/// 展示CorePlayer现代化的动画效果

import 'package:flutter/material.dart';
import '../theme/design_tokens/design_tokens.dart';
import '../animations/animations.dart';
import '../widgets/modern_video_card.dart';
import '../widgets/responsive_grid.dart';

class AnimationDemo extends StatelessWidget {
  const AnimationDemo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'CorePlayer 动画演示',
          style: AppTextStyles.headlineSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 悬停动画演示
            _buildSection('悬停动画效果', _buildHoverAnimations()),

            const SizedBox(height: AppSpacing.xLarge),

            // 点击动画演示
            _buildSection('点击反馈效果', _buildTapAnimations()),

            const SizedBox(height: AppSpacing.xLarge),

            // 加载动画演示
            _buildSection('加载状态效果', _buildLoadingAnimations()),

            const SizedBox(height: AppSpacing.xLarge),

            // 视频卡片演示
            _buildSection('现代化视频卡片', _buildVideoCards()),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.medium),
        content,
      ],
    );
  }

  Widget _buildHoverAnimations() {
    return Wrap(
      spacing: AppSpacing.medium,
      runSpacing: AppSpacing.medium,
      children: [
        // 按钮悬停
        HoverButton(
          onPressed: () {
            debugPrint('Hover button clicked');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.large,
              vertical: AppSpacing.medium,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Text(
              '悬停按钮',
              style: AppTextStyles.labelLarge.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ),

        // 图标悬停
        HoverIcon(
          icon: Icons.favorite,
          onTap: () {
            debugPrint('Icon tapped');
          },
        ),

        // 卡片悬停
        HoverCard(
          onTap: () {
            debugPrint('Card tapped');
          },
          child: Container(
            width: 120,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.large),
            ),
            child: Center(
              child: Text(
                '悬停卡片',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTapAnimations() {
    return Wrap(
      spacing: AppSpacing.medium,
      runSpacing: AppSpacing.medium,
      children: [
        // 标准点击按钮
        TapButton(
          onPressed: () {
            debugPrint('Tap button clicked');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.large,
              vertical: AppSpacing.medium,
            ),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Text(
              '点击按钮',
              style: AppTextStyles.labelLarge.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ),

        // 图标点击
        TapIcon(
          icon: Icons.thumb_up,
          onTap: () {
            debugPrint('Thumbs up');
          },
        ),

        // 列表项点击
        TapListItem(
          onTap: () {
            debugPrint('List item tapped');
          },
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.medium),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.list,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.small),
                Text(
                  '列表项',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingAnimations() {
    return Column(
      children: [
        // Shimmer效果
        SkeletonScreen(
          child: Row(
            children: [
              AvatarSkeleton(),
              const SizedBox(width: AppSpacing.medium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TitleSkeleton(width: 200),
                    const SizedBox(height: AppSpacing.micro),
                    TextSkeleton.line(width: 150),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.large),

        // 旋转加载器
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SpinningIndicator(),
            PulseEffect(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.large),

        // 加载指示器
        LoadingIndicator(
          config: const LoadingAnimationConfig(
            type: LoadingAnimationType.bouncing,
            baseColor: AppColors.primary,
          ),
          message: '正在加载内容...',
        ),
      ],
    );
  }

  Widget _buildVideoCards() {
     final sampleVideos = [
       VideoCardData(
         title: '示例视频 1',
         subtitle: '演示悬停和点击效果',
         progress: 0.3,
         type: '本地',
         duration: const Duration(minutes: 2, seconds: 45),
         thumbnailUrl: 'https://via.placeholder.com/320x180/1C1C1E/FFFFFF?text=Video+1',
       ),
       VideoCardData(
         title: '示例视频 2',
         subtitle: '现代化UI设计',
         progress: 0.0,
         type: '网络',
         duration: const Duration(minutes: 5, seconds: 12),
         thumbnailUrl: 'https://via.placeholder.com/320x180/1C1C1E/FFFFFF?text=Video+2',
       ),
       VideoCardData(
         title: '示例视频 3',
         subtitle: '动画效果展示',
         progress: 0.7,
         type: '4K',
         duration: const Duration(minutes: 1, seconds: 30),
         thumbnailUrl: 'https://via.placeholder.com/320x180/1C1C1E/FFFFFF?text=Video+3',
       ),
     ];

    return AdaptiveVideoGrid(
      videos: sampleVideos,
      onTap: (video) {
        debugPrint('Tapped video: ${video.title}');
      },
      shrinkWrap: true,
    );
  }
}