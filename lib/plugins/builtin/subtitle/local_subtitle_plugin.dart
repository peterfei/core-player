import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/plugin_system/subtitle_download_plugin.dart';
import '../../../core/plugin_system/plugin_interface.dart';

/// 本地字幕插件
///
/// 提供本地字幕文件选择功能,适用于社区版和专业版
class LocalSubtitlePlugin extends SubtitleDownloadPlugin {
  static final _metadata = PluginMetadata(
    id: 'coreplayer.subtitle.local',
    name: '本地字幕',
    version: '1.0.0',
    description: '从本地文件系统选择字幕文件',
    author: 'CorePlayer Team',
    icon: Icons.folder_open,
    capabilities: ['local_subtitle_selection'],
    license: PluginLicense.bsd,
  );

  /// 插件内部状态
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
    print('LocalSubtitlePlugin initialized');
  }

  @override
  Future<void> onActivate() async {
    setStateInternal(PluginState.active);
    print('LocalSubtitlePlugin activated');
  }

  @override
  Future<void> onDeactivate() async {
    setStateInternal(PluginState.ready);
    print('LocalSubtitlePlugin deactivated');
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
  String get displayName => '本地字幕';

  @override
  IconData get icon => Icons.folder_open;

  @override
  bool get requiresNetwork => false;

  @override
  bool get supportsBatchDownload => false;

  @override
  Future<List<SubtitleSearchResult>> searchSubtitles({
    required String query,
    String? language,
    int page = 1,
    int limit = 20,
  }) async {
    // 本地字幕插件不支持搜索,返回空列表
    // UI应该直接调用 downloadSubtitle 打开文件选择器
    return [];
  }

  @override
  Future<String?> downloadSubtitle(
    SubtitleSearchResult result,
    String targetPath,
  ) async {
    // 打开文件选择器
    try {
      final fileResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'ass', 'ssa', 'vtt', 'sub', 'sbv'],
        allowMultiple: false,
        dialogTitle: '选择字幕文件',
      );

      if (fileResult != null && fileResult.files.single.path != null) {
        final filePath = fileResult.files.single.path!;
        print('LocalSubtitlePlugin: Selected file: $filePath');
        return filePath;
      }

      print('LocalSubtitlePlugin: No file selected');
      return null;
    } catch (e) {
      print('LocalSubtitlePlugin: Error picking file: $e');
      return null;
    }
  }

  /// 直接打开文件选择器(便捷方法)
  ///
  /// 返回选中的字幕文件路径,如果用户取消则返回 null
  Future<String?> pickSubtitleFile() async {
    return await downloadSubtitle(
      SubtitleSearchResult(
        id: 'local',
        title: 'Local Subtitle',
        language: 'unknown',
        languageName: '未知',
        format: 'srt',
        rating: 0,
        downloads: 0,
        uploadDate: DateTime.now(),
        downloadUrl: 'local://',
        source: 'Local',
      ),
      '',
    );
  }

  @override
  List<SubtitleLanguage> getSupportedLanguages() {
    // 本地字幕支持所有语言
    return SubtitleLanguage.common;
  }
}
