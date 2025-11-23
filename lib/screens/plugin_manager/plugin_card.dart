import 'package:flutter/material.dart';
import 'package:yinghe_player/core/plugin_system/core_plugin.dart';
import 'package:yinghe_player/core/plugin_system/plugin_interface.dart';
import 'package:yinghe_player/theme/design_tokens/design_tokens.dart';

/// 插件卡片组件
class PluginCard extends StatefulWidget {
  final CorePlugin plugin;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;

  const PluginCard({
    Key? key,
    required this.plugin,
    this.onTap,
    this.onToggle,
  }) : super(key: key);

  @override
  State<PluginCard> createState() => _PluginCardState();
}

class _PluginCardState extends State<PluginCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.7,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _handleTapCancel() {
    _animationController.reverse();
  }

  Color _getStateColor() {
    switch (widget.plugin.state) {
      case PluginState.active:
        return AppColors.success;
      case PluginState.error:
        return AppColors.error;
      case PluginState.inactive:
        return Colors.grey;
      case PluginState.initializing:
        return Colors.orange;
      default:
        return AppColors.primary;
    }
  }

  String _getStateText() {
    switch (widget.plugin.state) {
      case PluginState.uninitialized:
        return '未初始化';
      case PluginState.initializing:
        return '初始化中';
      case PluginState.ready:
        return '就绪';
      case PluginState.active:
        return '已启用';
      case PluginState.inactive:
        return '未启用';
      case PluginState.error:
        return '错误';
      case PluginState.disposed:
        return '已释放';
    }
  }

  IconData _getStateIcon() {
    switch (widget.plugin.state) {
      case PluginState.active:
        return Icons.check_circle;
      case PluginState.error:
        return Icons.error;
      case PluginState.inactive:
        return Icons.disabled_by_default;
      case PluginState.initializing:
        return Icons.sync;
      default:
        return Icons.extension;
    }
  }

  bool _isToggleEnabled() {
    return widget.plugin.state == PluginState.ready ||
           widget.plugin.state == PluginState.active ||
           widget.plugin.state == PluginState.inactive;
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.plugin.metadata;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: GestureDetector(
              onTapDown: _handleTapDown,
              onTapUp: _handleTapUp,
              onTapCancel: _handleTapCancel,
              onTap: widget.onTap,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: _getStateColor().withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getStateColor().withOpacity(0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            // Plugin icon
                            Hero(
                              tag: 'plugin-icon-${metadata.id}',
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _getStateColor().withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  metadata.icon,
                                  color: _getStateColor(),
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Plugin info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    metadata.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  Text(
                                    'v${metadata.version}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Status indicator
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStateColor().withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getStateColor().withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getStateIcon(),
                                    size: 12,
                                    color: _getStateColor(),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getStateText(),
                                    style: TextStyle(
                                      color: _getStateColor(),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Description
                        Text(
                          metadata.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 12),

                        // Capabilities
                        if (metadata.capabilities.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: metadata.capabilities.take(3).map(
                              (capability) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  capability,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ).toList(),
                          ),
                          if (metadata.capabilities.length > 3)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '+${metadata.capabilities.length - 3} 更多功能',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                        ],

                        // Actions
                        Row(
                          children: [
                            // Author
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      metadata.author,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Toggle button
                            if (widget.onToggle != null && _isToggleEnabled())
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: IconButton(
                                  key: ValueKey(widget.plugin.isActive),
                                  onPressed: widget.onToggle,
                                  icon: widget.plugin.isActive
                                      ? const Icon(Icons.toggle_on, color: AppColors.success)
                                      : const Icon(Icons.toggle_off, color: Colors.grey),
                                  tooltip: widget.plugin.isActive ? '停用' : '启用',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 扩展的插件卡片组件（用于详情页面）
class DetailedPluginCard extends StatelessWidget {
  final CorePlugin plugin;
  final VoidCallback? onSettings;
  final VoidCallback? onToggle;

  const DetailedPluginCard({
    Key? key,
    required this.plugin,
    this.onSettings,
    this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final metadata = plugin.metadata;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header with gradient background
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.1),
                  Theme.of(context).primaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  metadata.icon,
                  size: 64,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  metadata.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'v${metadata.version}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  metadata.description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status and actions
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusSection(),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        if (onSettings != null)
                          IconButton.outlined(
                            onPressed: onSettings,
                            icon: const Icon(Icons.settings),
                            tooltip: '设置',
                          ),
                        const SizedBox(width: 8),
                        if (onToggle != null)
                          ElevatedButton.icon(
                            onPressed: onToggle,
                            icon: Icon(
                              plugin.isActive ? Icons.stop : Icons.play_arrow,
                            ),
                            label: Text(plugin.isActive ? '停用' : '启用'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: plugin.isActive ? Colors.red : AppColors.success,
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Capabilities
                if (metadata.capabilities.isNotEmpty) ...[
                  Text(
                    '功能特性',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: metadata.capabilities.map(
                      (capability) => Chip(
                        label: Text(capability),
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      ),
                    ).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // Information
                Text(
                  '详细信息',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow('作者', metadata.author),
                if (metadata.homepage != null)
                  _buildInfoRow('主页', metadata.homepage!),
                _buildInfoRow('许可证', metadata.license.displayName),
                if (metadata.permissions.isNotEmpty)
                  _buildInfoRow('权限', '${metadata.permissions.length} 项'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (plugin.state) {
      case PluginState.active:
        statusColor = AppColors.success;
        statusText = '已启用';
        statusIcon = Icons.check_circle;
        break;
      case PluginState.error:
        statusColor = AppColors.error;
        statusText = '错误';
        statusIcon = Icons.error;
        break;
      case PluginState.inactive:
        statusColor = Colors.grey;
        statusText = '未启用';
        statusIcon = Icons.disabled_by_default;
        break;
      case PluginState.initializing:
        statusColor = Colors.orange;
        statusText = '初始化中';
        statusIcon = Icons.sync;
        break;
      default:
        statusColor = AppColors.primary;
        statusText = '就绪';
        statusIcon = Icons.extension;
    }

    return Row(
      children: [
        Icon(statusIcon, color: statusColor, size: 20),
        const SizedBox(width: 8),
        Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}