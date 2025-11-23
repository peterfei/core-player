import 'package:flutter/material.dart';
import '../core/plugin_system/plugin_loader.dart';
import '../core/plugin_system/plugin_interface.dart';
import '../core/plugin_system/core_plugin.dart';
import '../services/plugin_status_service.dart';
import '../widgets/plugin_error_handler.dart';

class PluginManagerScreen extends StatefulWidget {
  const PluginManagerScreen({super.key});

  @override
  State<PluginManagerScreen> createState() => _PluginManagerScreenState();
}

class _PluginManagerScreenState extends State<PluginManagerScreen> {
  List<CorePlugin> _plugins = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlugins();
  }

  Future<void> _loadPlugins() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 使用插件状态服务加载插件
      final pluginService = PluginStatusService();
      await pluginService.initialize();

      setState(() {
        _plugins = pluginService.plugins.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('插件管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPlugins,
            tooltip: '刷新插件状态',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载插件...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('插件加载失败', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPlugins,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 版本信息卡片
        _buildEditionInfo(),
        const Divider(),
        // 插件列表
        Expanded(
          child: ListView.builder(
            itemCount: _plugins.length,
            itemBuilder: (context, index) {
              final plugin = _plugins[index];
              return _buildPluginCard(plugin);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEditionInfo() {
    final isCommunity = EditionConfig.isCommunityEdition;
    final editionText = isCommunity ? '社区版' : '专业版';
    final editionColor = isCommunity ? Colors.orange : Colors.green;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: editionColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: editionColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCommunity ? Icons.star_outline : Icons.star,
                color: editionColor,
              ),
              const SizedBox(width: 8),
              Text(
                '当前版本：$editionText',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: editionColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isCommunity
              ? '社区版包含基础播放功能，升级专业版解锁媒体服务器支持。'
              : '专业版包含全部功能，支持SMB、Emby、Jellyfin等媒体服务器。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (isCommunity) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _showUpgradeDialog(),
              icon: const Icon(Icons.upgrade),
              label: const Text('升级到专业版'),
              style: ElevatedButton.styleFrom(
                backgroundColor: editionColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPluginCard(CorePlugin plugin) {
    final metadata = plugin.metadata;
    final isActive = plugin.isActive;
    final isAvailable = plugin.isReady;
    final hasError = plugin.hasError;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (hasError) {
      statusColor = Colors.red;
      statusIcon = Icons.error_outline;
      statusText = '错误';
    } else if (isActive) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
      statusText = '已激活';
    } else if (isAvailable) {
      statusColor = Colors.orange;
      statusIcon = Icons.pending_outlined;
      statusText = '就绪';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.help_outline;
      statusText = '未初始化';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(metadata.icon, color: statusColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                metadata.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 16, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(metadata.description),
            const SizedBox(height: 4),
            Text(
              '版本 ${metadata.version} • ${metadata.author}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPluginDetails(plugin),
                const SizedBox(height: 16),
                _buildPluginActions(plugin),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPluginDetails(CorePlugin plugin) {
    final metadata = plugin.metadata;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('插件ID', metadata.id),
        _buildDetailRow('状态', plugin.state.toString()),
        _buildDetailRow('权限', metadata.permissions.map((p) => p.toString()).join(', ')
            .isEmpty ? '无特殊权限' : metadata.permissions.map((p) => p.toString()).join(', ')),
        _buildDetailRow('功能', metadata.capabilities.join(', ')
            .isEmpty ? '基础功能' : metadata.capabilities.join(', ')),
        if (metadata.license != PluginLicense.unknown)
          _buildDetailRow('许可证', metadata.license.toString()),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPluginActions(CorePlugin plugin) {
    return Wrap(
      spacing: 8,
      children: [
        if (plugin.isReady && !plugin.isActive)
          ElevatedButton.icon(
            onPressed: () => _activatePlugin(plugin),
            icon: const Icon(Icons.play_arrow),
            label: const Text('激活'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        if (plugin.isActive)
          OutlinedButton.icon(
            onPressed: () => _deactivatePlugin(plugin),
            icon: const Icon(Icons.stop),
            label: const Text('停用'),
          ),
        if (plugin.isReady)
          OutlinedButton.icon(
            onPressed: () => _testPlugin(plugin),
            icon: const Icon(Icons.build_circle_outlined),
            label: const Text('测试'),
          ),
        if (plugin.buildSettingsScreen() != null)
          OutlinedButton.icon(
            onPressed: () => _openPluginSettings(plugin),
            icon: const Icon(Icons.settings),
            label: const Text('设置'),
          ),
      ],
    );
  }

  Future<void> _activatePlugin(CorePlugin plugin) async {
    try {
      final pluginService = PluginStatusService();
      final success = await pluginService.activatePlugin('mediaserver');

      if (success) {
        setState(() {});
        _showMessage('插件 "${plugin.metadata.name}" 已激活', Colors.green);
      } else {
        await PluginErrorHandler.showErrorDialog(
          context,
          error: '插件激活失败',
          plugin: plugin,
        );
      }
    } catch (e) {
      await PluginErrorHandler.showErrorDialog(
        context,
        error: e,
        plugin: plugin,
      );
    }
  }

  Future<void> _deactivatePlugin(CorePlugin plugin) async {
    try {
      final pluginService = PluginStatusService();
      final success = await pluginService.deactivatePlugin('mediaserver');

      if (success) {
        setState(() {});
        _showMessage('插件 "${plugin.metadata.name}" 已停用', Colors.orange);
      } else {
        await PluginErrorHandler.showErrorDialog(
          context,
          error: '插件停用失败',
          plugin: plugin,
        );
      }
    } catch (e) {
      await PluginErrorHandler.showErrorDialog(
        context,
        error: e,
        plugin: plugin,
      );
    }
  }

  Future<void> _testPlugin(CorePlugin plugin) async {
    try {
      final pluginService = PluginStatusService();
      final isHealthy = await pluginService.checkPluginHealth('mediaserver');

      _showMessage(
        '插件 "${plugin.metadata.name}" 健康检查: ${isHealthy ? "正常" : "异常"}',
        isHealthy ? Colors.green : Colors.orange,
      );
    } catch (e) {
      await PluginErrorHandler.showErrorDialog(
        context,
        error: e,
        plugin: plugin,
        title: '插件健康检查失败',
      );
    }
  }

  Future<void> _openPluginSettings(CorePlugin plugin) async {
    final settingsWidget = plugin.buildSettingsScreen();
    if (settingsWidget != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: Text('${plugin.metadata.name} 设置')),
            body: settingsWidget,
          ),
        ),
      );
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('升级到专业版'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('升级到专业版以解锁以下功能：'),
            SizedBox(height: 12),
            BulletPoint(text: 'SMB/CIFS 网络共享支持'),
            BulletPoint(text: 'Emby 媒体服务器集成'),
            BulletPoint(text: 'Jellyfin 媒体服务器集成'),
            BulletPoint(text: '高级网络功能'),
            BulletPoint(text: '优先技术支持'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showMessage('升级功能即将开放，敬请期待！', Colors.blue);
            },
            child: const Text('立即升级'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class BulletPoint extends StatelessWidget {
  final String text;

  const BulletPoint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}