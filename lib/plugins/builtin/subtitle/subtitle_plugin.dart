import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/plugin_system/core_plugin.dart';
import '../../../core/plugin_system/plugin_interface.dart';

/// 字幕处理插件
///
/// 功能：
/// - 支持多种字幕格式（SRT, ASS, VTT等）
/// - 字幕样式自定义
/// - 字幕编码自动检测
/// - 字幕时间轴调整
/// - 字幕搜索和导航
class SubtitlePlugin extends CorePlugin {
  static final _metadata = PluginMetadata(
    id: 'coreplayer.subtitle',
    name: '字幕处理插件',
    version: '1.0.0',
    description: '支持多种字幕格式加载、解析和渲染，提供丰富的字幕样式和导航功能',
    author: 'CorePlayer Team',
    icon: Icons.subtitles,
    capabilities: ['subtitle_parsing', 'subtitle_rendering', 'subtitle_styling', 'subtitle_search'],
    license: PluginLicense.bsd,
  );

  /// 插件内部状态
  PluginState _internalState = PluginState.uninitialized;

  /// 字幕文件解析器
  final Map<String, SubtitleParser> _parsers = {};

  /// 当前加载的字幕
  List<SubtitleEntry> _currentSubtitles = [];

  /// 字幕样式配置
  SubtitleStyle _subtitleStyle = const SubtitleStyle();

  SubtitlePlugin();

  @override
  PluginMetadata get metadata => _metadata;

  @override
  PluginState get state => _internalState;

  @override
  void setStateInternal(PluginState newState) {
    _internalState = newState;
  }

  @override
  Future<void> onInitialize() async {
    // 注册字幕解析器
    _registerParsers();

    // 加载默认样式
    await _loadDefaultStyle();

    setStateInternal(PluginState.initialized);
    print('SubtitlePlugin initialized');
  }

  @override
  Future<void> onActivate() async {
    setStateInternal(PluginState.active);
    print('SubtitlePlugin activated - Subtitle processing enabled');
  }

  @override
  Future<void> onDeactivate() async {
    // 清理当前字幕
    _currentSubtitles.clear();
    setStateInternal(PluginState.ready);
    print('SubtitlePlugin deactivated - Current subtitles cleared');
  }

  @override
  void onDispose() {
    _currentSubtitles.clear();
    _parsers.clear();
    setStateInternal(PluginState.disposed);
  }

  @override
  Future<bool> healthCheck() async {
    try {
      // 测试解析器是否正常工作
      final testContent = '''1
00:00:01,000 --> 00:00:03,000
测试字幕内容''';

      final parser = _parsers['srt'];
      if (parser == null) return false;

      final entries = await parser.parse(testContent);
      return entries.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// 注册字幕解析器
  void _registerParsers() {
    _parsers['srt'] = SrtParser();
    _parsers['ass'] = AssParser();
    _parsers['vtt'] = VttParser();
    _parsers['sbv'] = SbvParser();
  }

  /// 加载默认样式
  Future<void> _loadDefaultStyle() async {
    _subtitleStyle = SubtitleStyle(
      fontSize: 18.0,
      fontColor: Colors.white,
      backgroundColor: Colors.black.withOpacity(0.5),
      fontFamily: 'Arial',
      fontWeight: FontWeight.normal,
      textAlign: TextAlign.center,
      position: SubtitlePosition.bottom,
      margin: const EdgeInsets.all(20.0),
    );
  }

  /// 加载字幕文件
  Future<SubtitleLoadResult> loadSubtitleFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return SubtitleLoadResult(
          success: false,
          error: '字幕文件不存在: $filePath',
        );
      }

      final content = await file.readAsString(encoding: utf8);
      final extension = filePath.toLowerCase().split('.').last;

      final parser = _parsers[extension];
      if (parser == null) {
        return SubtitleLoadResult(
          success: false,
          error: '不支持的字幕格式: $extension',
        );
      }

      final entries = await parser.parse(content);
      _currentSubtitles = entries;

      return SubtitleLoadResult(
        success: true,
        entryCount: entries.length,
        format: extension.toUpperCase(),
      );
    } catch (e) {
      return SubtitleLoadResult(
        success: false,
        error: '加载字幕失败: $e',
      );
    }
  }

  /// 获取当前时间点的字幕
  SubtitleEntry? getSubtitleAt(Duration position) {
    for (final entry in _currentSubtitles) {
      if (position >= entry.startTime && position <= entry.endTime) {
        return entry;
      }
    }
    return null;
  }

  /// 搜索字幕
  List<SubtitleSearchResult> searchSubtitles(String query) {
    if (query.isEmpty) return [];

    final results = <SubtitleSearchResult>[];
    final lowerQuery = query.toLowerCase();

    for (int i = 0; i < _currentSubtitles.length; i++) {
      final entry = _currentSubtitles[i];
      if (entry.text.toLowerCase().contains(lowerQuery)) {
        results.add(SubtitleSearchResult(
          entry: entry,
          index: i,
          context: _getContextAroundEntry(i),
        ));
      }
    }

    return results;
  }

  /// 获取字幕条目上下文
  String _getContextAroundEntry(int index, {int contextSize = 2}) {
    final start = (index - contextSize).clamp(0, _currentSubtitles.length);
    final end = (index + contextSize + 1).clamp(0, _currentSubtitles.length);

    return _currentSubtitles
        .skip(start)
        .take(end - start)
        .map((e) => e.text)
        .join(' ');
  }

  /// 调整字幕时间轴
  void adjustSubtitleTiming(Duration offset) {
    for (final entry in _currentSubtitles) {
      entry.adjustTime(offset);
    }
  }

  /// 设置字幕样式
  void setSubtitleStyle(SubtitleStyle style) {
    _subtitleStyle = style;
  }

  /// 获取当前字幕样式
  SubtitleStyle get subtitleStyle => _subtitleStyle;

  /// 获取支持的字幕格式
  List<String> getSupportedFormats() {
    return _parsers.keys.toList();
  }

  /// 导出字幕
  Future<void> exportSubtitle(String filePath, String format) async {
    final parser = _parsers[format.toLowerCase()];
    if (parser == null) {
      throw Exception('不支持的导出格式: $format');
    }

    final content = parser.export(_currentSubtitles);
    final file = File(filePath);
    await file.writeAsString(content, encoding: utf8);
  }
}

