import 'package:flutter/material.dart';
import '../models/media_server_config.dart';
import '../services/media_server_service.dart';
import '../services/file_source/file_source.dart';
import '../services/file_source_factory.dart';
import '../theme/design_tokens/design_tokens.dart';

/// 共享文件夹管理页面
class SharedFolderManagementPage extends StatefulWidget {
  final MediaServerConfig server;

  const SharedFolderManagementPage({
    Key? key,
    required this.server,
  }) : super(key: key);

  @override
  State<SharedFolderManagementPage> createState() => _SharedFolderManagementPageState();
}

class _SharedFolderManagementPageState extends State<SharedFolderManagementPage> {
  late List<String> _sharedFolders;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _sharedFolders = List.from(widget.server.sharedFolders ?? []);
  }

  Future<void> _addNewSharedFolder() async {
    // 连接到服务器并获取共享列表
    setState(() => _isLoading = true);

    try {
      final source = FileSourceFactory.createFromConfig(widget.server);
      if (source == null) {
        throw Exception('不支持的服务器类型');
      }

      await source.connect();
      final shares = await source.listFiles('/');
      await source.disconnect();

      if (!mounted) return;

      // 显示共享选择对话框
      final selectedShares = await showDialog<List<String>>(
        context: context,
        builder: (context) => _ShareSelectionDialog(
          shares: shares,
          existingFolders: _sharedFolders,
        ),
      );

      if (selectedShares != null && selectedShares.isNotEmpty) {
        setState(() {
          _sharedFolders.addAll(selectedShares);
          _sharedFolders = _sharedFolders.toSet().toList(); // 去重
        });
        await _saveChanges();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取共享列表失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeSharedFolder(String folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          '删除共享文件夹',
          style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          '确定要删除 "$folder"？\n这不会删除服务器上的文件，只是从配置中移除。',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _sharedFolders.remove(folder);
      });
      await _saveChanges();
    }
  }

  Future<void> _saveChanges() async {
    final updatedConfig = widget.server.copyWith(sharedFolders: _sharedFolders);
    await MediaServerService.updateServer(updatedConfig);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('保存成功'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _clearAllFolders() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          '清空所有共享文件夹',
          style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          '确定要清空所有共享文件夹配置？\n这不会删除服务器上的文件。',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _sharedFolders.clear();
      });
      await _saveChanges();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          '管理共享文件夹',
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (_sharedFolders.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAllFolders,
              icon: const Icon(Icons.clear_all, color: AppColors.error),
              label: const Text('清空全部', style: TextStyle(color: AppColors.error)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 16),
        child: FloatingActionButton.extended(
          onPressed: _addNewSharedFolder,
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add),
          label: const Text('添加共享'),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBody() {
    if (_sharedFolders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_off_outlined,
              size: 80,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.large),
            Text(
              '未添加共享文件夹',
              style: AppTextStyles.headlineSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            Text(
              '点击下方按钮添加共享文件夹',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.medium),
      itemCount: _sharedFolders.length,
      itemBuilder: (context, index) {
        final folder = _sharedFolders[index];
        return Card(
          color: AppColors.surface,
          margin: const EdgeInsets.only(bottom: AppSpacing.medium),
          child: ListTile(
            leading: const Icon(
              Icons.folder_shared,
              color: AppColors.primary,
            ),
            title: Text(
              folder,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              '共享文件夹 ${index + 1}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: () => _removeSharedFolder(folder),
              tooltip: '删除',
            ),
          ),
        );
      },
    );
  }
}

/// 共享文件夹选择对话框
class _ShareSelectionDialog extends StatefulWidget {
  final List<FileItem> shares;
  final List<String> existingFolders;

  const _ShareSelectionDialog({
    required this.shares,
    required this.existingFolders,
  });

  @override
  State<_ShareSelectionDialog> createState() => _ShareSelectionDialogState();
}

class _ShareSelectionDialogState extends State<_ShareSelectionDialog> {
  final Set<String> _selectedShares = {};

  @override
  Widget build(BuildContext context) {
    // 过滤掉已存在的共享
    final availableShares = widget.shares
        .where((s) => !widget.existingFolders.contains(s.path))
        .toList();

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        '选择要添加的共享',
        style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimary),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: availableShares.isEmpty
            ? Text(
                '所有共享文件夹已添加',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: availableShares.map((share) {
                  final isSelected = _selectedShares.contains(share.path);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedShares.add(share.path);
                        } else {
                          _selectedShares.remove(share.path);
                        }
                      });
                    },
                    title: Text(
                      share.name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      share.path,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    secondary: const Icon(
                      Icons.folder_shared,
                      color: AppColors.textSecondary,
                    ),
                  );
                }).toList(),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _selectedShares.isEmpty
              ? null
              : () => Navigator.pop(context, _selectedShares.toList()),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: Text('添加 (${_selectedShares.length})'),
        ),
      ],
    );
  }
}
