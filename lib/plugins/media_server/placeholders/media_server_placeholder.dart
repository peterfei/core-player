import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import '../../core/plugin_system/core_plugin.dart';
import '../../core/plugin_system/media_server_plugin.dart';

/// 媒体服务器占位符插件（社区版）
///
/// 在社区版中，所有媒体服务器功能都通过此占位符提供，
/// 引导用户升级到专业版以获得完整功能。
class MediaServerPlaceholderPlugin extends MediaServerPlugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'com.coreplayer.mediaserver.placeholder',
    name: '媒体服务器',
    version: '1.0.0',
    description: '媒体服务器功能仅在专业版中可用',
    author: 'CorePlayer Team',
    icon: Icons.cloud_off,
    capabilities: ['placeholder'],
    homepage: 'https://core-player.com',
    license: PluginLicense.gpl,
    permissions: [PluginPermission.network],
  );

  @override
  String get serverType => 'placeholder';

  @override
  List<String> get supportedProtocols => [];

  @override
  ServerConfig? get currentConfig => null;

  @override
  bool get isConnected => false;

  @override
  PluginState get _state => PluginState.ready;

  @override
  void _setStateInternal(PluginState state) {
    // 占位符插件状态固定为 ready
  }

  // ===== 连接管理 =====

  @override
  Future<ConnectionTestResult> testConnection(ServerConfig config) async {
    return ConnectionTestResult.invalidConfiguration(
      message: '媒体服务器功能仅在专业版中可用',
      suggestion: '请升级到专业版以使用媒体服务器功能',
    );
  }

  @override
  Future<void> connect(ServerConfig config) async {
    throw FeatureNotAvailableException(
      '媒体服务器功能仅在专业版中可用',
      upgradeUrl: 'https://core-player.com/pro',
    );
  }

  @override
  Future<void> disconnect() async {
    // 占位符不需要连接操作
  }

  @override
  Map<String, dynamic> getConnectionInfo() {
    return {
      'status': 'placeholder',
      'message': 'Media server functionality is only available in Pro edition',
      'upgradeUrl': 'https://core-player.com/pro',
    };
  }

  // ===== 媒体库操作 =====

  @override
  Future<List<MediaFolder>> getFolders() async {
    throw FeatureNotAvailableException(
      '媒体库浏览仅在专业版中可用',
      upgradeUrl: 'https://core-player.com/pro',
    );
  }

  @override
  Future<List<VideoItem>> scanVideos({
    MediaFolder? folder,
    ScanOptions? options,
  }) async {
    throw FeatureNotAvailableException(
      '视频扫描仅在专业版中可用',
      upgradeUrl: 'https://core-player.com/pro',
    );
  }

  @override
  Future<VideoMetadata?> getVideoMetadata(String videoId) async {
    throw FeatureNotAvailableException(
      '视频元数据仅在专业版中可用',
      upgradeUrl: 'https://core-player.com/pro',
    );
  }

  @override
  Future<List<VideoItem>> searchVideos(String query, {ScanOptions? options}) async {
    throw FeatureNotAvailableException(
      '视频搜索仅在专业版中可用',
      upgradeUrl: 'https://core-player.com/pro',
    );
  }

  @override
  Future<void> refreshLibrary({MediaFolder? folder}) async {
    throw FeatureNotAvailableException(
      '媒体库刷新仅在专业版中可用',
      upgradeUrl: 'https://core-player.com/pro',
    );
  }

  // ===== 流媒体 =====

  @override
  Future<VideoStreamInfo> getVideoStream(String videoId, {VideoQuality? quality}) async {
    throw FeatureNotAvailableException(
      '网络视频流仅在专业版中可用',
      upgradeUrl: 'https://core-player.com/pro',
    );
  }

  @override
  Future<String?> getThumbnailUrl(String videoId) async {
    throw FeatureNotAvailableException(
      '远程缩略图仅在专业版中可用',
      upgradeUrl: 'https://core-player.com/pro',
    );
  }

  @override
  Future<List<SubtitleTrack>> getSubtitleTracks(String videoId) async {
    throw FeatureNotAvailableException(
      '远程字幕仅在专业版中可用',
      upgradeUrl: 'https://core-player.com/pro',
    );
  }

  @override
  Future<String?> getSubtitleContent(String videoId, String subtitleId) async {
    throw FeatureNotAvailableException(
      '远程字幕内容仅在专业版中可用',
      upgradeUrl: 'https://core-player.com/pro',
    );
  }

  // ===== 配置UI =====

  @override
  Widget buildAddServerScreen({
    required Function(ServerConfig) onSave,
    ServerConfig? initialConfig,
  }) {
    return ProFeaturePromptScreen(
      featureName: '媒体服务器集成',
      description: '''
连接 SMB/NAS、Emby、Jellyfin、Plex 等媒体服务器，
轻松管理和播放您的影音库。
      ''',
      features: [
        '🖥️ SMB/NAS 网络共享访问',
        '📺 Emby 媒体服务器支持',
        '🎬 Jellyfin 媒体库集成',
        '🍿 Plex 服务器连接',
        '🌐 远程视频流播放',
        '🖼️ 自动缩略图生成',
        '📱 跨设备同步播放进度',
        '🔐 安全的凭据管理',
      ],
      upgradeUrl: 'https://core-player.com/pro',
    );
  }

  @override
  Widget buildServerDetailScreen(ServerConfig config) {
    return ProFeaturePromptScreen(
      featureName: '服务器详情',
      description: '''
查看和管理您的媒体服务器连接详情，
包括服务器状态、媒体库信息和播放统计。
      ''',
      features: [
        '📊 服务器状态监控',
        '📈 播放统计信息',
        '🔧 高级配置选项',
        '🔄 自动连接管理',
      ],
      upgradeUrl: 'https://core-player.com/pro',
    );
  }

  @override
  String? validateConfig(ServerConfig config) {
    return '媒体服务器功能仅在专业版中可用，请升级到专业版';
  }

  @override
  Future<bool> healthCheck() async {
    // 占位符插件总是健康的
    return true;
  }

  @override
  Widget? buildSettingsScreen() {
    return ProFeaturePromptScreen(
      featureName: '媒体服务器设置',
      description: '''
配置您的媒体服务器连接选项，
包括网络设置、缓存选项和高级功能。
      ''',
      features: [
        '🌐 网络配置',
        '💾 缓存设置',
        '⚡ 性能优化',
        '🔒 安全选项',
        '📊 使用统计',
      ],
      upgradeUrl: 'https://core-player.com/pro',
    );
  }
}

