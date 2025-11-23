import 'dart:async';
import 'package:flutter/material.dart';
import '../services/plugin_status_service.dart';
import '../services/plugin_performance_service.dart';

/// 插件性能仪表盘
class PluginPerformanceDashboard extends StatefulWidget {
  const PluginPerformanceDashboard({super.key});

  @override
  State<PluginPerformanceDashboard> createState() => _PluginPerformanceDashboardState();
}

class _PluginPerformanceDashboardState extends State<PluginPerformanceDashboard> {
  final PluginStatusService _statusService = PluginStatusService();
  final PluginPerformanceService _performanceService = PluginPerformanceService();
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _startAutoUpdate();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startAutoUpdate() {
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = _statusService.statusSummary;
    final perfSummary = _performanceService.getPerformanceSummary();
    final suggestions = _performanceService.getPerformanceSuggestions();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  '插件性能监控',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _buildPerformanceGrade(summary.performanceGrade),
              ],
            ),
            const SizedBox(height: 16),

            // 性能概览
            _buildPerformanceOverview(summary, perfSummary),

            const SizedBox(height: 16),

            // 详细指标
            _buildDetailedMetrics(summary, perfSummary),

            const SizedBox(height: 16),

            // 性能建议
            if (suggestions.isNotEmpty) ...[
              _buildPerformanceSuggestions(suggestions),
              const SizedBox(height: 16),
            ],

            // 操作按钮
            _buildActionButtons(summary),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceGrade(String grade) {
    Color gradeColor;
    IconData gradeIcon;

    switch (grade) {
      case 'A+':
        gradeColor = Colors.green;
        gradeIcon = Icons.star;
        break;
      case 'A':
        gradeColor = Colors.lightGreen;
        gradeIcon = Icons.thumb_up;
        break;
      case 'B':
        gradeColor = Colors.orange;
        gradeIcon = Icons.speed;
        break;
      case 'C':
        gradeColor = Colors.deepOrange;
        gradeIcon = Icons.warning;
        break;
      case 'D':
        gradeColor = Colors.red;
        gradeIcon = Icons.error;
        break;
      default:
        gradeColor = Colors.grey;
        gradeIcon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: gradeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gradeColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(gradeIcon, color: gradeColor, size: 16),
          const SizedBox(width: 4),
          Text(
            '性能评级: $grade',
            style: TextStyle(
              color: gradeColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceOverview(PluginStatusSummary summary, PluginPerformanceSummary perfSummary) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '性能概览',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  '加载进度',
                  '${(summary.loadProgress * 100).toInt()}%',
                  summary.allLoaded ? Colors.green : Colors.orange,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  '激活率',
                  '${(summary.activationRate * 100).toInt()}%',
                  summary.allActive ? Colors.green : Colors.blue,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  '总内存',
                  '${perfSummary.totalMemoryUsageMB}MB',
                  perfSummary.totalMemoryUsageMB > 200 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDetailedMetrics(PluginStatusSummary summary, PluginPerformanceSummary perfSummary) {
    return ExpansionTile(
      leading: const Icon(Icons.analytics_outlined),
      title: const Text('详细性能指标'),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildMetricRow('插件总数', '${summary.total}'),
              _buildMetricRow('已加载插件', '${summary.loaded}'),
              _buildMetricRow('活跃插件', '${summary.active}'),
              _buildMetricRow('就绪插件', '${summary.ready}'),
              _buildMetricRow('错误插件', '${summary.errors}'),
              const Divider(),
              _buildMetricRow('平均初始化时间', '${perfSummary.averageInitTimeMs}ms'),
              _buildMetricRow('平均内存使用', '${perfSummary.averageMemoryUsageMB}MB'),
              _buildMetricRow('性能状态', summary.performanceStatus),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSuggestions(List<String> suggestions) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                '性能优化建议',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...suggestions.map((suggestion) => Padding(
            padding: const EdgeInsets.only(left: 28, top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                Expanded(
                  child: Text(
                    suggestion,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildActionButtons(PluginStatusSummary summary) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _performMemoryCleanup(),
            icon: const Icon(Icons.cleaning_services),
            label: const Text('内存清理'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _reloadAllPlugins(),
            icon: const Icon(Icons.refresh),
            label: const Text('重新加载'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showDetailedReport(),
            icon: const Icon(Icons.assessment),
            label: const Text('详细报告'),
          ),
        ),
      ],
    );
  }

  Future<void> _performMemoryCleanup() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在清理内存...'),
          ],
        ),
      ),
    );

    try {
      // 执行内存清理
      _statusService.lazyLoader.unloadUnusedPlugins();

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('内存清理完成'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('内存清理失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _reloadAllPlugins() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在重新加载插件...'),
          ],
        ),
      ),
    );

    try {
      // 重新加载所有插件
      final availablePlugins = _statusService.lazyLoader.getAvailablePluginIds();
      await _statusService.lazyLoader.loadMultiplePlugins(availablePlugins);

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('插件重新加载完成'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('插件重新加载失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDetailedReport() {
    final metrics = _performanceService.metrics;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('详细性能报告'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView(
            children: metrics.entries.map((entry) {
              final pluginId = entry.key;
              final metric = entry.value;

              return ExpansionTile(
                title: Text(metric.pluginName),
                subtitle: Text('ID: $pluginId'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildReportRow('初始化时间', '${metric.initTime ?? "N/A"}ms'),
                        _buildReportRow('初始化成功', '${metric.initSuccess ?? "N/A"}'),
                        _buildReportRow('激活次数', '${metric.activationCount}'),
                        _buildReportRow('激活失败', '${metric.activationFailures}'),
                        _buildReportRow('成功率', '${(metric.activationSuccessRate * 100).toInt()}%'),
                        _buildReportRow('当前内存', '${metric.currentMemoryUsageMB}MB'),
                        _buildReportRow('峰值内存', '${metric.peakMemoryUsageMB}MB'),
                        _buildReportRow('运行时长', '${metric.runtime?.inSeconds ?? "N/A"}s'),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}