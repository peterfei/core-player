/// 动画Design Tokens
/// 定义CorePlayer应用中所有动画的标准参数
/// 基于openspec/changes/modernize-ui-design规格

import 'package:flutter/material.dart';

/// 动画持续时间
class AppDurations {
  AppDurations._();

  // 基础持续时间 (毫秒)
  static const int instant = 0;
  static const int fast = 150;
  static const int normal = 250;
  static const int slow = 350;
  static const int slower = 500;

  // 具体动画持续时间
  static const Duration hoverDuration = Duration(milliseconds: normal);
  static const Duration clickDuration = Duration(milliseconds: fast);
  static const Duration pageTransitionDuration = Duration(milliseconds: 300);
  static const Duration fadeInDuration = Duration(milliseconds: normal);
  static const Duration slideDuration = Duration(milliseconds: slow);
  static const Duration shimmerDuration = Duration(milliseconds: 1500);
  static const Duration pulseDuration = Duration(milliseconds: 1000);
  static const Duration bounceDuration = Duration(milliseconds: 600);
  static const Duration rippleDuration = Duration(milliseconds: 300);
}

/// 动画曲线
class AppCurves {
  AppCurves._();

  // 标准曲线
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeIn = Curves.easeIn;
  static const Curve linear = Curves.linear;

  // Material Design曲线
  static const Curve standard = Curves.easeInOut;
  static const Curve standardDecelerate = Curves.decelerate;
  static const Curve standardAccelerate = Curves.easeIn;

  // 强调曲线
  static const Curve emphasized = Curves.easeInOutCubic;
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  // 特殊效果曲线
  static const Curve bounce = Curves.elasticOut;
  static const Curve sharp = Cubic(0.4, 0.0, 0.6, 1.0);
  static const Curve smooth = Curves.easeOutCubic;
  static const Curve entry = Cubic(0.0, 0.0, 0.2, 1.0);
  static const Curve exit = Cubic(0.4, 0.0, 1.0, 1.0);
}

/// 动画阈值和触发条件
class AnimationThresholds {
  AnimationThresholds._();

  // 悬停检测
  static const Duration hoverDelay = Duration(milliseconds: 100);
  static const Duration hoverReverseDelay = Duration(milliseconds: 50);

  // 点击检测
  static const Duration clickTimeout = Duration(milliseconds: 200);
  static const Duration doubleClickTimeout = Duration(milliseconds: 300);

  // 长按检测
  static const Duration longPressTimeout = Duration(milliseconds: 500);

  // 滚动检测
  static const double scrollVelocityThreshold = 100.0;
  static const Duration scrollSettleDuration = Duration(milliseconds: 300);
}

/// 动画参数范围
class AnimationRanges {
  AnimationRanges._();

  // 缩放范围
  static const double scaleMin = 0.8;
  static const double scaleNormal = 1.0;
  static const double scaleHoverMax = 1.05;
  static const double scalePressMin = 0.95;
  static const double scaleBounceMax = 1.1;

  // 透明度范围
  static const double opacityHidden = 0.0;
  static const double opacityMin = 0.3;
  static const double opacityNormal = 1.0;
  static const double opacityDisabled = 0.38;
  static const double opacityHover = 0.8;
  static const double opacityPressed = 0.6;

  // 位移范围 (像素)
  static const double slideSmall = 4.0;
  static const double slideMedium = 8.0;
  static const double slideLarge = 16.0;
  static const double slideXLarge = 32.0;
  static const double slidePage = 100.0;

  // 旋转范围
  static const double rotationSmall = 0.05; // 弧度
  static const double rotationMedium = 0.1;
  static const double rotationLarge = 0.2;

  // 模糊范围
  static const double blurNone = 0.0;
  static const double blurSmall = 2.0;
  static const double blurMedium = 4.0;
  static const double blurLarge = 8.0;
}

/// 页面过渡动画参数
class PageTransitions {
  PageTransitions._();

  // 淡入淡出
  static const Duration fadeDuration = AppDurations.pageTransitionDuration;
  static const Curve fadeCurve = AppCurves.emphasizedDecelerate;

