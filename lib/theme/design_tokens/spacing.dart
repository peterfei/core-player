import 'package:flutter/material.dart';

/// 应用间距系统 - 基于8px网格的规范化间距
/// 参考openspec/changes/modernize-ui-design规格
class AppSpacing {
  AppSpacing._();

  // ================== 基础间距单位 ==================
  /// 微间距 - 4px (最紧密的元素间距)
  static const double micro = 4.0;

  /// 小间距 - 8px (相关元素间距)
  static const double small = 8.0;

  /// 中间距 - 12px (元素组之间)
  static const double medium = 12.0;

  /// 标准间距 - 16px (组件内边距)
  static const double standard = 16.0;

  /// 大间距 - 24px (区块间距)
  static const double large = 24.0;

  /// 超大间距 - 32px (主要区域间距)
  static const double xLarge = 32.0;

  /// 特大间距 - 48px (页面级别大区块)
  static const double xxLarge = 48.0;

  // ================== 特殊用途间距 ==================
  /// 紧密间距 - 2px (边框与内容的极小间距)
  static const double tight = 2.0;

  /// 超小间距 - 6px (微调间距)
  static const double xSmall = 6.0;

  /// 10px间距 - 常用于小部件间距
  static const double ten = 10.0;

  /// 14px间距 - 常用于表单项间距
  static const double fourteen = 14.0;

  /// 20px间距 - 常用于卡片间距
  static const double twenty = 20.0;

  /// 28px间距 - 常用于section间距
  static const double twentyEight = 28.0;

  /// 36px间距 - 常用于主要区域间距
  static const double thirtySix = 36.0;

  /// 40px间距 - 常用于页面顶部/底部间距
  static const double forty = 40.0;

  /// 56px间距 - 常用于页面大标题间距
  static const double fiftySix = 56.0;

  /// 64px间距 - 常用于页面标题与内容间距
  static const double sixtyFour = 64.0;

  // ================== 组件特定间距 ==================
  /// 卡片内边距
  static const EdgeInsets cardPadding = EdgeInsets.all(medium);

  /// 按钮内边距 (水平)
  static const EdgeInsets buttonPaddingHorizontal = EdgeInsets.symmetric(horizontal: large);

  /// 按钮内边距 (垂直)
  static const EdgeInsets buttonPaddingVertical = EdgeInsets.symmetric(vertical: medium);

