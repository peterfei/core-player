/// 页面过渡动画框架
/// 为CorePlayer提供统一的页面转场动画效果
/// 基于openspec/changes/modernize-ui-design规格

import 'package:flutter/material.dart';
import '../theme/design_tokens/design_tokens.dart';

/// 自定义页面转场类型
enum PageTransitionType {
  fade,           // 淡入淡出
  slideFromRight, // 从右滑入
  slideFromLeft,  // 从左滑入
  slideFromTop,   // 从上滑入
  slideFromBottom,// 从下滑入
  scale,          // 缩放
  rotation,       // 旋转
  combined,       // 组合效果
}

/// 页面转场配置
class PageTransitionConfig {
  final PageTransitionType type;
  final Duration duration;
  final Curve curve;
  final bool maintainState;
  final bool fullscreenDialog;
  final double? slideOffset;
  final double? scaleStart;
  final Alignment? alignment;

  const PageTransitionConfig({
    this.type = PageTransitionType.fade,
    this.duration = PageTransitions.fadeDuration,
    this.curve = PageTransitions.fadeCurve,
    this.maintainState = true,
    this.fullscreenDialog = false,
    this.slideOffset,
    this.scaleStart,
    this.alignment,
  });
}

/// 自定义页面转场构建器
class CustomPageTransitionBuilder extends PageTransitionsBuilder {
  final PageTransitionConfig config;

