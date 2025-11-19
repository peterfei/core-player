import 'package:flutter/material.dart';
import '../theme/design_tokens/design_tokens.dart';

/// 响应式网格组件
/// 基于openspec/changes/modernize-ui-design规格
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final SliverGridDelegate? gridDelegate;
  final EdgeInsets? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final int? crossAxisCount;
  final double? childAspectRatio;
  final double? crossAxisSpacing;
  final double? mainAxisSpacing;
  final double? maxWidth;

  const ResponsiveGrid({
    Key? key,
    required this.children,
    this.gridDelegate,
    this.padding,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
    this.crossAxisCount,
    this.childAspectRatio = 16 / 9,
    this.crossAxisSpacing,
    this.mainAxisSpacing,
    this.maxWidth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 如果指定了最大宽度，使用最大宽度
        final effectiveWidth = maxWidth != null && maxWidth! < constraints.maxWidth
            ? maxWidth!
            : constraints.maxWidth;

        final effectiveCrossAxisCount = crossAxisCount ?? _getCrossAxisCount(effectiveWidth);
        final effectiveChildAspectRatio = childAspectRatio ?? 16 / 9;
        final effectiveCrossAxisSpacing = crossAxisSpacing ?? _getCrossAxisSpacing(effectiveWidth);
        final effectiveMainAxisSpacing = mainAxisSpacing ?? _getMainAxisSpacing(effectiveWidth);
        final effectivePadding = padding ?? _getResponsivePadding(effectiveWidth);

        return GridView.builder(
          controller: controller,
          physics: physics,
          shrinkWrap: shrinkWrap,
          padding: effectivePadding,
          gridDelegate: gridDelegate ??
              SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: effectiveCrossAxisCount,
                childAspectRatio: effectiveChildAspectRatio,
                crossAxisSpacing: effectiveCrossAxisSpacing,
                mainAxisSpacing: effectiveMainAxisSpacing,
              ),
          itemCount: children.length,
          itemBuilder: (context, index) {
            return RepaintBoundary(
              key: ValueKey('grid_item_$index'),
              child: children[index],
            );
          },
        );
      },
    );
  }

  /// 根据屏幕宽度获取列数
  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth >= 1400) return 8;      // 超大屏：8列
    if (screenWidth >= 1200) return 6;      // 大屏桌面：6列
    if (screenWidth >= 1000) return 5;      // 中大屏：5列
    if (screenWidth >= 800) return 4;       // 中屏桌面：4列
    if (screenWidth >= 600) return 3;       // 平板：3列
    return 2;                               // 移动端：2列
  }

  /// 根据屏幕宽度获取横向间距
  double _getCrossAxisSpacing(double screenWidth) {
    if (screenWidth >= 1200) return 20.0;  // 20px
    if (screenWidth >= 800) return 16.0;   // 16px
    if (screenWidth >= 600) return 12.0;   // 12px
    return 8.0;                              // 8px
  }

  /// 根据屏幕宽度获取纵向间距
  double _getMainAxisSpacing(double screenWidth) {
    return _getCrossAxisSpacing(screenWidth);
  }

  /// 根据屏幕宽度获取内边距
  EdgeInsets _getResponsivePadding(double screenWidth) {
    if (screenWidth >= 1200) {
      return const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxLarge, // 48px
        vertical: AppSpacing.large,      // 24px
      );
    } else if (screenWidth >= 800) {
      return const EdgeInsets.symmetric(
        horizontal: AppSpacing.xLarge,   // 32px
        vertical: AppSpacing.large,      // 24px
      );
    } else if (screenWidth >= 600) {
      return const EdgeInsets.symmetric(
        horizontal: AppSpacing.large,    // 24px
        vertical: AppSpacing.medium,     // 16px
      );
    } else {
      return const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,   // 16px
        vertical: AppSpacing.medium,     // 16px
      );
    }
  }
}

/// 自适应视频卡片网格
class AdaptiveVideoGrid extends StatelessWidget {
  final List<VideoCardData> videos;
  final Function(VideoCardData)? onTap;
  final ScrollController? controller;
  final bool shrinkWrap;
  final EdgeInsets? padding;
  final double? maxWidth;

  const AdaptiveVideoGrid({
    Key? key,
    required this.videos,
    this.onTap,
    this.controller,
    this.shrinkWrap = false,
    this.padding,
    this.maxWidth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      controller: controller,
      shrinkWrap: shrinkWrap,
      padding: padding,
      maxWidth: maxWidth,
      childAspectRatio: 16 / 9,
      children: videos.map((video) {
        return ModernVideoCard(
          thumbnailUrl: video.thumbnailUrl,
          title: video.title,
          subtitle: video.subtitle,
          progress: video.progress,
          videoType: video.type,
          duration: video.duration,
          onTap: () => onTap?.call(video),
        );
      }).toList(),
    );
  }
}

/// 视频卡片数据模型
class VideoCardData {
  final String? thumbnailUrl;
  final String title;
  final String? subtitle;
  final double progress; // 0.0 - 1.0
  final String? type;
  final Duration? duration;
  final String? url;
  final String? localPath;

