import 'package:flutter/material.dart';
import '../services/network_stream_service.dart';
import '../models/stream_info.dart';

/// URL输入对话框
class UrlInputDialog extends StatefulWidget {
  const UrlInputDialog({Key? key}) : super(key: key);

  @override
  State<UrlInputDialog> createState() => _UrlInputDialogState();
}

class _UrlInputDialogState extends State<UrlInputDialog> {
  final TextEditingController _urlController = TextEditingController();
  final NetworkStreamService _networkService = NetworkStreamService();
  List<Map<String, dynamic>> _urlHistory = [];
  bool _isLoading = false;
  bool _isValidUrl = false;

  @override
  void initState() {
    super.initState();
    _loadUrlHistory();
    _urlController.addListener(_validateUrl);
  }

  @override
  void dispose() {
    _urlController.removeListener(_validateUrl);
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadUrlHistory() async {
    final history = await _networkService.getUrlHistory();
    setState(() {
      _urlHistory = history;
    });
  }

  void _validateUrl() {
    final url = _urlController.text.trim();
    setState(() {
      _isValidUrl = _networkService.isValidUrl(url);
    });
  }

  void _onHistoryItemSelected(String url) {
    _urlController.text = url;
    _validateUrl();
  }

  Future<void> _testUrl() async {
    final url = _urlController.text.trim();
    if (!_isValidUrl || url.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final isAccessible = await _networkService.testUrlAccessibility(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAccessible ? 'URL 可访问' : 'URL 无法访问'),
            backgroundColor: isAccessible ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('连接测试失败'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeFromHistory(String url) async {
    await _networkService.removeUrlFromHistory(url);
    await _loadUrlHistory();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已从历史记录中删除')),
      );
    }
  }

  void _clearAllHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除所有历史记录'),
        content: const Text('确定要清除所有URL历史记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _networkService.clearUrlHistory();
              await _loadUrlHistory();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link, size: 24),
                const SizedBox(width: 12),
                const Text(
                  '播放网络视频',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // URL输入区域
            const Text(
              '请输入视频URL:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'https://example.com/video.mp4',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: const OutlineInputBorder(),
                      errorText: _urlController.text.isNotEmpty && !_isValidUrl
                          ? '请输入有效的URL'
                          : null,
                    ),
                    onSubmitted: (_) => _handlePlay(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isLoading ? null : _testUrl,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  tooltip: '测试URL',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // URL历史记录
            if (_urlHistory.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '最近播放:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  TextButton(
                    onPressed: _clearAllHistory,
                    style: TextButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text('清除全部'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _urlHistory.length,
                  itemBuilder: (context, index) {
                    final item = _urlHistory[index];
                    final url = item['url'] as String;
                    final protocol = item['protocol'] as String;
                    final addedAt = DateTime.parse(item['addedAt'] as String);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: _getProtocolColor(protocol),
                          child: Text(
                            protocol.toUpperCase().substring(0, 1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          url,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _getProtocolLabel(protocol),
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        onTap: () => _onHistoryItemSelected(url),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _onHistoryItemSelected(url),
                              icon: const Icon(Icons.play_arrow, size: 20),
                              tooltip: '播放',
                            ),
                            IconButton(
                              onPressed: () => _removeFromHistory(url),
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: '删除',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              const Text(
                '暂无播放历史',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],

            const SizedBox(height: 16),

            // 按钮区域
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isValidUrl ? _handlePlay : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('播放'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePlay() async {
    final url = _urlController.text.trim();
    if (!_isValidUrl || url.isEmpty) return;

    // 添加到历史记录
    await _networkService.addUrlToHistory(url);

    // 关闭对话框并返回URL
    Navigator.of(context).pop(url);
  }

  Color _getProtocolColor(String protocol) {
    switch (protocol.toLowerCase()) {
      case 'hls':
        return Colors.orange;
      case 'dash':
        return Colors.purple;
      case 'http':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getProtocolLabel(String protocol) {
    switch (protocol.toLowerCase()) {
      case 'hls':
        return 'HLS流媒体';
      case 'dash':
        return 'DASH流媒体';
      case 'http':
        return 'HTTP直连';
      default:
        return '未知协议';
    }
  }
}

/// 显示URL输入对话框
Future<String?> showUrlInputDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const UrlInputDialog(),
  );
}
