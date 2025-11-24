import 'package:flutter/material.dart';
import '../plugins/plugin_registry.dart';
import '../plugins/core/plugin_system/core_plugin.dart';

/// 插件演示组件
///
/// 展示插件系统的各种功能，包括：
/// - 插件列表展示
/// - 插件状态管理
/// - 插件功能演示
/// - 插件统计信息
class PluginDemoWidget extends StatefulWidget {
  const PluginDemoWidget({super.key});

  @override
  State<PluginDemoWidget> createState() => _PluginDemoWidgetState();
}

class _PluginDemoWidgetState extends State<PluginDemoWidget> {
  final PluginRegistry _registry = PluginRegistry.instance;
  Map<String, CorePlugin> _plugins = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializePlugins();
  }

  Future<void> _initializePlugins() async {
    try {
      setState(() => _isLoading = true);

      // 初始化插件系统
      await _registry.initialize();

      // 创建和激活一些示例插件
      final pluginIds = [
        'coreplayer.subtitle',
        'coreplayer.audio_effects',
        'coreplayer.theme_manager',
        'third_party.youtube',
        'third_party.bilibili',
      ];

      for (final pluginId in pluginIds) {
        final plugin = await _registry.createPlugin(pluginId);
        if (plugin != null) {
          await _registry.activatePlugin(pluginId);
        }
      }

      setState(() {
        _plugins = _registry.getAllPlugins();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('插件初始化失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('插件系统演示'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializePlugins,
            tooltip: '重新加载插件',
          ),
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: _showSystemInfo,
            tooltip: '系统信息',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatsHeader(),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildPluginListView(),
                      _buildCategoryView(),
                      _buildFeatureDemoView(),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const TabBar(
        tabs: [
          Tab(icon: Icon(Icons.extension), text: '插件列表'),
          Tab(icon: Icon(Icons.category), text: '分类浏览'),
          Tab(icon: Icon(Icons.play_circle), text: '功能演示'),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    final stats = _registry.getStats();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '插件统计',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatItem('总插件', '${stats.totalRegistered}', Icons.extension),
                  _buildStatItem('内置', '${stats.builtinCount}', Icons.build),
                  _buildStatItem('商业', '${stats.commercialCount}', Icons.monetization_on),
                  _buildStatItem('第三方', '${stats.thirdPartyCount}', Icons.people),
                  _buildStatItem('活跃', '${stats.activeCount}', Icons.power),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 24, color: Theme.of(context).primaryColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPluginListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _plugins.length,
      itemBuilder: (context, index) {
        final pluginId = _plugins.keys.elementAt(index);
        final plugin = _plugins[pluginId]!;
        final metadata = plugin.metadata;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(metadata.icon),
            ),
            title: Text(metadata.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(metadata.description),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Chip(
                      label: Text(metadata.version),
                      backgroundColor: Colors.blue.shade100,
                      labelStyle: const TextStyle(fontSize: 10),
                    ),
                    const SizedBox(width: 4),
                    Chip(
                      label: Text(_getStateText(plugin.state)),
                      backgroundColor: _getStateColor(plugin.state),
                      labelStyle: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    plugin.state == PluginState.active
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  onPressed: () => _togglePlugin(pluginId),
                  tooltip: plugin.state == PluginState.active ? '停用' : '启用',
                ),
                PopupMenuButton<String>(
                  onSelected: (action) => _handlePluginAction(pluginId, action),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'reload',
                      child: Row(
                        children: [
                          Icon(Icons.refresh),
                          SizedBox(width: 8),
                          Text('重新加载'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'unload',
                      child: Row(
                        children: [
                          Icon(Icons.delete),
                          SizedBox(width: 8),
                          Text('卸载'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'info',
                      child: Row(
                        children: [
                          Icon(Icons.info),
                          SizedBox(width: 8),
                          Text('详细信息'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryView() {
    final categories = [
      'media',
      'audio',
      'video',
      'network',
      'streaming',
      'ui',
      'player',
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final plugins = _registry.getPluginsByCategory(category);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ExpansionTile(
            leading: Icon(_getCategoryIcon(category)),
            title: Text(_getCategoryName(category)),
            subtitle: Text('${plugins.length} 个插件'),
            children: plugins.map((pluginInfo) {
              return ListTile(
                title: Text(pluginInfo.name),
                subtitle: Text(pluginInfo.description),
                trailing: pluginInfo.isCommunityEdition
                    ? const Chip(label: Text('社区版'), backgroundColor: Colors.green)
                    : const Chip(label: Text('专业版'), backgroundColor: Colors.orange),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildFeatureDemoView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFeatureDemoCard(
          '字幕功能演示',
          '演示字幕插件的加载、解析和显示功能',
          Icons.subtitles,
          Colors.blue,
          () => _demoSubtitleFeature(),
        ),
        _buildFeatureDemoCard(
          '音频效果演示',
          '演示10频段均衡器和音频增强功能',
          Icons.equalizer,
          Colors.purple,
          () => _demoAudioEffectsFeature(),
        ),
        _buildFeatureDemoCard(
          '主题切换演示',
          '演示主题管理和实时切换功能',
          Icons.palette,
          Colors.orange,
          () => _demoThemeFeature(),
        ),
        _buildFeatureDemoCard(
          '视频增强演示',
          '演示视频画面增强和处理功能',
          Icons.high_quality,
          Colors.green,
          () => _demoVideoEnhancementFeature(),
        ),
        _buildFeatureDemoCard(
          'YouTube集成演示',
          '演示YouTube视频搜索和播放功能',
          Icons.play_circle_filled,
          Colors.red,
          () => _demoYouTubeFeature(),
        ),
      ],
    );
  }

  Widget _buildFeatureDemoCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                child: Icon(icon, color: Colors.white),
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
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
        ),
      ),
    );
  }

  String _getStateText(PluginState state) {
    switch (state) {
      case PluginState.uninitialized:
        return '未初始化';
      case PluginState.initialized:
        return '已初始化';
      case PluginState.active:
        return '活跃';
      case PluginState.ready:
        return '就绪';
      case PluginState.error:
        return '错误';
      case PluginState.disposed:
        return '已销毁';
    }
  }

  Color _getStateColor(PluginState state) {
    switch (state) {
      case PluginState.active:
        return Colors.green.shade100;
      case PluginState.error:
        return Colors.red.shade100;
      case PluginState.ready:
        return Colors.blue.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'media':
        return Icons.movie;
      case 'audio':
        return Icons.audiotrack;
      case 'video':
        return Icons.videocam;
      case 'network':
        return Icons.wifi;
      case 'streaming':
        return Icons.live_tv;
      case 'ui':
        return Icons.palette;
      case 'player':
        return Icons.play_circle;
      default:
        return Icons.extension;
    }
  }

  String _getCategoryName(String category) {
    switch (category) {
      case 'media':
        return '媒体处理';
      case 'audio':
        return '音频效果';
      case 'video':
        return '视频处理';
      case 'network':
        return '网络服务';
      case 'streaming':
        return '流媒体';
      case 'ui':
        return '用户界面';
      case 'player':
        return '播放器';
      default:
        return '其他';
    }
  }

  Future<void> _togglePlugin(String pluginId) async {
    final plugin = _registry.getPlugin(pluginId);
    if (plugin == null) return;

    try {
      if (plugin.state == PluginState.active) {
        await _registry.deactivatePlugin(pluginId);
      } else {
        await _registry.activatePlugin(pluginId);
      }
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('插件操作失败: $e')),
      );
    }
  }

  Future<void> _handlePluginAction(String pluginId, String action) async {
    try {
      switch (action) {
        case 'reload':
          await _registry.reloadPlugin(pluginId);
          break;
        case 'unload':
          await _registry.unloadPlugin(pluginId);
          break;
        case 'info':
          _showPluginInfo(pluginId);
          break;
      }
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e')),
      );
    }
  }

  void _showPluginInfo(String pluginId) {
    final plugin = _registry.getPlugin(pluginId);
    if (plugin == null) return;

    final metadata = plugin.metadata;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(metadata.name),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ID: ${metadata.id}'),
            Text('版本: ${metadata.version}'),
            Text('作者: ${metadata.author}'),
            Text('描述: ${metadata.description}'),
            Text('许可证: ${metadata.license.toString()}'),
            Text('功能: ${metadata.capabilities.join(', ')}'),
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

  void _showSystemInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('插件系统信息'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('插件注册表版本: 2.0.0'),
            Text('插件管理器版本: 2.0.0'),
            Text('支持的许可证类型: ${PluginLicense.values.length}'),
            Text('支持的仓库类型: ${PluginRepositoryType.values.length}'),
            const SizedBox(height: 16),
            const Text('系统特性:', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('✓ 懒加载机制'),
            const Text('✓ 内存监控'),
            const Text('✓ 错误恢复'),
            const Text('✓ 热更新支持'),
            const Text('✓ 版本管理'),
            const Text('✓ 安全检查'),
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

  void _demoSubtitleFeature() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('字幕功能演示：支持SRT、ASS、VTT等多种格式')),
    );
  }

  void _demoAudioEffectsFeature() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('音频效果演示：10频段均衡器，支持多种预设')),
    );
  }

  void _demoThemeFeature() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('主题功能演示：内置5种主题，支持自定义创建')),
    );
  }

  void _demoVideoEnhancementFeature() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('视频增强演示：HDR、AI放大、视频稳定等功能')),
    );
  }

  void _demoYouTubeFeature() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('YouTube集成演示：视频搜索、播放、字幕下载')),
    );
  }
}