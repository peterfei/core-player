import 'dart:async';
import 'package:flutter/material.dart';
import 'core_plugin.dart';
import 'plugin_interface.dart';

/// 字幕下载插件接口
///
/// 提供字幕搜索和下载功能的统一接口
abstract class SubtitleDownloadPlugin extends CorePlugin {
  /// 搜索字幕
  ///
  /// [query] 搜索关键词(通常是视频标题)
  /// [language] 语言代码(如 'zh', 'en')
  /// [page] 页码
  /// [limit] 每页结果数量
  Future<List<SubtitleSearchResult>> searchSubtitles({
    required String query,
    String? language,
    int page = 1,
    int limit = 20,
  });

  /// 下载字幕
  ///
  /// [result] 搜索结果
  /// [targetPath] 目标视频路径(用于确定字幕保存位置)
  /// 返回下载的字幕文件路径,失败返回 null
  Future<String?> downloadSubtitle(
    SubtitleSearchResult result,
    String targetPath,
  );

  /// 获取支持的语言列表
  List<SubtitleLanguage> getSupportedLanguages();

  /// 插件显示名称(用于UI选择器)
  String get displayName;

  /// 插件图标
  IconData get icon;

  /// 是否需要网络连接
  bool get requiresNetwork => true;

  /// 是否支持批量下载
  bool get supportsBatchDownload => false;
}

/// 字幕搜索结果
class SubtitleSearchResult {
  /// 唯一标识符
  final String id;

  /// 字幕标题
  final String title;

  /// 语言代码
  final String language;

  /// 语言显示名称
  final String languageName;

  /// 字幕格式(srt, ass, vtt等)
  final String format;

  /// 评分(0-5)
  final double rating;

  /// 下载次数
  final int downloads;

  /// 上传日期
  final DateTime uploadDate;

  /// 下载URL或标识符
  final String downloadUrl;

  /// 字幕来源(SubHD, OpenSubtitles等)
  final String source;

  /// 文件大小(字节)
  final int? fileSize;

  /// 上传者
  final String? uploader;

  /// 备注信息
  final String? notes;

  const SubtitleSearchResult({
    required this.id,
    required this.title,
    required this.language,
    required this.languageName,
    required this.format,
    required this.rating,
    required this.downloads,
    required this.uploadDate,
    required this.downloadUrl,
    required this.source,
    this.fileSize,
    this.uploader,
    this.notes,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubtitleSearchResult &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          source == other.source;

  @override
  int get hashCode => id.hashCode ^ source.hashCode;

  @override
  String toString() {
    return 'SubtitleSearchResult{id: $id, title: $title, language: $languageName, source: $source}';
  }
}

/// 字幕语言
class SubtitleLanguage {
  /// 语言代码(ISO 639-1)
  final String code;

  /// 语言显示名称
  final String name;

  /// 语言本地名称
  final String? nativeName;

  const SubtitleLanguage({
    required this.code,
    required this.name,
    this.nativeName,
  });

  /// 常用语言列表
  static const List<SubtitleLanguage> common = [
    SubtitleLanguage(code: 'zh', name: '简体中文', nativeName: '中文'),
    SubtitleLanguage(code: 'zh-tw', name: '繁体中文', nativeName: '中文'),
    SubtitleLanguage(code: 'en', name: 'English', nativeName: 'English'),
    SubtitleLanguage(code: 'ja', name: '日语', nativeName: '日本語'),
    SubtitleLanguage(code: 'ko', name: '韩语', nativeName: '한국어'),
    SubtitleLanguage(code: 'fr', name: 'French', nativeName: 'Français'),
    SubtitleLanguage(code: 'de', name: 'German', nativeName: 'Deutsch'),
    SubtitleLanguage(code: 'es', name: 'Spanish', nativeName: 'Español'),
    SubtitleLanguage(code: 'ru', name: 'Russian', nativeName: 'Русский'),
    SubtitleLanguage(code: 'ar', name: 'Arabic', nativeName: 'العربية'),
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubtitleLanguage &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'SubtitleLanguage{code: $code, name: $name}';
}
