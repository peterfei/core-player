import 'package:flutter/material.dart';
import 'package:yinghe_player/core/plugin_system/subtitle_download_plugin.dart';
import 'package:yinghe_player/core/plugin_system/plugin_interface.dart';
import 'package:coreplayer_pro_plugins/coreplayer_pro_plugins.dart';

/// SubHD 插件适配器
/// 将商业版 SubHDPlugin 适配为 SubtitleDownloadPlugin 接口
class SubHDAdapter extends SubtitleDownloadPlugin {
  final SubHDPlugin _plugin;

  SubHDAdapter() : _plugin = SubHDPlugin();

  static final _metadata = PluginMetadata(
    id: 'coreplayer.pro.subtitle.subhd',
    name: 'SubHD',
    version: '1.0.0',
    description: 'SubHD 中文字幕搜索和下载 (Pro)',
    author: 'CorePlayer Team',
    icon: Icons.subtitles,
    capabilities: ['online_subtitle_search', 'subhd', 'chinese_subtitle'],
    license: PluginLicense.proprietary,
  );

  PluginState _internalState = PluginState.uninitialized;

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
  }

  @override
  Future<void> onActivate() async {
    setStateInternal(PluginState.active);
  }

  @override
  Future<void> onDeactivate() async {
    setStateInternal(PluginState.ready);
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
  String get displayName => _plugin.displayName;

  @override
  IconData get icon => _plugin.icon;

  @override
  bool get requiresNetwork => true;

  @override
  bool get supportsBatchDownload => false;

  @override
  Future<List<SubtitleSearchResult>> searchSubtitles({
    required String query,
    String? language,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final results = await _plugin.searchSubtitles(query: query);

      return results.map((item) {
        return SubtitleSearchResult(
          id: item['id']?.toString() ?? '',
          title: item['title']?.toString() ?? query,
          language: 'zh', // SubHD 主要是中文
          languageName: '简体中文',
          format: 'srt', // 假设默认格式
          rating: 0.0,
          downloads: 0,
          uploadDate: DateTime.now(),
          downloadUrl: 'subhd://${item['id']}',
          source: 'SubHD',
        );
      }).toList();
    } catch (e) {
      print('SubHDAdapter search error: $e');
      return [];
    }
  }

  @override
  Future<String?> downloadSubtitle(
    SubtitleSearchResult result,
    String targetPath,
  ) async {
    return await _plugin.downloadSubtitle(result.id, targetPath);
  }

  @override
  List<SubtitleLanguage> getSupportedLanguages() {
    final langs = _plugin.getSupportedLanguages();
    return langs.map((code) => SubtitleLanguage(code: code, name: code)).toList();
  }
}
