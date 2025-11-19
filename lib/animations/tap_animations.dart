/// 点击反馈动画系统
/// 为CorePlayer提供流畅的点击交互体验
/// 基于openspec/changes/modernize-ui-design规格

import 'package:flutter/material.dart';
import '../theme/design_tokens/design_tokens.dart';
import 'hover_animations.dart';

/// 点击动画类型
enum TapAnimationType {
  ripple,         // 涟漪效果
  scale,          // 缩放反馈
  shake,          // 震动反馈
  bounce,         // 弹跳反馈
  highlight,      // 高亮反馈
  combined,       // 组合效果
}

/// 点击动画配置
class TapAnimationConfig {
  final TapAnimationType type;
  final Duration duration;
  final Curve curve;
  final double? scaleStart;
  final double? scaleEnd;
  final double? shakeDistance;
  final double? bounceHeight;
  final Color? highlightColor;
  final double? highlightOpacity;
  final bool enableHapticFeedback;

  const TapAnimationConfig({
    this.type = TapAnimationType.ripple,
    this.duration = AppDurations.clickDuration,
    this.curve = AppCurves.easeOut,
    this.scaleStart = 1.0,
    this.scaleEnd = MicroInteractions.buttonPressScale,
    this.shakeDistance = 3.0,
    this.bounceHeight = 5.0,
    this.highlightColor,
    this.highlightOpacity = 0.1,
    this.enableHapticFeedback = false,
  });
}

/// 点击动画组件
class TapAnimatedWidget extends StatefulWidget {
  final Widget child;
  final TapAnimationConfig config;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final BorderRadius? borderRadius;

  const TapAnimatedWidget({
    Key? key,
    required this.child,
    this.config = const TapAnimationConfig(),
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<TapAnimatedWidget> createState() => _TapAnimatedWidgetState();
}

class _TapAnimatedWidgetState extends State<TapAnimatedWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _shakeAnimation;
  late Animation<double> _bounceAnimation;
  late Animation<Color?> _highlightAnimation;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      duration: widget.config.duration,
      vsync: this,
    );

