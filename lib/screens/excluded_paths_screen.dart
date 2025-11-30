import 'package:flutter/material.dart';
import '../services/excluded_paths_service.dart';
import '../theme/design_tokens/design_tokens.dart';

/// 排除列表管理页面
/// 允许用户查看和恢复已排除的剧集路径
class ExcludedPathsScreen extends StatefulWidget {
  const ExcludedPathsScreen({Key? key}) : super(key: key);

  @override
  State<ExcludedPathsScreen> createState() => _ExcludedPathsScreenState();
}

class _ExcludedPathsScreenState extends State<ExcludedPathsScreen> {
  List<String> _excludedPaths = [];

  @override
  void initState() {
    super.initState();
    _loadPaths();
  }

  void _loadPaths() {
    setState(() {
      _excludedPaths = ExcludedPathsService.getAllPaths();
    });
  }

  Future<void> _removePath(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复此剧集'),
        content: const Text('确定要恢复显示此剧集吗？\n\n需要重新扫描媒体库后才能看到它。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ExcludedPathsService.removePath(path);
      _loadPaths();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已恢复，请重新扫描媒体库'),
          ),
        );
      }
    }
  }

  Future<void> _clearAll() async {
    if (_excludedPaths.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空排除列表'),
        content: Text('确定要清空所有 ${_excludedPaths.length} 个排除项吗？\n\n需要重新扫描媒体库后才能看到它们。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ExcludedPathsService.clearAll();
      _loadPaths();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已清空排除列表，请重新扫描媒体库'),
          ),
        );
      }
    }
  }

  String _formatPath(String path) {
    // 简化路径显示，只显示最后几个部分
    final parts = path.split('/');
    if (parts.length > 3) {
      return '.../${parts.sublist(parts.length - 3).join('/')}';
    }
    return path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('排除列表'),
        actions: [
          if (_excludedPaths.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: '清空全部',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _excludedPaths.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '没有排除的剧集',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '长按剧集封面可以将其排除',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _excludedPaths.length,
              itemBuilder: (context, index) {
                final path = _excludedPaths[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.block),
                    title: Text(
                      _formatPath(path),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.restore),
                      tooltip: '恢复',
                      onPressed: () => _removePath(path),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