/// 专业版功能提示界面
class ProFeaturePromptScreen extends StatelessWidget {
  final String featureName;
  final String description;
  final List<String> features;
  final String upgradeUrl;

  const ProFeaturePromptScreen({
    Key? key,
    required this.featureName,
    required this.description,
    required this.features,
    required this.upgradeUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(featureName),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 专业版图标
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  size: 80,
                  color: Colors.amber,
                ),
              ),

              const SizedBox(height: 32),

              // 标题
              Text(
                '专业版功能',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // 功能名称
              Text(
                featureName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // 描述
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // 功能列表
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.grey.withOpacity(0.2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '专业版包含以下功能：',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...features.map((feature) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                feature,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // 升级按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _launchUrl(context, upgradeUrl),
                  icon: const Icon(Icons.upgrade),
                  label: const Text('升级到专业版'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 学习更多按钮
              TextButton(
                onPressed: () => _launchUrl(context, 'https://core-player.com'),
                child: Text('了解更多关于专业版'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _launchUrl(BuildContext context, String url) {
    // 在实际实现中，这里应该使用 url_launcher 包
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('请在浏览器中访问: $url'),
        action: SnackBarAction(
          label: '复制',
          onPressed: () {
            // 复制URL到剪贴板
            // Clipboard.setData(ClipboardData(text: url));
          },
        ),
      ),
    );
  }
}