    switch (widget.config.type) {
      case TapAnimationType.scale:
        _initializeScaleAnimation();
        break;
      case TapAnimationType.shake:
        _initializeShakeAnimation();
        break;
      case TapAnimationType.bounce:
        _initializeBounceAnimation();
        break;
      case TapAnimationType.highlight:
        _initializeHighlightAnimation();
        break;
      case TapAnimationType.combined:
        _initializeCombinedAnimation();
        break;
      case TapAnimationType.ripple:
        // 涟漪效果通过 InkWell 实现
        break;
    }
  }

  void _initializeScaleAnimation() {
    _scaleAnimation = Tween<double>(
      begin: widget.config.scaleStart ?? 1.0,
      end: widget.config.scaleEnd ?? 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.config.curve,
    ));
  }

  void _initializeShakeAnimation() {
    _shakeAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: Offset(widget.config.shakeDistance ?? 3.0, 0),
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset(widget.config.shakeDistance ?? 3.0, 0),
          end: Offset(-(widget.config.shakeDistance ?? 3.0), 0),
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset(-(widget.config.shakeDistance ?? 3.0), 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25.0,
      ),
    ]).animate(_controller);
  }

  void _initializeBounceAnimation() {
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.9,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.9,
          end: 1.05,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 70.0,
      ),
    ]).animate(_controller);
  }

  void _initializeHighlightAnimation() {
    _highlightAnimation = ColorTween(
      begin: Colors.transparent,
      end: (widget.config.highlightColor ?? AppColors.primary)
          .withOpacity(widget.config.highlightOpacity ?? 0.1),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.config.curve,
    ));
  }

  void _initializeCombinedAnimation() {
    _initializeScaleAnimation();
    _initializeHighlightAnimation();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.enabled) return;

    setState(() {
      _isPressed = true;
    });

    _controller.forward();

    if (widget.config.enableHapticFeedback) {
      _triggerHapticFeedback();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.enabled) return;

    setState(() {
      _isPressed = false;
    });

    _controller.reverse().then((_) {
      widget.onTap?.call();
    });
  }

  void _handleTapCancel() {
    if (!widget.enabled) return;

    setState(() {
      _isPressed = false;
    });

    _controller.reverse();
  }

  void _triggerHapticFeedback() {
    // 根据平台提供触觉反馈
    // 这里可以根据不同平台调用相应的触觉反馈API
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    switch (widget.config.type) {
      case TapAnimationType.ripple:
        return _buildRippleEffect();
      case TapAnimationType.scale:
        return _buildScaleEffect();
      case TapAnimationType.shake:
        return _buildShakeEffect();
      case TapAnimationType.bounce:
        return _buildBounceEffect();
      case TapAnimationType.highlight:
        return _buildHighlightEffect();
      case TapAnimationType.combined:
        return _buildCombinedEffect();
    }
  }

  Widget _buildRippleEffect() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(AppRadius.medium),
        splashFactory: InkRipple.splashFactory,
        splashColor: AppColors.primary.withOpacity(0.3),
        highlightColor: AppColors.primary.withOpacity(0.1),
        child: widget.child,
      ),
    );
  }

  Widget _buildScaleEffect() {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }

  Widget _buildShakeEffect() {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: _shakeAnimation.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }

  Widget _buildBounceEffect() {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _bounceAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _bounceAnimation.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }

  Widget _buildHighlightEffect() {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _highlightAnimation,
        builder: (context, child) {
          return AnimatedContainer(
            duration: Duration.zero,
            decoration: BoxDecoration(
              color: _highlightAnimation.value,
              borderRadius: widget.borderRadius ?? BorderRadius.circular(AppRadius.medium),
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }

  Widget _buildCombinedEffect() {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _highlightAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: Duration.zero,
              decoration: BoxDecoration(
                color: _highlightAnimation.value,
                borderRadius: widget.borderRadius ?? BorderRadius.circular(AppRadius.medium),
              ),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// 预定义的点击动画组件

/// 按钮点击效果
class TapButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool enabled;
  final TapAnimationConfig? config;

  const TapButton({
    Key? key,
    required this.child,
    this.onPressed,
    this.enabled = true,
    this.config,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TapAnimatedWidget(
      config: config ?? const TapAnimationConfig(
        type: TapAnimationType.scale,
        scaleEnd: MicroInteractions.buttonPressScale,
      ),
      onTap: enabled ? onPressed : null,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1.0 : AnimationRanges.opacityDisabled,
        child: child,
      ),
    );
  }
}

/// 卡片点击效果
class TapCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;

  const TapCard({
    Key? key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TapAnimatedWidget(
      config: const TapAnimationConfig(
        type: TapAnimationType.combined,
        scaleEnd: MicroInteractions.cardPressScale,
        highlightColor: AppColors.surfaceVariant,
        highlightOpacity: 0.1,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.large),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.large),
        child: child,
      ),
    );
  }
}

/// 图标点击效果
class TapIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final VoidCallback? onTap;
  final bool enableHapticFeedback;

  const TapIcon({
    Key? key,
    required this.icon,
    this.size = 24.0,
    this.color,
    this.onTap,
    this.enableHapticFeedback = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TapAnimatedWidget(
      config: TapAnimationConfig(
        type: TapAnimationType.scale,
        scaleEnd: 0.9,
        enableHapticFeedback: enableHapticFeedback,
      ),
      onTap: onTap,
      child: Icon(
        icon,
        size: size,
        color: color ?? AppColors.textSecondary,
      ),
    );
  }
}

/// 列表项点击效果
class TapListItem extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? splashColor;
  final Color? highlightColor;

  const TapListItem({
    Key? key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.splashColor,
    this.highlightColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TapAnimatedWidget(
      config: TapAnimationConfig(
        type: TapAnimationType.ripple,
        highlightColor: highlightColor ?? AppColors.surfaceVariant.withOpacity(0.3),
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppRadius.small),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppRadius.small),
          splashColor: splashColor ?? AppColors.primary.withOpacity(0.2),
          highlightColor: highlightColor ?? AppColors.surfaceVariant.withOpacity(0.3),
          child: child,
        ),
      ),
    );
  }
}

/// 缩略图点击效果（用于视频卡片）
class TapThumbnail extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool showRipple;
  final bool showScale;

  const TapThumbnail({
    Key? key,
    required this.child,
    this.onTap,
    this.showRipple = true,
    this.showScale = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TapAnimatedWidget(
      config: TapAnimationConfig(
        type: showScale ? TapAnimationType.scale : TapAnimationType.ripple,
        scaleEnd: 0.98,
      ),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Stack(
        children: [
          child,
          if (showRipple)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  splashColor: Colors.white.withOpacity(0.3),
                  highlightColor: Colors.white.withOpacity(0.1),
                  child: Container(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 交互式按钮（结合悬停和点击效果）
class InteractiveButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool enabled;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const InteractiveButton({
    Key? key,
    required this.child,
    this.onPressed,
    this.enabled = true,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.foregroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TapAnimatedWidget(
      config: const TapAnimationConfig(
        type: TapAnimationType.combined,
        scaleEnd: MicroInteractions.buttonPressScale,
      ),
      onTap: enabled ? onPressed : null,
      enabled: enabled,
      borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.medium),
      child: HoverAnimatedWidget(
        config: const HoverAnimationConfig(
          type: HoverAnimationType.scale,
          scaleEnd: MicroInteractions.buttonHoverScale,
        ),
        enabled: enabled,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: padding ?? const EdgeInsets.symmetric(
            horizontal: AppSpacing.medium,
            vertical: AppSpacing.small,
          ),
          decoration: BoxDecoration(
            color: enabled
                ? (backgroundColor ?? AppColors.primary)
                : AppColors.surfaceVariant,
            borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.medium),
          ),
          child: DefaultTextStyle(
            style: AppTextStyles.labelLarge.copyWith(
              color: enabled
                  ? (foregroundColor ?? Colors.white)
                  : AppColors.textDisabled,
              fontWeight: FontWeight.w600,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}