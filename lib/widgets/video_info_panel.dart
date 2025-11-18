import 'package:flutter/material.dart';
import '../models/video_info.dart';
import '../models/codec_info.dart';
import '../models/hardware_acceleration_config.dart';
import '../services/hardware_acceleration_service.dart';

/// 视频信息面板组件
/// 显示详细的视频技术信息
class VideoInfoPanel extends StatefulWidget {
  final VideoInfo videoInfo;
  final VoidCallback? onClose;
  final bool showHardwareAccelerationInfo;

  const VideoInfoPanel({
    super.key,
    required this.videoInfo,
    this.onClose,
    this.showHardwareAccelerationInfo = true,
  });

  /// 显示视频信息面板的静态方法
  static void show({
    required BuildContext context,
    required VideoInfo videoInfo,
    bool showHardwareAccelerationInfo = true,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return VideoInfoPanel(
          videoInfo: videoInfo,
          showHardwareAccelerationInfo: showHardwareAccelerationInfo,
          onClose: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  @override
  State<VideoInfoPanel> createState() => _VideoInfoPanelState();
}

class _VideoInfoPanelState extends State<VideoInfoPanel> {
  HardwareAccelerationConfig? _hwAccelConfig;

  @override
  void initState() {
    super.initState();
    _loadHardwareAccelerationInfo();
  }

  Future<void> _loadHardwareAccelerationInfo() async {
    final config = HardwareAccelerationService.instance.currentConfig;
    if (mounted) {
      setState(() {
        _hwAccelConfig = config;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '视频信息',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onClose,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('关闭'),
                ),
              ],
            ),
          ),

          // 内容区域
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 基本信息
                  _buildSection(
                    title: '基本信息',
                    icon: Icons.info,
                    children: [
                      _buildInfoRow('文件名', widget.videoInfo.fileName),
                      _buildInfoRow('分辨率', widget.videoInfo.resolutionLabel),
                      _buildInfoRow('画质', widget.videoInfo.qualityLabel),
                      _buildInfoRow(
                        '时长',
                        widget.videoInfo.formattedDuration,
                      ),
                      _buildInfoRow(
                        '帧率',
                        widget.videoInfo.fpsLabel,
                      ),
                      _buildInfoRow(
                        '文件大小',
                        widget.videoInfo.formattedFileSize,
                      ),
                      _buildInfoRow('容器格式', widget.videoInfo.container),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 视频编码
                  _buildSection(
                    title: '视频编码',
                    icon: Icons.video_settings,
                    children: [
                      _buildInfoRow(
                        '编解码器',
                        widget.videoInfo.videoCodec.displayName,
                      ),
                      _buildInfoRow(
                        '编码规格',
                        widget.videoInfo.videoCodec.fullDescription,
                      ),
                      if (widget.videoInfo.colorSpace != null)
                        _buildInfoRow(
                          '色彩空间',
                          widget.videoInfo.colorSpace!,
                        ),
                      if (widget.videoInfo.pixelFormat != null)
                        _buildInfoRow(
                          '像素格式',
                          widget.videoInfo.pixelFormat!,
                        ),
                      if (widget.videoInfo.bitDepth != null)
                        _buildInfoRow(
                          '位深度',
                          '${widget.videoInfo.bitDepth}-bit',
                        ),
                      if (widget.videoInfo.bitrate > 0)
                        _buildInfoRow(
                          '码率',
                          widget.videoInfo.formattedBitrate,
                        ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 音频编码
                  if (widget.videoInfo.audioCodecs.isNotEmpty)
                    _buildSection(
                      title: '音频编码',
                      icon: Icons.audiotrack,
                      children: [
                        for (int i = 0;
                            i < widget.videoInfo.audioCodecs.length;
                            i++) ...[
                          if (i > 0) const Divider(),
                          _buildInfoRow(
                            '音轨 ${i + 1}',
                            widget.videoInfo.audioCodecs[i].displayName,
                          ),
                          if (widget.videoInfo.audioCodecs[i].channels != null)
                            _buildInfoRow(
                              '声道',
                              widget
                                  .videoInfo.audioCodecs[i].channelDescription,
                            ),
                          if (widget.videoInfo.audioCodecs[i].sampleRate !=
                              null)
                            _buildInfoRow(
                              '采样率',
                              widget.videoInfo.audioCodecs[i]
                                  .sampleRateDescription,
                            ),
                        ],
                      ],
                    ),

                  const SizedBox(height: 24),

                  // 轨道信息
                  if (widget.videoInfo.hasMultipleAudioTracks ||
                      widget.videoInfo.hasSubtitles)
                    _buildSection(
                      title: '多轨道信息',
                      icon: Icons.playlist_add_check,
                      children: [
                        if (widget.videoInfo.hasMultipleAudioTracks)
                          _buildInfoRow(
                            '音频轨道',
                            '${widget.videoInfo.audioTracks.length} 个轨道',
                          ),
                        if (widget.videoInfo.hasSubtitles)
                          _buildInfoRow(
                            '字幕轨道',
                            '${widget.videoInfo.subtitleTracks.length} 个轨道',
                          ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // 硬件加速信息
                  if (widget.showHardwareAccelerationInfo &&
                      _hwAccelConfig != null)
                    _buildSection(
                      title: '硬件加速',
                      icon: Icons.speed,
                      children: [
                        _buildInfoRow(
                          '状态',
                          _hwAccelConfig!.enabled ? '已启用' : '未启用',
                          valueColor: _hwAccelConfig!.enabled
                              ? const Color(0xFF1565C0)  // 深蓝色，确保可见
                              : const Color(0xFF424242),  // 深灰色
                        ),
                        if (_hwAccelConfig!.enabled)
                          _buildInfoRow(
                            '加速类型',
                            _hwAccelConfig!.displayName,
                          ),
                        if (_hwAccelConfig!.enabled)
                          _buildInfoRow(
                            '支持编解码器',
                            _hwAccelConfig!.supportedCodecs.join(', '),
                          ),
                        if (_hwAccelConfig!.gpuInfo != null)
                          _buildInfoRow(
                            'GPU',
                            '${_hwAccelConfig!.gpuInfo!.vendor} ${_hwAccelConfig!.gpuInfo!.model}',
                          ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // HDR和特殊功能
                  if (widget.videoInfo.isHDR ||
                      widget.videoInfo.isHighFramerate)
                    _buildSection(
                      title: '特殊功能',
                      icon: Icons.auto_awesome,
                      children: [
                        if (widget.videoInfo.isHDR) ...[
                          _buildInfoRow(
                            'HDR',
                            widget.videoInfo.hdrType ?? 'HDR',
                            valueColor: const Color(0xFFE65100),  // 深橙色，确保可见
                          ),
                        ],
                        if (widget.videoInfo.isHighFramerate)
                          _buildInfoRow(
                            '高帧率',
                            widget.videoInfo.fpsLabel,
                            valueColor: Colors.blue,
                          ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // 质量评级
                  _buildSection(
                    title: '质量评级',
                    icon: Icons.star,
                    children: [
                      _buildInfoRow(
                        '画质等级',
                        widget.videoInfo.qualityRating,
                        valueColor: Colors.deepPurple,
                      ),
                      _buildInfoRow(
                        '视频标签',
                        widget.videoInfo.qualityTags.join(', '),
                      ),
                    ],
                  ),

                  // 分析时间信息
                  const SizedBox(height: 24),
                  _buildSection(
                    title: '分析信息',
                    icon: Icons.analytics,
                    children: [
                      _buildInfoRow(
                        '分析时间',
                        widget.videoInfo.analyzedAt.toString().substring(0, 19),
                      ),
                      if (widget.videoInfo.lastPlayedAt !=
                          widget.videoInfo.analyzedAt)
                        _buildInfoRow(
                          '最后播放',
                          widget.videoInfo.lastPlayedAt
                              .toString()
                              .substring(0, 19),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),  // 纯白色背景
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFE0E0E0),  // 浅灰色边框
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF000000),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(
              color: Color(0xFF000000),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? const Color(0xFF000000),
                fontSize: 14,
                fontWeight: FontWeight.w900,  // 最粗的字体
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 显示视频信息面板的底部弹窗
  static Future<void> show({
    required BuildContext context,
    required VideoInfo videoInfo,
    bool showHardwareAccelerationInfo = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return VideoInfoPanel(
          videoInfo: videoInfo,
          showHardwareAccelerationInfo: showHardwareAccelerationInfo,
          onClose: () => Navigator.of(context).pop(),
        );
      },
    );
  }
}

/// 简化的视频信息卡片（用于在播放器界面显示）
class VideoInfoCard extends StatelessWidget {
  final VideoInfo videoInfo;
  final VoidCallback? onTap;
  final bool showMoreButton;

  const VideoInfoCard({
    super.key,
    required this.videoInfo,
    this.onTap,
    this.showMoreButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),  // 纯白色背景
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE0E0E0),  // 浅灰色边框
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '视频信息',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const Spacer(),
              if (showMoreButton)
                GestureDetector(
                  onTap: onTap,
                  child: Icon(
                    Icons.keyboard_arrow_right,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildInfoChip(context, videoInfo.resolutionLabel, Icons.hd),
              const SizedBox(width: 4),
              _buildInfoChip(context, videoInfo.qualityLabel, Icons.star),
              if (videoInfo.isHighFramerate) ...[
                const SizedBox(width: 4),
                _buildInfoChip(context, '高帧率', Icons.speed),
              ],
              if (videoInfo.isHDR) ...[
                const SizedBox(width: 4),
                _buildInfoChip(context, 'HDR', Icons.wb_sunny),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '编解码器: ${videoInfo.videoCodec.displayName}',
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
