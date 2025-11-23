/// CorePlayer Pro 专业版功能演示
/// 展示商业插件包的所有高级功能

import 'package:flutter/material.dart';
import 'dart:async';

void main() {
  runApp(const CorePlayerProDemoApp());
}

class CorePlayerProDemoApp extends StatelessWidget {
  const CorePlayerProDemoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CorePlayer Pro - 专业版演示',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const ProDemoScreen(),
    );
  }
}

class ProDemoScreen extends StatefulWidget {
  const ProDemoScreen({Key? key}) : super(key: key);

  @override
  State<ProDemoScreen> createState() => _ProDemoScreenState();
}

class _ProDemoScreenState extends State<ProDemoScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // 性能监控
  Map<String, dynamic> _performanceStats = {};
  Timer? _performanceTimer;

  // 插件状态
  Map<String, bool> _pluginStatus = {
    'HEVC解码器': false,
    'AI字幕': false,
    '多设备同步': false,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializePlugins();
    _startPerformanceMonitoring();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _performanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializePlugins() async {
    // 模拟插件初始化
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _pluginStatus['HEVC解码器'] = true;
      _pluginStatus['AI字幕'] = true;
      _pluginStatus['多设备同步'] = true;
    });
  }

  void _startPerformanceMonitoring() {
    _performanceTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      setState(() {
        _performanceStats = {
          'CPU使用率': '${(15 + (DateTime.now().millisecond % 20)).toString()}%',
          '内存使用': '${(120 + (DateTime.now().millisecond % 80)).toString()}MB',
          'GPU使用率': '${(25 + (DateTime.now().millisecond % 15)).toString()}%',
          '解码速度': '${58 + (DateTime.now().millisecond % 5)}fps',
          '同步延迟': '${30 + (DateTime.now().millisecond % 50)}ms',
        };
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text('CorePlayer Pro'),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.movie_filter,
                      size: 64,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.dashboard), text: '概览'),
                  Tab(icon: Icon(Icons.high_quality), text: 'HEVC解码'),
                  Tab(icon: Icon(Icons.subtitles), text: 'AI字幕'),
                  Tab(icon: Icon(Icons.sync), text: '多设备同步'),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildHEVCTab(),
            _buildSubtitleTab(),
            _buildSyncTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPerformanceDialog,
        icon: const Icon(Icons.speed),
        label: const Text('性能监控'),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 版本信息卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.workspace_premium, color: Colors.amber),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CorePlayer Pro',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '专业视频播放器 v2.0.0',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('专业版功能特性：'),
                  const SizedBox(height: 8),
                  ...['✨ HEVC/H.265 4K/8K 硬件解码',
                        '🤖 AI 智能字幕生成',
                        '☁️ 多设备云端同步',
                        '🎨 专业色彩管理',
                        '🚀 极致性能优化']
                      .map((feature) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            Expanded(child: Text(feature)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 插件状态
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '插件状态',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  ..._pluginStatus.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          entry.value ? Icons.check_circle : Icons.error,
                          color: entry.value ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(entry.key)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: entry.value ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            entry.value ? '已激活' : '未激活',
                            style: TextStyle(
                              color: entry.value ? Colors.green : Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 性能指标
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '实时性能',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  ..._performanceStats.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text(
                          entry.value.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHEVCTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.high_quality, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'HEVC/H.265 解码器',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('专业级4K/8K视频解码能力'),
                  const SizedBox(height: 16),
                  _buildFeatureTile('硬件加速', true, 'GPU加速解码'),
                  _buildFeatureTile('4K支持', true, '3840×2160分辨率'),
                  _buildFeatureTile('8K支持', true, '7680×4320分辨率'),
                  _buildFeatureTile('10位色深', true, 'HDR内容支持'),
                  _buildFeatureTile('多线程', true, '并行解码处理'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _testHEVCDecoding,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('测试解码性能'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.subtitles, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'AI 智能字幕',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('基于人工智能的字幕生成和翻译'),
                  const SizedBox(height: 16),
                  _buildFeatureTile('语音识别', true, '支持20+语言'),
                  _buildFeatureTile('实时翻译', true, '多语言互译'),
                  _buildFeatureTile('情感分析', true, '字幕情感标记'),
                  _buildFeatureTile('风格化', true, '多种字幕样式'),
                  _buildFeatureTile('时间轴精确', true, '毫秒级同步'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _testSubtitleGeneration,
                      icon: const Icon(Icons.translate),
                      label: const Text('生成智能字幕'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sync, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        '多设备同步',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('跨设备的无缝数据同步体验'),
                  const SizedBox(height: 16),
                  _buildFeatureTile('实时同步', true, '<100ms延迟'),
                  _buildFeatureTile('冲突解决', true, '智能合并策略'),
                  _buildFeatureTile('增量同步', true, '只同步变化数据'),
                  _buildFeatureTile('离线支持', true, '断网继续使用'),
                  _buildFeatureTile('安全加密', true, '端到端加密'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _testMultiDeviceSync,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('测试数据同步'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile(String title, bool enabled, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.circle_outlined,
            color: enabled ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _testHEVCDecoding() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('HEVC解码测试'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('正在测试4K视频解码性能...'),
            const SizedBox(height: 16),
            _buildPerformanceItem('解码速度', '60fps'),
            _buildPerformanceItem('CPU使用', '15%'),
            _buildPerformanceItem('内存占用', '180MB'),
            _buildPerformanceItem('硬件加速', '已启用'),
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

  void _testSubtitleGeneration() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI字幕生成测试'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('正在分析音频并生成字幕...'),
            const SizedBox(height: 16),
            const Text('00:00:01,234 --> 00:00:04,567'),
            Text('欢迎来到CorePlayer Pro专业版',
                 style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 8),
            const Text('00:00:05,000 --> 00:00:08,123'),
            Text('体验极致的视频播放效果',
                 style: TextStyle(color: Theme.of(context).colorScheme.primary)),
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

  void _testMultiDeviceSync() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('多设备同步测试'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('正在同步到云端...'),
            const SizedBox(height: 16),
            _buildSyncItem('播放历史', '已同步', Colors.green),
            _buildSyncItem('收藏夹', '已同步', Colors.green),
            _buildSyncItem('设置偏好', '已同步', Colors.green),
            _buildSyncItem('字幕样式', '已同步', Colors.green),
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

  Widget _buildPerformanceItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        ],
      ),
    );
  }

  Widget _buildSyncItem(String label, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Row(
            children: [
              Icon(Icons.check_circle, color: color, size: 16),
              const SizedBox(width: 4),
              Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  void _showPerformanceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('性能监控'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('实时系统资源监控'),
              const SizedBox(height: 16),
              ..._performanceStats.entries.map((entry) =>
                _buildPerformanceItem(entry.key, entry.value.toString())),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text('系统运行正常'),
                  ],
                ),
              ),
            ],
          ),
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
}