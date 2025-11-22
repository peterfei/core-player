import 'package:flutter/material.dart';
import 'dart:math';

/// 应用颜色系统 - 基于现代化深色主题设计
/// 参考openspec/changes/modernize-ui-design规格
class AppColors {
  AppColors._();

  // ================== 背景色系统 ==================
  /// 真正的暗黑背景 - Level 0 (最深)
  static const Color background = Color(0xFF0A0A0A);

  /// 卡片表面 - Level 1
  static const Color surface = Color(0xFF1C1C1E);

  /// 高亮表面 - Level 2 (选中状态、悬停状态)
  static const Color surfaceVariant = Color(0xFF2C2C2E);

  // ================== 强调色系统 ==================
  /// 主色调蓝
  static const Color primary = Color(0xFF0A7AFF);

  /// 主色容器
  static const Color primaryContainer = Color(0xFF1A3A5F);

  /// 辅助色橙
  static const Color secondary = Color(0xFFFF9500);

  /// 辅助色容器
  static const Color secondaryContainer = Color(0xFF5F3A00);

  // ================== 文字色系统 ==================
  /// 主要文字 - 100%白色
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// 次要文字 - 70%白色
  static const Color textSecondary = Color(0xFFB3B3B3);

  /// 辅助文字 - 50%白色
  static const Color textTertiary = Color(0xFF808080);

  /// 禁用文字 - 30%白色
  static const Color textDisabled = Color(0xFF4D4D4D);

  // ================== 功能色系统 ==================
  /// 成功色 - 完成、成功状态
  static const Color success = Color(0xFF34C759);

  /// 警告色 - 警告、注意状态
  static const Color warning = Color(0xFFFF9500);

  /// 错误色 - 错误、删除状态
  static const Color error = Color(0xFFFF3B30);

  /// 信息色 - 信息提示
  static const Color info = Color(0xFF0A7AFF);

  // ================== 半透明叠加层 ==================
  /// 轻微叠加 - 10%白色
  static const Color overlayLight = Color(0x1AFFFFFF);

  /// 中等叠加 - 20%白色
  static const Color overlayMedium = Color(0x33FFFFFF);

  /// 重度叠加 - 30%白色
  static const Color overlayHeavy = Color(0x4DFFFFFF);

  /// 黑色叠加 - 70%黑色 (用于卡片标题渐变)
  static const Color overlayBlack = Color(0xB3000000);

  // ================== 分隔线 ==================
  /// 分隔线颜色 - 10%白色
  static const Color divider = Color(0x1AFFFFFF);

  // ================== 特殊用途色 ==================
  /// 徽章背景 - 80%黑色半透明
  static const Color badgeBackground = Color(0xCC000000);

  /// 侧边栏选中背景
  static const Color sidebarSelected = Color(0xFF2C2C2E);

  /// 侧边栏悬停背景
  static const Color sidebarHover = Color(0x1AFFFFFF);

  // ================== 状态色 ==================
  /// 播放状态 - 绿色
  static const Color playing = Color(0xFF34C759);

  /// 暂停状态 - 橙色
  static const Color paused = Color(0xFFFF9500);

  /// 缓存中状态 - 蓝色
  static const Color caching = Color(0xFF0A7AFF);

  /// 已缓存状态 - 深绿色
  static const Color cached = Color(0xFF30D158);

  // ================== 视频类型色 ==================
  /// 本地视频标识色
  static const Color localVideo = Color(0xFF34C759);

  /// 网络视频标识色
  static const Color networkVideo = Color(0xFF0A7AFF);

  /// 4K分辨率标识色
  static const Color resolution4K = Color(0xFFFF9500);

  /// HDR标识色
  static const Color hdr = Color(0xFFAF52DE);

  // ================== Material 3 适配色 ==================
  /// Material 3 兼容的主色调
  static const Color materialPrimary = Color(0xFF0A7AFF);

  /// Material 3 兼容的表面色
  static const Color materialSurface = Color(0xFF1C1C1E);

  /// Material 3 兼容的背景色
  static const Color materialBackground = Color(0xFF0A0A0A);

  // ================== 渐变色 ==================
  /// 卡片底部渐变起始色 (透明)
  static const Color cardGradientStart = Color(0x00000000);

  /// 卡片底部渐变结束色 (70%黑色)
  static const Color cardGradientEnd = Color(0xB3000000);

  // ================== 工具方法 ==================
  /// 获取带透明度的颜色
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }

  /// 获取文字色层级
  static Color getTextOpacity(int level) {
    switch (level) {
      case 1: // 主要文字
        return textPrimary;
      case 2: // 次要文字
        return textSecondary;
      case 3: // 辅助文字
        return textTertiary;
      case 4: // 禁用文字
        return textDisabled;
      default:
        return textPrimary;
    }
  }

  /// 获取背景色层级
  static Color getBackgroundLevel(int level) {
    switch (level) {
      case 0: // 最深背景
        return background;
      case 1: // 表面背景
        return surface;
      case 2: // 高亮背景
        return surfaceVariant;
      default:
        return background;
    }
  }

  /// 验证颜色对比度是否符合WCAG标准
  static bool hasGoodContrast(Color foreground, Color background) {
    // 计算相对亮度对比度
    double fgLuminance = _calculateLuminance(foreground);
    double bgLuminance = _calculateLuminance(background);

    double contrast = (fgLuminance + 0.05) / (bgLuminance + 0.05);
    if (bgLuminance > fgLuminance) {
      contrast = (bgLuminance + 0.05) / (fgLuminance + 0.05);
    }

    // WCAG AA标准要求至少4.5:1
    return contrast >= 4.5;
  }

  /// 计算颜色亮度
  static double _calculateLuminance(Color color) {
    double r = _correctGamma(color.red / 255.0);
    double g = _correctGamma(color.green / 255.0);
    double b = _correctGamma(color.blue / 255.0);

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// 伽马校正
  static double _correctGamma(double channel) {
    if (channel <= 0.03928) {
      return channel / 12.92;
    } else {
      return pow((channel + 0.055) / 1.055, 2.4).toDouble();
    }
  }
}