  const VideoCardData({
    this.thumbnailUrl,
    required this.title,
    this.subtitle,
    this.progress = 0.0,
    this.type,
    this.duration,
    this.url,
    this.localPath,
  });

  VideoCardData copyWith({
    String? thumbnailUrl,
    String? title,
    String? subtitle,
    double? progress,
    String? type,
    Duration? duration,
    String? url,
    String? localPath,
  }) {
    return VideoCardData(
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      progress: progress ?? this.progress,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      url: url ?? this.url,
      localPath: localPath ?? this.localPath,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoCardData &&
        other.thumbnailUrl == thumbnailUrl &&
        other.title == title &&
        other.subtitle == subtitle &&
        other.progress == progress &&
        other.type == type &&
        other.duration == duration &&
        other.url == url &&
        other.localPath == localPath;
  }

  @override
  int get hashCode {
    return thumbnailUrl.hashCode ^
        title.hashCode ^
        subtitle.hashCode ^
        progress.hashCode ^
        type.hashCode ^
        duration.hashCode ^
        url.hashCode ^
        localPath.hashCode;
  }
}

/// 分组响应式网格
class GroupedResponsiveGrid extends StatelessWidget {
  final Map<String, List<VideoCardData>> groupedVideos;
  final Function(VideoCardData)? onTap;
  final Map<String, Widget>? sectionHeaders;
  final ScrollController? controller;
  final bool shrinkWrap;
  final EdgeInsets? padding;
  final double? maxWidth;

  const GroupedResponsiveGrid({
    Key? key,
    required this.groupedVideos,
    this.onTap,
    this.sectionHeaders,
    this.controller,
    this.shrinkWrap = false,
    this.padding,
    this.maxWidth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      shrinkWrap: shrinkWrap,
      padding: padding ?? _getDefaultPadding(),
      itemCount: groupedVideos.length * 2, // 每个分组有一个标题 + 网格
      itemBuilder: (context, index) {
        final sectionIndex = index ~/ 2;
        final isHeader = index % 2 == 0;
        final sectionKey = groupedVideos.keys.elementAt(sectionIndex);
        final videos = groupedVideos[sectionKey]!;

        if (isHeader) {
          return _buildSectionHeader(sectionKey, videos);
        } else {
          return _buildSectionGrid(videos, sectionKey);
        }
      },
    );
  }

  Widget _buildSectionHeader(String sectionKey, List<VideoCardData> videos) {
    if (sectionHeaders != null && sectionHeaders!.containsKey(sectionKey)) {
      return sectionHeaders![sectionKey]!;
    }

    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppSpacing.medium,
        top: AppSpacing.large,
      ),
      child: Row(
        children: [
          Text(
            sectionKey,
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.small),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.small,
              vertical: AppSpacing.micro,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Text(
              '${videos.length}',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          if (videos.length > 4)
            TextButton(
              onPressed: () {
                // 查看全部功能
              },
              child: Text(
                '查看全部',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionGrid(List<VideoCardData> videos, String sectionKey) {
    // 如果视频数量很多，限制显示数量
    final displayVideos = videos.length > 6 ? videos.take(6).toList() : videos;

    return AdaptiveVideoGrid(
      videos: displayVideos,
      onTap: onTap,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
    );
  }

  EdgeInsets _getDefaultPadding() {
    return const EdgeInsets.symmetric(
      horizontal: AppSpacing.large,
      vertical: AppSpacing.medium,
    );
  }
}

/// 响应式布局工具类
class ResponsiveLayoutHelper {
  /// 获取屏幕尺寸类型
  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width >= 1200) return ScreenSize.desktop;
    if (width >= 800) return ScreenSize.tablet;
    if (width >= 600) return ScreenSize.largeMobile;
    return ScreenSize.mobile;
  }

  /// 判断是否为移动端
  static bool isMobile(BuildContext context) {
    return getScreenSize(context) == ScreenSize.mobile;
  }

  /// 判断是否为平板
  static bool isTablet(BuildContext context) {
    return getScreenSize(context) == ScreenSize.tablet;
  }

  /// 判断是否为桌面
  static bool isDesktop(BuildContext context) {
    return getScreenSize(context) == ScreenSize.desktop;
  }

  /// 获取响应式值
  static T getResponsiveValue<T>({
    required BuildContext context,
    required T mobile,
    T? largeMobile,
    T? tablet,
    T? desktop,
  }) {
    final screenSize = getScreenSize(context);

    switch (screenSize) {
      case ScreenSize.desktop:
        return desktop ?? tablet ?? largeMobile ?? mobile;
      case ScreenSize.tablet:
        return tablet ?? largeMobile ?? mobile;
      case ScreenSize.largeMobile:
        return largeMobile ?? mobile;
      case ScreenSize.mobile:
        return mobile;
    }
  }
}

/// 屏幕尺寸枚举
enum ScreenSize {
  mobile,      // < 600px
  largeMobile, // 600-800px
  tablet,      // 800-1200px
  desktop,     // >= 1200px
}