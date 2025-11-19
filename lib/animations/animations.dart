/// 动画系统统一入口文件
/// 导出所有动画组件，方便其他模块使用
/// 基于openspec/changes/modernize-ui-design规格

import 'package:flutter/material.dart';
import 'dart:ui' as ui;

export 'page_transitions.dart';
export 'hover_animations.dart';
export 'tap_animations.dart';
export 'loading_animations.dart';

/// 动画系统配置
class AnimationSystemConfig {
  static bool enablePerformanceOptimizations = true;
  static bool enableDebugLogs = false;
  static bool enableAccessibilityAnimations = true;
  static double globalAnimationScale = 1.0;

  /// 获取调整后的动画时长
  static Duration getScaledDuration(Duration duration) {
    return Duration(
      milliseconds: (duration.inMilliseconds / globalAnimationScale).round(),
    );
  }

  /// 检查是否应该运行动画
  static bool shouldRunAnimation(String? animationType) {
    // 检查全局设置
    if (!enablePerformanceOptimizations) return true;

    // 检查可访问性设置
    // 这里可以集成系统的动画偏好设置

    return true;
  }
}

/// 动画性能监控器
class AnimationPerformanceMonitor {
  static final Map<String, DateTime> _animationStartTimes = {};
  static final Map<String, int> _animationCounts = {};

  /// 记录动画开始
  static void startAnimation(String name) {
    if (!AnimationSystemConfig.enableDebugLogs) return;

    _animationStartTimes[name] = DateTime.now();
    _animationCounts[name] = (_animationCounts[name] ?? 0) + 1;
  }

  /// 记录动画结束
  static void endAnimation(String name) {
    if (!AnimationSystemConfig.enableDebugLogs) return;

    final startTime = _animationStartTimes[name];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      if (AnimationSystemConfig.enableDebugLogs) {
        debugPrint('Animation "$name" completed in ${duration.inMilliseconds}ms');
      }
      _animationStartTimes.remove(name);
    }
  }

  /// 获取动画统计信息
  static Map<String, dynamic> getStats() {
    return {
      'activeAnimations': _animationStartTimes.length,
      'totalCounts': Map.from(_animationCounts),
    };
  }

  /// 重置统计信息
  static void resetStats() {
    _animationStartTimes.clear();
    _animationCounts.clear();
  }
}

/// 动画预设配置
class AnimationPresets {
  AnimationPresets._();

  /// 快速轻量动画
  static const fast = Duration(milliseconds: 150);

  /// 标准动画
  static const normal = Duration(milliseconds: 250);

  /// 慢速动画
  static const slow = Duration(milliseconds: 350);

  /// 页面过渡动画
  static const pageTransition = Duration(milliseconds: 300);

  /// 加载动画
  static const loading = Duration(milliseconds: 1000);

  /// 舒缓曲线
  static const Curve gentleCurve = Curves.easeOutCubic;

  /// 活泼曲线
  static const Curve livelyCurve = Curves.elasticOut;

  /// 标准曲线
  static const Curve standardCurve = Curves.easeInOut;
}

/// 动画工具类
class AnimationUtils {
  AnimationUtils._();

  /// 创建缓动动画控制器
  static AnimationController createEasedController({
    required TickerProvider vsync,
    Duration duration = AnimationPresets.normal,
  }) {
    return AnimationController(
      duration: AnimationSystemConfig.getScaledDuration(duration),
      vsync: vsync,
    );
  }

  /// 创建缓动动画
  static Animation<double> createEasedAnimation({
    required AnimationController controller,
    double begin = 0.0,
    double end = 1.0,
    Curve curve = Curves.easeInOut,
  }) {
    return Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: curve),
    );
  }

  /// 创建颜色过渡动画
  static Animation<Color?> createColorAnimation({
    required AnimationController controller,
    required Color begin,
    required Color end,
    Curve curve = Curves.easeInOut,
  }) {
    return ColorTween(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: curve),
    );
  }

  /// 创建尺寸动画
  static Animation<Size?> createSizeAnimation({
    required AnimationController controller,
    required Size begin,
    required Size end,
    Curve curve = Curves.easeInOut,
  }) {
    return SizeTween(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: curve),
    );
  }

  /// 创建偏移动画
  static Animation<Offset> createOffsetAnimation({
    required AnimationController controller,
    required Offset begin,
    required Offset end,
    Curve curve = Curves.easeInOut,
  }) {
    return Tween<Offset>(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: curve),
    );
  }

  /// 创建阴影动画
  static Animation<List<BoxShadow>> createShadowAnimation({
    required AnimationController controller,
    required List<BoxShadow> begin,
    required List<BoxShadow> end,
    Curve curve = Curves.easeInOut,
  }) {
    return BoxShadowTween(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: curve),
    );
  }
}

/// 阴影插值器
class BoxShadowTween extends Tween<List<BoxShadow>> {
  BoxShadowTween({List<BoxShadow>? begin, List<BoxShadow>? end})
      : super(begin: begin ?? [], end: end ?? []);

  @override
  List<BoxShadow> lerp(double t) {
    if (begin == null || end == null) return [];

    if (begin!.length != end!.length) return end!;

    return List.generate(begin!.length, (index) {
      return BoxShadow.lerp(begin![index], end![index], t)!;
    });
  }
}

/// 动画包装器
class AnimatedWrapper extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final bool enabled;

  const AnimatedWrapper({
    Key? key,
    required this.child,
    this.duration = AnimationPresets.normal,
    this.curve = AnimationPresets.standardCurve,
    this.enabled = true,
  }) : super(key: key);

  @override
  State<AnimatedWrapper> createState() => _AnimatedWrapperState();
}

class _AnimatedWrapperState extends State<AnimatedWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimationSystemConfig.getScaledDuration(widget.duration),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    if (widget.enabled) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AnimatedWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
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
    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }
}

/// 交互动画包装器
class InteractiveAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve forwardCurve;
  final Curve reverseCurve;
  final double scaleStart;
  final double scaleEnd;
  final VoidCallback? onTap;

  const InteractiveAnimation({
    Key? key,
    required this.child,
    this.duration = AnimationPresets.fast,
    this.forwardCurve = AnimationPresets.gentleCurve,
    this.reverseCurve = AnimationPresets.standardCurve,
    this.scaleStart = 1.0,
    this.scaleEnd = 0.95,
    this.onTap,
  }) : super(key: key);

  @override
  State<InteractiveAnimation> createState() => _InteractiveAnimationState();
}

class _InteractiveAnimationState extends State<InteractiveAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimationSystemConfig.getScaledDuration(widget.duration),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: widget.scaleStart,
      end: widget.scaleEnd,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.forwardCurve,
      reverseCurve: widget.reverseCurve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse().then((_) {
      widget.onTap?.call();
    });
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
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
}