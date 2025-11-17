import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/buffer_config.dart';
import '../services/stream_quality_service.dart';

/// 画质选择器组件
class QualitySelector extends StatefulWidget {
  final List<QualityLevel> availableQualities;
  final QualityLevel currentQuality;
  final bool autoMode;
  final AbrAlgorithm currentAlgorithm;
  final Function(QualityLevel) onQualitySelected;
  final Function(AbrAlgorithm) onAlgorithmSelected;
  final bool enableAutoMode;
  final Color? color;
  final double? iconSize;

  const QualitySelector({
    Key? key,
    required this.availableQualities,
    required this.currentQuality,
    required this.autoMode,
    required this.currentAlgorithm,
    required this.onQualitySelected,
    required this.onAlgorithmSelected,
    this.enableAutoMode = true,
    this.color,
    this.iconSize,
  }) : super(key: key);

  @override
  State<QualitySelector> createState() => _QualitySelectorState();
}

class _QualitySelectorState extends State<QualitySelector> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.color ?? theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 主选择按钮
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
              HapticFeedback.lightImpact();
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.autoMode ? Icons.auto_fix_high : _getQualityIcon(widget.currentQuality),
                    size: widget.iconSize ?? 16,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getDisplayText(),
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: color,
                  ),
                ],
              ),
            ),
          ),

          // 展开的面板
          if (_isExpanded) _buildExpandedPanel(color),
        ],
      ),
    );
  }

  Widget _buildExpandedPanel(Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 画质选择
          if (widget.enableAutoMode) ...[
            _buildSectionTitle('画质', Icons.hd),
            _buildQualityOptions(color),
            const SizedBox(height: 12),
          ],

          // ABR 算法选择
          _buildSectionTitle('自适应算法', Icons.tune),
          _buildAlgorithmOptions(color),

          // 当前状态信息
          const SizedBox(height: 12),
          _buildStatusInfo(color),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityOptions(Color color) {
    final qualities = widget.enableAutoMode
        ? [QualityLevel.auto, ...widget.availableQualities.where((q) => q != QualityLevel.auto)]
        : widget.availableQualities.where((q) => q != QualityLevel.auto).toList();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: qualities.map((quality) => _buildQualityChip(quality, color)).toList(),
    );
  }

  Widget _buildQualityChip(QualityLevel quality, Color color) {
    final isSelected = (quality == QualityLevel.auto && widget.autoMode) ||
                      (quality != QualityLevel.auto && quality == widget.currentQuality);

    return InkWell(
      onTap: () {
        widget.onQualitySelected(quality);
        HapticFeedback.selectionClick();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              quality.icon,
              size: 14,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
            ),
            const SizedBox(width: 4),
            Text(
              quality.displayName,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlgorithmOptions(Color color) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: AbrAlgorithm.values.map((algorithm) => _buildAlgorithmChip(algorithm, color)).toList(),
    );
  }

  Widget _buildAlgorithmChip(AbrAlgorithm algorithm, Color color) {
    final isSelected = algorithm == widget.currentAlgorithm;

    return InkWell(
      onTap: () {
        widget.onAlgorithmSelected(algorithm);
        HapticFeedback.selectionClick();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          _getAlgorithmDisplayName(algorithm),
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusInfo(Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前设置',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getStatusText(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _getDisplayText() {
    if (widget.autoMode) {
      return '自动 (${widget.currentQuality.displayName})';
    } else {
      return widget.currentQuality.displayName;
    }
  }

  IconData _getQualityIcon(QualityLevel quality) {
    return quality.icon;
  }

  String _getAlgorithmDisplayName(AbrAlgorithm algorithm) {
    switch (algorithm) {
      case AbrAlgorithm.throughput:
        return '吞吐量';
      case AbrAlgorithm.bola:
        return 'BOLA';
      case AbrAlgorithm.dynamic:
        return '动态';
    }
  }

  String _getStatusText() {
    if (widget.autoMode) {
      return '自动模式，使用${_getAlgorithmDisplayName(widget.currentAlgorithm)}算法选择最优画质';
    } else {
      return '手动模式，固定画质${widget.currentQuality.displayName} (${widget.currentQuality.bitrateDescription})';
    }
  }
}

/// 简化的画质选择器（用于紧凑界面）
class CompactQualitySelector extends StatelessWidget {
  final List<QualityLevel> availableQualities;
  final QualityLevel currentQuality;
  final bool autoMode;
  final Function(QualityLevel) onQualitySelected;
  final Color? color;
  final double? fontSize;

  const CompactQualitySelector({
    Key? key,
    required this.availableQualities,
    required this.currentQuality,
    required this.autoMode,
    required this.onQualitySelected,
    this.color,
    this.fontSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = color ?? theme.colorScheme.primary;

    return PopupMenuButton<QualityLevel>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              autoMode ? Icons.auto_fix_high : currentQuality.icon,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              autoMode ? '自动' : currentQuality.displayName,
              style: TextStyle(
                color: color,
                fontSize: fontSize ?? 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: color,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        // 自动选项
        if (availableQualities.contains(QualityLevel.auto))
          PopupMenuItem(
            value: QualityLevel.auto,
            child: Row(
              children: [
                Icon(
                  Icons.auto_fix_high,
                  size: 18,
                  color: autoMode ? color : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  '自动',
                  style: TextStyle(
                    color: autoMode ? color : null,
                    fontWeight: autoMode ? FontWeight.w600 : null,
                  ),
                ),
                if (autoMode)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.check,
                      size: 16,
                      color: color,
                    ),
                  ),
              ],
            ),
          ),
        const PopupMenuDivider(height: 1),
        // 质量选项
        ...availableQualities
            .where((q) => q != QualityLevel.auto)
            .map((quality) => PopupMenuItem(
                  value: quality,
                  child: Row(
                    children: [
                      Icon(
                        quality.icon,
                        size: 18,
                        color: (!autoMode && quality == currentQuality) ? color : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quality.displayName,
                              style: TextStyle(
                                color: (!autoMode && quality == currentQuality) ? color : null,
                                fontWeight: (!autoMode && quality == currentQuality) ? FontWeight.w600 : null,
                              ),
                            ),
                            Text(
                              quality.bitrateDescription,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!autoMode && quality == currentQuality)
                        Icon(
                          Icons.check,
                          size: 16,
                          color: color,
                        ),
                    ],
                  ),
                )),
      ],
      onSelected: (quality) {
        onQualitySelected(quality);
        HapticFeedback.selectionClick();
      },
    );
  }
}

/// 画质信息面板
class QualityInfoPanel extends StatelessWidget {
  final QualityLevel currentQuality;
  final bool autoMode;
  final AbrAlgorithm algorithm;
  final List<QualityLevel> availableQualities;
  final Color? color;

  const QualityInfoPanel({
    Key? key,
    required this.currentQuality,
    required this.autoMode,
    required this.algorithm,
    required this.availableQualities,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = color ?? theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Icon(
                  Icons.settings_hd,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  '画质设置',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 当前画质信息
            _buildCurrentQualityInfo(color),

            const SizedBox(height: 16),

            // 可用画质列表
            _buildAvailableQualitiesList(color),

            const SizedBox(height: 16),

            // 算法信息
            if (autoMode) _buildAlgorithmInfo(color),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentQualityInfo(Color color) {
    final displayQuality = autoMode ? QualityLevel.auto : currentQuality;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(displayQuality.icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                '当前画质',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            autoMode
                ? '自动模式 (${_getAlgorithmDisplayName(algorithm)}算法)'
                : displayQuality.displayName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!autoMode) ...[
            const SizedBox(height: 2),
            Text(
              '比特率: ${currentQuality.bitrateDescription}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvailableQualitiesList(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '可用画质',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableQualities
              .where((q) => q != QualityLevel.auto)
              .map((quality) => _buildQualityBadge(quality, color))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildQualityBadge(QualityLevel quality, Color color) {
    final isCurrent = !autoMode && quality == currentQuality;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent ? color : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            quality.icon,
            size: 14,
            color: isCurrent ? Colors.white : Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(
            quality.displayName,
            style: TextStyle(
              fontSize: 12,
              color: isCurrent ? Colors.white : Colors.grey[700],
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlgorithmInfo(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '自适应算法',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getAlgorithmDisplayName(algorithm),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getAlgorithmDescription(algorithm),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getAlgorithmDisplayName(AbrAlgorithm algorithm) {
    switch (algorithm) {
      case AbrAlgorithm.throughput:
        return '吞吐量算法';
      case AbrAlgorithm.bola:
        return 'BOLA算法';
      case AbrAlgorithm.dynamic:
        return '动态算法';
    }
  }

  String _getAlgorithmDescription(AbrAlgorithm algorithm) {
    switch (algorithm) {
      case AbrAlgorithm.throughput:
        return '基于网络带宽选择最高可播放的画质';
      case AbrAlgorithm.bola:
        return '基于缓冲区占用量平衡画质和流畅度';
      case AbrAlgorithm.dynamic:
        return '综合考虑带宽、稳定性和缓冲状态';
    }
  }
}