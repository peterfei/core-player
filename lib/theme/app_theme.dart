import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_tokens/colors.dart';
import 'design_tokens/typography.dart';
import 'design_tokens/spacing.dart';
import 'design_tokens/borders.dart';
import 'design_tokens/shadows.dart';
import 'design_tokens/gradients.dart';

/// 应用主题系统 - 现代化深色主题配置
/// 参考openspec/changes/modernize-ui-design规格
class AppTheme {
  AppTheme._();

  /// 获取深色主题
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      useMaterial3: true,
      brightness: Brightness.dark,

      // ================== 颜色方案 ==================
      colorScheme: ColorScheme.dark(
        brightness: Brightness.dark,
        // 背景色
        background: AppColors.background,
        surface: AppColors.surface,
        surfaceVariant: AppColors.surfaceVariant,
        surfaceTint: Colors.transparent,

        // 强调色
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryContainer,
        secondary: AppColors.secondary,
        secondaryContainer: AppColors.secondaryContainer,

        // 文字色
        onBackground: AppColors.textPrimary,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,

        // 功能色
        error: AppColors.error,
        onError: Colors.white,
        outline: AppColors.divider,
        outlineVariant: AppColors.divider,

        // 其他
        inverseSurface: AppColors.textPrimary,
        onInverseSurface: AppColors.background,
        inversePrimary: AppColors.secondary,
      ),

      // ================== 文字主题 ==================
      textTheme: AppTextTheme.darkTextTheme,

