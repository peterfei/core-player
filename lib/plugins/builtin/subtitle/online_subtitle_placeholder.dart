import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/plugin_system/subtitle_download_plugin.dart';
import '../../../core/plugin_system/plugin_interface.dart';

/// 在线字幕占位符插件(社区版)
///
/// 用于社区版,当用户尝试使用在线字幕搜索时显示升级提示
class OnlineSubtitlePlaceholder extends SubtitleDownloadPlugin {
  static final _metadata = PluginMetadata(
    id: 'coreplayer.subtitle.online_placeholder',
    name: '在线字幕(需要专业版)',
    version: '1.0.0',
    description: '在线字幕搜索功能需要升级到专业版',
    author: 'CorePlayer Team',
    icon: Icons.cloud_off,
    capabilities: ['upgrade_prompt'],
    license: PluginLicense.bsd,
  );

  /// 插件内部状态
  PluginState _internalState = PluginState.uninitialized;

  /// 用于显示对话框的 BuildContext
  BuildContext? _context;

  @override
  PluginMetadata get staticMetadata => _metadata;

  @override
  PluginState get state => _internalState;

  @override
  void setStateInternal(PluginState newState) {
    _internalState = newState;
  }

  @override
  Future<void> onInitialize() async {
    setStateInternal(PluginState.ready);
    print('OnlineSubtitlePlaceholder initialized');
  }

  @override
  Future<void> onActivate() async {
    setStateInternal(PluginState.active);
    print('OnlineSubtitlePlaceholder activated');
  }

  @override
  Future<void> onDeactivate() async {
    setStateInternal(PluginState.ready);
    print('OnlineSubtitlePlaceholder deactivated');
  }

  @override
  Future<void> onDispose() async {
    setStateInternal(PluginState.disposed);
  }

  @override
  Future<bool> healthCheck() async {
    return true;
  }

  @override
  String get displayName => '在线字幕';

  @override
  IconData get icon => Icons.cloud_download;

  @override
  bool get requiresNetwork => true;

  @override
  bool get supportsBatchDownload => false;

  /// 设置 BuildContext 用于显示对话框
  void setContext(BuildContext context) {
    _context = context;
  }

  @override
  Future<List<SubtitleSearchResult>> searchSubtitles({
    required String query,
    String? language,
    int page = 1,
    int limit = 20,
  }) async {
    print('⚠️ OnlineSubtitlePlaceholder: Search attempted, throwing upgrade exception');
    throw FeatureNotAvailableException(
      '在线字幕搜索需要专业版\n\n'
      '专业版功能包括:\n'
      '• 🌐 OpenSubtitles 字幕搜索\n'
      '• 🇨🇳 SubHD 中文字幕搜索\n'
      '• ⚡ 高级解码器支持\n'
      '• 🎨 更多主题和自定义选项',
      upgradeUrl: 'https://coreplayer.pro/upgrade',
    );
  }

  @override
  Future<String?> downloadSubtitle(
    SubtitleSearchResult result,
    String targetPath,
  ) async {
    print('⚠️ OnlineSubtitlePlaceholder: Download attempted, throwing upgrade exception');
    throw FeatureNotAvailableException(
      '在线字幕下载需要专业版',
      upgradeUrl: 'https://coreplayer.pro/upgrade',
    );
  }

  @override
  List<SubtitleLanguage> getSupportedLanguages() {
    return SubtitleLanguage.common;
  }

  /// 显示升级提示对话框
  void _showUpgradeDialog() {
    if (_context == null) {
      print('OnlineSubtitlePlaceholder: No context available for dialog');
      return;
    }

    showDialog(
      context: _context!,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber),
            SizedBox(width: 8),
            Text('专业版功能'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '在线字幕搜索需要专业版',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('专业版功能包括:'),
            SizedBox(height: 8),
            _buildFeatureItem('🌐 OpenSubtitles 字幕搜索'),
            _buildFeatureItem('🇨🇳 SubHD 中文字幕搜索'),
            _buildFeatureItem('⚡ 高级解码器支持'),
            _buildFeatureItem('🎨 更多主题和自定义选项'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('稍后再说'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openProPage();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: Text('了解专业版'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  /// 打开专业版页面
  void _openProPage() {
    // TODO: 实现跳转到专业版购买页面
    print('OnlineSubtitlePlaceholder: Opening pro page...');
  }
}
