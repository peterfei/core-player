import 'package:flutter/material.dart';
import 'colors.dart';

/// 应用阴影系统 - 统一的阴影和深度效果
/// 参考openspec/changes/modernize-ui-design规格
class AppShadows {
  AppShadows._();

  // ================== 基础阴影配置 ==================
  /// 阴影颜色 - 30%透明度黑色
  static Color shadowColorLight = Colors.black.withOpacity(0.3);

  /// 阴影颜色 - 60%透明度黑色
  static Color shadowColorHeavy = Colors.black.withOpacity(0.6);

  /// 阴影颜色 - 20%透明度黑色
  static Color shadowColorSubtle = Colors.black.withOpacity(0.2);

  /// 阴影颜色 - 40%透明度黑色
  static Color shadowColorMedium = Colors.black.withOpacity(0.4);

  /// 阴影颜色 - 50%透明度黑色
  static Color shadowColorDialog = Colors.black.withOpacity(0.5);

  // ================== 卡片阴影系统 ==================
  /// 卡片默认阴影 (未悬停)
  /// 4px偏移，12px模糊，30%不透明度
  static List<BoxShadow> cardDefault = [
    BoxShadow(
      color: shadowColorLight,
      blurRadius: 12,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  /// 卡片悬停阴影
  /// 8px偏移，24px模糊，60%不透明度
  static List<BoxShadow> cardHover = [
    BoxShadow(
      color: shadowColorHeavy,
      blurRadius: 24,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  /// 卡片激活阴影 (点击时)
  /// 2px偏移，8px模糊，40%不透明度
  static List<BoxShadow> cardActive = [
    BoxShadow(
      color: shadowColorMedium,
      blurRadius: 8,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  /// 卡片选中阴影
  /// 6px偏移，16px模糊，50%不透明度
  static List<BoxShadow> cardSelected = [
    BoxShadow(
      color: shadowColorDialog,
      blurRadius: 16,
      offset: const Offset(0, 6),
      spreadRadius: 0,
    ),
  ];

  // ================== 视频卡片阴影 ==================
  /// 视频卡片默认阴影
  static List<BoxShadow> videoCardDefault = [
    BoxShadow(
      color: shadowColorLight,
      blurRadius: 12,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  /// 视频卡片悬停阴影 (更明显)
  static List<BoxShadow> videoCardHover = [
    BoxShadow(
      color: shadowColorHeavy,
      blurRadius: 32,
      offset: const Offset(0, 12),
      spreadRadius: 0,
    ),
    // 添加第二个阴影创造更立体效果
    BoxShadow(
      color: shadowColorMedium,
      blurRadius: 8,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  // ================== 历史记录卡片阴影 ==================
  /// 历史记录卡片默认阴影 (较轻)
  static List<BoxShadow> historyCardDefault = [
    BoxShadow(
      color: shadowColorSubtle,
      blurRadius: 8,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  /// 历史记录卡片悬停阴影
  static List<BoxShadow> historyCardHover = [
    BoxShadow(
      color: shadowColorMedium,
      blurRadius: 16,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  // ================== 导航相关阴影 ==================
  /// 侧边栏阴影
  /// 右侧投影，轻微模糊
  static List<BoxShadow> sidebar = [
    BoxShadow(
      color: shadowColorSubtle,
      blurRadius: 8,
      offset: const Offset(2, 0),
      spreadRadius: 0,
    ),
  ];

  /// AppBar阴影
  static List<BoxShadow> appBar = [
    BoxShadow(
      color: shadowColorSubtle,
      blurRadius: 4,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  /// 底部导航栏阴影
  static List<BoxShadow> bottomNav = [
    BoxShadow(
      color: shadowColorMedium,
      blurRadius: 8,
      offset: const Offset(0, -2),
      spreadRadius: 0,
    ),
  ];

  // ================== 对话框和弹窗阴影 ==================
  /// 对话框阴影
  /// 16px偏移，32px模糊，50%不透明度
  static List<BoxShadow> dialog = [
    BoxShadow(
      color: shadowColorDialog,
      blurRadius: 32,
      offset: const Offset(0, 16),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: shadowColorMedium,
      blurRadius: 8,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  /// 底部弹窗阴影
  static List<BoxShadow> bottomSheet = [
    BoxShadow(
      color: shadowColorHeavy,
      blurRadius: 24,
      offset: const Offset(0, -8),
      spreadRadius: 0,
    ),
  ];

  /// 菜单阴影
  static List<BoxShadow> menu = [
    BoxShadow(
      color: shadowColorMedium,
      blurRadius: 16,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  // ================== 按钮阴影 ==================
  /// 浮动按钮阴影
  static List<BoxShadow> floatingButton = [
    BoxShadow(
      color: shadowColorMedium,
      blurRadius: 16,
      offset: const Offset(0, 6),
      spreadRadius: 0,
    ),
  ];

  /// 按钮默认阴影
  static List<BoxShadow> buttonDefault = [
    BoxShadow(
      color: shadowColorLight,
      blurRadius: 4,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  /// 按钮悬停阴影
  static List<BoxShadow> buttonHover = [
    BoxShadow(
      color: shadowColorMedium,
      blurRadius: 8,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  // ================== 输入框阴影 ==================
  /// 输入框默认阴影
  static List<BoxShadow> inputDefault = [
    BoxShadow(
      color: shadowColorSubtle,
      blurRadius: 4,
      offset: const Offset(0, 1),
      spreadRadius: 0,
    ),
  ];

  /// 输入框聚焦阴影
  static List<BoxShadow> inputFocused = [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.3),
      blurRadius: 8,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  // ================== 特殊效果阴影 ==================
  /// 发光效果 (用于强调色)
  static List<BoxShadow> glow(Color color, {double intensity = 0.6}) {
    return [
      BoxShadow(
        color: color.withOpacity(intensity),
        blurRadius: 20,
        offset: const Offset(0, 0),
        spreadRadius: 2,
      ),
    ];
  }

  /// 内阴影效果 (注: Flutter BoxShadow不支持inset, 使用内部装饰实现)
  static List<BoxShadow> inner = [
    BoxShadow(
      color: shadowColorSubtle,
      blurRadius: 4,
      offset: const Offset(0, 2),
      spreadRadius: -2,
    ),
  ];

  /// 多层阴影 (用于强调层级)
  static List<BoxShadow> elevated = [
    BoxShadow(
      color: shadowColorSubtle,
      blurRadius: 8,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: shadowColorLight,
      blurRadius: 16,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  // ================== 工具方法 ==================
  /// 创建自定义阴影
  static List<BoxShadow> custom({
    Color? color,
    double blurRadius = 8,
    Offset offset = const Offset(0, 4),
    double spreadRadius = 0,
  }) {
    return [
      BoxShadow(
        color: color ?? shadowColorMedium,
        blurRadius: blurRadius,
        offset: offset,
        spreadRadius: spreadRadius,
      ),
    ];
  }

  /// 创建多层阴影
  static List<BoxShadow> multiLayer(List<Map<String, dynamic>> layers) {
    List<BoxShadow> shadows = [];

    for (final layer in layers) {
      shadows.add(BoxShadow(
        color: layer['color'] ?? shadowColorMedium,
        blurRadius: layer['blurRadius'] ?? 8,
        offset: layer['offset'] ?? const Offset(0, 4),
        spreadRadius: layer['spreadRadius'] ?? 0,
      ));
    }

    return shadows;
  }

  /// 根据深度获取阴影
  static List<BoxShadow> getByDepth(ShadowDepth depth) {
    switch (depth) {
      case ShadowDepth.none:
        return [];
      case ShadowDepth.subtle:
        return inputDefault;
      case ShadowDepth.light:
        return buttonDefault;
      case ShadowDepth.medium:
        return cardDefault;
      case ShadowDepth.heavy:
        return dialog;
      case ShadowDepth.elevated:
        return elevated;
    }
  }

  /// 根据组件类型获取阴影
  static List<BoxShadow> getByComponentType(ComponentType type, {bool isHovered = false}) {
    switch (type) {
      case ComponentType.videoCard:
        return isHovered ? videoCardHover : videoCardDefault;
      case ComponentType.historyCard:
        return isHovered ? historyCardHover : historyCardDefault;
      case ComponentType.card:
        return isHovered ? cardHover : cardDefault;
      case ComponentType.dialog:
        return dialog;
      case ComponentType.sidebar:
        return sidebar;
      case ComponentType.button:
        return isHovered ? buttonHover : buttonDefault;
      case ComponentType.floatingButton:
        return floatingButton;
      case ComponentType.input:
        return inputDefault;
      case ComponentType.bottomSheet:
        return bottomSheet;
      default:
        return cardDefault;
    }
  }

  /// 获取响应式阴影
  static List<BoxShadow> getResponsiveShadow({
    required BuildContext context,
    required List<BoxShadow> mobile,
    List<BoxShadow>? tablet,
    List<BoxShadow>? desktop,
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

  /// 检查阴影是否过于复杂 (性能考虑)
  static bool isTooComplex(List<BoxShadow> shadows) {
    return shadows.length > 3;
  }

  /// 优化阴影 (移除冗余阴影)
  static List<BoxShadow> optimize(List<BoxShadow> shadows) {
    if (shadows.length <= 1) return shadows;

    // 简单的优化：合并相似的阴影
    List<BoxShadow> optimized = [shadows.first];

    for (int i = 1; i < shadows.length; i++) {
      final current = shadows[i];
      final last = optimized.last;

      // 如果阴影参数相似，跳过
      if ((current.blurRadius - last.blurRadius).abs() < 2 &&
          (current.offset.dx - last.offset.dx).abs() < 1 &&
          (current.offset.dy - last.offset.dy).abs() < 1) {
        continue;
      }

      optimized.add(current);
    }

    return optimized;
  }
}

/// 阴影深度枚举
enum ShadowDepth {
  none,     // 无阴影
  subtle,   // 轻微阴影
  light,    // 轻阴影
  medium,   // 中等阴影
  heavy,    // 重阴影
  elevated, // 高阴影
}

/// 组件类型枚举 (扩展自borders.dart中的定义)
enum ComponentType {
  videoCard,      // 视频卡片
  historyCard,    // 历史记录卡片
  card,           // 通用卡片
  dialog,         // 对话框
  sidebar,        // 侧边栏
  button,         // 按钮
  floatingButton, // 浮动按钮
  input,          // 输入框
  bottomSheet,    // 底部弹窗
}