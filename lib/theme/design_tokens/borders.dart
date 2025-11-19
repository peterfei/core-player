import 'package:flutter/material.dart';

/// 应用圆角系统 - 统一的边框和圆角规范
/// 参考openspec/changes/modernize-ui-design规格
class AppRadius {
  AppRadius._();

  // ================== 基础圆角值 ==================
  /// 无圆角 - 0px
  static const double none = 0.0;

  /// 微小圆角 - 2px (细边框、分割线)
  static const double xSmall = 2.0;

  /// 小圆角 - 4px (小徽章、小标签)
  static const double small = 4.0;

  /// 中小圆角 - 6px (小按钮、小输入框)
  static const double mediumSmall = 6.0;

  /// 中等圆角 - 8px (按钮、输入框、侧边栏选中项)
  static const double medium = 8.0;

  /// 中大圆角 - 10px (中等卡片)
  static const double mediumLarge = 10.0;

  /// 大圆角 - 12px (视频卡片、历史记录卡片)
  static const double large = 12.0;

  /// 超大圆角 - 16px (对话框、底部弹窗)
  static const double xLarge = 16.0;

  /// 特大圆角 - 20px (大型容器)
  static const double xxLarge = 20.0;

  /// 超大圆角 - 24px (特殊用途)
  static const double xxxLarge = 24.0;

  /// 圆形 - 100 (圆形头像、浮动按钮)
  static const double circular = 100.0;

  // ================== 组件特定圆角 ==================
  /// 视频卡片圆角
  static const double videoCard = large;

  /// 历史记录卡片圆角
  static const double historyCard = large;

  /// 对话框圆角
  static const double dialog = xLarge;

  /// 底部弹窗圆角
  static const double bottomSheet = xLarge;

  /// 按钮圆角
  static const double button = medium;

  /// 小按钮圆角
  static const double smallButton = small;

  /// 输入框圆角
  static const double input = medium;

  /// 侧边栏圆角
  static const double sidebar = small;

  /// 侧边栏选中项圆角
  static const double sidebarItemSelected = medium;

  /// 徽章圆角
  static const double badge = small;

  /// 标签圆角
  static const double chip = medium;

  /// 浮动按钮圆角
  static const double floatingButton = circular;

  /// 头像圆角
  static const double avatar = circular;

  /// 通知图标圆角
  static const double notification = small;

  /// 进度条圆角
  static const double progressBar = small;

  /// 搜索框圆角
  static const double searchField = medium;

  // ================== BorderRadius 对象 ==================
  /// 无圆角
  static BorderRadius noneBorder = BorderRadius.circular(none);

  /// 小圆角
  static BorderRadius smallBorder = BorderRadius.circular(small);

  /// 中等圆角
  static BorderRadius mediumBorder = BorderRadius.circular(medium);

  /// 大圆角
  static BorderRadius largeBorder = BorderRadius.circular(large);

  /// 超大圆角
  static BorderRadius xLargeBorder = BorderRadius.circular(xLarge);

  /// 圆形
  static BorderRadius circularBorder = BorderRadius.circular(circular);

  /// 视频卡片圆角
  static BorderRadius videoCardBorder = BorderRadius.circular(videoCard);

  /// 对话框圆角
  static BorderRadius dialogBorder = BorderRadius.circular(dialog);

  /// 按钮圆角
  static BorderRadius buttonBorder = BorderRadius.circular(button);

  /// 徽章圆角
  static BorderRadius badgeBorder = BorderRadius.circular(badge);

  // ================== 不对称圆角 ==================
  /// 顶部圆角 (用于底部弹窗)
  static BorderRadius topBorder = BorderRadius.only(
    topLeft: Radius.circular(xLarge),
    topRight: Radius.circular(xLarge),
  );

  /// 底部圆角 (用于顶部弹窗)
  static BorderRadius bottomBorder = BorderRadius.only(
    bottomLeft: Radius.circular(xLarge),
    bottomRight: Radius.circular(xLarge),
  );

  /// 左侧圆角 (用于右侧面板)
  static BorderRadius leftBorder = BorderRadius.only(
    topLeft: Radius.circular(large),
    bottomLeft: Radius.circular(large),
  );

  /// 右侧圆角 (用于左侧面板)
  static BorderRadius rightBorder = BorderRadius.only(
    topRight: Radius.circular(large),
    bottomRight: Radius.circular(large),
  );

  /// 卡片圆角 (略微不对称)
  static BorderRadius cardBorder = BorderRadius.only(
    topLeft: Radius.circular(large),
    topRight: Radius.circular(large),
    bottomLeft: Radius.circular(large - 2),
    bottomRight: Radius.circular(large - 2),
  );

  // ================== 边框宽度 ==================
  /// 无边框
  static const double noneBorderWidth = 0.0;

  /// 细边框
  static const double thinBorderWidth = 0.5;

  /// 标准边框
  static const double normalBorderWidth = 1.0;

  /// 粗边框
  static const double thickBorderWidth = 2.0;

