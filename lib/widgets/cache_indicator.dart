import 'package:flutter/material.dart';
import 'dart:async';
import '../models/cache_config.dart';
import '../models/cache_entry.dart';
import '../services/video_cache_service.dart';
import '../services/cache_download_service.dart';

class CacheIndicator extends StatefulWidget {
  final String videoUrl;
  final String? videoTitle;
  final bool showProgress;
  final VoidCallback? onTap;

  const CacheIndicator({
    Key? key,
    required this.videoUrl,
    this.videoTitle,
    this.showProgress = true,
    this.onTap,
  }) : super(key: key);

  @override
  State<CacheIndicator> createState() => _CacheIndicatorState();
}

class _CacheIndicatorState extends State<CacheIndicator> {
  CacheEntry? _cacheEntry;
  DownloadProgress? _downloadProgress;
  bool _isDownloading = false;
  StreamSubscription? _downloadSubscription;

  @override
  void initState() {
    super.initState();
    _initializeCacheStatus();
  }

  @override
  void didUpdateWidget(CacheIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _downloadSubscription?.cancel();
      _initializeCacheStatus();
    }
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeCacheStatus() async {
    await _updateCacheStatus();
    _setupDownloadListener();
  }

  Future<void> _updateCacheStatus() async {
    final cacheService = VideoCacheService.instance;
    final entry = await cacheService.getCacheEntry(widget.videoUrl);
    final isDownloading = CacheDownloadService.instance.isDownloading(widget.videoUrl);

    setState(() {
      _cacheEntry = entry;
      _isDownloading = isDownloading;
    });
  }

  void _setupDownloadListener() {
    _downloadSubscription?.cancel();
    _downloadSubscription = CacheDownloadService.instance
        .getDownloadProgress(widget.videoUrl)
        .listen((progress) {
      setState(() {
        _downloadProgress = progress;
      });
    });
  }

  bool get _isCached => _cacheEntry?.isComplete ?? false;
  bool get _isPartiallyCached => (_cacheEntry != null && !_isCached) || _isDownloading;
  double get _downloadPercentage {
    if (_downloadProgress != null) {
      return _downloadProgress!.progressPercentage;
    }
    if (_cacheEntry != null && !_isCached) {
      return _cacheEntry!.downloadProgress;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCacheIcon(),
            if (widget.showProgress && _isPartiallyCached) ...[
              const SizedBox(width: 8),
              _buildProgressIndicator(),
            ],
            if (widget.showProgress && _isCached) ...[
              const SizedBox(width: 8),
              _buildCachedLabel(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCacheIcon() {
    IconData icon;
    Color color;

    if (_isCached) {
      icon = Icons.offline_bolt;
      color = Colors.green;
    } else if (_isDownloading || _isPartiallyCached) {
      icon = Icons.downloading;
      color = Colors.orange;
    } else {
      icon = Icons.cloud_download_outlined;
      color = Colors.grey;
    }

    return Icon(
      icon,
      size: 20,
      color: color,
    );
  }

  Widget _buildProgressIndicator() {
    final percentage = _downloadPercentage;

    return SizedBox(
      width: 60,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              _isDownloading ? Colors.orange : Colors.blue,
            ),
            minHeight: 3,
          ),
          const SizedBox(height: 2),
          Text(
            '${(percentage * 100).toInt()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCachedLabel() {
    final size = _cacheEntry?.fileSize ?? 0;
    final formattedSize = _formatFileSize(size);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '已缓存',
          style: TextStyle(
            color: Colors.green,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          formattedSize,
          style: const TextStyle(
            color: Colors.green,
            fontSize: 8,
          ),
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class CacheControlButton extends StatefulWidget {
  final String videoUrl;
  final String? videoTitle;

  const CacheControlButton({
    Key? key,
    required this.videoUrl,
    this.videoTitle,
  }) : super(key: key);

  @override
  State<CacheControlButton> createState() => _CacheControlButtonState();
}

class _CacheControlButtonState extends State<CacheControlButton> {
  CacheEntry? _cacheEntry;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _updateStatus();
  }

  Future<void> _updateStatus() async {
    final cacheService = VideoCacheService.instance;
    final entry = await cacheService.getCacheEntry(widget.videoUrl);
    final isDownloading = CacheDownloadService.instance.isDownloading(widget.videoUrl);

    setState(() {
      _cacheEntry = entry;
      _isDownloading = isDownloading;
    });
  }

  bool get _isCached => _cacheEntry?.isComplete ?? false;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        _isCached ? Icons.offline_bolt : Icons.cloud_download,
        color: _isCached ? Colors.green : Colors.white,
      ),
      onSelected: _handleMenuSelection,
      itemBuilder: (context) => [
        if (_isCached) ...[
          PopupMenuItem(
            value: 'remove',
            child: Row(
              children: const [
                Icon(Icons.delete_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('移除缓存'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'info',
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text('缓存信息'),
              ],
            ),
          ),
        ] else ...[
          if (_isDownloading)
            PopupMenuItem(
              value: 'cancel',
              child: Row(
                children: const [
                  Icon(Icons.cancel, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('取消下载'),
                ],
              ),
            )
          else
            PopupMenuItem(
              value: 'download',
              child: Row(
                children: const [
                  Icon(Icons.download, color: Colors.green),
                  SizedBox(width: 8),
                  Text('缓存视频'),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _handleMenuSelection(String value) async {
    final cacheService = VideoCacheService.instance;
    final downloadService = CacheDownloadService.instance;

    switch (value) {
      case 'download':
        try {
          await downloadService.downloadAndCache(widget.videoUrl, title: widget.videoTitle);
          await _updateStatus();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('开始缓存视频'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('缓存失败: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        break;

      case 'cancel':
        await downloadService.cancelDownload(widget.videoUrl);
        await _updateStatus();
        break;

      case 'remove':
        await cacheService.removeCache(widget.videoUrl);
        await _updateStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('缓存已移除'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        break;

      case 'info':
        if (_cacheEntry != null && mounted) {
          _showCacheInfo();
        }
        break;
    }
  }

  void _showCacheInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.videoTitle ?? '视频缓存信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('文件大小: ${_formatFileSize(_cacheEntry!.fileSize)}'),
            Text('缓存时间: ${_formatDateTime(_cacheEntry!.createdAt)}'),
            Text('访问次数: ${_cacheEntry!.accessCount}'),
            Text('最后访问: ${_formatDateTime(_cacheEntry!.lastAccessedAt)}'),
            Text('文件路径: ${_cacheEntry!.localPath}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}