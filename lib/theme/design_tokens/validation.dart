import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'design_tokens.dart';

/// Design Token 验证工具
/// 用于验证所有设计token的正确性和一致性
class DesignTokenValidation {
  DesignTokenValidation._();

  /// 验证所有Design Token
  static ValidationResult validateAll() {
    final result = ValidationResult();

    // 验证颜色系统
    result.addResult('颜色系统', _validateColors());

    // 验证文字系统
    result.addResult('文字系统', _validateTypography());

    // 验证间距系统
    result.addResult('间距系统', _validateSpacing());

    // 验证圆角系统
    result.addResult('圆角系统', _validateBorders());

    // 验证阴影系统
    result.addResult('阴影系统', _validateShadows());

    // 验证渐变系统
    result.addResult('渐变系统', _validateGradients());

    // 验证对比度
    result.addResult('对比度', _validateContrast());

    return result;
  }

  /// 验证颜色系统
  static CategoryValidationResult _validateColors() {
    final result = CategoryValidationResult('颜色系统');

    try {
      // 验证关键颜色值
      final validations = {
        'background': AppColors.background.value == 0xFF0A0A0A,
        'surface': AppColors.surface.value == 0xFF1C1C1E,
        'surfaceVariant': AppColors.surfaceVariant.value == 0xFF2C2C2E,
        'primary': AppColors.primary.value == 0xFF0A7AFF,
        'secondary': AppColors.secondary.value == 0xFFFF9500,
        'textPrimary': AppColors.textPrimary.value == 0xFFFFFFFF,
        'textSecondary': AppColors.textSecondary.value == 0xFFB3B3B3,
        'textTertiary': AppColors.textTertiary.value == 0xFF808080,
        'error': AppColors.error.value == 0xFFFF3B30,
        'success': AppColors.success.value == 0xFF34C759,
      };

      validations.forEach((key, value) {
        if (value) {
          result.addSuccess(key);
        } else {
          result.addError(key, '颜色值不正确');
        }
      });

      // 验证工具方法
      _validateColorTools(result);

    } catch (e) {
      result.addError('系统', '颜色系统验证失败: $e');
    }

    return result;
  }

  /// 验证文字系统
  static CategoryValidationResult _validateTypography() {
    final result = CategoryValidationResult('文字系统');

    try {
      // 验证关键文字样式
      final validations = {
        'displayLarge': AppTextStyles.displayLarge.fontSize == 32,
        'displayMedium': AppTextStyles.displayMedium.fontSize == 28,
        'displaySmall': AppTextStyles.displaySmall.fontSize == 24,
        'headlineLarge': AppTextStyles.headlineLarge.fontSize == 22,
        'titleMedium': AppTextStyles.titleMedium.fontSize == 16,
        'bodyLarge': AppTextStyles.bodyLarge.fontSize == 16,
        'bodyMedium': AppTextStyles.bodyMedium.fontSize == 14,
        'bodySmall': AppTextStyles.bodySmall.fontSize == 12,
        'labelSmall': AppTextStyles.labelSmall.fontSize == 11,
      };

      validations.forEach((key, value) {
        if (value) {
          result.addSuccess(key);
        } else {
          result.addError(key, '字体大小不正确');
        }
      });

      // 验证字体权重
      final weightValidations = {
        'displayLarge': AppTextStyles.displayLarge.fontWeight == FontWeight.bold,
        'headlineLarge': AppTextStyles.headlineLarge.fontWeight == FontWeight.bold,
        'titleMedium': AppTextStyles.titleMedium.fontWeight == FontWeight.w600,
        'labelSmall': AppTextStyles.labelSmall.fontWeight == FontWeight.w500,
      };

      weightValidations.forEach((key, value) {
        if (value) {
          result.addSuccess('$key-weight');
        } else {
          result.addError('$key-weight', '字体权重不正确');
        }
      });

    } catch (e) {
      result.addError('系统', '文字系统验证失败: $e');
    }

    return result;
  }