  /// 超粗边框
  static const double extraThickBorderWidth = 3.0;

  // ================== 工具方法 ==================
  /// 创建自定义圆角
  static BorderRadius custom(double radius) {
    return BorderRadius.circular(radius);
  }

  /// 创建不对称圆角
  static BorderRadius asymmetric({
    double topLeft = 0,
    double topRight = 0,
    double bottomLeft = 0,
    double bottomRight = 0,
  }) {
    return BorderRadius.only(
      topLeft: Radius.circular(topLeft),
      topRight: Radius.circular(topRight),
      bottomLeft: Radius.circular(bottomLeft),
      bottomRight: Radius.circular(bottomRight),
    );
  }

  /// 创建水平对称圆角
  static BorderRadius horizontalSymmetric(double radius) {
    return BorderRadius.only(
      topLeft: Radius.circular(radius),
      bottomLeft: Radius.circular(radius),
    );
  }

  /// 创建垂直对称圆角
  static BorderRadius verticalSymmetric(double radius) {
    return BorderRadius.only(
      topLeft: Radius.circular(radius),
      topRight: Radius.circular(radius),
    );
  }

  /// 根据组件类型获取圆角
  static BorderRadius getBorderRadius(ComponentType type) {
    switch (type) {
      case ComponentType.videoCard:
        return videoCardBorder;
      case ComponentType.historyCard:
        return BorderRadius.circular(historyCard);
      case ComponentType.dialog:
        return dialogBorder;
      case ComponentType.button:
        return buttonBorder;
      case ComponentType.smallButton:
        return BorderRadius.circular(smallButton);
      case ComponentType.input:
        return BorderRadius.circular(input);
      case ComponentType.sidebar:
        return BorderRadius.circular(sidebar);
      case ComponentType.badge:
        return badgeBorder;
      case ComponentType.chip:
        return BorderRadius.circular(chip);
      case ComponentType.floatingButton:
        return circularBorder;
      case ComponentType.avatar:
        return circularBorder;
      case ComponentType.bottomSheet:
        return topBorder;
      default:
        return mediumBorder;
    }
  }

  /// 获取响应式圆角
  static double getResponsiveRadius({
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

  /// 获取圆角级别名称
  static String getRadiusName(double value) {
    switch (value.toInt()) {
      case 0: return 'none';
      case 2: return 'xSmall';
      case 4: return 'small';
      case 6: return 'mediumSmall';
      case 8: return 'medium';
      case 10: return 'mediumLarge';
      case 12: return 'large';
      case 16: return 'xLarge';
      case 20: return 'xxLarge';
      case 24: return 'xxxLarge';
      case 100: return 'circular';
      default: return 'custom';
    }
  }

  /// 验证圆角值是否在有效范围内
  static bool isValidRadius(double value) {
    return value >= 0 && value <= 100;
  }

  /// 获取最近的合法圆角值
  static double getNearestValidRadius(double value) {
    if (value <= 0) return 0;
    if (value >= 100) return 100;

    // 常用圆角值列表
    final commonValues = [0.0, 2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 16.0, 20.0, 24.0, 100.0];

    double closest = commonValues.first;
    double minDistance = (value - closest).abs();

    for (final commonValue in commonValues) {
      final distance = (value - commonValue).abs();
      if (distance < minDistance) {
        minDistance = distance;
        closest = commonValue;
      }
    }

    return closest;
  }
}

/// 组件类型枚举
enum ComponentType {
  videoCard,      // 视频卡片
  historyCard,    // 历史记录卡片
  dialog,         // 对话框
  button,         // 按钮
  smallButton,    // 小按钮
  input,          // 输入框
  sidebar,        // 侧边栏
  badge,          // 徽章
  chip,           // 标签
  floatingButton, // 浮动按钮
  avatar,         // 头像
  bottomSheet,    // 底部弹窗
}

/// 边框样式
class AppBorderStyle {
  /// 无边框
  static Border none = Border.all(width: 0, color: Colors.transparent);

  /// 标准边框
  static Border standard(Color color, {double width = 1.0}) {
    return Border.all(color: color, width: width);
  }

  /// 顶部边框
  static Border top(Color color, {double width = 1.0}) {
    return Border(top: BorderSide(color: color, width: width));
  }

  /// 底部边框
  static Border bottom(Color color, {double width = 1.0}) {
    return Border(bottom: BorderSide(color: color, width: width));
  }

  /// 左侧边框
  static Border left(Color color, {double width = 1.0}) {
    return Border(left: BorderSide(color: color, width: width));
  }

  /// 右侧边框
  static Border right(Color color, {double width = 1.0}) {
    return Border(right: BorderSide(color: color, width: width));
  }

  /// 阴影边框效果
  static Border shadow = Border.all(
    color: Colors.black.withOpacity(0.1),
    width: 0.5,
  );

  /// 分割线边框
  static Border divider(Color color) {
    return Border(
      bottom: BorderSide(
        color: color,
        width: 0.5,
      ),
    );
  }
}