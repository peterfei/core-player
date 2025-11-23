import 'package:flutter/material.dart';
import 'package:yinghe_player/core/plugin_system/core_plugin.dart';
import 'package:yinghe_player/core/plugin_system/plugin_interface.dart';
import 'enhanced_plugin_manager_screen.dart';
import 'plugin_filter_model.dart';

/// 增强插件管理功能演示应用
class EnhancedPluginDemoApp extends StatelessWidget {
  const EnhancedPluginDemoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '增强插件管理演示',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const EnhancedPluginDemoScreen(),
    );
  }
}

/// 增强插件管理演示屏幕
class EnhancedPluginDemoScreen extends StatelessWidget {
  const EnhancedPluginDemoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('增强插件管理演示'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('新功能特性'),
            _buildFeatureCards(),
            const SizedBox(height: 32),
            _buildSectionTitle('演示项目'),
            _buildDemoItems(context),
            const SizedBox(height: 32),
            _buildSectionTitle('性能优化'),
            _buildPerformanceFeatures(),
            const SizedBox(height: 32),
            _buildSectionTitle('技术改进'),
            _buildTechnicalImprovements(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFeatureCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _FeatureCard(
          icon: Icons.search,
          title: '高级搜索',
          description: '多字段搜索，支持名称、描述、作者、功能和权限过滤',
          color: Colors.blue,
        ),
        _FeatureCard(
          icon: Icons.filter_list,
          title: '智能过滤',
          description: '状态、许可证、作者等多维度过滤器',
          color: Colors.green,
        ),
        _FeatureCard(
          icon: Icons.sort,
          title: '灵活排序',
          description: '按名称、版本、状态、功能数量等多种方式排序',
          color: Colors.orange,
        ),
        _FeatureCard(
          icon: Icons.dashboard,
          title: '批量操作',
          description: '支持批量启用、停用和刷新插件',
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildDemoItems(BuildContext context) {
    return Column(
      children: [
        _DemoItem(
          title: '增强插件管理界面',
          description: '体验全新的插件管理界面，包含高级搜索和过滤功能',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const EnhancedPluginManagerScreen(),
              ),
            );
          },
          icon: Icons.extension,
          color: Colors.blue,
        ),
        const SizedBox(height: 12),
        _DemoItem(
          title: '过滤器配置演示',
          description: '查看各种过滤器的配置和效果',
          onTap: () {
            _showFilterDemo(context);
          },
          icon: Icons.filter_alt,
          color: Colors.green,
        ),
        const SizedBox(height: 12),
        _DemoItem(
          title: '性能监控演示',
          description: '展示虚拟化列表和性能监控功能',
          onTap: () {
            _showPerformanceDemo(context);
          },
          icon: Icons.speed,
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildPerformanceFeatures() {
    return Column(
      children: [
        _PerformanceItem(
          title: '虚拟化列表',
          description: '使用 VirtualizedPluginList 处理大量插件，保持流畅滚动',
          icon: Icons.list_alt,
        ),
        _PerformanceItem(
          title: '智能缓存',
          description: '自动缓存插件卡片，减少重复渲染开销',
          icon: Icons.cache,
        ),
        _PerformanceItem(
          title: '懒加载',
          description: '延迟渲染非可见插件，提升初始加载速度',
          icon: Icons.hourglass_empty,
        ),
        _PerformanceItem(
          title: '可见性检测',
          description: '精确检测组件可见性，优化资源使用',
          icon: Icons.visibility,
        ),
      ],
    );
  }

  Widget _buildTechnicalImprovements() {
    return Column(
      children: [
        _TechnicalItem(
          title: '模块化架构',
          description: '分离搜索、过滤、排序逻辑，提高代码可维护性',
        ),
        _TechnicalItem(
          title: '类型安全',
          description: '使用强类型配置对象，减少运行时错误',
        ),
        _TechnicalItem(
          title: '状态管理',
          description: '优化状态更新机制，减少不必要的重建',
        ),
        _TechnicalItem(
          title: '内存管理',
          description: '自动清理缓存，避免内存泄漏',
        ),
      ],
    );
  }

  void _showFilterDemo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '过滤器配置演示',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildFilterSection('基础过滤器', [
                      '按插件状态过滤（已启用、未启用、错误）',
                      '按许可证类型过滤（商业版、免费版）',
                      '按作者名称过滤',
                    ]),
                    _buildFilterSection('高级过滤器', [
                      '按所需权限过滤',
                      '按功能特性过滤',
                      '按版本号范围过滤',
                    ]),
                    _buildFilterSection('搜索选项', [
                      '搜索插件名称',
                      '搜索插件描述',
                      '搜索功能标签',
                      '搜索权限信息',
                      '区分大小写搜索',
                    ]),
                    _buildFilterSection('排序选项', [
                      '按名称排序',
                      '按作者排序',
                      '按版本排序',
                      '按状态排序',
                      '按功能数量排序',
                      '按许可证排序',
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, List<String> items) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _showPerformanceDemo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('性能监控'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• FPS 实时监控'),
            Text('• 内存使用统计'),
            Text('• 滚动性能分析'),
            Text('• 缓存命中率'),
            Text('• 渲染时间测量'),
            SizedBox(height: 16),
            Text(
              '性能指标会实时显示在插件列表右上角（仅调试模式）',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

/// 功能卡片组件
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 演示项目组件
class _DemoItem extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onTap;
  final IconData icon;
  final Color color;

  const _DemoItem({
    required this.title,
    required this.description,
    required this.onTap,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// 性能特性组件
class _PerformanceItem extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _PerformanceItem({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 技术改进组件
class _TechnicalItem extends StatelessWidget {
  final String title;
  final String description;

  const _TechnicalItem({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 运行演示应用的主函数
void main() {
  runApp(const EnhancedPluginDemoApp());
}