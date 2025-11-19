import 'dart:io';
import 'package:flutter/material.dart';
import '../models/series.dart';
import '../services/series_service.dart';
import '../services/media_library_service.dart';
import '../services/metadata_store_service.dart';
import '../services/metadata_scraper_service.dart';

class MetadataManagementPage extends StatefulWidget {
  const MetadataManagementPage({super.key});

  @override
  State<MetadataManagementPage> createState() => _MetadataManagementPageState();
}

class _MetadataManagementPageState extends State<MetadataManagementPage> {
  List<Series> _allSeries = [];
  Map<String, bool> _scrapedStatus = {}; // seriesId -> isScraped
  Map<String, Map<String, dynamic>?> _metadata = {}; // seriesId -> metadata
  bool _isLoading = true;
  bool _isScraping = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    debugPrint('');
    debugPrint('📋 ═══════════════════════════════════════════════════════');
    debugPrint('📋 元数据管理页面: 加载数据');
    debugPrint('📋 ═══════════════════════════════════════════════════════');
    
    setState(() => _isLoading = true);

    // 获取所有视频
    debugPrint('📹 获取所有视频...');
    final allVideos = MediaLibraryService.getAllVideos();
    debugPrint('   找到 ${allVideos.length} 个视频文件');
    
    // 分组为剧集
    debugPrint('📁 分组为剧集...');
    final seriesList = SeriesService.groupVideosBySeries(allVideos);
    debugPrint('   找到 ${seriesList.length} 个剧集');
    
    // 检查刮削状态
    debugPrint('🔍 检查刮削状态...');
    final scrapedStatus = <String, bool>{};
    final metadata = <String, Map<String, dynamic>?>{};
    
    int scrapedCount = 0;
    for (var series in seriesList) {
      final isScraped = MetadataStoreService.isScraped(series.folderPath);
      scrapedStatus[series.id] = isScraped;
      metadata[series.id] = MetadataStoreService.getSeriesMetadata(series.folderPath);
      
      if (isScraped) {
        scrapedCount++;
        debugPrint('   ✅ ${series.name}: 已刮削');
      } else {
        debugPrint('   ⭕ ${series.name}: 未刮削');
      }
    }
    
    debugPrint('');
    debugPrint('📊 统计:');
    debugPrint('   总数: ${seriesList.length}');
    debugPrint('   已刮削: $scrapedCount');
    debugPrint('   未刮削: ${seriesList.length - scrapedCount}');
    debugPrint('📋 ═══════════════════════════════════════════════════════');
    debugPrint('');