  /// 按钮内边距 (完整)
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: large,
    vertical: medium,
  );

  /// 小按钮内边距
  static const EdgeInsets smallButtonPadding = EdgeInsets.symmetric(
    horizontal: medium,
    vertical: small,
  );

  /// 输入框内边距
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: medium,
    vertical: small,
  );

  /// 列表项内边距
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: standard,
    vertical: medium,
  );

  /// 侧边栏内边距
  static const EdgeInsets sidebarPadding = EdgeInsets.all(large);

  /// 侧边栏项目内边距
  static const EdgeInsets sidebarItemPadding = EdgeInsets.symmetric(
    horizontal: standard,
    vertical: small,
  );

  /// 页面内边距 (移动端)
  static const EdgeInsets pagePaddingMobile = EdgeInsets.all(standard);

  /// 页面内边距 (平板)
  static const EdgeInsets pagePaddingTablet = EdgeInsets.all(large);

  /// 页面内边距 (桌面)
  static const EdgeInsets pagePaddingDesktop = EdgeInsets.symmetric(
    horizontal: xxLarge,
    vertical: large,
  );

  /// 对话框内边距
  static const EdgeInsets dialogPadding = EdgeInsets.all(xLarge);

  /// 底部弹窗内边距
  static const EdgeInsets bottomSheetPadding = EdgeInsets.symmetric(
    horizontal: large,
    vertical: xLarge,
  );

  // ================== 布局间距 ==================
  /// 网格间距 (桌面)
  static const double gridSpacingDesktop = 20.0;

  /// 网格间距 (平板)
  static const double gridSpacingTablet = 16.0;

  /// 网格间距 (移动)
  static const double gridSpacingMobile = 12.0;

  /// 网格间距 (小屏)
  static const double gridSpacingSmall = 8.0;

  /// 卡片间距
  static const double cardSpacing = medium;

  /// 列表项间距
  static const double listItemSpacing = small;

  /// section间距
  static const double sectionSpacing = large;

  /// paragraph间距
  static const double paragraphSpacing = medium;

  // ================== 边距 Margin ==================
  /// 小部件外边距
  static const EdgeInsets widgetMargin = EdgeInsets.all(small);

  /// 组件外边距
  static const EdgeInsets componentMargin = EdgeInsets.all(medium);

  /// 区块外边距
  static const EdgeInsets sectionMargin = EdgeInsets.all(large);

  /// 页面外边距
  static const EdgeInsets pageMargin = EdgeInsets.symmetric(
    horizontal: large,
    vertical: medium,
  );

  // ================== 工具方法 ==================
  /// 获取指定方向的间距
  static EdgeInsets only({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) {
    return EdgeInsets.only(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );
  }

  /// 获取对称间距
  static EdgeInsets symmetric({
    double horizontal = 0,
    double vertical = 0,
  }) {
    return EdgeInsets.symmetric(
      horizontal: horizontal,
      vertical: vertical,
    );
  }

  /// 获取统一间距
  static EdgeInsets all(double value) {
    return EdgeInsets.all(value);
  }

  /// 获取响应式间距
  static double getResponsiveSpacing({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;

    if (width >= 1200 && desktop != null) {
      return desktop;
    } else if (width >= 800 && tablet != null) {
      return tablet;
    } else {
      return mobile;
    }
  }

  /// 获取响应式内边距
  static EdgeInsets getResponsivePadding({
    required BuildContext context,
    EdgeInsets mobile = EdgeInsets.zero,
    EdgeInsets? tablet,
    EdgeInsets? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;

    if (width >= 1200 && desktop != null) {
      return desktop;
    } else if (width >= 800 && tablet != null) {
      return tablet;
    } else {
      return mobile;
    }
  }

  /// 计算间距比例
  static double scale(double baseSpacing, double factor) {
    return baseSpacing * factor;
  }

  /// 获取间距名称
  static String getSpacingName(double value) {
    switch (value.toInt()) {
      case 2: return 'tight';
      case 4: return 'micro';
      case 6: return 'xSmall';
      case 8: return 'small';
      case 10: return 'ten';
      case 12: return 'medium';
      case 14: return 'fourteen';
      case 16: return 'standard';
      case 20: return 'twenty';
      case 24: return 'large';
      case 28: return 'twentyEight';
      case 32: return 'xLarge';
      case 36: return 'thirtySix';
      case 40: return 'forty';
      case 48: return 'xxLarge';
      case 56: return 'fiftySix';
      case 64: return 'sixtyFour';
      default: return 'custom';
    }
  }

  /// 验证间距是否符合8px网格系统
  static bool isValidSpacing(double value) {
    return value % 4 == 0; // 基于4px网格，允许4的倍数
  }

  /// 获取最近的合法间距
  static double getNearestValidSpacing(double value) {
    return (value / 4).round() * 4.0;
  }
}

/// 间距级别枚举
enum SpacingLevel {
  micro(4),
  small(8),
  medium(12),
  standard(16),
  large(24),
  xLarge(32),
  xxLarge(48);

  const SpacingLevel(this.value);

  final double value;

  double get spacing => value;

  EdgeInsets get padding => EdgeInsets.all(value);

  EdgeInsets get margin => EdgeInsets.all(value);

  EdgeInsets get horizontalPadding => EdgeInsets.symmetric(horizontal: value);

  EdgeInsets get verticalPadding => EdgeInsets.symmetric(vertical: value);
}