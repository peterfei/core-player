import 'package:flutter/material.dart';
import 'colors.dart';

/// 应用渐变系统 - 统一的渐变效果和叠加层
/// 参考openspec/changes/modernize-ui-design规格
class AppGradients {
  AppGradients._();

  // ================== 视频卡片渐变 ==================
  /// 视频卡片底部渐变 (显示标题用)
  /// 从透明到70%黑色，用于文字可读性
  static const LinearGradient videoCardBottom = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.cardGradientStart,  // 透明
      AppColors.cardGradientEnd,    // 70%黑色
    ],
    stops: [0.5, 1.0],
  );

  /// 视频卡片顶部渐变 (徽章背景)
  static const LinearGradient videoCardTop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.overlayBlack,        // 70%黑色
      Color(0x80000000),            // 50%黑色
      Colors.transparent,           // 透明
    ],
    stops: [0.0, 0.3, 1.0],
  );

  // ================== 侧边栏渐变 ==================
  /// 侧边栏顶部渐变
  static const LinearGradient sidebarHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.surface,             // #1C1C1E
      AppColors.surfaceVariant,      // #2C2C2E
    ],
  );

  /// 侧边栏选中项渐变
  static const LinearGradient sidebarItemSelected = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      AppColors.sidebarSelected,     // #2C2C2E
      AppColors.surfaceVariant,      // #2C2C2E
    ],
  );

  // ================== 按钮渐变 ==================
  /// 主色按钮渐变
  static const LinearGradient primaryButton = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      AppColors.primary,             // #0A7AFF
      Color(0xFF0066CC),            // 稍深的蓝色
    ],
  );

  /// 辅助色按钮渐变
  static const LinearGradient secondaryButton = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      AppColors.secondary,           // #FF9500
      Color(0xFFE67E00),            // 稍深的橙色
    ],
  );

  /// 成功按钮渐变
  static const LinearGradient successButton = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      AppColors.success,             // #34C759
      Color(0xFF28A745),            // 稍深的绿色
    ],
  );

  // ================== 加载状态渐变 ==================
  /// Shimmer加载渐变
  static const LinearGradient shimmerLoading = LinearGradient(
    begin: Alignment(-1.0, -0.5),
    end: Alignment(1.0, 0.5),
    colors: [
      Color(0xFF1C1C1E),            // 基础色
      Color(0xFF2C2C2E),            // 高亮色
      Color(0xFF1C1C1E),            // 基础色
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// 骨架屏渐变
  static const LinearGradient skeleton = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF2C2C2E),            // 较亮
      Color(0xFF1C1C1E),            // 基础
      Color(0xFF2C2C2E),            // 较亮
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // ================== 背景渐变 ==================
  /// 主背景渐变 (深色到稍浅)
  static LinearGradient mainBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.background,          // #0A0A0A
      Color(0xFF0F0F0F),            // 稍浅
    ],
  );

  /// 表面背景渐变 (轻微渐变)
  static LinearGradient surfaceBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.surface,             // #1C1C1E
      Color(0xFF1A1A1C),            // 稍深
    ],
  );

  // ================== 对话框渐变 ==================
  /// 对话框背景渐变
  static LinearGradient dialogBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.surface,             // #1C1C1E
      AppColors.surfaceVariant,      // #2C2C2E
    ],
  );

  /// 遮罩层渐变
  static LinearGradient overlayMask = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Colors.black.withOpacity(0.3),
      Colors.black.withOpacity(0.6),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // ================== 功能性渐变 ==================
  /// 进度条渐变
  static const LinearGradient progressBar = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      AppColors.primary,             // #0A7AFF
      Color(0xFF00D4FF),            // 青色
    ],
  );

  /// 播放按钮渐变
  static const LinearGradient playButton = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      AppColors.success,             // #34C759
      Color(0xFF30D158),            // 更亮的绿色
    ],
  );

  /// 缓存状态渐变
  static const LinearGradient cachingProgress = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      AppColors.info,                // #0A7AFF
      AppColors.caching,             // #0A7AFF
    ],
  );

  // ================== 分辨率标识渐变 ==================
  /// 4K标识渐变
  static const LinearGradient resolution4K = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      AppColors.resolution4K,        // #FF9500
      Color(0xFFFF6B00),            // 较亮的橙色
    ],
  );

  /// HDR标识渐变
  static const LinearGradient hdr = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      AppColors.hdr,                 // #AF52DE
      Color(0xFFBF5FFF),            // 较亮的紫色
    ],
  );

  // ================== 特殊效果渐变 ==================
  /// 发光效果渐变
  static LinearGradient glowEffect(Color color) {
    return LinearGradient(
      begin: Alignment.center,
      end: const Alignment(1.0, 1.0),
      colors: [
        color.withOpacity(0.8),
        color.withOpacity(0.4),
        color.withOpacity(0.1),
        Colors.transparent,
      ],
      stops: [0.0, 0.3, 0.6, 1.0],
    );
  }

  /// 扫描线效果渐变
  static LinearGradient scanningLine(Color color) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        color.withOpacity(0.3),
        color.withOpacity(0.6),
        color.withOpacity(0.3),
        Colors.transparent,
      ],
      stops: [0.0, 0.3, 0.5, 0.7, 1.0],
    );
  }

  /// 脉冲效果渐变
  static RadialGradient pulseEffect(Color color) {
    return RadialGradient(
      center: Alignment.center,
      colors: [
        color.withOpacity(0.8),
        color.withOpacity(0.4),
        color.withOpacity(0.1),
        Colors.transparent,
      ],
      stops: [0.0, 0.3, 0.6, 1.0],
    );
  }

  // ================== 工具方法 ==================
  /// 创建线性渐变
  static LinearGradient linear({
    required Alignment begin,
    required Alignment end,
    required List<Color> colors,
    List<double>? stops,
    TileMode tileMode = TileMode.clamp,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: colors,
      stops: stops,
      tileMode: tileMode,
    );
  }

  /// 创建径向渐变
  static RadialGradient radial({
    required Alignment center,
    required double radius,
    required List<Color> colors,
    List<double>? stops,
    TileMode tileMode = TileMode.clamp,
  }) {
    return RadialGradient(
      center: center,
      radius: radius,
      colors: colors,
      stops: stops,
      tileMode: tileMode,
    );
  }

  /// 创建扫描渐变
  static SweepGradient sweep({
    required Alignment center,
    required List<Color> colors,
    List<double>? stops,
    TileMode tileMode = TileMode.clamp,
  }) {
    return SweepGradient(
      center: center,
      colors: colors,
      stops: stops,
      tileMode: tileMode,
    );
  }

  /// 创建自定义视频卡片渐变
  static LinearGradient customVideoCard({
    Color startColor = Colors.transparent,
    Color endColor = AppColors.overlayBlack,
    double startStop = 0.5,
    double endStop = 1.0,
  }) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [startColor, endColor],
      stops: [startStop, endStop],
    );
  }

  /// 创建按钮渐变
  static LinearGradient buttonGradient({
    required Color primaryColor,
    Color? secondaryColor,
    bool isVertical = false,
  }) {
    final colors = secondaryColor != null
        ? [primaryColor, secondaryColor]
        : [primaryColor, primaryColor.withOpacity(0.8)];

    return LinearGradient(
      begin: isVertical ? Alignment.topCenter : Alignment.centerLeft,
      end: isVertical ? Alignment.bottomCenter : Alignment.centerRight,
      colors: colors,
    );
  }

  /// 创建背景渐变
  static LinearGradient backgroundGradient({
    Color startColor = AppColors.background,
    Color endColor = const Color(0xFF0F0F0F),
    bool isVertical = true,
  }) {
    return LinearGradient(
      begin: isVertical ? Alignment.topCenter : Alignment.centerLeft,
      end: isVertical ? Alignment.bottomCenter : Alignment.centerRight,
      colors: [startColor, endColor],
    );
  }

  /// 获取状态渐变
  static LinearGradient getStatusGradient(StatusType type) {
    switch (type) {
      case StatusType.success:
        return successButton;
      case StatusType.warning:
        return secondaryButton;
      case StatusType.error:
        return LinearGradient(
          colors: [AppColors.error, Color(0xFFE60026)],
        );
      case StatusType.info:
        return primaryButton;
      case StatusType.neutral:
        return const LinearGradient(
          colors: [AppColors.surface, AppColors.surfaceVariant],
        );
    }
  }

  /// 创建动画渐变
  static Animation<LinearGradient> animatedGradient(
    AnimationController controller, {
    required List<Color> colors,
    Alignment begin = Alignment.centerLeft,
    Alignment end = Alignment.centerRight,
  }) {
    return Tween<LinearGradient>(
      begin: LinearGradient(colors: colors, begin: begin, end: end),
      end: LinearGradient(
        colors: colors.reversed.toList(),
        begin: begin,
        end: end,
      ),
    ).animate(controller);
  }
}