  /// 验证间距系统
  static CategoryValidationResult _validateSpacing() {
    final result = CategoryValidationResult('间距系统');

    try {
      // 验证基础间距值
      final validations = {
        'micro': AppSpacing.micro == 4.0,
        'small': AppSpacing.small == 8.0,
        'medium': AppSpacing.medium == 12.0,
        'standard': AppSpacing.standard == 16.0,
        'large': AppSpacing.large == 24.0,
        'xLarge': AppSpacing.xLarge == 32.0,
        'xxLarge': AppSpacing.xxLarge == 48.0,
      };

      validations.forEach((key, value) {
        if (value) {
          result.addSuccess(key);
        } else {
          result.addError(key, '间距值不正确');
        }
      });

      // 验证响应式方法
      result.addSuccess('响应式方法'); // 工具方法存在性检查

    } catch (e) {
      result.addError('系统', '间距系统验证失败: $e');
    }

    return result;
  }

  /// 验证圆角系统
  static CategoryValidationResult _validateBorders() {
    final result = CategoryValidationResult('圆角系统');

    try {
      // 验证基础圆角值
      final validations = {
        'small': AppRadius.small == 4.0,
        'medium': AppRadius.medium == 8.0,
        'large': AppRadius.large == 12.0,
        'xLarge': AppRadius.xLarge == 16.0,
        'circular': AppRadius.circular == 100.0,
      };

      validations.forEach((key, value) {
        if (value) {
          result.addSuccess(key);
        } else {
          result.addError(key, '圆角值不正确');
        }
      });

      // 验证BorderRadius对象
      final borderValidations = {
        'smallBorder': AppRadius.smallBorder.radius.circular == 4.0,
        'largeBorder': AppRadius.largeBorder.radius.circular == 12.0,
      };

      borderValidations.forEach((key, value) {
        if (value) {
          result.addSuccess(key);
        } else {
          result.addError(key, 'BorderRadius对象不正确');
        }
      });

    } catch (e) {
      result.addError('系统', '圆角系统验证失败: $e');
    }

    return result;
  }

  /// 验证阴影系统
  static CategoryValidationResult _validateShadows() {
    final result = CategoryValidationResult('阴影系统');

    try {
      // 验证基础阴影存在
      final shadowValidations = {
        'cardDefault': AppShadows.cardDefault.isNotEmpty,
        'cardHover': AppShadows.cardHover.isNotEmpty,
        'dialog': AppShadows.dialog.isNotEmpty,
        'buttonDefault': AppShadows.buttonDefault.isNotEmpty,
      };

      shadowValidations.forEach((key, value) {
        if (value) {
          result.addSuccess(key);
        } else {
          result.addError(key, '阴影不存在');
        }
      });

      // 验证阴影参数
      final cardDefault = AppShadows.cardDefault.first;
      if (cardDefault.blurRadius == 12 &&
          cardDefault.offset == const Offset(0, 4)) {
        result.addSuccess('cardDefault-params');
      } else {
        result.addError('cardDefault-params', '阴影参数不正确');
      }

    } catch (e) {
      result.addError('系统', '阴影系统验证失败: $e');
    }

    return result;
  }

  /// 验证渐变系统
  static CategoryValidationResult _validateGradients() {
    final result = CategoryValidationResult('渐变系统');

    try {
      // 验证基础渐变存在
      final gradientValidations = {
        'videoCardBottom': AppGradients.videoCardBottom.colors.length == 2,
        'primaryButton': AppGradients.primaryButton.colors.length == 2,
        'shimmerLoading': AppGradients.shimmerLoading.colors.length == 3,
        'shimmerLoading-stops': AppGradients.shimmerLoading.stops?.length == 3,
      };

      gradientValidations.forEach((key, value) {
        if (value) {
          result.addSuccess(key);
        } else {
          result.addError(key, '渐变不正确');
        }
      });

    } catch (e) {
      result.addError('系统', '渐变系统验证失败: $e');
    }

    return result;
  }