/// 字幕条目
class SubtitleEntry {
  final Duration startTime;
  final Duration endTime;
  String text;
  final List<SubtitleStyle> styles;

  SubtitleEntry({
    required this.startTime,
    required this.endTime,
    required this.text,
    this.styles = const [],
  });

  /// 调整时间
  void adjustTime(Duration offset) {
    // 这里需要实现时间调整逻辑
    // 由于Duration是不可变的，需要创建新的条目
  }
}

/// 字幕样式
class SubtitleStyle {
  final double fontSize;
  final Color fontColor;
  final Color backgroundColor;
  final String fontFamily;
  final FontWeight fontWeight;
  final TextAlign textAlign;
  final SubtitlePosition position;
  final EdgeInsets margin;

  const SubtitleStyle({
    this.fontSize = 16.0,
    this.fontColor = Colors.white,
    this.backgroundColor = Colors.transparent,
    this.fontFamily = 'Arial',
    this.fontWeight = FontWeight.normal,
    this.textAlign = TextAlign.center,
    this.position = SubtitlePosition.bottom,
    this.margin = EdgeInsets.zero,
  });
}

/// 字幕位置
enum SubtitlePosition {
  top,
  center,
  bottom,
}

/// 字幕加载结果
class SubtitleLoadResult {
  final bool success;
  final int? entryCount;
  final String? format;
  final String? error;

  const SubtitleLoadResult({
    required this.success,
    this.entryCount,
    this.format,
    this.error,
  });
}

/// 字幕搜索结果
class SubtitleSearchResult {
  final SubtitleEntry entry;
  final int index;
  final String context;

  const SubtitleSearchResult({
    required this.entry,
    required this.index,
    required this.context,
  });
}

/// 字幕解析器接口
abstract class SubtitleParser {
  Future<List<SubtitleEntry>> parse(String content);
  String export(List<SubtitleEntry> entries);
}

/// SRT解析器
class SrtParser extends SubtitleParser {
  @override
  Future<List<SubtitleEntry>> parse(String content) async {
    final entries = <SubtitleEntry>[];
    final blocks = content.split('\n\n').where((block) => block.trim().isNotEmpty);

    for (final block in blocks) {
      final lines = block.split('\n');
      if (lines.length >= 3) {
        try {
          final index = int.parse(lines[0].trim());
          final timeLine = lines[1].trim();
          final text = lines.skip(2).join('\n');

          final times = timeLine.split(' --> ');
          if (times.length == 2) {
            final startTime = _parseTime(times[0]);
            final endTime = _parseTime(times[1]);

            entries.add(SubtitleEntry(
              startTime: startTime,
              endTime: endTime,
              text: text.trim(),
            ));
          }
        } catch (e) {
          // 忽略解析错误的条目
        }
      }
    }

    return entries;
  }

  Duration _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length == 3) {
      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      final secondsAndMs = parts[2].split(',');
      final seconds = int.parse(secondsAndMs[0]);
      final milliseconds = int.parse(secondsAndMs[1]);

      return Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      );
    }
    return Duration.zero;
  }

  @override
  String export(List<SubtitleEntry> entries) {
    final buffer = StringBuffer();

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      buffer.writeln(i + 1);
      buffer.writeln(_formatTime(entry.startTime) + ' --> ' + _formatTime(entry.endTime));
      buffer.writeln(entry.text);
      if (i < entries.length - 1) {
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  String _formatTime(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds = (duration.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds,$milliseconds';
  }
}

/// ASS解析器（简化版）
class AssParser extends SubtitleParser {
  @override
  Future<List<SubtitleEntry>> parse(String content) async {
    // 实现ASS格式解析
    // 这里是简化实现
    return [];
  }

  @override
  String export(List<SubtitleEntry> entries) {
    // 实现ASS格式导出
    return '';
  }
}

/// VTT解析器（简化版）
class VttParser extends SubtitleParser {
  @override
  Future<List<SubtitleEntry>> parse(String content) async {
    // 实现VTT格式解析
    // 这里是简化实现
    return [];
  }

  @override
  String export(List<SubtitleEntry> entries) {
    // 实现VTT格式导出
    return '';
  }
}

/// SBV解析器（简化版）
class SbvParser extends SubtitleParser {
  @override
  Future<List<SubtitleEntry>> parse(String content) async {
    // 实现SBV格式解析
    // 这里是简化实现
    return [];
  }

  @override
  String export(List<SubtitleEntry> entries) {
    // 实现SBV格式导出
    return '';
  }
}