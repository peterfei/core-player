/// CorePlayer Pro 商业插件包使用示例
/// 展示如何在主项目中使用商业插件

import 'package:flutter/material.dart';

void main() {
  runApp(const CorePlayerProDemoApp());
}

class CorePlayerProDemoApp extends StatelessWidget {
  const CorePlayerProDemoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CorePlayer Pro - 商业插件演示',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const PluginDemoScreen(),
    );
  }
}

class PluginDemoScreen extends StatefulWidget {
  const PluginDemoScreen({Key? key}) : super(key: key);

  @override
  State<PluginDemoScreen> createState() => _PluginDemoScreenState();
}

class _PluginDemoScreenState extends State<PluginDemoScreen> {
  int _currentFeature = 0;

  final List<PluginFeature> _features = [
    PluginFeature(
      name: 'HEVC解码器',
      description: '硬件加速的4K/8K视频解码',
      icon: Icons.high_quality,
      status: '已激活',
    ),
    PluginFeature(
      name: '智能字幕',
      description: 'AI驱动的多语言字幕生成',
      icon: Icons.subtitles,
      status: '已激活',
    ),
    PluginFeature(
      name: '多设备同步',
      description: '跨设备设置和数据同步',
      icon: Icons.sync,
      status: '已激活',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CorePlayer Pro 商业版'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () => _showAboutDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 版本信息卡片
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CorePlayer Pro v2.0.0',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '专业视频播放器插件包',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),

          // 功能列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _features.length,
              itemBuilder: (context, index) {
                final feature = _features[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Icon(
                        feature.icon,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    title: Text(
                      feature.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(feature.description),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        feature.status,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    onTap: () => _showFeatureDetails(context, feature),
                  ),
                );
              },
            ),
          ),

          // 底部按钮
          Container(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => _showPerformanceInfo(context),
              icon: const Icon(Icons.speed),
              label: const Text('性能指标'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFeatureDetails(BuildContext context, PluginFeature feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(feature.icon),
            const SizedBox(width: 8),
            Text(feature.name),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(feature.description),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  feature.status,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showPerformanceInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('性能指标'),
        content: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            PerformanceMetric(label: '启动时间', value: '<500ms'),
            PerformanceMetric(label: '内存使用', value: '<50MB'),
            PerformanceMetric(label: '解码速度', value: '60fps'),
            PerformanceMetric(label: '同步延迟', value: '<100ms'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'CorePlayer Pro',
      applicationVersion: '2.0.0',
      applicationIcon: const Icon(Icons.movie, size: 48),
      children: [
        const Text('专业级视频播放器商业插件包'),
        const SizedBox(height: 16),
        const Text('包含功能:'),
        const Text('• HEVC/H.265 硬件解码'),
        const Text('• AI 智能字幕生成'),
        const Text('• 多设备云同步'),
        const Text('• 4K/8K 视频支持'),
      ],
    );
  }
}

class PluginFeature {
  final String name;
  final String description;
  final IconData icon;
  final String status;

  PluginFeature({
    required this.name,
    required this.description,
    required this.icon,
    required this.status,
  });
}

class PerformanceMetric extends StatelessWidget {
  final String label;
  final String value;

  const PerformanceMetric({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}