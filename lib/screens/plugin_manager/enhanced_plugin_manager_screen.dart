import 'package:flutter/material.dart';
import 'package:yinghe_player/core/plugin_system/plugin_loader.dart';
import 'package:yinghe_player/core/plugin_system/plugin_registry.dart';
import 'package:yinghe_player/core/plugin_system/core_plugin.dart';
import 'package:yinghe_player/screens/plugin_manager/plugin_card.dart';
import 'package:yinghe_player/theme/design_tokens/design_tokens.dart';
import 'plugin_filter_model.dart';
import 'advanced_search_widget.dart';

/// 增强版插件管理界面
class EnhancedPluginManagerScreen extends StatefulWidget {
  const EnhancedPluginManagerScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedPluginManagerScreen> createState() => _EnhancedPluginManagerScreenState();
}

class _EnhancedPluginManagerScreenState extends State<EnhancedPluginManagerScreen>
    with AutomaticKeepAliveClientMixin {
  List<CorePlugin> _allPlugins = [];
  List<CorePlugin> _filteredPlugins = [];
  bool _isLoading = true;
  PluginDisplayConfig _displayConfig = const PluginDisplayConfig();

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPlugins();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _applyFiltersAndSearch();
  }

  Future<void> _loadPlugins() async {
    try {
      final plugins = pluginRegistry.listAll();
      setState(() {
        _allPlugins = plugins;
        _isLoading = false;
      });
      _applyFiltersAndSearch();
    } catch (e) {
      print('Failed to load plugins: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFiltersAndSearch() {
    setState(() {
      _filteredPlugins = _allPlugins.where((plugin) {
        // 应用搜索条件
        if (!_displayConfig.searchConfig.matches(plugin)) {
          return false;
        }

        // 应用过滤器
        if (!_displayConfig.filter.matches(plugin)) {
          return false;
        }

        return true;
      }).toList();

      // 应用排序
      _filteredPlugins.sort((a, b) => _displayConfig.sortConfig.compare(a, b));
    });
  }

  Future<void> _refreshPlugins() async {
    setState(() {
      _isLoading = true;
    });
    await _loadPlugins();
  }

  void _clearAllFilters() {
    setState(() {
      _displayConfig = const PluginDisplayConfig();
      _searchController.clear();
    });
    _applyFiltersAndSearch();
  }

  void _showPluginDetails(CorePlugin plugin) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PluginDetailScreen(plugin: plugin),
      ),
    );
  }

  void _showBulkActions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildBulkActionsSheet(),
    );
  }

  Widget _buildBulkActionsSheet() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '批量操作',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('启用所有插件'),
            onTap: () {
              Navigator.pop(context);
              _bulkEnablePlugins();
            },
          ),
          ListTile(
            leading: const Icon(Icons.stop),
            title: const Text('停用所有插件'),
            onTap: () {
              Navigator.pop(context);
              _bulkDisablePlugins();
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('刷新所有插件'),
            onTap: () {
              Navigator.pop(context);
              _refreshPlugins();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _bulkEnablePlugins() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      for (final plugin in _filteredPlugins) {
        if (!plugin.isActive && plugin.state == PluginState.ready) {
          await pluginLoader.activatePlugin(plugin.metadata.id);
        }
      }
      await _refreshPlugins();
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('已批量启用插件')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('批量启用失败: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _bulkDisablePlugins() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      for (final plugin in _filteredPlugins) {
        if (plugin.isActive) {
          await pluginLoader.deactivatePlugin(plugin.metadata.id);
        }
      }
      await _refreshPlugins();
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('已批量停用插件')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('批量停用失败: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 自定义AppBar
          SliverAppBar(
            floating: true,
            pinned: true,
            snap: true,
            title: const Text('插件管理'),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: _showBulkActions,
                tooltip: '批量操作',
              ),
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
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(120),
              child: _buildSearchAndFilterSection(),
            ),
          ),

          // 过滤状态指示器
          SliverToBoxAdapter(
            child: FilterStatusWidget(
              searchConfig: _displayConfig.searchConfig,
              filter: _displayConfig.filter,
              totalPlugins: _allPlugins.length,
              filteredPlugins: _filteredPlugins.length,
              onClearFilters: _clearAllFilters,
            ),
          ),

          // 统计信息
          SliverToBoxAdapter(
            child: _buildStatisticsSection(),
          ),

          // 插件列表
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filteredPlugins.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final plugin = _filteredPlugins[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: PluginCard(
                      plugin: plugin,
                      onTap: () => _showPluginDetails(plugin),
                      onToggle: () => _togglePlugin(plugin),
                    ),
                  );
                },
                childCount: _filteredPlugins.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterSection() {
    return Column(
      children: [
        // 高级搜索组件
        AdvancedSearchWidget(
          searchConfig: _displayConfig.searchConfig,
          filter: _displayConfig.filter,
          onSearchChanged: (config) {
            setState(() {
              _displayConfig = _displayConfig.copyWith(searchConfig: config);
            });
            _applyFiltersAndSearch();
          },
          onFilterChanged: (filter) {
            setState(() {
              _displayConfig = _displayConfig.copyWith(filter: filter);
            });
            _applyFiltersAndSearch();
          },
          onClear: _clearAllFilters,
        ),

        // 排序选项
        SortOptionsWidget(
          sortConfig: _displayConfig.sortConfig,
          onSortChanged: (config) {
            setState(() {
              _displayConfig = _displayConfig.copyWith(sortConfig: config);
            });
            _applyFiltersAndSearch();
          },
        ),
      ],
    );
  }

  Widget _buildStatisticsSection() {
    final activeCount = _allPlugins.where((p) => p.isActive).length;
    final errorCount = _allPlugins.where((p) => p.state == PluginState.error).length;
    final commercialCount = _allPlugins.where((p) => p.metadata.license != PluginLicense.mit).length;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.extension,
                  label: '总插件',
                  value: _allPlugins.length.toString(),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle,
                  label: '已启用',
                  value: activeCount.toString(),
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.error_outline,
                  label: '错误',
                  value: errorCount.toString(),
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.workspace_premium,
                  label: '商业版',
                  value: commercialCount.toString(),
                  color: Colors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters = !_displayConfig.filter.isEmpty || _displayConfig.searchConfig.query.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters ? Icons.filter_alt_off : Icons.extension_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? '没有匹配的插件' : '未找到插件',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 8),
            Text(
              '尝试调整搜索条件或过滤器',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('清除所有过滤'),
            ),
          ],
        ],
      ),
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
}

/// 统计卡片组件
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
    return Container(
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
    );
  }
}

/// 插件详情界面（复用原有组件）
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
        child: DetailedPluginCard(
          plugin: plugin,
          onToggle: () async {
            try {
              if (plugin.isActive) {
                await pluginLoader.deactivatePlugin(plugin.metadata.id);
              } else {
                await pluginLoader.activatePlugin(plugin.metadata.id);
              }
              Navigator.of(context).pop();
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('操作失败: $e'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
        ),
      ),
    );
  }
}