      // ================== 卡片主题 ==================
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: Colors.black,
        margin: EdgeInsets.all(0),
        clipBehavior: Clip.antiAlias,
      ),

      // ================== AppBar主题 ==================
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpacing.large,
        titleTextStyle: AppTextStyles.headlineLarge,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.textPrimary,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: AppColors.textPrimary,
          size: 24,
        ),
      ),

      // ================== 按钮主题 ==================
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonBorder,
          ),
          padding: AppSpacing.buttonPadding,
          textStyle: AppTextStyles.buttonText,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonBorder,
          ),
          padding: AppSpacing.buttonPadding,
          textStyle: AppTextStyles.buttonText,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonBorder,
          ),
          padding: AppSpacing.buttonPadding,
          textStyle: AppTextStyles.buttonText,
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: CircleBorder(),
      ),

      // ================== 输入框主题 ==================
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mediumBorder,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumBorder,
          borderSide: BorderSide(
            color: AppColors.divider,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumBorder,
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumBorder,
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumBorder,
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2,
          ),
        ),
        contentPadding: AppSpacing.inputPadding,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
        labelStyle: AppTextStyles.labelMedium,
        errorStyle: AppTextStyles.bodySmall.copyWith(
          color: AppColors.error,
        ),
      ),

      // ================== 列表瓦片主题 ==================
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: AppColors.surfaceVariant,
        iconColor: AppColors.textSecondary,
        selectedColor: AppColors.primary,
        textColor: AppColors.textPrimary,
        contentPadding: AppSpacing.listItemPadding,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mediumBorder,
        ),
        titleTextStyle: AppTextStyles.titleMedium,
        subtitleTextStyle: AppTextStyles.bodyMedium,
        leadingAndTrailingTextStyle: AppTextStyles.labelMedium,
      ),

      // ================== 对话框主题 ==================
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 16,
        shadowColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.dialogBorder,
        ),
        titleTextStyle: AppTextStyles.titleLarge,
        contentTextStyle: AppTextStyles.bodyMedium,
        actionsPadding: const EdgeInsets.all(AppSpacing.large),
        alignment: Alignment.center,
      ),

      // ================== 底部弹窗主题 ==================
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        elevation: 16,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppRadius.xLarge),
            topRight: Radius.circular(AppRadius.xLarge),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        modalBackgroundColor: AppColors.surface,
        modalElevation: 16,
        showDragHandle: true,
        dragHandleColor: AppColors.divider,
        dragHandleSize: const Size(40, 4),
      ),

      // ================== 分隔线主题 ==================
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
        indent: 0,
        endIndent: 0,
      ),

      // ================== 图标主题 ==================
      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: 24,
        fill: 0,
        weight: 400,
        grade: 0,
        opticalSize: 24,
      ),

      // ================== Chip主题 ==================
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        brightness: Brightness.dark,
        labelStyle: AppTextStyles.labelMedium,
        secondaryLabelStyle: AppTextStyles.labelMedium.copyWith(
          color: AppColors.textPrimary,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: AppSpacing.small,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mediumBorder,
        ),
      ),

      // ================== Tab主题 ==================
      tabBarTheme: TabBarThemeData(
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppColors.primary,
        labelStyle: AppTextStyles.labelLarge,
        unselectedLabelColor: AppColors.textTertiary,
        unselectedLabelStyle: AppTextStyles.labelLarge,
        dividerColor: AppColors.divider,
        splashFactory: InkRipple.splashFactory,
      ),

      // ================== 滑块主题 ==================
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.surfaceVariant,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withOpacity(0.2),
        valueIndicatorColor: AppColors.primary,
        valueIndicatorTextStyle: AppTextStyles.labelMedium.copyWith(
          color: Colors.white,
        ),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
        rangeTickMarkShape: const RoundRangeSliderTickMarkShape(),
      ),

      // ================== 进度条主题 ==================
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceVariant,
        circularTrackColor: AppColors.surfaceVariant,
        linearMinHeight: 4,
        refreshBackgroundColor: AppColors.surface,
      ),

      // ================== 开关主题 ==================
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.primary;
          }
          return AppColors.textTertiary;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.primary.withOpacity(0.5);
          }
          return AppColors.textTertiary.withOpacity(0.3);
        }),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),

      // ================== 复选框主题 ==================
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.primary;
          }
          return Colors.transparent;
        }),
        checkColor: MaterialStateProperty.all(Colors.white),
        overlayColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.hovered)) {
            return AppColors.primary.withOpacity(0.2);
          }
          if (states.contains(MaterialState.focused)) {
            return AppColors.primary.withOpacity(0.1);
          }
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.smallBorder,
        ),
        side: const BorderSide(
          color: AppColors.textTertiary,
          width: 2,
        ),
      ),

      // ================== 单选框主题 ==================
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.primary;
          }
          return AppColors.textTertiary;
        }),
        overlayColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.hovered)) {
            return AppColors.primary.withOpacity(0.2);
          }
          if (states.contains(MaterialState.focused)) {
            return AppColors.primary.withOpacity(0.1);
          }
          return Colors.transparent;
        }),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),

      // ================== 工具提示主题 ==================
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.badgeBackground,
          borderRadius: AppRadius.smallBorder,
        ),
        textStyle: AppTextStyles.bodySmall.copyWith(
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: AppSpacing.small,
        ),
        margin: const EdgeInsets.all(AppSpacing.small),
        preferBelow: true,
        verticalOffset: 24,
        waitDuration: const Duration(milliseconds: 500),
        showDuration: const Duration(milliseconds: 1500),
      ),

      // ================== 横幅主题 ==================
      bannerTheme: MaterialBannerThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: AppTextStyles.bodyMedium,
        padding: const EdgeInsets.all(AppSpacing.medium),
        leadingPadding: const EdgeInsets.only(
          left: AppSpacing.medium,
          right: AppSpacing.small,
        ),
      ),

      // ================== SnackBar主题 ==================
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceVariant,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
        ),
        actionTextColor: AppColors.primary,
        elevation: 6,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppRadius.medium),
            topRight: Radius.circular(AppRadius.medium),
          ),
        ),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(AppSpacing.medium),
      ),

      // ================== 页面过渡主题 ==================
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

    /// 赛博霓虹主题 (深色)
    static ThemeData get neonCyberTheme {
      return ThemeData.dark().copyWith(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF), // Cyan Neon
          secondary: Color(0xFFFF4081), // Pink Neon
          background: Color(0xFF121212),
          surface: Color(0xFF1E1E1E),
          onBackground: Colors.white,
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          foregroundColor: Color(0xFF00E5FF),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF2C2C2C),
          elevation: 4,
          shadowColor: Color(0xFF00E5FF),
        ),
      );
    }
  
    /// 北欧极简主题 (浅色)
    static ThemeData get nordicLightTheme {
      return ThemeData.light().copyWith(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF455A64), // Slate Grey
          secondary: Color(0xFF90A4AE), // Light Blue Grey
          background: Color(0xFFF5F7FA), // Very Light Grey
          surface: Colors.white,
          onBackground: Color(0xFF263238),
          onSurface: Color(0xFF263238),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF455A64),
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 1,
          shadowColor: Color(0xFFCFD8DC),
        ),
      );
    }
  
    /// 获取轻量主题 (用于测试)
    static ThemeData get lightTheme {
    return ThemeData.light().copyWith(
      useMaterial3: true,
      // 这里可以定义轻量主题，如果需要的话
    );
  }

  /// 获取自定义主题
  static ThemeData customTheme({
    Color? primaryColor,
    Color? backgroundColor,
    Color? surfaceColor,
  }) {
    return darkTheme.copyWith(
      colorScheme: darkTheme.colorScheme.copyWith(
        primary: primaryColor,
        background: backgroundColor,
        surface: surfaceColor,
      ),
    );
  }

  /// 根据设备类型调整主题
  static ThemeData getResponsiveTheme(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width >= 1200) {
      // 桌面端主题
      return darkTheme.copyWith(
        textTheme: darkTheme.textTheme.copyWith(
          displayLarge: darkTheme.textTheme.displayLarge?.copyWith(fontSize: 36),
          headlineLarge: darkTheme.textTheme.headlineLarge?.copyWith(fontSize: 26),
        ),
      );
    } else if (width >= 800) {
      // 平板主题
      return darkTheme;
    } else {
      // 移动端主题
      return darkTheme.copyWith(
        textTheme: darkTheme.textTheme.copyWith(
          displayLarge: darkTheme.textTheme.displayLarge?.copyWith(fontSize: 28),
          headlineLarge: darkTheme.textTheme.headlineLarge?.copyWith(fontSize: 20),
        ),
      );
    }
  }

  /// 应用主题到Widget
  static Widget withTheme({
    required Widget child,
    ThemeData? theme,
    bool? useMaterial3,
  }) {
    return Theme(
      data: theme ?? darkTheme,
      child: child,
    );
  }
}