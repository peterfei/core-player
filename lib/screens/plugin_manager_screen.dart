import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/plugin_system/plugin_loader.dart';
import '../core/plugin_system/plugin_interface.dart';
import '../core/plugin_system/core_plugin.dart';
import '../services/plugin_status_service.dart';
import '../widgets/plugin_error_handler.dart';
import '../widgets/plugin_performance_dashboard.dart';
import 'plugin_manager/plugin_filter_model.dart';

import 'package:yinghe_player/widgets/update/update_notification_dialog.dart';
import 'package:yinghe_player/screens/plugin_update_management_page.dart';
import 'package:yinghe_player/plugins/plugin_registry_update_extension.dart';
import 'package:yinghe_player/core/plugin_system/plugin_registry.dart';

class PluginManagerScreen extends StatefulWidget {
  const PluginManagerScreen({super.key});

  @override
  State<PluginManagerScreen> createState() => _PluginManagerScreenState();
}

class _PluginManagerScreenState extends State<PluginManagerScreen>
    with SingleTickerProviderStateMixin {
  List<CorePlugin> _allPlugins = [];
  List<CorePlugin> _filteredPlugins = [];
  bool _isLoading = true;
  String? _error;

  // 增强功能相关状态
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  PluginDisplayConfig _displayConfig = const PluginDisplayConfig();
  bool _isSearchExpanded = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadPlugins();
    _searchController.addListener(_onSearchChanged);
    
    // 延迟检查更新
    Future.delayed(const Duration(seconds: 1), _checkAutoUpdates);
  }

  Future<void> _checkAutoUpdates() async {
    try {
      final updates = await PluginRegistry().checkAllPluginUpdates();
      if (updates.isNotEmpty && mounted) {
        showDialog(
          context: context,
          builder: (context) => UpdateNotificationDialog(
            updates: updates,
            onUpdateNow: () {
              Navigator.of(context).pop();
              _showUpdateManagementPage();
            },
            onUpdateLater: () {
              Navigator.of(context).pop();
            },
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Auto update check failed: $e');
      }
    }
  }

  void _showUpdateManagementPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PluginUpdateManagementPage(),
      ),
    );
  }

  void _onTabChanged() {
    // 当tab切换时，强制重建UI以刷新插件列表
    // 移除 indexIsChanging 检查，确保立即响应用户点击
    setState(() {
      // 强制重建所有 tab 的内容
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _applyFiltersAndSearch();
  }

  Future<void> _loadPlugins() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 使用插件状态服务加载插件
      final pluginService = PluginStatusService();
      await pluginService.initialize();

      setState(() {
        _allPlugins = pluginService.plugins.values.toList();
        _filteredPlugins = _allPlugins;
        _isLoading = false;
      });
      _applyFiltersAndSearch();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFiltersAndSearch() {
    final searchQuery = _searchController.text.toLowerCase();

    setState(() {
      _filteredPlugins = _allPlugins.where((plugin) {
        // 应用搜索条件
        if (searchQuery.isNotEmpty) {
          final matchesSearch = plugin.metadata.name.toLowerCase().contains(searchQuery) ||
              plugin.metadata.description.toLowerCase().contains(searchQuery) ||
              plugin.metadata.author.toLowerCase().contains(searchQuery) ||
              plugin.metadata.capabilities.any((cap) => cap.toLowerCase().contains(searchQuery));
          if (!matchesSearch) return false;
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

  List<CorePlugin> _getPluginsByTab(int tabIndex) {
    List<CorePlugin> result;
    if (tabIndex == 0) {
      // All plugins - 返回新列表以触发UI更新
      result = List.from(_filteredPlugins);
    } else if (tabIndex == 1) {
      // Active plugins
      result = _filteredPlugins.where((p) => p.isActive).toList();
    } else {
      // Available plugins
      result = _filteredPlugins.where((p) => !p.isActive).toList();
    }

    if (kDebugMode) {
      print('Tab $tabIndex: 显示 ${result.length} 个插件 (总共 ${_filteredPlugins.length} 个)');
      if (tabIndex == 1) {
        print('  已启用的插件: ${result.map((p) => p.metadata.name).join(", ")}');
      } else if (tabIndex == 2) {
        print('  未启用的插件: ${result.map((p) => p.metadata.name).join(", ")}');
      }
    }

    return result;
  }

  void _clearAllFilters() {
    setState(() {
      _displayConfig = const PluginDisplayConfig();
      _searchController.clear();
    });
    _applyFiltersAndSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('插件管理'),
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            // 显式触发重建以更新插件列表
            setState(() {});
          },
          tabs: const [
            Tab(text: '全部'),
            Tab(text: '已启用'),
            Tab(text: '未启用'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.system_update),
            onPressed: _showUpdateManagementPage,
            tooltip: '检查更新',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              setState(() {
                _isSearchExpanded = !_isSearchExpanded;
              });
            },
            tooltip: '搜索和过滤',
          ),
          if (_hasActiveFilters())
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearAllFilters,
              tooltip: '清除所有过滤',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPlugins,
            tooltip: '刷新插件状态',
          ),
        ],
      ),
      body: _buildEnhancedBody(),
    );
  }

  bool _hasActiveFilters() {
    return _searchController.text.isNotEmpty ||
           !_displayConfig.filter.isEmpty ||
           _filteredPlugins.length != _allPlugins.length;
  }

  Widget _buildEnhancedBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载插件...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('插件加载失败', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPlugins,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              // 搜索栏
              _buildSearchBar(),

              // 版本信息卡片
              _buildEditionInfo(),

              // 统计信息
              _buildStatistics(),

              // 性能仪表盘
              const PluginPerformanceDashboard(),

              const Divider(),

              // 过滤状态指示器
              _buildFilterStatus(),
            ],
          ),
        ),

        // 插件列表 - 直接根据选中的tab显示，避免TabBarView缓存问题
        _buildPluginListSliver(_tabController.index),
      ],
    );
  }

  Widget _buildSearchBar() {
    if (!_isSearchExpanded) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 基础搜索
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索插件...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          // 过滤选项
          _buildFilterOptions(),
        ],
      ),
    );
  }

  Widget _buildFilterOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '快速过滤',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),

          // 状态过滤
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('已启用'),
                selected: _displayConfig.filter.onlyEnabled,
                onSelected: (value) {
                  setState(() {
                    _displayConfig = _displayConfig.copyWith(
                      filter: _displayConfig.filter.copyWith(onlyEnabled: value),
                    );
                  });
                  _applyFiltersAndSearch();
                },
              ),
              FilterChip(
                label: const Text('错误状态'),
                selected: _displayConfig.filter.onlyWithError,
                onSelected: (value) {
                  setState(() {
                    _displayConfig = _displayConfig.copyWith(
                      filter: _displayConfig.filter.copyWith(onlyWithError: value),
                    );
                  });
                  _applyFiltersAndSearch();
                },
              ),
              FilterChip(
                label: const Text('商业版'),
                selected: _displayConfig.filter.onlyCommercial,
                onSelected: (value) {
                  setState(() {
                    _displayConfig = _displayConfig.copyWith(
                      filter: _displayConfig.filter.copyWith(onlyCommercial: value),
                    );
                  });
                  _applyFiltersAndSearch();
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 排序选项
          Row(
            children: [
              Icon(Icons.sort, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                '排序：',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<PluginSortOption>(
                  value: _displayConfig.sortConfig.option,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: PluginSortOption.name,
                      child: Text('名称'),
                    ),
                    DropdownMenuItem(
                      value: PluginSortOption.author,
                      child: Text('作者'),
                    ),
                    DropdownMenuItem(
                      value: PluginSortOption.status,
                      child: Text('状态'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _displayConfig = _displayConfig.copyWith(
                          sortConfig: _displayConfig.sortConfig.copyWith(option: value),
                        );
                      });
                      _applyFiltersAndSearch();
                    }
                  },
                ),
              ),
              IconButton(
                icon: Icon(
                  _displayConfig.sortConfig.order == SortOrder.ascending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                ),
                onPressed: () {
                  setState(() {
                    _displayConfig = _displayConfig.copyWith(
                      sortConfig: _displayConfig.sortConfig.copyWith(
                        order: _displayConfig.sortConfig.order == SortOrder.ascending
                            ? SortOrder.descending
                            : SortOrder.ascending,
                      ),
                    );
                  });
                  _applyFiltersAndSearch();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    final activeCount = _allPlugins.where((p) => p.isActive).length;
    final errorCount = _allPlugins.where((p) => p.state == PluginState.error).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.extension,
              label: '总插件',
              value: _allPlugins.length.toString(),
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.check_circle,
              label: '已启用',
              value: activeCount.toString(),
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.error_outline,
              label: '错误',
              value: errorCount.toString(),
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterStatus() {
    if (!_hasActiveFilters()) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 16, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '显示 ${_filteredPlugins.length} / ${_allPlugins.length} 个插件',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: _clearAllFilters,
            child: const Text('清除过滤'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }



  /// 构建 Sliver 版本的插件列表（用于 CustomScrollView）
  Widget _buildPluginListSliver(int tabIndex) {
    final plugins = _getPluginsByTab(tabIndex);

    if (plugins.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
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
                    ? (_hasActiveFilters() ? '没有匹配的插件' : '未找到插件')
                    : tabIndex == 1
                        ? '没有已启用的插件'
                        : '没有可用的插件',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
              if (_hasActiveFilters() && tabIndex == 0) ...[
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
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.system_update, color: Colors.blue),
                ),
                title: const Text('检查插件更新'),
                subtitle: const Text('查看并管理所有插件的更新'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: _showUpdateManagementPage,
              ),
            );
          }
          final plugin = plugins[index - 1];
          return _buildPluginCard(plugin);
        },
        childCount: plugins.length + 1,
      ),
    );
  }

  Widget _buildEditionInfo() {
    final isCommunity = EditionConfig.isCommunityEdition;
    final editionText = isCommunity ? '社区版' : '专业版';
    final editionColor = isCommunity ? Colors.orange : Colors.green;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: editionColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: editionColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCommunity ? Icons.star_outline : Icons.star,
                color: editionColor,
              ),
              const SizedBox(width: 8),
              Text(
                '当前版本：$editionText',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: editionColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isCommunity
              ? '社区版包含基础播放功能，升级专业版解锁媒体服务器支持。'
              : '专业版包含全部功能，支持SMB、Emby、Jellyfin等媒体服务器。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (isCommunity) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _showUpgradeDialog(),
              icon: const Icon(Icons.upgrade),
              label: const Text('升级到专业版'),
              style: ElevatedButton.styleFrom(
                backgroundColor: editionColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPluginCard(CorePlugin plugin) {
    final metadata = plugin.metadata;
    final isActive = plugin.isActive;
    final isAvailable = plugin.isReady;
    final hasError = plugin.hasError;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (hasError) {
      statusColor = Colors.red;
      statusIcon = Icons.error_outline;
      statusText = '错误';
    } else if (isActive) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
      statusText = '已激活';
    } else if (isAvailable) {
      statusColor = Colors.orange;
      statusIcon = Icons.pending_outlined;
      statusText = '就绪';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.help_outline;
      statusText = '未初始化';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(metadata.icon, color: statusColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                metadata.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 16, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(metadata.description),
            const SizedBox(height: 4),
            Text(
              '版本 ${metadata.version} • ${metadata.author}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPluginDetails(plugin),
                const SizedBox(height: 16),
                _buildPluginActions(plugin),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPluginDetails(CorePlugin plugin) {
    final metadata = plugin.metadata;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('插件ID', metadata.id),
        _buildDetailRow('状态', plugin.state.toString()),
        _buildDetailRow('权限', metadata.permissions.map((p) => p.toString()).join(', ')
            .isEmpty ? '无特殊权限' : metadata.permissions.map((p) => p.toString()).join(', ')),
        _buildDetailRow('功能', metadata.capabilities.join(', ')
            .isEmpty ? '基础功能' : metadata.capabilities.join(', ')),
        if (metadata.license != PluginLicense.unknown)
          _buildDetailRow('许可证', metadata.license.toString()),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPluginActions(CorePlugin plugin) {
    return Wrap(
      spacing: 8,
      children: [
        if (plugin.isReady && !plugin.isActive)
          ElevatedButton.icon(
            onPressed: () => _activatePlugin(plugin),
            icon: const Icon(Icons.play_arrow),
            label: const Text('激活'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        if (plugin.isActive)
          OutlinedButton.icon(
            onPressed: () => _deactivatePlugin(plugin),
            icon: const Icon(Icons.stop),
            label: const Text('停用'),
          ),
        if (plugin.isReady)
          OutlinedButton.icon(
            onPressed: () => _testPlugin(plugin),
            icon: const Icon(Icons.build_circle_outlined),
            label: const Text('测试'),
          ),
        if (plugin.buildSettingsScreen() != null)
          OutlinedButton.icon(
            onPressed: () => _openPluginSettings(plugin),
            icon: const Icon(Icons.settings),
            label: const Text('设置'),
          ),
      ],
    );
  }

  Future<void> _activatePlugin(CorePlugin plugin) async {
    // 检查是否是占位符插件（社区版）
    if (plugin.metadata.capabilities.contains('placeholder') ||
        plugin.metadata.capabilities.contains('upgrade-prompt')) {
      await _showUpgradeDialog(plugin);
      return;
    }

    try {
      final pluginService = PluginStatusService();
      final success = await pluginService.activatePlugin(plugin.metadata.id);

      if (success) {
        setState(() {});
        _showMessage('插件 "${plugin.metadata.name}" 已激活', Colors.green);
      } else {
        await PluginErrorHandler.showErrorDialog(
          context,
          error: '插件激活失败',
          plugin: plugin,
        );
      }
    } catch (e) {
      await PluginErrorHandler.showErrorDialog(
        context,
        error: e,
        plugin: plugin,
      );
    }
  }

  /// 显示升级到专业版的对话框
  Future<void> _showUpgradeDialog([CorePlugin? plugin]) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.star, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            const Text('升级到专业版'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '解锁完整的媒体服务器功能',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text('专业版包含以下功能：'),
            const SizedBox(height: 12),
            _buildFeatureItem('SMB/CIFS 网络共享访问'),
            _buildFeatureItem('FTP/SFTP 安全文件传输'),
            _buildFeatureItem('NFS 网络文件系统支持'),
            _buildFeatureItem('WebDAV 协议支持'),
            _buildFeatureItem('HEVC/H.265 专业解码器'),
            _buildFeatureItem('AI 智能字幕'),
            _buildFeatureItem('多设备同步'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '社区版仅包含基础插件功能',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('暂不升级'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _showMessage('升级功能即将推出，敬请期待！', Colors.blue);
            },
            icon: const Icon(Icons.upgrade),
            label: const Text('立即升级'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feature,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deactivatePlugin(CorePlugin plugin) async {
    try {
      final pluginService = PluginStatusService();
      final success = await pluginService.deactivatePlugin(plugin.metadata.id);

      if (success) {
        setState(() {});
        _showMessage('插件 "${plugin.metadata.name}" 已停用', Colors.orange);
      } else {
        await PluginErrorHandler.showErrorDialog(
          context,
          error: '插件停用失败',
          plugin: plugin,
        );
      }
    } catch (e) {
      await PluginErrorHandler.showErrorDialog(
        context,
        error: e,
        plugin: plugin,
      );
    }
  }

  Future<void> _testPlugin(CorePlugin plugin) async {
    try {
      final pluginService = PluginStatusService();
      final isHealthy = await pluginService.checkPluginHealth(plugin.metadata.id);

      _showMessage(
        '插件 "${plugin.metadata.name}" 健康检查: ${isHealthy ? "正常" : "异常"}',
        isHealthy ? Colors.green : Colors.orange,
      );
    } catch (e) {
      await PluginErrorHandler.showErrorDialog(
        context,
        error: e,
        plugin: plugin,
        title: '插件健康检查失败',
      );
    }
  }

  Future<void> _openPluginSettings(CorePlugin plugin) async {
    final settingsWidget = plugin.buildSettingsScreen();
    if (settingsWidget != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: Text('${plugin.metadata.name} 设置')),
            body: settingsWidget,
          ),
        ),
      );
    }
  }


  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class BulletPoint extends StatelessWidget {
  final String text;

  const BulletPoint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}