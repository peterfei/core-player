/// 加载状态和Shimmer效果系统
/// 为CorePlayer提供优雅的加载动画和骨架屏效果
/// 基于openspec/changes/modernize-ui-design规格

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/design_tokens/design_tokens.dart';

/// 加载动画类型
enum LoadingAnimationType {
  shimmer,        // Shimmer效果
  pulse,          // 脉冲效果
  spinning,       // 旋转加载
  bouncing,       // 弹跳加载
  skeleton,       // 骨架屏
  dots,           // 点状加载
  wave,           // 波浪加载
  progress,       // 进度条加载
}

/// 加载动画配置
class LoadingAnimationConfig {
  final LoadingAnimationType type;
  final Duration duration;
  final Duration delay;
  final Color? baseColor;
  final Color? highlightColor;
  final double? strokeWidth;
  final double? dotSize;
  final double? amplitude;
  final double? frequency;

  const LoadingAnimationConfig({
    this.type = LoadingAnimationType.shimmer,
    this.duration = LoadingAnimations.shimmerDuration,
    this.delay = LoadingAnimations.shimmerDelay,
    this.baseColor,
    this.highlightColor,
    this.strokeWidth,
    this.dotSize,
    this.amplitude,
    this.frequency,
  });
}

/// Shimmer效果组件
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;
  final bool enabled;

  const ShimmerEffect({
    Key? key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = LoadingAnimations.shimmerDuration,
    this.enabled = true,
  }) : super(key: key);

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: LoadingAnimations.shimmerStartX,
      end: LoadingAnimations.shimmerEndX,
    ).animate(_controller);

    if (widget.enabled) {
      _startShimmer();
    }
  }

  void _startShimmer() {
    Future.delayed(LoadingAnimations.shimmerDelay, () {
      if (mounted && widget.enabled) {
        _controller.repeat();
      }
    });
  }

  @override
  void didUpdateWidget(ShimmerEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _startShimmer();
      } else {
        _controller.stop();
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

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 + _animation.value, 0.0),
              end: Alignment(_animation.value, 0.0),
              colors: [
                widget.baseColor ?? Colors.grey[300]!,
                widget.highlightColor ?? Colors.grey[100]!,
                widget.baseColor ?? Colors.grey[300]!,
              ],
              stops: const [
                0.0,
                LoadingAnimations.shimmerGradientWidth,
                1.0,
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// 脉冲效果组件
class PulseEffect extends StatefulWidget {
  final Widget child;
  final double minOpacity;
  final double maxOpacity;
  final Duration duration;
  final Curve curve;
  final bool enabled;

  const PulseEffect({
    Key? key,
    required this.child,
    this.minOpacity = LoadingAnimations.pulseMinOpacity,
    this.maxOpacity = LoadingAnimations.pulseMaxOpacity,
    this.duration = LoadingAnimations.pulseDuration,
    this.curve = LoadingAnimations.pulseCurve,
    this.enabled = true,
  }) : super(key: key);

  @override
  State<PulseEffect> createState() => _PulseEffectState();
}

class _PulseEffectState extends State<PulseEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: widget.minOpacity,
      end: widget.maxOpacity,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    if (widget.enabled) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulseEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
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

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// 旋转加载指示器
class SpinningIndicator extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final Color? color;
  final Duration duration;
  final bool enabled;

  const SpinningIndicator({
    Key? key,
    this.size = 24.0,
    this.strokeWidth = 2.0,
    this.color,
    this.duration = LoadingAnimations.spinDuration,
    this.enabled = true,
  }) : super(key: key);

  @override
  State<SpinningIndicator> createState() => _SpinningIndicatorState();
}

class _SpinningIndicatorState extends State<SpinningIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(SpinningIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.repeat();
      } else {
        _controller.stop();
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
    if (!widget.enabled) return const SizedBox.shrink();

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _controller.value * 2 * 3.14159,
            child: child,
          );
        },
        child: CircularProgressIndicator(
          strokeWidth: widget.strokeWidth,
          valueColor: AlwaysStoppedAnimation(
            widget.color ?? AppColors.primary,
          ),
          backgroundColor: (widget.color ?? AppColors.primary).withOpacity(0.2),
        ),
      ),
    );
  }
}

/// 骨架屏组件
class SkeletonScreen extends StatelessWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  const SkeletonScreen({
    Key? key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = LoadingAnimations.shimmerDuration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      baseColor: baseColor ?? AppColors.surfaceVariant.withOpacity(0.3),
      highlightColor: highlightColor ?? AppColors.surfaceVariant.withOpacity(0.6),
      duration: duration,
      child: child,
    );
  }
}

