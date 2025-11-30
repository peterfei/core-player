import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../services/excluded_paths_service.dart';
import '../theme/design_tokens/design_tokens.dart';

class ExcludedPathsScreen extends StatefulWidget {
  const ExcludedPathsScreen({Key? key}) : super(key: key);

  @override
  State<ExcludedPathsScreen> createState() => _ExcludedPathsScreenState();
}

class _ExcludedPathsScreenState extends State<ExcludedPathsScreen> {
  List<String> _paths = [];

  @override
  void initState() {
    super.initState();
    _loadPaths();
  }

  void _loadPaths() {
    setState(() {
      _paths = ExcludedPathsService.getAllPaths();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('排除列表管理'),
        actions: [
          if (_paths.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: '清空全部',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('清空排除列表'),
                    content: const Text('确定要清空所有排除项吗？被排除的剧集将在下次扫描时重新出现。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('清空'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await ExcludedPathsService.clearAll();
                  _loadPaths();
                }
              },
            ),
        ],
      ),
      body: _paths.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_off,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    '没有排除的路径',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _paths.length,
              itemBuilder: (context, index) {
                final itemPath = _paths[index];
                return ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(path.basename(itemPath)),
                  subtitle: Text(
                    itemPath,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.restore),
                    tooltip: '恢复',
                    onPressed: () async {
                      await ExcludedPathsService.removePath(itemPath);
                      _loadPaths();
                    },
                  ),
                );
              },
            ),
    );
  }
}
