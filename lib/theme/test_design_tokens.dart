import 'package:flutter/material.dart';
import 'design_tokens/design_tokens.dart';

/// Design Token 简化验证测试
class DesignTokenTest {
  static void runTests() {
    print('=== 开始 Design Token 验证 ===\n');

    // 验证颜色系统
    _testColors();

    // 验证文字系统
    _testTypography();

    // 验证间距系统
    _testSpacing();

    // 验证圆角系统
    _testBorders();

    // 验证阴影系统
    _testShadows();

    // 验证渐变系统
    _testGradients();

    print('=== Design Token 验证完成 ===\n');
  }

  static void _testColors() {
    print('🎨 测试颜色系统...');
    try {
      assert(AppColors.background.value == 0xFF0A0A0A);
      assert(AppColors.surface.value == 0xFF1C1C1E);
      assert(AppColors.primary.value == 0xFF0A7AFF);
      assert(AppColors.secondary.value == 0xFFFF9500);
      print('   ✅ 颜色系统测试通过\n');
    } catch (e) {
      print('   ❌ 颜色系统测试失败: $e\n');
    }
  }

  static void _testTypography() {
    print('📝 测试文字系统...');
    try {
      assert(AppTextStyles.displayLarge.fontSize == 32);
      assert(AppTextStyles.headlineLarge.fontSize == 22);
      assert(AppTextStyles.bodyLarge.fontSize == 16);
      assert(AppTextStyles.labelSmall.fontSize == 11);
      assert(AppTextStyles.displayLarge.fontWeight == FontWeight.bold);
      print('   ✅ 文字系统测试通过\n');
    } catch (e) {
      print('   ❌ 文字系统测试失败: $e\n');
    }
  }

  static void _testSpacing() {
    print('📏 测试间距系统...');
    try {
      assert(AppSpacing.micro == 4.0);
      assert(AppSpacing.small == 8.0);
      assert(AppSpacing.medium == 12.0);
      assert(AppSpacing.standard == 16.0);
      assert(AppSpacing.large == 24.0);
      print('   ✅ 间距系统测试通过\n');
    } catch (e) {
      print('   ❌ 间距系统测试失败: $e\n');
    }
  }

  static void _testBorders() {
    print('🔲 测试圆角系统...');
    try {
      assert(AppRadius.small == 4.0);
      assert(AppRadius.medium == 8.0);
      assert(AppRadius.large == 12.0);
      assert(AppRadius.xLarge == 16.0);
      assert(AppRadius.circular == 100.0);
      print('   ✅ 圆角系统测试通过\n');
    } catch (e) {
      print('   ❌ 圆角系统测试失败: $e\n');
    }
  }

  static void _testShadows() {
    print('🌑 测试阴影系统...');
    try {
      assert(AppShadows.cardDefault.isNotEmpty);
      assert(AppShadows.cardHover.isNotEmpty);
      assert(AppShadows.cardHover.length >= AppShadows.cardDefault.length);
      print('   ✅ 阴影系统测试通过\n');
    } catch (e) {
      print('   ❌ 阴影系统测试失败: $e\n');
    }
  }

  static void _testGradients() {
    print('🌈 测试渐变系统...');
    try {
      assert(AppGradients.videoCardBottom.colors.length == 2);
      assert(AppGradients.primaryButton.colors.length == 2);
      assert(AppGradients.shimmerLoading.colors.length == 3);
      assert(AppGradients.shimmerLoading.stops?.length == 3);
      print('   ✅ 渐变系统测试通过\n');
    } catch (e) {
      print('   ❌ 渐变系统测试失败: $e\n');
    }
  }
}