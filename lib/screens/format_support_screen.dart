import 'package:flutter/material.dart';
import '../services/hardware_acceleration_service.dart';
import '../models/hardware_acceleration_config.dart';
import '../models/codec_info.dart';

/// 格式支持文档页面
/// 显示所有支持的视频格式、编解码器和硬件加速信息
class FormatSupportScreen extends StatefulWidget {
  const FormatSupportScreen({super.key});

  @override
  State<FormatSupportScreen> createState() => _FormatSupportScreenState();
}

class _FormatSupportScreenState extends State<FormatSupportScreen> {
  HardwareAccelerationConfig? _hwAccelConfig;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHardwareAccelerationInfo();
  }

  Future<void> _loadHardwareAccelerationInfo() async {
    try {
      await HardwareAccelerationService.instance.initialize();
      final config = await HardwareAccelerationService.instance.getRecommendedConfig();
      if (mounted) {
        setState(() {
          _hwAccelConfig = config;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('格式支持'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 硬件加速状态
                  _buildHardwareAccelerationSection(),
                  const SizedBox(height: 24),

                  // 视频容器格式支持
                  _buildContainerFormatsSection(),
                  const SizedBox(height: 24),

                  // 视频编解码器支持
                  _buildVideoCodecsSection(),
                  const SizedBox(height: 24),

                  // 音频编解码器支持
                  _buildAudioCodecsSection(),
                  const SizedBox(height: 24),

                  // 分辨率支持
                  _buildResolutionSection(),
                  const SizedBox(height: 24),

                  // 特殊功能支持
                  _buildSpecialFeaturesSection(),
                  const SizedBox(height: 24),

                  // 性能建议
                  _buildPerformanceTipsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildHardwareAccelerationSection() {
    return _buildSection(
      title: '硬件加速状态',
      icon: Icons.speed,
      children: [
        if (_hwAccelConfig != null) ...[
          _buildInfoRow(
            '状态',
            _hwAccelConfig!.enabled ? '✅ 已启用' : '❌ 未启用',
            valueColor: _hwAccelConfig!.enabled ? Colors.green : Colors.red,
          ),
          _buildInfoRow(
            '加速类型',
            _hwAccelConfig!.displayName,
          ),
          _buildInfoRow(
            '支持编解码器',
            _hwAccelConfig!.supportedCodecs.join(', '),
          ),
          if (_hwAccelConfig!.gpuInfo != null)
            _buildInfoRow(
              'GPU',
              '${_hwAccelConfig!.gpuInfo!.vendor} ${_hwAccelConfig!.gpuInfo!.model}',
            ),
        ] else ...[
          _buildInfoRow(
            '状态',
            '❌ 检测失败',
            valueColor: Colors.red,
          ),
          _buildInfoRow(
            '说明',
            '无法检测硬件加速，将使用软件解码',
          ),
        ],
      ],
    );
  }

  Widget _buildContainerFormatsSection() {
    return _buildSection(
      title: '视频容器格式',
      icon: Icons.video_file,
      children: [
        _buildFormatRow('MKV', '✅ 完全支持', 'Matroska容器，支持多音轨/字幕'),
        _buildFormatRow('MP4', '✅ 完全支持', 'MPEG-4容器，广泛兼容'),
        _buildFormatRow('WebM', '✅ 完全支持', 'Google开发的Web优化格式'),
        _buildFormatRow('AVI', '⚠️ 基础支持', '较老的容器，部分高级功能受限'),
        _buildFormatRow('MOV', '✅ 完全支持', 'QuickTime容器'),
        _buildFormatRow('FLV', '⚠️ 基础支持', 'Flash Video，主要用于网络视频'),
      ],
    );
  }

  Widget _buildVideoCodecsSection() {
    return _buildSection(
      title: '视频编解码器',
      icon: Icons.video_settings,
      children: [
        _buildCodecRow(
          'H.264/AVC',
          '✅ 完全支持',
          '最广泛使用的视频编解码器',
          hardwareSupport: true,
          maxResolution: '4K',
        ),
        _buildCodecRow(
          'HEVC/H.265',
          '✅ 完全支持',
          '新一代高效视频编解码器，支持4K/8K',
          hardwareSupport: true,
          maxResolution: '8K',
        ),
        _buildCodecRow(
          'VP9',
          '✅ 完全支持',
          'Google开发的开源编解码器',
          hardwareSupport: true,
          maxResolution: '4K',
        ),
        _buildCodecRow(
          'AV1',
          '✅ 完全支持',
          '下一代开放媒体编解码器',
          hardwareSupport: true,
          maxResolution: '8K',
        ),
        _buildCodecRow(
          'MPEG-2',
          '✅ 完全支持',
          'DVD和数字电视标准编解码器',
          hardwareSupport: true,
          maxResolution: '1080p',
        ),
        _buildCodecRow(
          'MPEG-4 ASP',
          '✅ 完全支持',
          '早期的MPEG-4编解码器',
          hardwareSupport: true,
          maxResolution: '720p',
        ),
        _buildCodecRow(
          'VP8',
          '✅ 完全支持',
          'WebM视频格式的基础编解码器',
          hardwareSupport: true,
          maxResolution: '1080p',
        ),
        _buildCodecRow(
          'ProRes',
          '⚠️ 部分支持',
          'Apple专业视频编解码器',
          hardwareSupport: false,
          maxResolution: '8K',
        ),
        _buildCodecRow(
          'DNxHD',
          '⚠️ 部分支持',
          'Avid专业视频编解码器',
          hardwareSupport: false,
          maxResolution: '4K',
        ),
      ],
    );
  }

  Widget _buildAudioCodecsSection() {
    return _buildSection(
      title: '音频编解码器',
      icon: Icons.audiotrack,
      children: [
        _buildCodecRow(
          'AAC',
          '✅ 完全支持',
          '高级音频编码，广泛使用',
          hardwareSupport: true,
          maxResolution: '-',
        ),
        _buildCodecRow(
          'MP3',
          '✅ 完全支持',
          '经典音频格式',
          hardwareSupport: true,
          maxResolution: '-',
        ),
        _buildCodecRow(
          'AC3/E-AC3',
          '✅ 完全支持',
          '杜比数字音频',
          hardwareSupport: true,
          maxResolution: '-',
        ),
        _buildCodecRow(
          'DTS',
          '✅ 完全支持',
          '数字影院系统',
          hardwareSupport: true,
          maxResolution: '-',
        ),
        _buildCodecRow(
          'FLAC',
          '✅ 完全支持',
          '无损音频压缩',
          hardwareSupport: true,
          maxResolution: '-',
        ),
        _buildCodecRow(
          'Vorbis',
          '✅ 完全支持',
          '开源音频编解码器',
          hardwareSupport: true,
          maxResolution: '-',
        ),
        _buildCodecRow(
          'Opus',
          '✅ 完全支持',
          '现代开源音频编解码器',
          hardwareSupport: true,
          maxResolution: '-',
        ),
      ],
    );
  }

  Widget _buildResolutionSection() {
    return _buildSection(
      title: '分辨率支持',
      icon: Icons.hd,
      children: [
        _buildResolutionRow('8K (7680×4320)', '✅ 支持', '超高清视频'),
        _buildResolutionRow('4K (3840×2160)', '✅ 支持', '超高清视频'),
        _buildResolutionRow('2K (2560×1440)', '✅ 支持', 'QHD视频'),
        _buildResolutionRow('1080p (1920×1080)', '✅ 支持', '全高清视频'),
        _buildResolutionRow('720p (1280×720)', '✅ 支持', '高清视频'),
        _buildResolutionRow('480p (854×480)', '✅ 支持', '标清视频'),
        _buildResolutionRow('360p (640×360)', '✅ 支持', '低清视频'),
      ],
    );
  }

  Widget _buildSpecialFeaturesSection() {
    return _buildSection(
      title: '特殊功能',
      icon: Icons.auto_awesome,
      children: [
        _buildFeatureRow('HDR视频', '✅ 支持', 'HDR10, Dolby Vision, HLG'),
        _buildFeatureRow('高帧率', '✅ 支持', '60fps, 120fps视频播放'),
        _buildFeatureRow('多音轨', '✅ 支持', '多个音频轨道切换'),
        _buildFeatureRow('多字幕', '✅ 支持', '多个字幕轨道选择'),
        _buildFeatureRow('硬件解码', '✅ 支持', 'GPU硬件加速解码'),
        _buildFeatureRow('软件解码', '✅ 支持', 'CPU软件解码作为备选'),
        _buildFeatureRow('大文件', '✅ 支持', '10GB+大文件播放'),
        _buildFeatureRow('网络流', '✅ 支持', 'HTTP/HTTPS流媒体'),
      ],
    );
  }

  Widget _buildPerformanceTipsSection() {
    return _buildSection(
      title: '性能优化建议',
      icon: Icons.lightbulb,
      children: [
        _buildTipRow(
          '4K视频播放',
          '建议启用硬件加速，确保GPU支持H.265解码',
        ),
        _buildTipRow(
          '8K视频播放',
          '需要高端硬件支持，推荐使用专用显卡',
        ),
        _buildTipRow(
          '大文件处理',
          '建议使用SSD存储以提高seek速度',
        ),
        _buildTipRow(
          '网络视频',
          '检查网络带宽，4K视频需要25Mbps以上',
        ),
        _buildTipRow(
          'HDR视频',
          '需要HDR显示器和操作系统支持',
        ),
        _buildTipRow(
          '性能优化',
          '在设置中可调整缓冲策略和视频质量',
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
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
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatRow(String format, String status, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              format,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            status,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodecRow(
    String codec,
    String status,
    String description, {
    bool hardwareSupport = false,
    String maxResolution = '-',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  codec,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  status,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildTag('硬件解码', hardwareSupport ? '支持' : '不支持'),
                if (maxResolution != '-') ...[
                  const SizedBox(width: 8),
                  _buildTag('最高分辨率', maxResolution),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResolutionRow(String resolution, String status, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              resolution,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(status),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String feature, String status, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              feature,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(status),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipRow(String title, String tip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.tips_and_updates,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              tip,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}