/// 预定义的骨架屏组件

/// 文本骨架屏
class TextSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final EdgeInsets? margin;

  const TextSkeleton({
    Key? key,
    required this.width,
    required this.height,
    this.margin,
  }) : super(key: key);

  const TextSkeleton.line({
    Key? key,
    this.width = double.infinity,
    this.height = 16.0,
    this.margin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4.0),
      ),
    );
  }
}

/// 标题骨架屏
class TitleSkeleton extends StatelessWidget {
  final double width;
  final EdgeInsets? margin;

  const TitleSkeleton({
    Key? key,
    this.width = double.infinity,
    this.margin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextSkeleton(
      width: width,
      height: 24.0,
      margin: margin,
    );
  }
}

/// 头像骨架屏
class AvatarSkeleton extends StatelessWidget {
  final double size;
  final EdgeInsets? margin;

  const AvatarSkeleton({
    Key? key,
    this.size = 40.0,
    this.margin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 缩略图骨架屏
class ThumbnailSkeleton extends StatelessWidget {
  final double width;
  final double? height;
  final double aspectRatio;
  final EdgeInsets? margin;

  const ThumbnailSkeleton({
    Key? key,
    this.width = double.infinity,
    this.height,
    this.aspectRatio = 16 / 9,
    this.margin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height ?? width / aspectRatio,
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
    );
  }
}

/// 按钮骨架屏
class ButtonSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final EdgeInsets? margin;
  final BorderRadius? borderRadius;

  const ButtonSkeleton({
    Key? key,
    this.width = double.infinity,
    this.height = 40.0,
    this.margin,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withOpacity(0.3),
        borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.medium),
      ),
    );
  }
}

/// 视频卡片骨架屏
class VideoCardSkeleton extends StatelessWidget {
  final double? width;
  final double aspectRatio;
  final EdgeInsets? margin;

  const VideoCardSkeleton({
    Key? key,
    this.width,
    this.aspectRatio = 16 / 9,
    this.margin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 缩略图
          ThumbnailSkeleton(
            width: width ?? double.infinity,
            aspectRatio: aspectRatio,
          ),
          const SizedBox(height: AppSpacing.small),
          // 标题
          TextSkeleton.line(
            width: width != null ? width! * 0.8 : 200.0,
            height: 14.0,
          ),
          const SizedBox(height: AppSpacing.micro),
          // 副标题
          TextSkeleton.line(
            width: width != null ? width! * 0.6 : 150.0,
            height: 12.0,
          ),
        ],
      ),
    );
  }
}

