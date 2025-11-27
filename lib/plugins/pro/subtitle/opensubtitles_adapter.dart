import 'package:flutter/material.dart';
import 'package:yinghe_player/core/plugin_system/subtitle_download_plugin.dart';
import 'package:yinghe_player/core/plugin_system/plugin_interface.dart';
import 'package:coreplayer_pro_plugins/coreplayer_pro_plugins.dart';

/// OpenSubtitles 插件适配器
/// 将商业版 OpenSubtitlesPlugin 适配为 SubtitleDownloadPlugin 接口
class OpenSubtitlesAdapter extends SubtitleDownloadPlugin {
  final OpenSubtitlesPlugin _plugin;

  OpenSubtitlesAdapter() : _plugin = OpenSubtitlesPlugin();

  static final _metadata = PluginMetadata(
    id: 'coreplayer.pro.subtitle.opensubtitles',
    name: 'OpenSubtitles',
    version: '1.0.0',
    description: 'OpenSubtitles 字幕搜索和下载 (Pro)',
    author: 'CorePlayer Team',
    icon: Icons.public,
    capabilities: ['online_subtitle_search', 'opensubtitles'],
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
    // 商业版插件不需要显式初始化，或者可以在这里做一些准备工作
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
      print('🔍 OpenSubtitlesAdapter: Searching for "$query" (language: $language)');
      
      final results = await _plugin.searchSubtitles(
        query: query,
        language: language,
        page: page,
      );

      print('📦 OpenSubtitlesAdapter: Received ${results.length} raw results');
      
      if (results.isEmpty) {
        print('⚠️ OpenSubtitlesAdapter: No results from OpenSubtitles API');
        return [];
      }

      // 打印第一个结果的结构以便调试
      if (results.isNotEmpty) {
        print('📋 First result structure: ${results.first.keys.toList()}');
      }

      final parsedResults = <SubtitleSearchResult>[];
      
      for (var item in results) {
        try {
          final attributes = item['attributes'] as Map<String, dynamic>? ?? {};
          final files = attributes['files'] as List<dynamic>? ?? [];
          
          if (files.isEmpty) {
            print('⚠️ No files in result: ${item['id']}');
            continue;
          }
          
          final firstFile = files[0] as Map<String, dynamic>;
          final fileId = firstFile['file_id']?.toString() ?? '';
          
          if (fileId.isEmpty) {
            print('⚠️ No file_id in result');
            continue;
          }

          parsedResults.add(SubtitleSearchResult(
            id: fileId,
            title: attributes['release']?.toString() ?? query,
            language: attributes['language']?.toString() ?? 'unknown',
            languageName: attributes['language']?.toString() ?? 'Unknown',
            format: firstFile['file_name']?.toString().split('.').last ?? 'srt',
            rating: (attributes['ratings']?.toDouble() ?? 0.0),
            downloads: attributes['download_count']?.toInt() ?? 0,
            uploadDate: DateTime.tryParse(attributes['upload_date']?.toString() ?? '') ?? DateTime.now(),
            downloadUrl: 'opensubtitles://$fileId',
            source: 'OpenSubtitles',
          ));
        } catch (e) {
          print('❌ Error parsing result: $e');
        }
      }
      
      print('✅ OpenSubtitlesAdapter: Parsed ${parsedResults.length} results');
      return parsedResults;
    } catch (e) {
      print('❌ OpenSubtitlesAdapter search error: $e');
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
