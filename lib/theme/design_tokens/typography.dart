import 'dart:math';
import 'package:flutter/material.dart';
import 'colors.dart';

/// 应用文字排版系统 - 基于现代化设计规范
/// 参考openspec/changes/modernize-ui-design规格
class AppTextStyles {
  AppTextStyles._();

  // ================== 显示级别 Display ==================
  /// Display Large - 32px Bold
  /// 使用场景: 应用标题、欢迎页大标题
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  /// Display Medium - 28px Bold
  /// 使用场景: 页面主标题
  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    height: 1.25,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  /// Display Small - 24px Bold
  /// 使用场景: 次级页面标题
  static const TextStyle displaySmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    height: 1.3,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  // ================== 标题级别 Headline ==================
  /// Headline Large - 22px Bold
  /// 使用场景: 区域标题、分组标题 (如"继续观看"、"最近添加")
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    height: 1.3,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  /// Headline Medium - 20px SemiBold
  /// 使用场景: 卡片标题、视频名称
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  /// Headline Small - 18px SemiBold
  /// 使用场景: 小标题、设置项标题
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  // ================== 标题级别 Title (Material 3兼容) ==================
  /// Title Large - 22px Bold
  /// 使用场景: 页面区域标题 (与headlineLarge相同，Material 3兼容)
  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    height: 1.3,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  /// Title Medium - 16px SemiBold
  /// 使用场景: 列表项标题、卡片标题
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  /// Title Small - 14px SemiBold
  /// 使用场景: 小标题、标签文字
  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  // ================== 正文级别 Body ==================
  /// Body Large - 16px Regular
  /// 使用场景: 主要内容、描述文字
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.5,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  /// Body Medium - 14px Regular
  /// 使用场景: 次要内容、视频元数据
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
    letterSpacing: 0,
    color: AppColors.textSecondary,
  );

  /// Body Small - 12px Regular
  /// 使用场景: 辅助信息、时间戳、小字注释
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.5,
    letterSpacing: 0,
    color: AppColors.textTertiary,
  );

  // ================== 标签级别 Label ==================
  /// Label Large - 14px Medium
  /// 使用场景: 按钮文字、输入标签
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  /// Label Medium - 12px Medium
  /// 使用场景: 小按钮文字、表单标签
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.1,
    color: AppColors.textSecondary,
  );

  /// Label Small - 11px Medium
  /// 使用场景: 徽章文字、小标签
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.2,
    color: AppColors.textPrimary,
  );

  // ================== 特殊用途样式 ==================
  /// 视频卡片标题样式
  /// 在渐变背景上显示，需要阴影效果
  static const TextStyle videoCardTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0,
    color: Colors.white,
    shadows: [
      Shadow(
        color: Color(0x80000000), // 50%黑色阴影
        offset: Offset(0, 1),
        blurRadius: 2,
      ),
    ],
  );

  /// 侧边栏导航项样式
  static const TextStyle sidebarNavItem = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  /// 侧边栏分组标题样式
  static const TextStyle sidebarSectionTitle = TextStyle(
    fontSize: 11, // 从9增加到11，更易阅读
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.5,
    color: AppColors.textTertiary,
    textBaseline: TextBaseline.alphabetic,
  );

  /// 徽章文字样式
  static const TextStyle badgeText = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.3,
    color: Colors.white,
  );

  /// 按钮文字样式
  static const TextStyle buttonText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.2,
    color: AppColors.textPrimary,
  );

  /// 设置项标题样式
  static const TextStyle settingTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  /// 设置项描述样式
  static const TextStyle settingDescription = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    height: 1.4,
    letterSpacing: 0,
    color: AppColors.textSecondary,
  );

  /// 状态文字样式
  static const TextStyle statusText = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.2,
    color: AppColors.textTertiary,
  );

  // ================== 工具方法 ==================
  /// 获取指定颜色版本的文字样式
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  /// 获取指定字重版本的文字样式
  static TextStyle withFontWeight(TextStyle style, FontWeight fontWeight) {
    return style.copyWith(fontWeight: fontWeight);
  }

  /// 获取指定大小版本的文字样式
  static TextStyle withFontSize(TextStyle style, double fontSize) {
    return style.copyWith(fontSize: fontSize);
  }

  /// 获取带透明度的文字样式
  static TextStyle withOpacity(TextStyle style, double opacity) {
    Color? originalColor = style.color;
    if (originalColor != null) {
      return style.copyWith(color: originalColor.withOpacity(opacity));
    }
    return style;
  }

  /// 根据重要性获取文字样式
  static TextStyle getByImportance(TextImportance importance) {
    switch (importance) {
      case TextImportance.display:
        return displayLarge;
      case TextImportance.headline:
        return headlineLarge;
      case TextImportance.title:
        return titleMedium;
      case TextImportance.body:
        return bodyLarge;
      case TextImportance.caption:
        return bodySmall;
      case TextImportance.label:
        return labelSmall;
    }
  }

  /// 应用阴影效果
  static TextStyle withShadow(TextStyle style, {
    Color shadowColor = Colors.black,
    double offsetX = 0,
    double offsetY = 1,
    double blurRadius = 2,
    double opacity = 0.5,
  }) {
    final shadow = Shadow(
      color: shadowColor.withOpacity(opacity),
      offset: Offset(offsetX, offsetY),
      blurRadius: blurRadius,
    );

    // 如果已有阴影，添加新阴影
    final shadows = List<Shadow>.from(style.shadows ?? []);
    shadows.add(shadow);

    return style.copyWith(shadows: shadows);
  }
}

/// 文字重要性枚举
enum TextImportance {
  display,    // 显示级别
  headline,   // 标题级别
  title,      // 标题级别
  body,       // 正文级别
  caption,    // 说明级别
  label,      // 标签级别
}

/// Material 3 兼容的文字主题
class AppTextTheme {
  static TextTheme get darkTextTheme {
    return TextTheme(
      displayLarge: AppTextStyles.displayLarge,
      displayMedium: AppTextStyles.displayMedium,
      displaySmall: AppTextStyles.displaySmall,
      headlineLarge: AppTextStyles.headlineLarge,
      headlineMedium: AppTextStyles.headlineMedium,
      headlineSmall: AppTextStyles.headlineSmall,
      titleLarge: AppTextStyles.titleLarge,
      titleMedium: AppTextStyles.titleMedium,
      titleSmall: AppTextStyles.titleSmall,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.bodyMedium,
      bodySmall: AppTextStyles.bodySmall,
      labelLarge: AppTextStyles.labelLarge,
      labelMedium: AppTextStyles.labelMedium,
      labelSmall: AppTextStyles.labelSmall,
    );
  }
}