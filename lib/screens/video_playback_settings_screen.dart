import 'package:flutter/material.dart';
import '../services/hardware_acceleration_service.dart';
import '../models/hardware_acceleration_config.dart';
import '../models/buffer_config.dart';
import '../models/video_info.dart';
import '../widgets/feedback_dialog.dart';
import 'format_support_screen.dart';

/// 视频播放设置页面
/// 包含播放质量、硬件加速和缓冲设置
class VideoPlaybackSettingsScreen extends StatefulWidget {
  const VideoPlaybackSettingsScreen({super.key});

  @override
  State<VideoPlaybackSettingsScreen> createState() =>
      _VideoPlaybackSettingsScreenState();
}

class _VideoPlaybackSettingsScreenState
    extends State<VideoPlaybackSettingsScreen> {
  // 播放质量设置
  PlaybackQualityMode _qualityMode = PlaybackQualityMode.auto;

  // 硬件加速设置
  bool _hardwareAccelerationEnabled = true;
  HardwareAccelerationConfig? _hwAccelConfig;
  bool _isLoadingHwAccel = true;

  // 缓冲设置
  BufferStrategy _bufferStrategy = BufferStrategy.adaptive;
  bool _backgroundPreload = true;
  double _bufferSize = 50.0; // MB

  // 其他设置
  bool _enablePerformanceOverlay = false;
  bool _autoSwitchQuality = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      // 加载硬件加速信息
      await HardwareAccelerationService.instance.initialize();
      final config =
          await HardwareAccelerationService.instance.getRecommendedConfig();

      setState(() {
        _hwAccelConfig = config;
        _hardwareAccelerationEnabled = config?.enabled ?? true;
        _isLoadingHwAccel = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingHwAccel = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('播放设置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: _resetToDefaults,
            child: const Text('重置'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 播放质量设置
          _buildPlaybackQualitySection(),
          const SizedBox(height: 24),

          // 硬件加速设置
          _buildHardwareAccelerationSection(),
          const SizedBox(height: 24),

          // 缓冲设置
          _buildBufferSettingsSection(),
          const SizedBox(height: 24),

          // 性能设置
          _buildPerformanceSection(),
          const SizedBox(height: 24),

          // 关于设置
          _buildAboutSection(),
        ],
      ),
    );
  }

  Widget _buildPlaybackQualitySection() {
    return _buildSection(
      title: '播放质量',
      icon: Icons.high_quality,
      children: [
        const Text(
          '选择视频播放的默认质量模式',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        ...PlaybackQualityMode.values.map((mode) {
          return RadioListTile<PlaybackQualityMode>(
            title: Text(_getQualityModeTitle(mode)),
            subtitle: Text(_getQualityModeDescription(mode)),
            value: mode,
            groupValue: _qualityMode,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _qualityMode = value;
                });
              }
            },
          );
        }).toList(),
      ],
    );
  }

  Widget _buildHardwareAccelerationSection() {
    if (_isLoadingHwAccel) {
      return _buildSection(
        title: '硬件加速',
        icon: Icons.speed,
        children: [
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }

    return _buildSection(
      title: '硬件加速',
      icon: Icons.speed,
      children: [
        SwitchListTile(
          title: const Text('启用硬件加速'),
          subtitle: const Text('使用GPU硬件解码降低CPU占用'),
          value: _hardwareAccelerationEnabled,
          onChanged: (value) {
            setState(() {
              _hardwareAccelerationEnabled = value;
            });
          },
        ),
        if (_hwAccelConfig != null) ...[
          ListTile(
            title: const Text('当前状态'),
            subtitle: Text(_hwAccelConfig!.displayName),
            leading: Icon(
              _hwAccelConfig!.enabled ? Icons.check_circle : Icons.cancel,
              color: _hwAccelConfig!.enabled ? Colors.green : Colors.red,
            ),
          ),
          ListTile(
            title: const Text('支持的编解码器'),
            subtitle: Text(_hwAccelConfig!.supportedCodecs.join(', ')),
            leading: const Icon(Icons.videocam),
          ),
        ] else ...[
          const ListTile(
            title: const Text('硬件加速不可用'),
            subtitle: const Text('您的设备可能不支持硬件加速'),
            leading: Icon(
              Icons.warning,
              color: Colors.orange,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBufferSettingsSection() {
    return _buildSection(
      title: '缓冲设置',
      icon: Icons.storage,
      children: [
        const Text(
          '调整视频缓冲策略以优化播放体验',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        ...BufferStrategy.values.map((strategy) {
          return RadioListTile<BufferStrategy>(
            title: Text(_getBufferStrategyTitle(strategy)),
            subtitle: Text(_getBufferStrategyDescription(strategy)),
            value: strategy,
            groupValue: _bufferStrategy,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _bufferStrategy = value;
                });
              }
            },
          );
        }).toList(),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('后台预加载'),
          subtitle: const Text('在后台预加载下一段视频'),
          value: _backgroundPreload,
          onChanged: (value) {
            setState(() {
              _backgroundPreload = value;
            });
          },
        ),
        ListTile(
          title: Text('缓冲大小: ${_bufferSize.toInt()} MB'),
          subtitle: Slider(
            value: _bufferSize,
            min: 10,
            max: 200,
            divisions: 19,
            onChanged: (value) {
              setState(() {
                _bufferSize = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceSection() {
    return _buildSection(
      title: '性能设置',
      icon: Icons.tune,
      children: [
        SwitchListTile(
          title: const Text('显示性能信息'),
          subtitle: const Text('在播放时显示FPS、CPU等性能指标'),
          value: _enablePerformanceOverlay,
          onChanged: (value) {
            setState(() {
              _enablePerformanceOverlay = value;
            });
          },
        ),
        SwitchListTile(
          title: const Text('自动调整质量'),
          subtitle: const Text('根据网络和硬件条件自动调整播放质量'),
          value: _autoSwitchQuality,
          onChanged: (value) {
            setState(() {
              _autoSwitchQuality = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return _buildSection(
      title: '关于设置',
      icon: Icons.info,
      children: [
        ListTile(
          title: const Text('帮助文档'),
          subtitle: const Text('查看详细的设置说明和使用指南'),
          leading: const Icon(Icons.help),
          onTap: _openHelp,
        ),
        ListTile(
          title: const Text('反馈建议'),
          subtitle: const Text('如果您有建议或遇到问题，请告诉我们'),
          leading: const Icon(Icons.feedback),
          onTap: _openFeedback,
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
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withOpacity(0.3),
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

  String _getQualityModeTitle(PlaybackQualityMode mode) {
    switch (mode) {
      case PlaybackQualityMode.auto:
        return '自动模式';
      case PlaybackQualityMode.high:
        return '高质量';
      case PlaybackQualityMode.balanced:
        return '平衡模式';
      case PlaybackQualityMode.powerSaving:
        return '省电模式';
      case PlaybackQualityMode.compatibility:
        return '兼容模式';
    }
  }

  String _getQualityModeDescription(PlaybackQualityMode mode) {
    switch (mode) {
      case PlaybackQualityMode.auto:
        return '根据硬件和网络条件自动选择最佳质量';
      case PlaybackQualityMode.high:
        return '优先使用最高画质，需要较好的硬件支持';
      case PlaybackQualityMode.balanced:
        return '平衡画质和性能，适合大多数设备';
      case PlaybackQualityMode.powerSaving:
        return '降低画质以节省电量，适合移动设备';
      case PlaybackQualityMode.compatibility:
        return '强制软件解码，确保最大兼容性';
    }
  }

  String _getBufferStrategyTitle(BufferStrategy strategy) {
    switch (strategy) {
      case BufferStrategy.conservative:
        return '保守策略';
      case BufferStrategy.balanced:
        return '平衡策略';
      case BufferStrategy.aggressive:
        return '激进策略';
      case BufferStrategy.adaptive:
        return '自适应策略';
    }
  }

  String _getBufferStrategyDescription(BufferStrategy strategy) {
    switch (strategy) {
      case BufferStrategy.conservative:
        return '大缓冲，适合不稳定网络';
      case BufferStrategy.balanced:
        return '中等缓冲，默认选择';
      case BufferStrategy.aggressive:
        return '小缓冲，适合高速网络';
      case BufferStrategy.adaptive:
        return '根据网络动态调整';
    }
  }

  void _resetToDefaults() {
    setState(() {
      _qualityMode = PlaybackQualityMode.auto;
      _hardwareAccelerationEnabled = _hwAccelConfig?.enabled ?? true;
      _bufferStrategy = BufferStrategy.adaptive;
      _backgroundPreload = true;
      _bufferSize = 50.0;
      _enablePerformanceOverlay = false;
      _autoSwitchQuality = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已重置为默认设置')),
    );
  }

  void _openHelp() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormatSupportScreen(),
      ),
    );
  }

  void _openFeedback() {
    showDialog(
      context: context,
      builder: (context) => FeedbackDialog(
        preFilledIssue: '播放设置反馈\n\n'
            '请分享您对播放设置功能的建议或问题：\n\n'
            '当前设置:\n'
            '• 播放质量: ${_getQualityModeTitle(_qualityMode)}\n'
            '• 硬件加速: ${_hardwareAccelerationEnabled ? "已启用" : "已禁用"}\n'
            '• 缓冲策略: ${_getBufferStrategyTitle(_bufferStrategy)}\n'
            '• 后台预加载: ${_backgroundPreload ? "已启用" : "已禁用"}\n'
            '• 缓冲大小: ${_bufferSize.toInt()} MB\n\n'
            '请描述您的建议或遇到的问题:',
      ),
    );
  }
}

/// 播放质量模式
enum PlaybackQualityMode {
  auto,
  high,
  balanced,
  powerSaving,
  compatibility,
}