/// 渐变工具类
class GradientUtils {
  /// 混合两种颜色
  static Color blendColors(Color color1, Color color2, double ratio) {
    return Color.lerp(color1, color2, ratio) ?? color1;
  }

  /// 创建彩虹渐变
  static List<Color> rainbowColors() {
    return [
      const Color(0xFFFF0000), // 红
      const Color(0xFFFF7F00), // 橙
      const Color(0xFFFFFF00), // 黄
      const Color(0xFF00FF00), // 绿
      const Color(0xFF0000FF), // 蓝
      const Color(0xFF4B0082), // 靛
      const Color(0xFF9400D3), // 紫
    ];
  }

  /// 创建温度渐变 (冷到热)
  static List<Color> temperatureColors() {
    return [
      const Color(0xFF0066CC), // 冷蓝
      const Color(0xFF00A8E8), // 天蓝
      const Color(0xFF00CED1), // 深青
      const Color(0xFF40E0D0), // 绿松石
      const Color(0xFFFFA500), // 橙
      const Color(0xFFFF4500), // 橙红
      const Color(0xFFFF0000), // 红
    ];
  }
}

/// 状态类型枚举
enum StatusType {
  success,    // 成功
  warning,    // 警告
  error,      // 错误
  info,       // 信息
  neutral,    // 中性
}