  const CustomPageTransitionBuilder({
    this.config = const PageTransitionConfig(),
  });

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    switch (config.type) {
      case PageTransitionType.fade:
        return _buildFadeTransition(animation, child);
      case PageTransitionType.slideFromRight:
        return _buildSlideTransition(
          animation,
          child,
          Offset(config.slideOffset ?? 0.1, 0),
        );
      case PageTransitionType.slideFromLeft:
        return _buildSlideTransition(
          animation,
          child,
          Offset(-(config.slideOffset ?? 0.1), 0),
        );
      case PageTransitionType.slideFromTop:
        return _buildSlideTransition(
          animation,
          child,
          Offset(0, -(config.slideOffset ?? 0.1)),
        );
      case PageTransitionType.slideFromBottom:
        return _buildSlideTransition(
          animation,
          child,
          Offset(0, config.slideOffset ?? 0.1),
        );
      case PageTransitionType.scale:
        return _buildScaleTransition(animation, child);
      case PageTransitionType.rotation:
        return _buildRotationTransition(animation, child);
      case PageTransitionType.combined:
        return _buildCombinedTransition(animation, secondaryAnimation, child);
    }
  }

  Widget _buildFadeTransition(Animation<double> animation, Widget child) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }

  Widget _buildSlideTransition(
    Animation<double> animation,
    Widget child,
    Offset offset,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: offset,
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: config.curve,
      )),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  Widget _buildScaleTransition(Animation<double> animation, Widget child) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: config.scaleStart ?? 0.9,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: config.curve,
      )),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  Widget _buildRotationTransition(Animation<double> animation, Widget child) {
    return RotationTransition(
      turns: Tween<double>(
        begin: 0.05,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: config.curve,
      )),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  Widget _buildCombinedTransition(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slideOffset = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: config.curve,
    ));

    final scale = Tween<double>(
      begin: config.scaleStart ?? 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: config.curve,
    ));

    final opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: config.curve,
    ));

    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      builder: (context, child) {
        return Transform.translate(
          offset: slideOffset.value,
          child: Transform.scale(
            scale: scale.value,
            child: Opacity(
              opacity: opacity.value,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// 增强的PageRoute
class AnimatedPageRoute<T> extends PageRoute<T> {
  final Widget child;
  final PageTransitionConfig config;

  AnimatedPageRoute({
    required this.child,
    this.config = const PageTransitionConfig(),
    super.settings,
  });

  @override
  bool get maintainState => config.maintainState;

  @override
  bool get fullscreenDialog => config.fullscreenDialog;

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => config.duration;

  @override
  Duration get reverseTransitionDuration => config.duration;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return child;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final builder = CustomPageTransitionBuilder(config: config);
    return builder.buildTransitions<T>(this, context, animation, secondaryAnimation, child);
  }
}

/// 预定义的页面转场
class PageTransitionBuilders {
  PageTransitionBuilders._();

  /// 淡入淡出转场
  static PageRouteBuilder<T> fadeTransition<T>({
    required Widget page,
    Duration? duration,
    Curve? curve,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration ?? PageTransitions.fadeDuration,
      reverseTransitionDuration: duration ?? PageTransitions.fadeDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: curve ?? PageTransitions.fadeCurve,
          ),
          child: child,
        );
      },
    );
  }

  /// 从右滑入转场
  static PageRouteBuilder<T> slideFromRightTransition<T>({
    required Widget page,
    Duration? duration,
    Curve? curve,
    double offset = 0.1,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration ?? PageTransitions.slideDuration,
      reverseTransitionDuration: duration ?? PageTransitions.slideDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(
          begin: Offset(offset, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve ?? PageTransitions.slideCurve,
        ));

        final fade = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(animation);

        return SlideTransition(
          position: slide,
          child: FadeTransition(
            opacity: fade,
            child: child,
          ),
        );
      },
    );
  }

  /// 从下滑入转场（用于模态页面）
  static PageRouteBuilder<T> slideFromBottomTransition<T>({
    required Widget page,
    Duration? duration,
    Curve? curve,
    double offset = 0.1,
    bool fullscreenDialog = true,
  }) {
    return PageRouteBuilder<T>(
      fullscreenDialog: fullscreenDialog,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration ?? PageTransitions.slideDuration,
      reverseTransitionDuration: duration ?? PageTransitions.slideDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(
          begin: Offset(0, offset),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve ?? PageTransitions.slideCurve,
        ));

        final fade = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(animation);

        return SlideTransition(
          position: slide,
          child: FadeTransition(
            opacity: fade,
            child: child,
          ),
        );
      },
    );
  }

  /// 缩放转场
  static PageRouteBuilder<T> scaleTransition<T>({
    required Widget page,
    Duration? duration,
    Curve? curve,
    double scaleStart = 0.9,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration ?? PageTransitions.scaleDuration,
      reverseTransitionDuration: duration ?? PageTransitions.scaleDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final scale = Tween<double>(
          begin: scaleStart,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve ?? PageTransitions.scaleCurve,
        ));

        final fade = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(animation);

        return ScaleTransition(
          scale: scale,
          child: FadeTransition(
            opacity: fade,
            child: child,
          ),
        );
      },
    );
  }

  /// 组合转场（推荐用于主要页面）
  static PageRouteBuilder<T> combinedTransition<T>({
    required Widget page,
    Duration? duration,
    Curve? curve,
    double slideOffset = 0.05,
    double scaleStart = 0.95,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration ?? PageTransitions.combinedDuration,
      reverseTransitionDuration: duration ?? PageTransitions.combinedDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(
          begin: Offset(slideOffset, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve ?? PageTransitions.combinedCurve,
        ));

        final scale = Tween<double>(
          begin: scaleStart,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve ?? PageTransitions.combinedCurve,
        ));

        final fade = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(animation);

        return AnimatedBuilder(
          animation: Listenable.merge([animation, secondaryAnimation]),
          builder: (context, child) {
            return Transform.translate(
              offset: slide.value,
              child: Transform.scale(
                scale: scale.value,
                child: Opacity(
                  opacity: fade.value,
                  child: child,
                ),
              ),
            );
          },
          child: child,
        );
      },
    );
  }
}

/// 页面转场主题配置
class CorePlayerPageTransitions extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 根据路由类型选择不同的转场
    if (route.fullscreenDialog) {
      return _buildModalTransition(animation, child);
    } else {
      return _buildMainTransition(animation, secondaryAnimation, child);
    }
  }

  Widget _buildMainTransition(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 主要页面使用组合转场
    final slideOffset = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOut,
    ));

    final scale = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOut,
    ));

    final opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(animation);

    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      builder: (context, child) {
        return Transform.translate(
          offset: slideOffset.value * MediaQuery.of(context).size.width,
          child: Transform.scale(
            scale: scale.value,
            child: Opacity(
              opacity: opacity.value,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildModalTransition(Animation<double> animation, Widget child) {
    // 模态页面使用从下滑入
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      )),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
}