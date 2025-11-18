import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/performance_monitor_service.dart';

/// 性能监控覆盖层组件
/// 在视频播放器上显示实时性能指标
class PerformanceOverlay extends StatefulWidget {
  final bool showByDefault;
  final VoidCallback? onToggle;
  final bool enableKeyboardToggle;

  const PerformanceOverlay({
    super.key,
    this.showByDefault = false,
    this.onToggle,
    this.enableKeyboardToggle = true,
  });

  @override
  State<PerformanceOverlay> createState() => _PerformanceOverlayState();
}

class _PerformanceOverlayState extends State<PerformanceOverlay>
    with TickerProviderStateMixin {
  bool _isVisible = false;
  StreamSubscription<PerformanceMetrics>? _metricsSubscription;
  PerformanceMetrics? _currentMetrics;
  PerformanceStats? _stats;
  Timer? _statsUpdateTimer;

  // 动画控制器
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _isVisible = widget.showByDefault;
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    if (_isVisible) {
      _fadeController.value = 1.0;
    }

    _startPerformanceMonitoring();
    _setupKeyboardListener();
  }

  @override
  void dispose() {
    _metricsSubscription?.cancel();
    _statsUpdateTimer?.cancel();
    _fadeController.dispose();
    _removeKeyboardListener();
    super.dispose();
  }

  void _setupKeyboardListener() {
    if (widget.enableKeyboardToggle) {
      RawKeyboard.instance.addListener(_handleKeyEvent);
    }
  }

  void _removeKeyboardListener() {
    if (widget.enableKeyboardToggle) {
      RawKeyboard.instance.removeListener(_handleKeyEvent);
    }
  }

  void _handleKeyEvent(RawKeyEvent event) {
    // F8键切换性能监控覆盖层
    if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.f8) {
      _toggleVisibility();
    }
  }

  void _toggleVisibility() {
    setState(() {
      _isVisible = !_isVisible;
    });

    if (_isVisible) {
      _fadeController.forward();
    } else {
      _fadeController.reverse();
    }

    widget.onToggle?.call();
  }

  void _startPerformanceMonitoring() {
    // 监听性能指标
    _metricsSubscription =
        PerformanceMonitorService.instance.metricsStream.listen(
      (metrics) {
        setState(() {
          _currentMetrics = metrics;
        });
      },
    );

    // 定期更新统计数据
    _statsUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateStats();
    });
  }

  void _updateStats() {
    _stats = PerformanceMonitorService.instance.getPerformanceStats();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentMetrics == null || !_isVisible) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        Positioned(
          top: 16,
          right: 16,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getPerformanceColor().withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标题栏
                    Row(
                      children: [
                        Icon(
                          Icons.speed,
                          color: _getPerformanceColor(),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '性能监控',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _toggleVisibility,
                          child: Icon(
                            Icons.close,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(color: Colors.white24),
                    // 实时指标
                    _buildPerformanceMetrics(),
                    const SizedBox(height: 8),
                    if (_stats != null) _buildPerformanceStats(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceMetrics() {
    final metrics = _currentMetrics!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMetricRow(
          'FPS',
          '${metrics.fps.toStringAsFixed(1)}/${metrics.targetFps.toStringAsFixed(1)}',
          _getFpsColor(metrics),
        ),
        _buildMetricRow(
          '丢帧',
          '${metrics.droppedFramePercentage.toStringAsFixed(1)}%',
          _getDroppedFrameColor(metrics),
        ),
        _buildMetricRow(
          'CPU',
          '${metrics.cpuUsage.toStringAsFixed(1)}%',
          _getCpuColor(metrics),
        ),
        _buildMetricRow(
          '内存',
          '${metrics.memoryUsage.toStringAsFixed(0)}MB',
          _getMemoryColor(metrics),
        ),
        _buildMetricRow(
          '缓冲',
          '${metrics.bufferPercentage.toStringAsFixed(0)}%',
          _getBufferColor(metrics),
        ),
        if (metrics.gpuUsage > 0)
          _buildMetricRow(
            'GPU',
            '${metrics.gpuUsage.toStringAsFixed(1)}%',
            _getGpuColor(metrics),
          ),
        _buildMetricRow(
          '解码器',
          metrics.decoderType,
          _getDecoderColor(metrics),
        ),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceStats() {
    final stats = _stats!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          '统计信息',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        _buildMetricRow(
          '平均FPS',
          stats.averageFps.toStringAsFixed(1),
          Colors.white,
        ),
        _buildMetricRow(
          '最大FPS',
          stats.maxFps.toStringAsFixed(1),
          Colors.green,
        ),
        _buildMetricRow(
          '总丢帧',
          '${stats.totalDroppedFrames}',
          Colors.white,
        ),
        _buildMetricRow(
          '监控时长',
          '${stats.monitoringDuration}s',
          Colors.white,
        ),
        _buildMetricRow(
          '性能问题',
          '${stats.performanceIssues}',
          stats.performanceIssues > 0 ? Colors.red : Colors.green,
        ),
      ],
    );
  }

  Color _getPerformanceColor() {
    final metrics = _currentMetrics!;
    if (metrics.isExcellentPerformance) return Colors.green;
    if (metrics.isGoodPerformance) return Colors.blue;
    if (metrics.isPoorPerformance) return Colors.red;
    return Colors.orange;
  }

  Color _getFpsColor(PerformanceMetrics metrics) {
    if (metrics.fps >= metrics.targetFps * 0.95) return Colors.green;
    if (metrics.fps >= metrics.targetFps * 0.8) return Colors.orange;
    return Colors.red;
  }

  Color _getDroppedFrameColor(PerformanceMetrics metrics) {
    if (metrics.droppedFramePercentage <= 0.5) return Colors.green;
    if (metrics.droppedFramePercentage <= 2.0) return Colors.orange;
    return Colors.red;
  }

  Color _getCpuColor(PerformanceMetrics metrics) {
    if (metrics.cpuUsage <= 50) return Colors.green;
    if (metrics.cpuUsage <= 80) return Colors.orange;
    return Colors.red;
  }

  Color _getMemoryColor(PerformanceMetrics metrics) {
    if (metrics.memoryUsage <= 512) return Colors.green; // 512MB
    if (metrics.memoryUsage <= 1024) return Colors.orange; // 1GB
    return Colors.red;
  }

  Color _getBufferColor(PerformanceMetrics metrics) {
    if (metrics.bufferPercentage >= 50) return Colors.green;
    if (metrics.bufferPercentage >= 20) return Colors.orange;
    return Colors.red;
  }

  Color _getGpuColor(PerformanceMetrics metrics) {
    if (metrics.gpuUsage <= 60) return Colors.green;
    if (metrics.gpuUsage <= 80) return Colors.orange;
    return Colors.red;
  }

  Color _getDecoderColor(PerformanceMetrics metrics) {
    if (metrics.decoderType.contains('硬件') ||
        metrics.decoderType.contains('hardware')) {
      return Colors.green;
    }
    return Colors.orange;
  }
}

/// 简单的性能指示器（仅显示关键指标）
class PerformanceIndicator extends StatelessWidget {
  final PerformanceMetrics? metrics;
  final bool isVisible;

  const PerformanceIndicator({
    super.key,
    this.metrics,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible || metrics == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIndicator(
            'FPS',
            '${metrics!.fps.toStringAsFixed(0)}',
            _getIndicatorColor(
                metrics!.fps >= (metrics!.targetFps ?? 60.0) * 0.9),
          ),
          const SizedBox(width: 8),
          _buildIndicator(
            'CPU',
            '${metrics!.cpuUsage.toStringAsFixed(0)}%',
            _getIndicatorColor(metrics!.cpuUsage <= 70),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getIndicatorColor(bool isGood) {
    return isGood ? Colors.green : Colors.red;
  }
}

/// 性能监控切换按钮
class PerformanceMonitorToggle extends StatelessWidget {
  final bool isVisible;
  final VoidCallback? onToggle;

  const PerformanceMonitorToggle({
    super.key,
    required this.isVisible,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isVisible ? Colors.green : Colors.white.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Icon(
          isVisible ? Icons.speed : Icons.speed_outlined,
          color: isVisible ? Colors.green : Colors.white,
          size: 16,
        ),
      ),
    );
  }
}
