import 'package:flutter/material.dart';
import 'package:yinghe_player/core/plugin_system/plugin_loader.dart';
import 'package:yinghe_player/core/plugin_system/plugin_registry.dart';
import 'package:yinghe_player/core/plugin_system/core_plugin.dart';
import 'package:yinghe_player/screens/plugin_manager/plugin_card.dart';
import 'package:yinghe_player/theme/design_tokens/design_tokens.dart';

/// 插件管理界面
class PluginManagerScreen extends StatefulWidget {
  const PluginManagerScreen({Key? key}) : super(key: key);

  @override
  State<PluginManagerScreen> createState() => _PluginManagerScreenState();
}

class _PluginManagerScreenState extends State<PluginManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<CorePlugin> _allPlugins = [];
  List<CorePlugin> _filteredPlugins = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPlugins();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _searchQuery = query;
      _filteredPlugins = _allPlugins.where((plugin) {
        return plugin.metadata.name.toLowerCase().contains(query) ||
               plugin.metadata.description.toLowerCase().contains(query) ||
               plugin.metadata.author.toLowerCase().contains(query) ||
               plugin.metadata.capabilities.any((cap) => cap.toLowerCase().contains(query));
      }).toList();
    });
  }

  Future<void> _loadPlugins() async {
    try {
      final plugins = pluginRegistry.listAll();
      setState(() {
        _allPlugins = plugins;
        _filteredPlugins = plugins;
        _isLoading = false;
      });
    } catch (e) {
      print('Failed to load plugins: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<CorePlugin> _getPluginsByTab(int tabIndex) {
    if (tabIndex == 0) {
      // All plugins
      return _filteredPlugins;
    } else if (tabIndex == 1) {
      // Active plugins
      return _filteredPlugins.where((p) => p.isActive).toList();
    } else {
      // Available plugins
      return _filteredPlugins.where((p) => !p.isActive).toList();
    }
  }

  Future<void> _refreshPlugins() async {
    setState(() {
      _isLoading = true;
    });
    await _loadPlugins();
  }

  void _showPluginDetails(CorePlugin plugin) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PluginDetailScreen(plugin: plugin),
      ),
    );
  }

  void _showEditionInfo() {
    final isCommunityEdition = pluginLoader.config.isCommunityEdition;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCommunityEdition ? '社区版' : '专业版'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCommunityEdition
                  ? '当前运行的是社区版，包含核心播放功能和插件占位符。'
                  : '当前运行的是专业版，包含所有媒体服务器插件功能。',
            ),
            const SizedBox(height: 16),
            if (isCommunityEdition) ...[
              Text(
                '升级到专业版可获得：',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text('• SMB/NAS 网络共享访问'),
              const Text('• Emby 媒体服务器支持'),
              const Text('• Jellyfin 媒体库集成'),
              const Text('• Plex 服务器连接'),
              const Text('• 远程视频流播放'),
              const Text('• 技术支持'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
          if (isCommunityEdition)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showUpgradeDialog();
              },
              child: const Text('升级到专业版'),
            ),
        ],
      ),
    );
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('升级到专业版'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium, size: 64, color: Colors.amber),
            SizedBox(height: 16),
            Text('专业版提供完整的媒体服务器集成功能'),
            SizedBox(height: 8),
            Text('请访问 core-player.com 了解详情'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('访问官网'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('插件管理'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '全部'),
            Tab(text: '已启用'),
            Tab(text: '未启用'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showEditionInfo,
            tooltip: '版本信息',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshPlugins,
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索插件...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Plugin statistics
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StatCard(
                  icon: Icons.extension,
                  label: '总插件',
                  value: _allPlugins.length.toString(),
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.check_circle,
                  label: '已启用',
                  value: _allPlugins.where((p) => p.isActive).length.toString(),
                  color: AppColors.success,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.error_outline,
                  label: '错误',
                  value: _allPlugins.where((p) => p.hasError).length.toString(),
                  color: AppColors.error,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Plugin list
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPluginList(0),
                _buildPluginList(1),
                _buildPluginList(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPluginList(int tabIndex) {
    final plugins = _getPluginsByTab(tabIndex);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (plugins.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tabIndex == 0
                  ? Icons.extension_outlined
                  : tabIndex == 1
                      ? Icons.check_circle_outline
                      : Icons.disabled_by_default,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              tabIndex == 0
                  ? '未找到插件'
                  : tabIndex == 1
                      ? '没有已启用的插件'
                      : '没有可用的插件',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '尝试调整搜索条件',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: plugins.length,
      itemBuilder: (context, index) {
        final plugin = plugins[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PluginCard(
            plugin: plugin,
            onTap: () => _showPluginDetails(plugin),
            onToggle: () => _togglePlugin(plugin),
          ),
        );
      },
    );
  }

  Future<void> _togglePlugin(CorePlugin plugin) async {
    try {
      if (plugin.isActive) {
        await pluginLoader.deactivatePlugin(plugin.metadata.id);
      } else {
        await pluginLoader.activatePlugin(plugin.metadata.id);
      }
      await _refreshPlugins();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

/// 统计卡片
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 插件详情界面
class PluginDetailScreen extends StatelessWidget {
  final CorePlugin plugin;

  const PluginDetailScreen({
    Key? key,
    required this.plugin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final metadata = plugin.metadata;

    return Scaffold(
      appBar: AppBar(
        title: Text(metadata.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              final settingsScreen = plugin.buildSettingsScreen();
              if (settingsScreen != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => settingsScreen,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('此插件没有设置界面'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plugin header
            Row(
              children: [
                Icon(
                  metadata.icon,
                  size: 48,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metadata.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        'v${metadata.version}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStateColor(plugin.state).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStateColor(plugin.state).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _getStateText(plugin.state),
                    style: TextStyle(
                      color: _getStateColor(plugin.state),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Description
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '描述',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(metadata.description),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '信息',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      label: 'ID',
                      value: metadata.id,
                    ),
                    _InfoRow(
                      label: '作者',
                      value: metadata.author,
                    ),
                    if (metadata.homepage != null)
                      _InfoRow(
                        label: '主页',
                        value: metadata.homepage!,
                      ),
                    _InfoRow(
                      label: '许可证',
                      value: metadata.license.displayName,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Capabilities
            if (metadata.capabilities.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '功能特性',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: metadata.capabilities
                            .map((capability) => Chip(
                                  label: Text(capability),
                                  backgroundColor: Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.1),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Permissions
            if (metadata.permissions.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '所需权限',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      ...metadata.permissions.map((permission) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.security,
                              size: 16,
                              color: Colors.orange[700],
                            ),
                            const SizedBox(width: 8),
                            Text(permission.displayName),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStateColor(PluginState state) {
    switch (state) {
      case PluginState.active:
        return Colors.green;
      case PluginState.error:
        return Colors.red;
      case PluginState.inactive:
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _getStateText(PluginState state) {
    switch (state) {
      case PluginState.uninitialized:
        return '未初始化';
      case PluginState.initializing:
        return '初始化中';
      case PluginState.ready:
        return '就绪';
      case PluginState.active:
        return '已启用';
      case PluginState.inactive:
        return '未启用';
      case PluginState.error:
        return '错误';
      case PluginState.disposed:
        return '已释放';
    }
  }
}

/// 信息行组件
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}