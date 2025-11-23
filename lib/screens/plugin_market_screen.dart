import 'package:flutter/material.dart';
import 'package:yinghe_player/core/plugin_system/plugin_repository.dart';
import 'package:yinghe_player/core/plugin_system/plugin_loader.dart';
import 'package:yinghe_player/theme/design_tokens/design_tokens.dart';
import '../widgets/plugin_card.dart';
import '../widgets/plugin_repository_section.dart';
import '../widgets/plugin_search_delegate.dart';

/// 插件市场/管理屏幕
class PluginMarketScreen extends StatefulWidget {
  const PluginMarketScreen({super.key});

  @override
  State<PluginMarketScreen> createState() => _PluginMarketScreenState();
}

class _PluginMarketScreenState extends State<PluginMarketScreen> {
  final PluginRepository _repository = PluginRepository();
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'all';
  PluginSortType _sortType = PluginSortType.name;

  // 当前显示的插件仓库信息
  List<PluginRepositoryInfo> _repositories = [];

  // 加载状态
  bool _isLoading = false;
  String? _error;

  // 过滤参数
  bool _showCommunityOnly = false;
  bool _showCommercialOnly = false;

  @override
  void initState() {
    super.initState();
    _loadRepositories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRepositories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _repository.initialize();
      final repos = _repository.getAvailableRepositories();

      setState(() {
        _repositories = _applyFilters(repos);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载插件失败: $e';
        _isLoading = false;
      });
    }
  }

  List<PluginRepositoryInfo> _applyFilters(List<PluginRepositoryInfo> repositories) {
    var filtered = <PluginRepositoryInfo>[];

    // 版本过滤
    if (_showCommunityOnly) {
      filtered = repositories.where((repo) => repo.isCommunityEdition).toList();
    } else if (_showCommercialOnly) {
      filtered = repositories.where((repo) => !repo.isCommunityEdition).toList();
    } else {
      filtered = repositories;
    }

    // 分类过滤
    if (_selectedCategory != 'all') {
      filtered = filtered.where((repo) => _getCategory(repo) == _selectedCategory).toList();
    }

    // 搜索过滤
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      filtered = _repository.searchPlugins(query);
    }

    // 排序
    _sortRepositories(filtered);

    return filtered;
  }

  String _getCategory(PluginRepositoryInfo repository) {
    // 根据插件名称和描述确定分类
    final nameAndDesc = '${repository.name}${repository.description}'.toLowerCase();

    if (nameAndDesc.contains('subtitle') || nameAndDesc.contains('字幕')) {
      return 'subtitle';
    } else if (nameAndDesc.contains('audio') || nameAndDesc.contains('sound')) {
      return 'audio';
    } else if (nameAndDesc.contains('video') || nameAndDesc.contains('visual')) {
      return 'video';
    } else if (nameAndDesc.contains('theme') || nameAndDesc.contains('ui')) {
      return 'theme';
    } else if (nameAndDesc.contains('metadata') || nameAndDesc.contains('info')) {
      return 'metadata';
    } else if (nameAndDesc.contains('media') || nameAndDesc.contains('server')) {
      return 'media';
    }

    return 'other';
  }

  void _sortRepositories(List<PluginRepositoryInfo> repositories) {
    switch (_sortType) {
      case PluginSortType.name:
        repositories.sort((a, b) => a.name.compareTo(b.name));
        break;
      case PluginSortType.type:
        repositories.sort((a, b) => a.type.index.compareTo(b.type.index));
        break;
      case PluginSortType.version:
        repositories.sort((a, b) => _versionToNumber(b.version).compareTo(_versionToNumber(a.version)));
        break;
    }
  }

  double _versionToNumber(String version) {
    try {
      final parts = version.split('.');
      return double.parse(parts.first);
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> _refreshPlugins() async {
    await _loadRepositories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        title: const Text('插件市场'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _refreshPlugins,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 0:
                  _showImportDialog();
                  break;
                case 1:
                  _showExportDialog();
                  break;
                case 2:
                  _showSettingsDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 0,
                child: Row(
                  children: [
                    const Icon(Icons.file_upload),
                    const SizedBox(width: 8),
                    const Text('导入插件'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 1,
                child: Row(
                  children: [
                    const Icon(Icons.file_download),
                    const SizedBox(width: 8),
                    const Text('导出配置'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 2,
                child: Row(
                  children: [
                    const Icon(Icons.settings),
                    const SizedBox(width: 8),
                    const Text('设置'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: AppTextStyles.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refreshPlugins,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildSearchBar(),
        _buildFilterBar(),
        _buildPluginGrid(),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
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
                    setState(() {
                      _repositories = _applyFilters(_repository.getAvailableRepositories());
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.medium,
            vertical: AppSpacing.medium,
          ),
        ),
        onSubmitted: (value) {
          setState(() {
            _repositories = _applyFilters(_repository.getAvailableRepositories());
          });
        },
        onChanged: (value) {
          setState(() {
            _repositories = _applyFilters(_repository.getAvailableRepositories());
          });
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 版本过滤
          Row(
            children: [
              Expanded(
                child: FilterChip(
                  label: '社区版',
                  selected: _showCommunityOnly,
                  onSelected: (selected) {
                    setState(() {
                      _showCommunityOnly = selected;
                      _showCommercialOnly = false;
                      if (selected) {
                        _selectedCategory = 'all';
                      }
                      _repositories = _applyFilters(_repository.getAvailableRepositories());
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilterChip(
                  label: '专业版',
                  selected: _showCommercialOnly,
                  onSelected: (selected) {
                    setState(() {
                      _showCommercialOnly = selected;
                      _showCommunityOnly = false;
                      if (selected) {
                        _selectedCategory = 'all';
                      }
                      _repositories = _applyFilters(_repository.getAvailableRepositories());
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilterChip(
                  label: '全部',
                  selected: !_showCommunityOnly && !_showCommercialOnly,
                  onSelected: (selected) {
                    setState(() {
                      _showCommunityOnly = false;
                      _showCommercialOnly = false;
                      _repositories = _applyFilters(_repository.getAvailableRepositories());
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 分类过滤
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip('all', '全部'),
                _buildCategoryChip('subtitle', '字幕'),
                _buildCategoryChip('audio', '音频'),
                _buildCategoryChip('video', '视频'),
                _buildCategoryChip('theme', '主题'),
                _buildCategoryChip('metadata', '元数据'),
                _buildCategoryChip('media', '媒体'),
                _buildCategoryChip('other', '其他'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 排序选项
          Row(
            children: [
              const Text(
                '排序：',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _getSortTypeLabel(),
                  items: PluginSortType.values.map((type) {
                    return DropdownMenuItem(
                      value: type.toString(),
                      child: Text(_getSortTypeDisplayName(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _sortType = PluginSortType.values.firstWhere(
                        (type) => type.toString() == value,
                      );
                      _repositories = _applyFilters(_repositories);
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String value, String label) {
    final isSelected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: label,
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? value : 'all';
            _repositories = _applyFilters(_repository.getAvailableRepositories());
          });
        },
        backgroundColor: isSelected ? AppColors.primary : null,
      ),
    );
  }

  Widget _buildPluginGrid() {
    if (_repositories.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.extension_off,
                color: AppColors.textTertiary,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                '没有找到匹配的插件',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _refreshPlugins,
                icon: const Icon(Icons.refresh),
                label: const Text('刷新'),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: _repositories.length,
        itemBuilder: (context, index) {
          final repository = _repositories[index];
          return PluginCard(
            repository: repository,
            onTap: () => _showPluginDetails(repository),
          );
        },
      ),
    );
  }

  String _getSortTypeLabel() {
    return _sortType.toString();
  }

  String _getSortTypeDisplayName(PluginSortType type) {
    switch (type) {
      case PluginSortType.name:
        return '名称';
      case PluginSortType.type:
        return '类型';
      case PluginSortType.version:
        return '版本';
    }
  }

  void _showPluginDetails(PluginRepositoryInfo repository) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => PluginDetailsSheet(
        repository: repository,
        repository: _repository,
        onInstall: () => _installPlugin(repository),
      ),
    );
  }

  Future<void> _installPlugin(PluginRepositoryInfo repository) async {
    try {
      // 检查版本限制
      if (!repository.isCommunityEdition && EditionConfig.isCommunityEdition) {
        _showUpgradeDialog();
        return;
      }

      // 执行安装
      final plugin = await _repository.loadPlugin(repository.id);

      if (plugin != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('插件 "${repository.name}" 安装成功'),
            backgroundColor: Colors.green,
          ),
        );

        // 刷新列表
        _refreshPlugins();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('插件安装失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('安装插件时出错: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('专业版功能'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.upgrade, size: 48, color: Colors.blue),
            SizedBox(height: 16),
            Text(
              '此插件仅在专业版中可用',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              '升级到专业版，解锁所有高级插件功能！',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: 实现升级功能
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('升级功能即将开放')),
              );
            },
            child: const Text('升级专业版'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入插件'),
        content: const Text('选择插件文件进行导入'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: 实现文件选择和导入功能
            },
            child: const Text('选择文件'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出配置'),
        content: const Text('导出当前插件配置'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: 实现配置导出功能
            },
            child: const Text('导出'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('插件设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('插件设置选项'),
            const SizedBox(height: 16),
            // TODO: 添加具体的设置选项
          ],
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
}

/// 插件详情底部弹窗
class PluginDetailsSheet extends StatelessWidget {
  final PluginRepositoryInfo repository;
  final PluginRepository pluginRepository;
  final VoidCallback? onInstall;

  const PluginDetailsSheet({
    super.key,
    required this.repository,
    required this.pluginRepository,
    this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 插件头部信息
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.surface,
                child: Icon(repository.icon, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      repository.name,
                      style: AppTextStyles.headlineSmall,
                    ),
                    Text(
                      'v${repository.version}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (repository.isCommunityEdition)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Text(
                    '社区版',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 描述
          Text(
            repository.description,
            style: AppTextStyles.bodyMedium,
          ),

          const SizedBox(height: 16),

          // 功能列表
          Text(
            '功能特性：',
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: repository.capabilities.map((capability) {
              return Chip(
                label: _getCapabilityDisplayName(capability),
                backgroundColor: AppColors.surface,
                side: BorderSide(color: AppColors.outline),
              );
            }).toList(),
          ),

          if (repository.author != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '作者：${repository.author}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ],

          if (repository.website != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.link, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                  repository.website!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
                ),
              ],
            ),
          ],

          const Spacer(),

          // 操作按钮
          if (onInstall != null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onInstall,
                icon: repository.isCommunityEdition
                  ? const Icon(Icons.download)
                  : const Icon(Icons.lock),
                label: Text(repository.isCommunityEdition ? '安装' : '需要专业版'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: repository.isCommunityEdition
                    ? null
                    : Colors.grey,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getCapabilityDisplayName(String capability) {
    switch (capability) {
      case 'subtitle_parsing':
        return '字幕解析';
      case 'subtitle_rendering':
        return '字幕渲染';
      case 'subtitle_styling':
        return '字幕样式';
      case 'subtitle_search':
        return '字幕搜索';
      case 'equalizer':
        return '均衡器';
      case 'volume_control':
        return '音量控制';
      case 'audio_enhancement':
        return '音频增强';
      case 'surround_sound':
        return '环绕声';
      case 'sharpening':
        return '画面锐化';
      case 'noise_reduction':
        return '降噪';
      case 'color_correction':
        return '色彩校正';
      case 'resolution_upscale':
        return '分辨率提升';
      case 'hdr_support':
        return 'HDR支持';
      case 'metadata_fetching':
        return '元数据获取';
      case 'local_cache':
        return '本地缓存';
      case 'poster_download':
        return '海报下载';
      case 'multi_language':
        return '多语言';
      case 'theme_management':
        return '主题管理';
      case 'custom_themes':
        return '自定义主题';
      case 'theme_switching':
        return '主题切换';
      case 'color_customization':
        return '颜色定制';
      default:
        return capability;
    }
  }
}

/// 插件排序类型
enum PluginSortType {
  name,
  type,
  version,
}