    if (mounted) {
      setState(() {
        _allSeries = seriesList;
        _scrapedStatus = scrapedStatus;
        _metadata = metadata;
        _isLoading = false;
      });
    }
  }

  Future<void> _scrapeSeries(Series series) async {
    debugPrint('');
    debugPrint('🎬 ═══════════════════════════════════════════════════════');
    debugPrint('🎬 元数据管理页面: 单个刮削');
    debugPrint('🎬 剧集: ${series.name}');
    debugPrint('🎬 ═══════════════════════════════════════════════════════');
    
    setState(() => _isScraping = true);

    // 显示进度对话框
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildProgressDialog('正在刮削 ${series.name}...'),
    );

    final result = await MetadataScraperService.scrapeSeries(
      series,
      onProgress: (status) {
        debugPrint('   进度: $status');
      },
      forceUpdate: true,
    );

    if (!mounted) return;
    
    // 关闭进度对话框
    Navigator.of(context).pop();

    debugPrint('');
    if (result.success) {
      debugPrint('✅ 刮削结果: 成功');
    } else {
      debugPrint('❌ 刮削结果: 失败 - ${result.errorMessage}');
    }
    debugPrint('🎬 ═══════════════════════════════════════════════════════');
    debugPrint('');

    // 显示结果
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success 
            ? '✅ 刮削成功: ${series.name}'
            : '❌ 刮削失败: ${result.errorMessage ?? "未知错误"}',
        ),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );

    // 重新加载数据
    await _loadData();
    
    setState(() => _isScraping = false);
  }

  Future<void> _scrapeBatch() async {
    // 筛选未刮削的剧集
    final unscrapedSeries = _allSeries.where((s) => 
      _scrapedStatus[s.id] != true
    ).toList();

    debugPrint('');
    debugPrint('📦 ═══════════════════════════════════════════════════════');
    debugPrint('📦 元数据管理页面: 批量刮削');
    debugPrint('📦 总剧集数: ${_allSeries.length}');
    debugPrint('📦 未刮削数: ${unscrapedSeries.length}');
    debugPrint('📦 ═══════════════════════════════════════════════════════');

    if (unscrapedSeries.isEmpty) {
      debugPrint('ℹ️  所有剧集都已刮削，无需处理');
      debugPrint('');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所有剧集都已刮削')),
      );
      return;
    }

    debugPrint('📦 开始批量刮削 ${unscrapedSeries.length} 个剧集:');
    for (var series in unscrapedSeries) {
      debugPrint('   - ${series.name}');
    }
    debugPrint('');

    setState(() => _isScraping = true);

    // 显示进度对话框
    int currentIndex = 0;
    int total = unscrapedSeries.length;
    String currentStatus = '准备开始...';

    final dialogContext = context;
    
    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('批量刮削'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: total > 0 ? currentIndex / total : 0,
                ),
                const SizedBox(height: 16),
                Text('进度: $currentIndex / $total'),
                const SizedBox(height: 8),
                Text(
                  currentStatus,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );

    final results = await MetadataScraperService.scrapeBatchSeries(
      unscrapedSeries,
      onProgress: (current, total, status) {
        currentIndex = current;
        currentStatus = status;
        debugPrint('📊 批量刮削进度: $current/$total - $status');
      },
    );

    if (!mounted) return;
    
    // 关闭进度对话框
    Navigator.of(dialogContext).pop();

    // 统计结果
    final successCount = results.where((r) => r.success).length;
    final failedCount = results.length - successCount;

    debugPrint('');
    debugPrint('📦 ═══════════════════════════════════════════════════════');
    debugPrint('📦 批量刮削完成');
    debugPrint('📦 成功: $successCount');
    debugPrint('📦 失败: $failedCount');
    debugPrint('📦 总计: ${results.length}');
    
    // 列出失败的剧集
    if (failedCount > 0) {
      debugPrint('');
      debugPrint('❌ 失败的剧集:');
      for (var result in results.where((r) => !r.success)) {
        debugPrint('   - ${result.seriesName}: ${result.errorMessage}');
      }
    }
    debugPrint('📦 ═══════════════════════════════════════════════════════');
    debugPrint('');

    // 显示结果
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '批量刮削完成\n成功: $successCount, 失败: $failedCount',
        ),
        duration: const Duration(seconds: 3),
      ),
    );

    // 重新加载数据
    await _loadData();
    
    setState(() => _isScraping = false);
  }

  Widget _buildProgressDialog(String message) {
    return AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('元数据管理'),
        actions: [
          if (!_isScraping && _allSeries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '刷新',
              onPressed: _loadData,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allSeries.isEmpty
              ? const Center(
                  child: Text(
                    '没有找到剧集\n请先扫描媒体库',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : Column(
                  children: [
                    // 统计信息
                    _buildStatistics(),
                    const Divider(height: 1),
                    // 剧集列表
                    Expanded(
                      child: ListView.builder(
                        itemCount: _allSeries.length,
                        itemBuilder: (context, index) {
                          final series = _allSeries[index];
                          return _buildSeriesCard(series);
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _allSeries.isNotEmpty && !_isScraping
          ? FloatingActionButton.extended(
              onPressed: _scrapeBatch,
              icon: const Icon(Icons.download),
              label: const Text('批量刮削'),
            )
          : null,
    );
  }

  Widget _buildStatistics() {
    final scrapedCount = _scrapedStatus.values.where((s) => s).length;
    final totalCount = _allSeries.length;
    final unscrapedCount = totalCount - scrapedCount;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('总数', totalCount, Colors.blue),
          _buildStatItem('已刮削', scrapedCount, Colors.green),
          _buildStatItem('未刮削', unscrapedCount, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSeriesCard(Series series) {
    final isScraped = _scrapedStatus[series.id] ?? false;
    final metadata = _metadata[series.id];
    final posterPath = metadata?['posterPath'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: _buildPosterImage(posterPath, isScraped),
        title: Text(
          series.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('集数: ${series.episodeCount}'),
            if (metadata != null) ...[
              Text(
                '评分: ${metadata['rating']?.toStringAsFixed(1) ?? 'N/A'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
        trailing: _buildActionButton(series, isScraped),
        isThreeLine: metadata != null,
      ),
    );
  }

  Widget _buildPosterImage(String? posterPath, bool isScraped) {
    if (posterPath != null && File(posterPath).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(posterPath),
          width: 50,
          height: 75,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 50,
      height: 75,
      decoration: BoxDecoration(
        color: isScraped ? Colors.grey[300] : Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        isScraped ? Icons.image : Icons.image_not_supported,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildActionButton(Series series, bool isScraped) {
    if (_isScraping) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return IconButton(
      icon: Icon(
        isScraped ? Icons.refresh : Icons.download,
        color: isScraped ? Colors.grey : Colors.blue,
      ),
      tooltip: isScraped ? '重新刮削' : '刮削',
      onPressed: () => _scrapeSeries(series),
    );
  }
}