  // 滑动效果
  static const Duration slideDuration = AppDurations.pageTransitionDuration;
  static const Curve slideCurve = AppCurves.emphasizedDecelerate;
  static const double slideOffset = 0.05; // 5% of screen size

  // 缩放效果
  static const Duration scaleDuration = AppDurations.pageTransitionDuration;
  static const Curve scaleCurve = AppCurves.emphasizedDecelerate;
  static const double scaleStart = 0.95;

  // 组合过渡
  static const Duration combinedDuration = AppDurations.pageTransitionDuration;
  static const Curve combinedCurve = AppCurves.emphasizedDecelerate;
}

/// 微交互动画参数
class MicroInteractions {
  MicroInteractions._();

  // 按钮悬停
  static const Duration buttonHoverDuration = AppDurations.hoverDuration;
  static const Curve buttonHoverCurve = AppCurves.smooth;
  static const double buttonHoverScale = 1.05;
  static const double buttonPressScale = 0.95;

  // 卡片悬停
  static const Duration cardHoverDuration = AppDurations.hoverDuration;
  static const Curve cardHoverCurve = AppCurves.smooth;
  static const double cardHoverScale = 1.02;
  static const double cardHoverElevation = 8.0;
  static const double cardPressScale = 0.98;

  // 列表项悬停
  static const Duration listItemHoverDuration = Duration(milliseconds: AppDurations.fast);
  static const Curve listItemHoverCurve = AppCurves.standard;
  static const double listItemHoverScale = 1.01;
  
  // 图标动画
  static const Duration iconAnimationDuration = Duration(milliseconds: AppDurations.normal);
  static const Curve iconAnimationCurve = AppCurves.bounce;
  
  // 开关动画
  static const Duration toggleDuration = Duration(milliseconds: AppDurations.normal);
  static const Curve toggleCurve = AppCurves.sharp;
}

/// 加载动画参数
class LoadingAnimations {
  LoadingAnimations._();

  // Shimmer效果
  static const Duration shimmerDuration = AppDurations.shimmerDuration;
  static const Duration shimmerDelay = Duration(milliseconds: 500);
  static const Curve shimmerCurve = Curves.linear;
  static const double shimmerStartX = -1.0;
  static const double shimmerEndX = 2.0;
  static const double shimmerGradientWidth = 0.5;

  // 脉冲效果
  static const Duration pulseDuration = AppDurations.pulseDuration;
  static const Curve pulseCurve = AppCurves.easeInOut;
  static const double pulseMinOpacity = 0.3;
  static const double pulseMaxOpacity = 1.0;

  // 旋转加载
  static const Duration spinDuration = Duration(milliseconds: 1000);
  static const Curve spinCurve = Curves.linear;
  static const double spinStartAngle = 0.0;
  static const double spinEndAngle = 6.28318; // 2π

  // 弹跳加载
  static const Duration bounceDuration = AppDurations.bounceDuration;
  static const Curve bounceCurve = AppCurves.bounce;
  static const double bounceHeight = 20.0;

  // 骨架屏动画
   static const Duration skeletonDuration = Duration(milliseconds: AppDurations.slower);
  static const Curve skeletonCurve = AppCurves.easeInOut;
  static const double skeletonOpacityMin = 0.1;
  static const double skeletonOpacityMax = 0.3;
}

/// 性能优化参数
class PerformanceOptimizations {
  PerformanceOptimizations._();

  // 动画帧率
  static const int targetFPS = 60;
  static const int maxFPS = 120;
  static const int minFPS = 30;

  // 动画更新频率
  static const Duration animationUpdateInterval = Duration(milliseconds: 16); // ~60fps

  // 内存管理
  static const int maxConcurrentAnimations = 10;
  static const Duration animationCleanupDelay = Duration(milliseconds: 5000);

  // 视图优化
  static const bool enableRepaintBoundary = true;
  static const bool enableCacheDrawing = true;
  static const bool enableOpacityOptimization = true;

  // 滚动优化
  static const Duration scrollThrottle = Duration(milliseconds: 16);
  static const double scrollThreshold = 1.0;
  static const bool enableScrollMomentum = true;
}