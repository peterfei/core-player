/// 悬停动画效果系统
/// 为CorePlayer提供丰富的交互动画效果
/// 基于openspec/changes/modernize-ui-design规格

import 'package:flutter/material.dart';
import '../theme/design_tokens/design_tokens.dart';

/// 悬停动画类型
enum HoverAnimationType {
  scale,          // 缩放
  elevation,      // 阴影/高度
  brightness,     // 亮度
  shake,          // 摇晃
  bounce,         // 弹跳
  glow,           // 发光
  color,          // 颜色
  combined,       // 组合效果
}

/// 悬停动画配置
class HoverAnimationConfig {
  final HoverAnimationType type;
  final Duration duration;
  final Duration reverseDuration;
  final Curve curve;
  final Curve reverseCurve;
  final double? scaleStart;
  final double? scaleEnd;
  final double? elevationStart;
  final double? elevationEnd;
  final double? brightnessStart;
  final double? brightnessEnd;
  final double? shakeDistance;
  final double? bounceHeight;
  final Color? glowColor;
  final double? glowRadius;
  final Color? colorStart;
  final Color? colorEnd;

  const HoverAnimationConfig({
    this.type = HoverAnimationType.scale,
    this.duration = AppDurations.hoverDuration,
    this.reverseDuration = AppDurations.hoverDuration,
    this.curve = AppCurves.easeOut,
    this.reverseCurve = AppCurves.easeIn,
    this.scaleStart = 1.0,
    this.scaleEnd,
    this.elevationStart = 0.0,
    this.elevationEnd,
    this.brightnessStart = 1.0,
    this.brightnessEnd = 1.2,
    this.shakeDistance = 5.0,
    this.bounceHeight = 10.0,
    this.glowColor,
    this.glowRadius = 15.0,
    this.colorStart,
    this.colorEnd,
  });
}

/// 悬停动画组件
class HoverAnimatedWidget extends StatefulWidget {
  final Widget child;
  final HoverAnimationConfig config;
  final VoidCallback? onTap;
  final bool enabled;

  const HoverAnimatedWidget({
    Key? key,
    required this.child,
    this.config = const HoverAnimationConfig(),
    this.onTap,
    this.enabled = true,
  }) : super(key: key);

  @override
  State<HoverAnimatedWidget> createState() => _HoverAnimatedWidgetState();
}

