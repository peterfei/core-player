import 'package:flutter/material.dart';
import 'package:yinghe_player/core/plugin_system/plugin_registry.dart';
import '../plugins/plugin_registry_update_extension.dart';
import '../models/update/update_models.dart';
import '../widgets/update/update_progress_indicator.dart';

/// 插件更新管理页面
class PluginUpdateManagementPage extends StatefulWidget {
  const PluginUpdateManagementPage({super.key});

  @override
  State<PluginUpdateManagementPage> createState() => _PluginUpdateManagementPageState();
}

class _PluginUpdateManagementPageState extends State<PluginUpdateManagementPage> {
  final PluginRegistry _registry = PluginRegistry();
  
  List<UpdateInfo> _availableUpdates = [];
  bool _isChecking = false;
  bool _isUpdating = false;
  String? _error;
  
  final Map<String, DownloadProgress> _downloadProgress = {};
  final Map<String, String> _updateStages = {};

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isChecking = true;
      _error = null;
    });

    try {
      final updates = await _registry.checkAllPluginUpdates();
      setState(() {
        _availableUpdates = updates;
        _isChecking = false;
      });
    } catch (e) {
      setState(() {
        _error = '检查更新失败: $e';
        _isChecking = false;
      });
    }
  }

  Future<void> _updatePlugin(UpdateInfo updateInfo) async {
    setState(() {
      _isUpdating = true;
      _updateStages[updateInfo.pluginId] = 'checking';
    });

    try {
      final result = await _registry.performPluginUpdate(
        pluginId: updateInfo.pluginId,
        onProgress: (stage, progress) {
          setState(() {
            _updateStages[updateInfo.pluginId] = stage;
            _downloadProgress[updateInfo.pluginId] = _createProgress(
              updateInfo.pluginId,
              progress,
            );
          });
        },
      );

      if (result.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${updateInfo.pluginId} 更新成功!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _checkForUpdates();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ 更新失败: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 更新失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _updateStages.remove(updateInfo.pluginId);
          _downloadProgress.remove(updateInfo.pluginId);
        });
      }
    }
  }

  Future<void> _updateAll() async {
    if (_availableUpdates.isEmpty) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final results = await _registry.batchUpdatePlugins(
        updates: _availableUpdates,
        onProgress: (pluginId, stage, progress) {
          setState(() {
            _updateStages[pluginId] = stage;
            _downloadProgress[pluginId] = _createProgress(
              pluginId,
              progress,
            );
          });
        },
      );

      final successCount = results.values.where((r) => r.isSuccess).length;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 批量更新完成: $successCount/${results.length} 成功'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _checkForUpdates();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 批量更新失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _updateStages.clear();
          _downloadProgress.clear();
        });
      }
    }
  }

  DownloadProgress _createProgress(String pluginId, double progress) {
    return DownloadProgress(
      pluginId: pluginId,
      downloadedBytes: (progress * 100).toInt(),
      totalBytes: 100,
      status: DownloadStatus.downloading,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('插件更新管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isChecking || _isUpdating ? null : _checkForUpdates,
            tooltip: '检查更新',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _checkForUpdates,
        child: _buildBody(),
      ),
      floatingActionButton: _availableUpdates.isNotEmpty && !_isUpdating
          ? FloatingActionButton.extended(
              onPressed: _updateAll,
              icon: const Icon(Icons.system_update),
              label: const Text('全部更新'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isChecking && _availableUpdates.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在检查更新...'),
          ],
        ),
      );
    }

    if (_error != null && _availableUpdates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkForUpdates,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_availableUpdates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text('所有插件都是最新版本!'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkForUpdates,
              child: const Text('重新检查'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _availableUpdates.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final update = _availableUpdates[index];
        return _buildUpdateCard(update);
      },
    );
  }

  Widget _buildUpdateCard(UpdateInfo update) {
    final isUpdating = _updateStages.containsKey(update.pluginId);
    final stage = _updateStages[update.pluginId];
    final progress = _downloadProgress[update.pluginId];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        update.pluginId,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${update.currentVersion} → ${update.latestVersion}',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (update.isSecurityUpdate)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '安全更新',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              update.changelog,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.file_download, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  update.formattedSize,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _formatDate(update.releaseDate),
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            if (isUpdating) ...[
              const SizedBox(height: 12),
              UpdateProgressIndicator(
                stage: stage ?? '',
                progress: progress,
              ),
            ] else ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : () => _updatePlugin(update),
                  icon: const Icon(Icons.system_update),
                  label: const Text('立即更新'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
