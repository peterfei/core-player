import 'package:flutter/material.dart';
import 'package:yinghe_player/core/plugin_system/plugin_interface.dart';
import 'plugin_filter_model.dart';

/// 高级搜索和过滤器组件
class AdvancedSearchWidget extends StatefulWidget {
  final PluginSearchConfig searchConfig;
  final PluginFilter filter;
  final ValueChanged<PluginSearchConfig>? onSearchChanged;
  final ValueChanged<PluginFilter>? onFilterChanged;
  final VoidCallback? onClear;

  const AdvancedSearchWidget({
    Key? key,
    required this.searchConfig,
    required this.filter,
    this.onSearchChanged,
    this.onFilterChanged,
    this.onClear,
  }) : super(key: key);

  @override
  State<AdvancedSearchWidget> createState() => _AdvancedSearchWidgetState();
}

class _AdvancedSearchWidgetState extends State<AdvancedSearchWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.text = widget.searchConfig.query;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AdvancedSearchWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchConfig.query != widget.searchConfig.query) {
      _searchController.text = widget.searchConfig.query;
    }
  }

  void _onSearchChanged() {
    if (widget.onSearchChanged != null) {
      widget.onSearchChanged!(widget.searchConfig.copyWith(
        query: _searchController.text,
      ));
    }
  }

  void _onSearchFieldChanged(bool? value, String field) {
    if (widget.onSearchChanged != null) {
      switch (field) {
        case 'name':
          widget.onSearchChanged!(widget.searchConfig.copyWith(searchName: value ?? false));
          break;
        case 'description':
          widget.onSearchChanged!(widget.searchConfig.copyWith(searchDescription: value ?? false));
          break;
        case 'author':
          widget.onSearchChanged!(widget.searchConfig.copyWith(searchAuthor: value ?? false));
          break;
        case 'capabilities':
          widget.onSearchChanged!(widget.searchConfig.copyWith(searchCapabilities: value ?? false));
          break;
        case 'permissions':
          widget.onSearchChanged!(widget.searchConfig.copyWith(searchPermissions: value ?? false));
          break;
        case 'caseSensitive':
          widget.onSearchChanged!(widget.searchConfig.copyWith(caseSensitive: value ?? false));
          break;
      }
    }
  }

  void _onFilterChanged(String field, dynamic value) {
    if (widget.onFilterChanged != null) {
      switch (field) {
        case 'state':
          widget.onFilterChanged!(widget.filter.copyWith(state: value as PluginState?));
          break;
        case 'license':
          widget.onFilterChanged!(widget.filter.copyWith(license: value as PluginLicense?));
          break;
        case 'onlyEnabled':
          widget.onFilterChanged!(widget.filter.copyWith(onlyEnabled: value as bool));
          break;
        case 'onlyDisabled':
          widget.onFilterChanged!(widget.filter.copyWith(onlyDisabled: value as bool));
          break;
        case 'onlyWithError':
          widget.onFilterChanged!(widget.filter.copyWith(onlyWithError: value as bool));
          break;
        case 'onlyCommercial':
          widget.onFilterChanged!(widget.filter.copyWith(onlyCommercial: value as bool));
          break;
        case 'onlyFree':
          widget.onFilterChanged!(widget.filter.copyWith(onlyFree: value as bool));
          break;
        case 'author':
          widget.onFilterChanged!(widget.filter.copyWith(author: value as String?));
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
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
          // 主要搜索栏
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => _onSearchChanged(),
                    decoration: InputDecoration(
                      hintText: '搜索插件...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged();
                              },
                            ),
                          IconButton(
                            icon: Icon(
                              _isExpanded ? Icons.expand_less : Icons.expand_more,
                            ),
                            onPressed: () {
                              setState(() {
                                _isExpanded = !_isExpanded;
                              });
                            },
                            tooltip: '高级搜索',
                          ),
                        ],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (widget.onClear != null)
                  IconButton.outlined(
                    onPressed: widget.onClear,
                    icon: const Icon(Icons.clear_all),
                    tooltip: '清除所有过滤',
                  ),
              ],
            ),
          ),

          // 高级搜索选项
          if (_isExpanded) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(16),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSearchOptionsTab(),
                  _buildFilterOptionsTab(),
                ],
              ),
            ),
            Container(
              height: 50,
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '搜索选项'),
                  Tab(text: '过滤器'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchOptionsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '搜索范围',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _buildCheckboxOption(
              '插件名称',
              widget.searchConfig.searchName,
              (value) => _onSearchFieldChanged(value, 'name'),
            ),
            _buildCheckboxOption(
              '描述',
              widget.searchConfig.searchDescription,
              (value) => _onSearchFieldChanged(value, 'description'),
            ),
            _buildCheckboxOption(
              '作者',
              widget.searchConfig.searchAuthor,
              (value) => _onSearchFieldChanged(value, 'author'),
            ),
            _buildCheckboxOption(
              '功能特性',
              widget.searchConfig.searchCapabilities,
              (value) => _onSearchFieldChanged(value, 'capabilities'),
            ),
            _buildCheckboxOption(
              '所需权限',
              widget.searchConfig.searchPermissions,
              (value) => _onSearchFieldChanged(value, 'permissions'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              '选择要在哪些字段中搜索',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildCheckboxOption(
          '区分大小写',
          widget.searchConfig.caseSensitive,
          (value) => _onSearchFieldChanged(value, 'caseSensitive'),
        ),
      ],
    );
  }

  Widget _buildFilterOptionsTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态过滤器
          Text(
            '插件状态',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('已启用'),
                selected: widget.filter.onlyEnabled,
                onSelected: (value) => _onFilterChanged('onlyEnabled', value),
              ),
              FilterChip(
                label: const Text('未启用'),
                selected: widget.filter.onlyDisabled,
                onSelected: (value) => _onFilterChanged('onlyDisabled', value),
              ),
              FilterChip(
                label: const Text('错误状态'),
                selected: widget.filter.onlyWithError,
                onSelected: (value) => _onFilterChanged('onlyWithError', value),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 许可证过滤器
          Text(
            '许可证类型',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('商业版'),
                selected: widget.filter.onlyCommercial,
                onSelected: (value) => _onFilterChanged('onlyCommercial', value),
              ),
              FilterChip(
                label: const Text('免费版'),
                selected: widget.filter.onlyFree,
                onSelected: (value) => _onFilterChanged('onlyFree', value),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 具体状态选择
          Text(
            '具体状态',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: DropdownButton<PluginState?>(
              value: widget.filter.state,
              hint: const Text('选择状态'),
              isExpanded: true,
              items: [
                const DropdownMenuItem<PluginState?>(
                  value: null,
                  child: Text('全部状态'),
                ),
                ...PluginState.values.map(
                  (state) => DropdownMenuItem<PluginState>(
                    value: state,
                    child: Text(_getStateDisplayName(state)),
                  ),
                ),
              ],
              onChanged: (value) => _onFilterChanged('state', value),
            ),
          ),
          const SizedBox(height: 20),

          // 许可证选择
          Text(
            '许可证',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: DropdownButton<PluginLicense?>(
              value: widget.filter.license,
              hint: const Text('选择许可证'),
              isExpanded: true,
              items: [
                const DropdownMenuItem<PluginLicense?>(
                  value: null,
                  child: Text('全部许可证'),
                ),
                ...PluginLicense.values.map(
                  (license) => DropdownMenuItem<PluginLicense>(
                    value: license,
                    child: Text(license.displayName),
                  ),
                ),
              ],
              onChanged: (value) => _onFilterChanged('license', value),
            ),
          ),
          const SizedBox(height: 20),

          // 作者过滤
          Text(
            '作者',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              hintText: '输入作者名称...',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              _onFilterChanged('author', value.isEmpty ? null : value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxOption(String label, bool value, Function(bool?) onChanged) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
      showCheckmark: true,
    );
  }

  String _getStateDisplayName(PluginState state) {
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

/// 排序选项组件
class SortOptionsWidget extends StatelessWidget {
  final PluginSortConfig sortConfig;
  final ValueChanged<PluginSortConfig>? onSortChanged;

  const SortOptionsWidget({
    Key? key,
    required this.sortConfig,
    this.onSortChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.sort, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Text(
            '排序：',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<PluginSortOption>(
              value: sortConfig.option,
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
                  value: PluginSortOption.version,
                  child: Text('版本'),
                ),
                DropdownMenuItem(
                  value: PluginSortOption.status,
                  child: Text('状态'),
                ),
                DropdownMenuItem(
                  value: PluginSortOption.capabilities,
                  child: Text('功能数量'),
                ),
                DropdownMenuItem(
                  value: PluginSortOption.license,
                  child: Text('许可证'),
                ),
              ],
              onChanged: (value) {
                if (value != null && onSortChanged != null) {
                  onSortChanged!(sortConfig.copyWith(option: value));
                }
              },
            ),
          ),
          IconButton(
            icon: Icon(
              sortConfig.order == SortOrder.ascending
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
            ),
            onPressed: () {
              if (onSortChanged != null) {
                onSortChanged!(sortConfig.copyWith(
                  order: sortConfig.order == SortOrder.ascending
                      ? SortOrder.descending
                      : SortOrder.ascending,
                ));
              }
            },
            tooltip: sortConfig.order == SortOrder.ascending ? '升序' : '降序',
          ),
        ],
      ),
    );
  }
}

/// 过滤状态指示器
class FilterStatusWidget extends StatelessWidget {
  final PluginSearchConfig searchConfig;
  final PluginFilter filter;
  final int totalPlugins;
  final int filteredPlugins;
  final VoidCallback? onClearFilters;

  const FilterStatusWidget({
    Key? key,
    required this.searchConfig,
    required this.filter,
    required this.totalPlugins,
    required this.filteredPlugins,
    this.onClearFilters,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters =
        searchConfig.query.isNotEmpty ||
        !filter.isEmpty ||
        (filteredPlugins != totalPlugins);

    if (!hasActiveFilters) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 16, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '显示 $filteredPlugins / $totalPlugins 个插件',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onClearFilters != null)
            TextButton(
              onPressed: onClearFilters,
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
}