class _HoverAnimatedWidgetState extends State<HoverAnimatedWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  late Animation<double> _brightnessAnimation;
  late Animation<Offset> _shakeAnimation;
  late Animation<double> _bounceAnimation;
  late Animation<double> _glowAnimation;
  late Animation<Color?> _colorAnimation;

  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      duration: widget.config.duration,
      reverseDuration: widget.config.reverseDuration,
      vsync: this,
    );

    switch (widget.config.type) {
      case HoverAnimationType.scale:
        _initializeScaleAnimation();
        break;
      case HoverAnimationType.elevation:
        _initializeElevationAnimation();
        break;
      case HoverAnimationType.brightness:
        _initializeBrightnessAnimation();
        break;
      case HoverAnimationType.shake:
        _initializeShakeAnimation();
        break;
      case HoverAnimationType.bounce:
        _initializeBounceAnimation();
        break;
      case HoverAnimationType.glow:
        _initializeGlowAnimation();
        break;
      case HoverAnimationType.color:
        _initializeColorAnimation();
        break;
      case HoverAnimationType.combined:
        _initializeCombinedAnimation();
        break;
    }
  }

  void _initializeScaleAnimation() {
    _scaleAnimation = Tween<double>(
      begin: widget.config.scaleStart ?? 1.0,
      end: widget.config.scaleEnd ?? MicroInteractions.buttonHoverScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.config.curve,
      reverseCurve: widget.config.reverseCurve,
    ));
  }

  void _initializeElevationAnimation() {
    _elevationAnimation = Tween<double>(
      begin: widget.config.elevationStart ?? 0.0,
      end: widget.config.elevationEnd ?? MicroInteractions.cardHoverElevation,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.config.curve,
      reverseCurve: widget.config.reverseCurve,
    ));
  }

  void _initializeBrightnessAnimation() {
    _brightnessAnimation = Tween<double>(
      begin: widget.config.brightnessStart ?? 1.0,
      end: widget.config.brightnessEnd ?? 1.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.config.curve,
      reverseCurve: widget.config.reverseCurve,
    ));
  }

  void _initializeShakeAnimation() {
    _shakeAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: Offset(widget.config.shakeDistance ?? 5.0, 0),
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset(widget.config.shakeDistance ?? 5.0, 0),
          end: Offset(-(widget.config.shakeDistance ?? 5.0), 0),
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset(-(widget.config.shakeDistance ?? 5.0), 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25.0,
      ),
    ]).animate(_controller);
  }

  void _initializeBounceAnimation() {
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: widget.config.bounceHeight ?? 10.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: widget.config.bounceHeight ?? 10.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 50.0,
      ),
    ]).animate(_controller);
  }

  void _initializeGlowAnimation() {
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.config.curve,
      reverseCurve: widget.config.reverseCurve,
    ));
  }

  void _initializeColorAnimation() {
    _colorAnimation = ColorTween(
      begin: widget.config.colorStart ?? Colors.transparent,
      end: widget.config.colorEnd ?? AppColors.primary.withOpacity(0.1),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.config.curve,
      reverseCurve: widget.config.reverseCurve,
    ));
  }

  void _initializeCombinedAnimation() {
    _initializeScaleAnimation();
    _initializeElevationAnimation();
    _initializeBrightnessAnimation();
  }

  void _handleHover(bool isHovered) {
    if (!widget.enabled) return;

    if (_isHovered != isHovered) {
      setState(() {
        _isHovered = isHovered;
      });

      if (isHovered) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            Widget animatedChild = child!;

            switch (widget.config.type) {
              case HoverAnimationType.scale:
                animatedChild = Transform.scale(
                  scale: _scaleAnimation.value,
                  child: animatedChild,
                );
                break;
              case HoverAnimationType.elevation:
                animatedChild = AnimatedContainer(
                  duration: Duration.zero,
                  decoration: BoxDecoration(
                    boxShadow: _getElevationShadow(_elevationAnimation.value),
                  ),
                  child: animatedChild,
                );
                break;
              case HoverAnimationType.brightness:
                animatedChild = ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.white.withOpacity(_brightnessAnimation.value - 1.0),
                    BlendMode.lighten,
                  ),
                  child: animatedChild,
                );
                break;
              case HoverAnimationType.shake:
                animatedChild = Transform.translate(
                  offset: _shakeAnimation.value,
                  child: animatedChild,
                );
                break;
              case HoverAnimationType.bounce:
                animatedChild = Transform.translate(
                  offset: Offset(0, -_bounceAnimation.value),
                  child: animatedChild,
                );
                break;
              case HoverAnimationType.glow:
                animatedChild = Container(
                  decoration: BoxDecoration(
                    boxShadow: _getGlowShadow(_glowAnimation.value),
                  ),
                  child: animatedChild,
                );
                break;
              case HoverAnimationType.color:
                animatedChild = AnimatedContainer(
                  duration: Duration.zero,
                  decoration: BoxDecoration(
                    color: _colorAnimation.value,
                  ),
                  child: animatedChild,
                );
                break;
              case HoverAnimationType.combined:
                animatedChild = Transform.scale(
                  scale: _scaleAnimation.value,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.white.withOpacity(_brightnessAnimation.value - 1.0),
                      BlendMode.lighten,
                    ),
                    child: AnimatedContainer(
                      duration: Duration.zero,
                      decoration: BoxDecoration(
                        boxShadow: _getElevationShadow(_elevationAnimation.value),
                      ),
                      child: animatedChild,
                    ),
                  ),
                );
                break;
            }

            return animatedChild;
          },
          child: widget.child,
        ),
      ),
    );
  }

  List<BoxShadow> _getElevationShadow(double elevation) {
    if (elevation <= 0) return [];

    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.2 * (elevation / 10)),
        blurRadius: elevation * 2,
        offset: Offset(0, elevation),
      ),
    ];
  }

  List<BoxShadow> _getGlowShadow(double intensity) {
    if (intensity <= 0) return [];

    return [
      BoxShadow(
        color: (widget.config.glowColor ?? AppColors.primary).withOpacity(0.4 * intensity),
        blurRadius: (widget.config.glowRadius ?? 15.0) * intensity,
        spreadRadius: 2.0 * intensity,
      ),
    ];
  }
}

/// 预定义的悬停动画组件

/// 按钮悬停效果
class HoverButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool enabled;

  const HoverButton({
    Key? key,
    required this.child,
    this.onPressed,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return HoverAnimatedWidget(
      config: const HoverAnimationConfig(
        type: HoverAnimationType.scale,
        scaleEnd: MicroInteractions.buttonHoverScale,
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

/// 卡片悬停效果
class HoverCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const HoverCard({
    Key? key,
    required this.child,
    this.onTap,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return HoverAnimatedWidget(
      config: const HoverAnimationConfig(
        type: HoverAnimationType.combined,
        scaleEnd: MicroInteractions.cardHoverScale,
        elevationEnd: MicroInteractions.cardHoverElevation,
      ),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.large),
        child: child,
      ),
    );
  }
}

/// 图标悬停效果
class HoverIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final VoidCallback? onTap;

  const HoverIcon({
    Key? key,
    required this.icon,
    this.size = 24.0,
    this.color,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return HoverAnimatedWidget(
      config: const HoverAnimationConfig(
        type: HoverAnimationType.scale,
        scaleEnd: 1.1,
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

/// 列表项悬停效果
class HoverListItem extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? hoverColor;

  const HoverListItem({
    Key? key,
    required this.child,
    this.onTap,
    this.hoverColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return HoverAnimatedWidget(
      config: HoverAnimationConfig(
        type: HoverAnimationType.color,
        colorEnd: hoverColor ?? AppColors.surfaceVariant.withOpacity(0.3),
      ),
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.small),
          child: child,
        ),
      ),
    );
  }
}

/// 缩略图悬停效果（用于视频卡片）
class HoverThumbnail extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool showPlayButton;

  const HoverThumbnail({
    Key? key,
    required this.child,
    this.onTap,
    this.showPlayButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return HoverAnimatedWidget(
      config: const HoverAnimationConfig(
        type: HoverAnimationType.combined,
        scaleEnd: 1.02,
        brightnessEnd: 1.1,
      ),
      onTap: onTap,
      child: Stack(
        children: [
          child,
          if (showPlayButton)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: 0.0,
                  duration: AppDurations.hoverDuration,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.5,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}