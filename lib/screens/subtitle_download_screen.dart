import 'package:flutter/material.dart';
import '../services/subtitle_download_manager.dart';
import '../core/plugin_system/subtitle_download_plugin.dart';
import '../core/plugin_system/plugin_interface.dart';
import '../models/subtitle_track.dart' as subtitle_models;

/// 字幕下载界面
class SubtitleDownloadScreen extends StatefulWidget {
  final String videoTitle;
  final String? videoPath;

  const SubtitleDownloadScreen({
    super.key,
    required this.videoTitle,
    this.videoPath,
  });

  @override
  State<SubtitleDownloadScreen> createState() => _SubtitleDownloadScreenState();
}

class _SubtitleDownloadScreenState extends State<SubtitleDownloadScreen> {
  final SubtitleDownloadManager _downloadManager =
      SubtitleDownloadManager.instance;
  final TextEditingController _searchController = TextEditingController();

  List<SubtitleSearchResult> _searchResults = [];
  List<SubtitleLanguage> _availableLanguages = [];
  SubtitleLanguage? _selectedLanguage;
  bool _isLoading = false;
  String? _error;
  Map<String, bool> _downloadingStatus = {};

  @override
  void initState() {
    super.initState();
    print('📱 SubtitleDownloadScreen initState');
    print('   Video title: ${widget.videoTitle}');
    print('   Video path: ${widget.videoPath}');
    
    _searchController.text = widget.videoTitle;
    _availableLanguages = _downloadManager.getSupportedLanguages();
    _selectedLanguage = _availableLanguages.firstWhere(
      (lang) => lang.code == 'zh',
      orElse: () => _availableLanguages.first,
    );

    print('   Initial _isLoading: $_isLoading');
    print('   Search query: ${_searchController.text}');
    
    // 自动搜索
    _searchSubtitles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchSubtitles() async {
    print('🔍 _searchSubtitles called with query: "${_searchController.text.trim()}"');
    
    if (_searchController.text.trim().isEmpty) {
      print('⚠️ Search query is empty, returning');
      return;
    }

    print('📝 Setting state: _isLoading=true');
    setState(() {
      _isLoading = true;
      _error = null;
      _searchResults = [];
    });
    print('✅ State set successfully');

    try {
      print('🌐 Calling _downloadManager.searchSubtitles...');
      final results = await _downloadManager.searchSubtitles(
        query: _searchController.text.trim(),
        language: _selectedLanguage?.code,
      );
      print('📦 Received ${results.length} results from manager');

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
        print('✅ Results displayed');
      }
    } on FeatureNotAvailableException catch (e) {
      print('⚠️ Caught FeatureNotAvailableException: ${e.message}');
      // 捕获升级提示异常
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showUpgradeDialog(e.message, e.upgradeUrl);
      }
    } catch (e) {
      print('❌ Caught exception: $e');
      if (mounted) {
        setState(() {
          _error = '搜索失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadSubtitle(SubtitleSearchResult result) async {
    if (widget.videoPath == null) {
      _showError('无法确定视频路径，无法下载字幕');
      return;
    }

    setState(() {
      _downloadingStatus[result.id] = true;
    });

    try {
      final subtitlePath = await _downloadManager.downloadSubtitle(
        result,
        widget.videoPath!,
      );

      if (subtitlePath != null && mounted) {
        // 加载下载的字幕到播放器
        // 注意：这里需要传递 Player 实例，暂时只显示成功消息
        _showSuccess('字幕下载成功: ${result.title}');

        setState(() {
          _downloadingStatus[result.id] = false;
        });

        // 可选：自动返回并选择刚下载的字幕
        Navigator.of(context).pop(subtitlePath);
      } else {
        throw Exception('下载失败');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadingStatus[result.id] = false;
        });
        _showError('下载失败: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('字幕下载'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _searchSubtitles,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchSection(),
          const SizedBox(height: 16),
          Expanded(
            child: _buildResultsSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 搜索输入框
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: '搜索字幕',
              labelStyle: const TextStyle(color: Colors.grey),
              hintStyle: const TextStyle(color: Colors.grey),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  print('🔘 Search button clicked! _isLoading=$_isLoading');
                  if (!_isLoading) {
                    _searchSubtitles();
                  } else {
                    print('⚠️ Button disabled because _isLoading=true');
                  }
                },
              ),
            ),
            onSubmitted: (_) => _searchSubtitles(),
          ),
          const SizedBox(height: 16),

          // 语言选择器
          Row(
            children: [
              const Text(
                '语言:',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<SubtitleLanguage>(
                  value: _selectedLanguage,
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: Colors.grey[800],
                  items: _availableLanguages.map((language) {
                    return DropdownMenuItem<SubtitleLanguage>(
                      value: language,
                      child: Text(
                        language.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (language) {
                    setState(() {
                      _selectedLanguage = language;
                    });
                    _searchSubtitles();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              '正在搜索字幕...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _searchSubtitles,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.subtitles_off_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              '未找到字幕',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              '尝试使用不同的关键词或语言搜索',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        final isDownloading = _downloadingStatus[result.id] ?? false;

        return _buildSubtitleResultCard(result, isDownloading);
      },
    );
  }

  Widget _buildSubtitleResultCard(
      SubtitleSearchResult result, bool isDownloading) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和信息
            Row(
              children: [
                Expanded(
                  child: Text(
                    result.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRatingColor(result.rating),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    result.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 详细信息行
            Row(
              children: [
                _buildInfoChip(result.languageName, Icons.language),
                const SizedBox(width: 8),
                _buildInfoChip(result.format.toUpperCase(), Icons.description),
                const SizedBox(width: 8),
                _buildInfoChip('${result.downloads} 次下载', Icons.download),
              ],
            ),
            const SizedBox(height: 8),

            // 来源和日期
            Row(
              children: [
                Text(
                  '来源: ${result.source}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  _formatDate(result.uploadDate),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 下载按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    isDownloading ? null : () => _downloadSubtitle(result),
                icon: isDownloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.download),
                label: Text(isDownloading ? '下载中...' : '下载'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.5) return Colors.green;
    if (rating >= 4.0) return Colors.orange;
    if (rating >= 3.0) return Colors.yellow;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} 天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} 小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} 分钟前';
    } else {
      return '刚刚';
    }
  }

  /// 显示升级对话框
  void _showUpgradeDialog(String message, String? upgradeUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber),
            SizedBox(width: 8),
            Text('专业版功能'),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('稍后再说'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: 打开升级页面
              if (upgradeUrl != null) {
                print('Opening upgrade URL: $upgradeUrl');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: Text('了解专业版'),
          ),
        ],
      ),
    );
  }
}