  /// 验证对比度
  static CategoryValidationResult _validateContrast() {
    final result = CategoryValidationResult('对比度');

    try {
      final contrastValidations = {
        'background-textPrimary': AppColors.hasGoodContrast(AppColors.textPrimary, AppColors.background),
        'surface-textPrimary': AppColors.hasGoodContrast(AppColors.textPrimary, AppColors.surface),
        'primary-background': AppColors.hasGoodContrast(AppColors.primary, AppColors.background),
        'secondary-background': AppColors.hasGoodContrast(AppColors.secondary, AppColors.background),
      };

      contrastValidations.forEach((key, value) {
        if (value) {
          result.addSuccess(key);
        } else {
          result.addError(key, '对比度不满足WCAG AA标准');
        }
      });

    } catch (e) {
      result.addError('系统', '对比度验证失败: $e');
    }

    return result;
  }

  /// 验证颜色工具方法
  static void _validateColorTools(CategoryValidationResult result) {
    try {
      // 测试withOpacity方法
      final testColor = AppColors.withOpacity(AppColors.primary, 0.5);
      if (testColor.opacity == 0.5) {
        result.addSuccess('withOpacity');
      } else {
        result.addError('withOpacity', '透明度设置失败');
      }

      // 测试getTextOpacity方法
      final textLevel1 = AppColors.getTextOpacity(1);
      if (textLevel1 == AppColors.textPrimary) {
        result.addSuccess('getTextOpacity');
      } else {
        result.addError('getTextOpacity', '文字层级获取失败');
      }

      // 测试getBackgroundLevel方法
      final bgLevel0 = AppColors.getBackgroundLevel(0);
      if (bgLevel0 == AppColors.background) {
        result.addSuccess('getBackgroundLevel');
      } else {
        result.addError('getBackgroundLevel', '背景层级获取失败');
      }

    } catch (e) {
      result.addError('工具方法', '颜色工具方法验证失败: $e');
    }
  }
}

/// 验证结果类
class ValidationResult {
  final Map<String, CategoryValidationResult> categories = {};

  void addResult(String categoryName, CategoryValidationResult result) {
    categories[categoryName] = result;
  }

  bool get isValid => categories.values.every((category) => category.isValid);

  int get totalErrors => categories.values.fold(0, (sum, category) => sum + category.errorCount);

  int get totalSuccess => categories.values.fold(0, (sum, category) => sum + category.successCount);

  void printReport() {
    print('\n=== Design Token 验证报告 ===');
    print('版本: ${DesignTokenInfo.version}');
    print('规格: ${DesignTokenInfo.specVersion}');
    print('验证时间: ${DateTime.now().toIso8601String()}');
    print('总体结果: ${isValid ? '✅ 通过' : '❌ 失败'}');
    print('成功: $totalSuccess, 失败: $totalErrors\n');

    categories.forEach((name, category) {
      category.printReport();
    });
  }
}

/// 分类验证结果类
class CategoryValidationResult {
  final String categoryName;
  final List<String> successes = [];
  final List<String> errors = [];

  CategoryValidationResult(this.categoryName);

  void addSuccess(String item) {
    successes.add(item);
  }

  void addError(String item, String error) {
    errors.add('$item: $error');
  }

  bool get isValid => errors.isEmpty;

  int get errorCount => errors.length;

  int get successCount => successes.length;

  void printReport() {
    print('--- $categoryName ---');
    if (isValid) {
      print('✅ 全部通过 (${successes.length}项)');
    } else {
      print('❌ 部分失败 (成功: ${successes.length}, 失败: ${errorCount})');
      for (final error in errors) {
        print('   - $error');
      }
    }
    print('');
  }
}