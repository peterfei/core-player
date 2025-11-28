import 'package:flutter/material.dart';
import '../models/series.dart';
import '../services/series_service.dart';
import '../services/media_library_service.dart';
import '../services/metadata_store_service.dart';
import '../theme/design_tokens/design_tokens.dart';
import '../widgets/series_folder_card.dart';
import 'series_detail_page.dart';
import 'metadata_management_page.dart';

class SeriesListPage extends StatefulWidget {
  const SeriesListPage({Key? key}) : super(key: key);

  @override
  State<SeriesListPage> createState() => _SeriesListPageState();
}

class _SeriesListPageState extends State<SeriesListPage> {
  List<Series> _seriesList = [];
  List<Series> _filteredSeries = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'name_asc'; // 'name_asc', 'name_desc', 'count_desc', 'date_desc'

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    debugPrint('🚀 SeriesListPage: _initAndLoad started');
    await MetadataStoreService.init();
    await _loadSeries();
  }

  Future<void> _loadSeries() async {
    debugPrint('🚀 SeriesListPage: _loadSeries started');
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 尝试获取已持久化的剧集数据
      var seriesList = await SeriesService.getAllSavedSeries();
      debugPrint('🚀 Loaded saved series count: ${seriesList.length}');
      
      // 2. 如果持久化数据为空（首次运行或被清除），则实时计算
      if (seriesList.isEmpty) {
        debugPrint('🚀 Saved series empty, trying realtime grouping...');
        final allVideos = MediaLibraryService.getAllVideos();
        debugPrint('🚀 Total videos: ${allVideos.length}');
        if (allVideos.isNotEmpty) {
           // 实时分组用于显示，不强制立即保存（保存操作通常在扫描时触发）
           seriesList = SeriesService.groupVideosBySeries(allVideos);
           debugPrint('🚀 Grouped series count: ${seriesList.length}');
        }
      }
      
      if (mounted) {
        setState(() {
          _seriesList = seriesList;
          _filterAndSortSeries();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading series: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _hasMetadata(Series series) {
    final metadata = MetadataStoreService.getSeriesMetadata(series.folderPath);
    // debugPrint('🔍 Metadata Check for [${series.name}]: ${metadata != null} (Poster: ${metadata?['posterPath'] != null})');
    return metadata != null && metadata['posterPath'] != null;
  }

  void _filterAndSortSeries() {
    debugPrint('🔍 开始筛选和排序剧集 (总数: ${_seriesList.length})');
    
    var result = List<Series>.from(_seriesList);
    
    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      result = SeriesService.searchSeries(result, _searchQuery);
    }
    
    // 排序
    result.sort((a, b) {
      // 优先显示有元数据（海报）的剧集
      final aHasMeta = _hasMetadata(a);
      final bHasMeta = _hasMetadata(b);
      
      if (aHasMeta != bHasMeta) {
        return aHasMeta ? -1 : 1;
      }
      
      // 次级排序
      switch (_sortBy) {
        case 'name_asc':
          return a.name.compareTo(b.name);
        case 'name_desc':
          return b.name.compareTo(a.name);
        case 'count_desc':
          return b.episodeCount.compareTo(a.episodeCount);
        case 'date_desc':
          return b.addedAt.compareTo(a.addedAt);
        default:
          return 0;
      }
    });
    
    // 打印排序结果前5名
    debugPrint('📊 排序结果 (Top 5):');
    for (var i = 0; i < result.length && i < 5; i++) {
      final s = result[i];
      debugPrint('  #${i+1} ${s.name} (Meta: ${_hasMetadata(s)})');
    }
    
    setState(() {
      _filteredSeries = result;
    });
  }

  void _navigateToDetail(Series series) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeriesDetailPage(series: series),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 搜索和排序栏
        Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Row(
            children: [
              // 搜索框
              Expanded(
                child: TextField(
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '搜索剧集...',
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                    prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.medium,
                      vertical: AppSpacing.small,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _filterAndSortSeries();
                    });
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.medium),
              
              // 排序下拉菜单
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    dropdownColor: AppColors.surface,
                    icon: const Icon(Icons.sort, color: AppColors.textSecondary),
                    style: TextStyle(color: AppColors.textPrimary),
                    items: const [
                      DropdownMenuItem(value: 'name_asc', child: Text('名称 (A-Z)')),
                      DropdownMenuItem(value: 'name_desc', child: Text('名称 (Z-A)')),
                      DropdownMenuItem(value: 'count_desc', child: Text('集数 (多到少)')),
                      DropdownMenuItem(value: 'date_desc', child: Text('最近添加')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _sortBy = value;
                          _filterAndSortSeries();
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.small),
              
              // 元数据管理按钮
              IconButton(
                icon: const Icon(Icons.settings, color: AppColors.textSecondary),
                tooltip: '元数据管理',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MetadataManagementPage(),
                    ),
                  ).then((_) => _loadSeries()); // 返回后刷新
                },
              ),
            ],
          ),
        ),

        // 剧集网格列表
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredSeries.isEmpty
                  ? Center(
                      child: Text(
                        '没有找到剧集',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(AppSpacing.large),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: AppSpacing.large,
                        mainAxisSpacing: AppSpacing.large,
                      ),
                      itemCount: _filteredSeries.length,
                      itemBuilder: (context, index) {
                        final series = _filteredSeries[index];
                        return SeriesFolderCard(
                          series: series,
                          onTap: () => _navigateToDetail(series),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
