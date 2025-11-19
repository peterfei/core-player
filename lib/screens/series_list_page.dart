import 'package:flutter/material.dart';
import '../models/series.dart';
import '../services/series_service.dart';
import '../services/media_library_service.dart';
import '../theme/design_tokens/design_tokens.dart';
import '../widgets/series_folder_card.dart';
import 'series_detail_page.dart';

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
    _loadSeries();
  }

  Future<void> _loadSeries() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取所有扫描的视频
      final allVideos = MediaLibraryService.getAllVideos();
      
      // 分组剧集
      final seriesList = SeriesService.groupVideosBySeries(allVideos);
      
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

  void _filterAndSortSeries() {
    var result = List<Series>.from(_seriesList);
    
    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      result = SeriesService.searchSeries(result, _searchQuery);
    }
    
    // 排序
    switch (_sortBy) {
      case 'name_asc':
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'name_desc':
        result.sort((a, b) => b.name.compareTo(a.name));
        break;
      case 'count_desc':
        result.sort((a, b) => b.episodeCount.compareTo(a.episodeCount));
        break;
      case 'date_desc':
        result.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
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