/// 列表骨架屏
class ListSkeleton extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  const ListSkeleton({
    Key? key,
    required this.itemCount,
    required this.itemBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}

/// 网格骨架屏
class GridSkeleton extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final EdgeInsets? padding;
  final Widget Function(BuildContext context, int index) itemBuilder;

  const GridSkeleton({
    Key? key,
    required this.itemCount,
    this.crossAxisCount = 2,
    this.childAspectRatio = 16 / 9,
    this.crossAxisSpacing = AppSpacing.small,
    this.mainAxisSpacing = AppSpacing.small,
    this.padding,
    required this.itemBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}

/// 全页面加载状态
class FullPageLoading extends StatelessWidget {
  final String? message;
  final Widget? customWidget;

  const FullPageLoading({
    Key? key,
    this.message,
    this.customWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          customWidget ?? const SpinningIndicator(
            size: 48.0,
            strokeWidth: 4.0,
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.medium),
            Text(
              message!,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 组合加载指示器（包含多种动画效果）
class LoadingIndicator extends StatelessWidget {
  final LoadingAnimationConfig config;
  final String? message;
  final bool showText;
  final bool showBackground;

  const LoadingIndicator({
    Key? key,
    required this.config,
    this.message,
    this.showText = true,
    this.showBackground = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget indicator;

    switch (config.type) {
      case LoadingAnimationType.shimmer:
        indicator = _buildShimmerIndicator();
        break;
      case LoadingAnimationType.pulse:
        indicator = _buildPulseIndicator();
        break;
      case LoadingAnimationType.spinning:
        indicator = _buildSpinningIndicator();
        break;
      case LoadingAnimationType.bouncing:
        indicator = _buildBouncingIndicator();
        break;
      case LoadingAnimationType.dots:
        indicator = _buildDotsIndicator();
        break;
      case LoadingAnimationType.wave:
        indicator = _buildWaveIndicator();
        break;
      case LoadingAnimationType.progress:
        indicator = _buildProgressIndicator();
        break;
      default:
        indicator = _buildSpinningIndicator();
    }

    return Container(
      padding: showBackground ? const EdgeInsets.all(AppSpacing.large) : EdgeInsets.zero,
      decoration: showBackground ? BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ) : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          if (showText && message != null) ...[
            const SizedBox(height: AppSpacing.medium),
            Text(
              message!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShimmerIndicator() {
    return Container(
      width: 40.0,
      height: 40.0,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: ShimmerEffect(
        baseColor: AppColors.surfaceVariant,
        highlightColor: AppColors.primary.withOpacity(0.3),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
        ),
      ),
    );
  }

  Widget _buildPulseIndicator() {
    return PulseEffect(
      duration: config.duration,
      child: Container(
        width: 40.0,
        height: 40.0,
        decoration: BoxDecoration(
          color: config.baseColor ?? AppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildSpinningIndicator() {
    return SpinningIndicator(
      size: 40.0,
      strokeWidth: config.strokeWidth ?? 3.0,
      color: config.baseColor,
      duration: config.duration,
    );
  }

  Widget _buildBouncingIndicator() {
    return SizedBox(
      width: 40.0,
      height: 40.0,
      child: _BouncingDots(
        color: config.baseColor ?? AppColors.primary,
        dotSize: config.dotSize ?? 8.0,
        duration: config.duration,
      ),
    );
  }

  Widget _buildDotsIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return _BouncingDot(
          color: config.baseColor ?? AppColors.primary,
          dotSize: config.dotSize ?? 8.0,
          delay: Duration(milliseconds: index * 200),
          duration: config.duration,
        );
      }).map((dot) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: dot,
        );
      }).toList(),
    );
  }

  Widget _buildWaveIndicator() {
    return SizedBox(
      width: 60.0,
      height: 40.0,
      child: _WaveLoader(
        color: config.baseColor ?? AppColors.primary,
        amplitude: config.amplitude ?? 10.0,
        frequency: config.frequency ?? 2.0,
        duration: config.duration,
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return SizedBox(
      width: 200.0,
      height: 4.0,
      child: LinearProgressIndicator(
        backgroundColor: AppColors.surfaceVariant,
        valueColor: AlwaysStoppedAnimation(config.baseColor ?? AppColors.primary),
      ),
    );
  }
}

/// 弹跳点组件
class _BouncingDot extends StatefulWidget {
  final Color color;
  final double dotSize;
  final Duration delay;
  final Duration duration;

  const _BouncingDot({
    required this.color,
    required this.dotSize,
    required this.delay,
    required this.duration,
  });

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.bounceOut,
    ));

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_animation.value * 10.0),
          child: Container(
            width: widget.dotSize,
            height: widget.dotSize,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

/// 弹跳点组合组件
class _BouncingDots extends StatelessWidget {
  final Color color;
  final double dotSize;
  final Duration duration;

  const _BouncingDots({
    required this.color,
    required this.dotSize,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (index) {
        return _BouncingDot(
          color: color,
          dotSize: dotSize,
          delay: Duration(milliseconds: index * 150),
          duration: duration,
        );
      }),
    );
  }
}

/// 波浪加载组件
class _WaveLoader extends StatefulWidget {
  final Color color;
  final double amplitude;
  final double frequency;
  final Duration duration;

  const _WaveLoader({
    required this.color,
    required this.amplitude,
    required this.frequency,
    required this.duration,
  });

  @override
  State<_WaveLoader> createState() => _WaveLoaderState();
}

class _WaveLoaderState extends State<_WaveLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _WavePainter(
            color: widget.color,
            progress: _controller.value,
            amplitude: widget.amplitude,
            frequency: widget.frequency,
          ),
        );
      },
    );
  }
}

/// 波浪画笔
class _WavePainter extends CustomPainter {
  final Color color;
  final double progress;
  final double amplitude;
  final double frequency;

  _WavePainter({
    required this.color,
    required this.progress,
    required this.amplitude,
    required this.frequency,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final width = size.width;
    final height = size.height;

    path.moveTo(0, height / 2);

    for (double x = 0; x <= width; x++) {
      final y = height / 2 + amplitude *
          math.sin((x / width * frequency * math.pi * 2) + (progress * math.pi * 2));
      path.lineTo(x, y);
    }

    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}