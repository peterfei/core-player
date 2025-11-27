import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:charset_converter/charset_converter.dart';
import '../models/subtitle_track.dart' as subtitle_models;
import '../models/subtitle_config.dart';
import 'subtitle_download_manager.dart';

/// 字幕服务
/// 提供字幕加载、解析、样式设置等功能
class SubtitleService {
  static final SubtitleService instance = SubtitleService._internal();

  factory SubtitleService() => instance;
  SubtitleService._internal();

  late Box<SubtitleConfig> _configBox;
  SubtitleConfig _config = SubtitleConfig.defaultConfig();

  /// 初始化服务
  Future<void> initialize() async {
    try {
      // 注册 Hive adapter（必须在打开 box 之前）
      if (!Hive.isAdapterRegistered(11)) {
        Hive.registerAdapter(SubtitlePositionAdapter());
      }
      if (!Hive.isAdapterRegistered(10)) {
        Hive.registerAdapter(SubtitleConfigAdapter());
      }

      _configBox = await Hive.openBox<SubtitleConfig>('subtitle_config');

      // 加载配置
      final savedConfig = _configBox.get('config');
      if (savedConfig != null) {
        _config = savedConfig;
      } else {
        // 保存默认配置
        await _configBox.put('config', _config);
      }

      debugPrint('SubtitleService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing SubtitleService: $e');
      // 使用默认配置
      _config = SubtitleConfig.defaultConfig();
    }
  }

  /// 获取当前配置
  SubtitleConfig get config => _config;

  /// 保存配置
  Future<void> saveConfig(SubtitleConfig config) async {
    try {
      _config = config;
      await _configBox.put('config', config);
      debugPrint('Subtitle config saved');
    } catch (e) {
      debugPrint('Error saving subtitle config: $e');
      rethrow;
    }
  }

  /// 获取可用的字幕轨道
  Future<List<subtitle_models.SubtitleTrack>> getAvailableTracks(
      Player player) async {
    try {
      final tracks = <subtitle_models.SubtitleTrack>[];

      // 添加关闭字幕选项
      tracks.add(subtitle_models.SubtitleTrack.disabled);

      // 获取播放器的字幕轨道
      // 注意：media_kit 的 API 可能不同，需要根据实际版本调整
      try {
        final subtitleTracks = player.state.tracks.subtitle;
        debugPrint('Found ${subtitleTracks.length} subtitle tracks in player');

        if (subtitleTracks.isNotEmpty) {
          for (int i = 0; i < subtitleTracks.length; i++) {
            final track = subtitleTracks[i];
            try {
              // 跳过特殊轨道（auto, no 等）
              if (track.id == 'auto' || track.id == 'no') {
                debugPrint('Skipping special track: id=${track.id}');
                continue;
              }

              // 使用索引作为ID，这样可以可靠地定位轨道
              final trackId = 'subtitle_$i';
              final subtitleTrack = subtitle_models.SubtitleTrack(
                id: trackId,
                title: track.title?.toString() ??
                    track.language?.toString() ??
                    '字幕轨道 ${tracks.length}',
                language: track.language?.toString() ?? 'unknown',
                languageName:
                    _getLanguageName(track.language?.toString() ?? 'unknown'),
                isExternal: false,
                format: 'unknown',
              );
              tracks.add(subtitleTrack);
              debugPrint(
                  'Added subtitle track: ${subtitleTrack.title} (index: $i, id: $trackId)');
            } catch (e) {
              debugPrint('Error processing subtitle track $i: $e');
              continue;
            }
          }
        }
      } catch (e) {
        debugPrint('Error accessing subtitle tracks: $e');
        // 返回默认的关闭字幕选项
      }

      debugPrint('Found ${tracks.length} subtitle tracks');
      return tracks;
    } catch (e) {
      debugPrint('Error getting subtitle tracks: $e');
      return [subtitle_models.SubtitleTrack.disabled];
    }
  }

  /// 加载外部字幕文件
  /// 支持 v1.2.0+ 的改进外部字幕轨道 API
  Future<subtitle_models.SubtitleTrack?> loadExternalSubtitle(
      Player player, String filePath) async {
    try {
      // 验证文件存在
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('Subtitle file not found: $filePath');
        return null;
      }

      // 检测字幕格式
      final format = _detectSubtitleFormat(filePath);
      if (format == 'unknown') {
        debugPrint('Unsupported subtitle format: $filePath');
        return null;
      }

      // 检测编码并转换（如果需要）
      String? convertedPath = filePath;
      String? subtitle_language;

      if (!await _isUtf8(filePath)) {
        convertedPath = await _convertToUtf8(filePath);
        if (convertedPath == null) {
          debugPrint('Failed to convert subtitle encoding: $filePath');
          return null;
        }
      }

      // 提取语言代码（如果文件名中包含）
      subtitle_language = _extractLanguageFromFileName(convertedPath);

      // 使用 media_kit 加载字幕
      // 创建字幕轨道对象并将其加载到播放器
      final track = subtitle_models.SubtitleTrack.external(
        filePath: convertedPath,
        title: path.basenameWithoutExtension(convertedPath),
        format: format,
        language: subtitle_language ?? 'unknown',
      );

      // 立即将字幕加载到播放器
      try {
        debugPrint('Subtitle file path: $convertedPath');
        debugPrint(
            'Subtitle file exists: ${await File(convertedPath).exists()}');

        // 方法1：使用 MPV 的 sub-add 命令直接加载字幕文件（最可靠）
        if (player.platform is NativePlayer) {
          final nativePlayer = player.platform as NativePlayer;
          // MPV sub-add 命令: sub-add <filename> [flags] [title] [lang]
          // 使用 'select' 标志立即激活字幕
          await nativePlayer.command([
            'sub-add',
            convertedPath,
            'select',
            track.title,
            subtitle_language ?? 'unknown'
          ]);
          debugPrint(
              'External subtitle loaded via MPV sub-add command: ${track.title}');

          // 确保字幕可见
          await nativePlayer.setProperty('sub-visibility', 'yes');
          debugPrint('MPV sub-visibility set to yes');
        } else {
          // 方法2：使用 SubtitleTrack.data() 作为备用
          final subtitleFile = File(convertedPath);
          final subtitleContent = await subtitleFile.readAsString();

          debugPrint(
              'Subtitle content length: ${subtitleContent.length} characters');
          debugPrint(
              'Subtitle content preview: ${subtitleContent.substring(0, subtitleContent.length > 200 ? 200 : subtitleContent.length)}');

          final mediaKitTrack = SubtitleTrack.data(
            subtitleContent,
            title: track.title,
            language: subtitle_language ?? 'unknown',
          );
          await player.setSubtitleTrack(mediaKitTrack);
          debugPrint(
              'External subtitle track loaded via data: ${track.title} (language: $subtitle_language)');
        }
      } catch (e) {
        debugPrint('Error setting external subtitle on player: $e');
        // 如果直接加载失败，尝试使用 URI 方式作为备用
        try {
          final fileUri = Uri.file(convertedPath).toString();
          final mediaKitTrack = SubtitleTrack.uri(
            fileUri,
            title: track.title,
            language: subtitle_language ?? 'unknown',
          );
          await player.setSubtitleTrack(mediaKitTrack);
          debugPrint(
              'External subtitle track loaded via URI (fallback): ${track.title}');
        } catch (e2) {
          debugPrint('Error setting external subtitle via URI fallback: $e2');
        }
      }

      debugPrint('External subtitle track created: ${track.title}');
      return track;
    } catch (e) {
      debugPrint('Error loading external subtitle: $e');
      return null;
    }
  }

  /// 使用 MPV 命令加载字幕（备用方案）
  Future<subtitle_models.SubtitleTrack?> _loadSubtitleWithMpv(
      Player player, String filePath, String format) async {
    try {
      // 使用 MPV 的 sub-add 命令
      // 注意：这需要 media_kit 暴露 MPV 命令接口
      // 这里是示例代码，实际 API 可能不同

      final track = subtitle_models.SubtitleTrack.external(
        filePath: filePath,
        title: path.basenameWithoutExtension(filePath),
        format: format,
      );

      debugPrint('Subtitle loaded with MPV: $filePath');
      return track;
    } catch (e) {
      debugPrint('Error loading subtitle with MPV: $e');
      return null;
    }
  }

  /// 选择字幕轨道
  Future<void> selectTrack(
      Player player, subtitle_models.SubtitleTrack track) async {
    try {
      debugPrint('Selecting subtitle track: ${track.title} (id: ${track.id})');

      if (track.id == 'disabled') {
        await _disableSubtitles(player);
        return;
      }

      // 如果是外部字幕，需要先加载
      if (track.isExternal && track.filePath != null) {
        // 外部字幕通过 sub-add 加载后会自动激活，不需要再次设置
        await loadExternalSubtitle(player, track.filePath!);
        // 只应用样式配置，不重新设置轨道
        await applyConfig(player);
        debugPrint('External subtitle loaded and activated: ${track.title}');
      } else {
        // 内置字幕轨道需要通过 media_kit 设置
        await _setSubtitleTrack(player, track);
        debugPrint('Selected internal subtitle track: ${track.title}');
      }
    } catch (e) {
      debugPrint('Error selecting subtitle track: $e');
    }
  }

  /// 设置字幕轨道 (media_kit 集成)
  Future<void> _setSubtitleTrack(
      Player player, subtitle_models.SubtitleTrack track) async {
    try {
      if (track.id == 'disabled') {
        // 禁用字幕 - 使用 SubtitleTrack.no()
        await player.setSubtitleTrack(SubtitleTrack.no());
        debugPrint('Disabled subtitles');
      } else if (track.isExternal && track.filePath != null) {
        // 外部字幕使用 SubtitleTrack.data() 直接传递内容
        try {
          final subtitleFile = File(track.filePath!);
          final subtitleContent = await subtitleFile.readAsString();
          final mediaKitTrack = SubtitleTrack.data(
            subtitleContent,
            title: track.title,
            language: track.language,
          );
          await player.setSubtitleTrack(mediaKitTrack);
          debugPrint(
              'Set external subtitle track via data: ${track.title} (${track.filePath})');
        } catch (e) {
          debugPrint('Error reading subtitle file, trying URI fallback: $e');
          // 备用：使用 URI 方式
          final fileUri = Uri.file(track.filePath!).toString();
          final mediaKitTrack = SubtitleTrack.uri(
            fileUri,
            title: track.title,
            language: track.language,
          );
          await player.setSubtitleTrack(mediaKitTrack);
          debugPrint('Set external subtitle track via URI: ${track.title}');
        }
      } else if (track.id.startsWith('subtitle_')) {
        // 内置字幕轨道：从ID中提取索引 (格式: "subtitle_0", "subtitle_1", etc.)
        final indexStr = track.id.replaceFirst('subtitle_', '');
        final index = int.tryParse(indexStr);

        if (index != null) {
          final mediaKitTracks = player.state.tracks.subtitle;
          debugPrint('Available subtitle tracks: ${mediaKitTracks.length}');
          for (int i = 0; i < mediaKitTracks.length; i++) {
            final t = mediaKitTracks[i];
            debugPrint(
                '  Track $i: id=${t.id}, title=${t.title}, language=${t.language}');
          }

          if (index >= 0 && index < mediaKitTracks.length) {
            final mkTrack = mediaKitTracks[index];

            // 检查当前播放器是否已经在使用这个字幕轨道
            // 如果是通过 sub-add 命令加载的外部字幕，它已经是活动的，不要重新设置
            final currentTrack = player.state.track.subtitle;
            debugPrint(
                'Current active track: id=${currentTrack.id}, title=${currentTrack.title}');
            debugPrint(
                'Target track: id=${mkTrack.id}, title=${mkTrack.title}');

            final isSameTrack = currentTrack.id == mkTrack.id ||
                (currentTrack.title != null &&
                    currentTrack.title == mkTrack.title);

            if (isSameTrack) {
              debugPrint(
                  'Subtitle track already active: ${mkTrack.title ?? mkTrack.id}, skipping re-selection');
            } else {
              // 如果目标轨道是通过 sub-add 加载的（ID 不是 auto/no），可能已经激活
              // 检查轨道 ID 是否为数字（sub-add 加载的轨道 ID 通常是数字）
              if (mkTrack.id != 'auto' &&
                  mkTrack.id != 'no' &&
                  currentTrack.id != 'auto' &&
                  currentTrack.id != 'no') {
                debugPrint(
                    'Both tracks are valid subtitle tracks, checking if we need to switch...');
              }
              debugPrint(
                  'Setting subtitle track: index=$index, id=${mkTrack.id}, title=${mkTrack.title}');
              await player.setSubtitleTrack(mkTrack);
              debugPrint(
                  'Set subtitle track by index: $index (${mkTrack.title ?? mkTrack.language ?? 'unknown'})');
            }
          } else {
            debugPrint(
                'Subtitle index $index out of range (${mediaKitTracks.length} tracks available)');
          }
        }
      }

      // 应用字幕样式配置
      await applyConfig(player);
    } catch (e) {
      debugPrint('Error setting subtitle track with media_kit: $e');
      rethrow;
    }
  }

  /// 使用 MPV 命令设置字幕轨道
  Future<void> _setSubtitleTrackWithMpv(
      Player player, subtitle_models.SubtitleTrack track) async {
    try {
      if (track.id == 'disabled') {
        // 禁用字幕
        // 注意：media_kit 可能需要暴露 MPV 命令接口
        debugPrint('Disabled subtitles via MPV command');
        return;
      }

      // 设置字幕轨道
      // 注意：这需要 media_kit 暴露 MPV 命令接口
      debugPrint('Set subtitle track via MPV command: ${track.id}');
    } catch (e) {
      debugPrint('Error setting subtitle track with MPV: $e');
    }
  }

  /// 禁用字幕
  Future<void> disableSubtitles(Player player) async {
    try {
      // 使用 MPV 命令禁用字幕
      // 注意：具体的 API 需要根据 media_kit 调整
      debugPrint('Subtitles disabled');
    } catch (e) {
      debugPrint('Error disabling subtitles: $e');
    }
  }

  /// 禁用字幕的私有方法
  Future<void> _disableSubtitles(Player player) async {
    await disableSubtitles(player);
  }

  /// 设置字幕延迟
  Future<void> setSubtitleDelay(Player player, Duration delay) async {
    try {
      // 使用 MPV 命令设置字幕延迟
      // 注意：具体的 API 需要根据 media_kit 调整

      // 保存到配置
      final newConfig = _config.copyWith(delayMs: delay.inMilliseconds);
      await saveConfig(newConfig);

      debugPrint('Subtitle delay set to ${delay.inMilliseconds}ms');
    } catch (e) {
      debugPrint('Error setting subtitle delay: $e');
    }
  }

  /// 应用字幕样式
  Future<void> applyConfig(Player player) async {
    try {
      final config = _config;

      // 方法1：使用 media_kit 的字幕样式API（如果可用）
      await _applySubtitleStylesWithMediaKit(player, config);

      // 方法2：使用 MPV 命令设置字幕样式
      await _applySubtitleStylesWithMpv(player, config);

      debugPrint('Subtitle style applied: ${config.toString()}');
    } catch (e) {
      debugPrint('Error applying subtitle config: $e');
    }
  }

  /// 使用 media_kit 应用字幕样式
  Future<void> _applySubtitleStylesWithMediaKit(
      Player player, SubtitleConfig config) async {
    try {
      // 尝试使用 media_kit 的字幕样式设置接口
      // 注意：具体API需要根据 media_kit 版本调整

      // 这里是假设的API调用方式
      // await player.setSubtitleStyles({
      //   'fontSize': config.fontSize,
      //   'fontColor': '#${config.fontColor.toRadixString(16).padLeft(8, '0').substring(2)}',
      //   'backgroundColor': '#${config.backgroundColor.toRadixString(16).padLeft(8, '0').substring(2)}',
      // });

      debugPrint('Applied subtitle styles with media_kit API');
    } catch (e) {
      debugPrint('Failed to apply styles with media_kit: $e');
      // 继续尝试MPV方法
      rethrow;
    }
  }

  /// 使用 MPV 命令应用字幕样式
  Future<void> _applySubtitleStylesWithMpv(
      Player player, SubtitleConfig config) async {
    try {
      if (player.platform is NativePlayer) {
        final nativePlayer = player.platform as NativePlayer;

        // 设置 MPV 字幕属性
        await nativePlayer.setProperty(
            'sub-font-size', config.fontSize.toString());
        await nativePlayer.setProperty('sub-font', config.fontFamily);
        await nativePlayer.setProperty(
            'sub-color', _colorToMpvFormat(config.fontColor));
        await nativePlayer.setProperty(
            'sub-back-color', _colorToMpvFormat(config.backgroundColor));
        await nativePlayer.setProperty(
            'sub-border-color', _colorToMpvFormat(config.outlineColor));
        await nativePlayer.setProperty(
            'sub-border-size', config.outlineWidth.toString());
        await nativePlayer.setProperty(
            'sub-pos', _positionToMpvValue(config.position).toString());
        await nativePlayer.setProperty(
            'sub-delay', (config.delayMs / 1000.0).toString());

        // 确保字幕可见
        await nativePlayer.setProperty('sub-visibility', 'yes');

        debugPrint(
            'Applied subtitle styles with MPV: font-size=${config.fontSize}, pos=${config.position}');
      } else {
        debugPrint('Cannot apply MPV styles: player is not NativePlayer');
      }
    } catch (e) {
      debugPrint('Failed to apply styles with MPV: $e');
    }
  }

  /// 将 ARGB 颜色转换为 MPV 格式
  String _colorToMpvFormat(int argbColor) {
    final a = (argbColor >> 24) & 0xFF;
    final r = (argbColor >> 16) & 0xFF;
    final g = (argbColor >> 8) & 0xFF;
    final b = argbColor & 0xFF;
    
    // MPV format: #AARRGGBB
    return '#${a.toRadixString(16).padLeft(2, '0')}${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
  }

  /// 将位置枚举转换为 MPV 位置值
  int _positionToMpvValue(SubtitlePosition position) {
    switch (position) {
      case SubtitlePosition.top:
        return 10;
      case SubtitlePosition.center:
        return 50;
      case SubtitlePosition.bottom:
        return 90;
    }
  }

  /// 查找匹配的字幕文件
  Future<String?> findMatchingSubtitle(String videoPath) async {
    try {
      final videoDir = path.dirname(videoPath);
      final videoName = path.basenameWithoutExtension(videoPath);

      // 搜索同目录的字幕文件
      final directory = Directory(videoDir);
      if (!await directory.exists()) {
        return null;
      }

      final subtitleExtensions = ['.srt', '.ass', '.ssa', '.vtt'];
      final candidates = <String>[];

      await for (final entity in directory.list()) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          final fileExtension = path.extension(fileName);

          if (subtitleExtensions.contains(fileExtension.toLowerCase())) {
            final baseName = path.basenameWithoutExtension(fileName);

            // 完全匹配
            if (baseName == videoName) {
              candidates.insert(0, entity.path); // 优先级最高
            }
            // 带语言标识匹配
            else if (baseName.startsWith('$videoName.')) {
              candidates.add(entity.path);
            }
          }
        }
      }

      // 根据语言偏好排序
      if (candidates.isNotEmpty) {
        return _selectBestSubtitleMatch(candidates);
      }

      return null;
    } catch (e) {
      debugPrint('Error finding matching subtitle: $e');
      return null;
    }
  }

  /// 根据语言偏好选择最佳字幕匹配
  String? _selectBestSubtitleMatch(List<String> candidates) {
    if (candidates.isEmpty) return null;

    final preferredLanguages = _config.preferredLanguages;

    // 按优先级评分
    int bestScore = -1;
    String? bestMatch;

    for (final candidate in candidates) {
      int score = 0;
      final fileName = path.basenameWithoutExtension(candidate).toLowerCase();

      // 完全匹配得分最高
      if (candidates.indexOf(candidate) == 0) {
        score += 100;
      }

      // 检查语言标识
      for (int i = 0; i < preferredLanguages.length; i++) {
        final lang = preferredLanguages[i].toLowerCase();
        if (fileName.contains(lang) ||
            fileName.contains(_getLanguageAlias(lang))) {
          score += (preferredLanguages.length - i) * 10;
          break;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = candidate;
      }
    }

    return bestMatch;
  }

  /// 获取语言名称
  String _getLanguageName(String languageCode) {
    final Map<String, String> languageMap = {
      'zh': '简体中文',
      'zh-cn': '简体中文',
      'zh-tw': '繁体中文',
      'en': 'English',
      'ja': '日语',
      'ko': '韩语',
      'fr': 'Français',
      'de': 'Deutsch',
      'es': 'Español',
      'it': 'Italiano',
      'pt': 'Português',
      'ru': 'Русский',
      'ar': 'العربية',
      'hi': 'हिन्दी',
      'th': 'ไทย',
      'vi': 'Tiếng Việt',
      'unknown': '未知',
    };

    return languageMap[languageCode.toLowerCase()] ?? languageMap['unknown']!;
  }

  /// 获取语言别名
  String _getLanguageAlias(String languageCode) {
    final aliases = {
      'zh': ['chinese', 'chs', 'cht', '中文', '简体', '繁体'],
      'zh-cn': ['chs', '简体', '简中'],
      'zh-tw': ['cht', '繁体', '繁中'],
      'en': ['english', 'eng'],
      'ja': ['japanese', 'jpn'],
      'ko': ['korean', 'kor'],
    };

    for (final entry in aliases.entries) {
      if (entry.key == languageCode.toLowerCase()) {
        return entry.value.first;
      }
      if (entry.value.contains(languageCode.toLowerCase())) {
        return entry.key;
      }
    }

    return languageCode;
  }

  /// 从文件名中提取语言代码
  /// 例如: movie.en.srt -> 'en', movie.zh-cn.srt -> 'zh-cn', movie.国语.srt -> 'zh'
  String? _extractLanguageFromFileName(String filePath) {
    try {
      final fileName = path.basenameWithoutExtension(filePath).toLowerCase();

      // 检查是否包含中文标识
      if (fileName.contains('国语') ||
          fileName.contains('简体') ||
          fileName.contains('简中')) {
        return 'zh-cn';
      }
      if (fileName.contains('繁体') || fileName.contains('繁中')) {
        return 'zh-tw';
      }

      // 检查是否包含其他语言标识
      final languagePatterns = {
        'en': ['english', 'eng', '英文', '英语', '英文字幕'],
        'ja': ['japanese', 'jpn', '日文', '日语', '日文字幕'],
        'ko': ['korean', 'kor', '韩文', '韩语'],
        'fr': ['french', 'fra', '法文', '法语'],
        'de': ['german', 'deu', '德文', '德语'],
        'es': ['spanish', 'esp', '西班牙文', '西班牙语'],
        'ru': ['russian', 'rus', '俄文', '俄语'],
        'pt': ['portuguese', 'por', '葡萄牙文', '葡萄牙语'],
      };

      for (final entry in languagePatterns.entries) {
        for (final pattern in entry.value) {
          if (fileName.contains(pattern)) {
            return entry.key;
          }
        }
      }

      // 检查扩展名之前的语言代码
      final parts = fileName.split('.');
      if (parts.length >= 2) {
        final potentialLang = parts[parts.length - 1];

        // 检查是否是有效的语言代码
        final languageCodes = [
          'zh',
          'zh-cn',
          'zh-tw',
          'en',
          'ja',
          'ko',
          'fr',
          'de',
          'es',
          'it',
          'pt',
          'ru',
          'ar',
          'hi',
          'th',
          'vi',
          'chs',
          'cht',
          'eng',
          'jpn',
          'kor',
          'fra',
          'deu',
          'esp',
          'ita',
          'por',
          'rus'
        ];

        if (languageCodes.contains(potentialLang)) {
          return potentialLang;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error extracting language from filename: $e');
      return null;
    }
  }

  /// 选择字幕文件
  Future<String?> pickSubtitleFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'ass', 'ssa', 'vtt'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        return result.files.single.path!;
      }

      return null;
    } catch (e) {
      debugPrint('Error picking subtitle file: $e');
      return null;
    }
  }

  /// 加载下载的字幕
  /// 支持 v1.2.0+ 的改进外部字幕轨道 API
  Future<subtitle_models.SubtitleTrack?> loadDownloadedSubtitle(
      Player player, String subtitlePath, String title,
      {String? language}) async {
    try {
      final format = _detectSubtitleFormat(subtitlePath);
      final extractedLang =
          language ?? _extractLanguageFromFileName(subtitlePath);

      final track = subtitle_models.SubtitleTrack.external(
        filePath: subtitlePath,
        title: title,
        format: format,
        language: extractedLang ?? 'unknown',
        languageName:
            extractedLang != null ? _getLanguageName(extractedLang) : '下载字幕',
      );

      // 立即将字幕加载到播放器
      try {
        // 方法1：使用 MPV 的 sub-add 命令直接加载字幕文件
        if (player.platform is NativePlayer) {
          final nativePlayer = player.platform as NativePlayer;
          // 使用 'select' 标志立即激活字幕
          await nativePlayer.command([
            'sub-add',
            subtitlePath,
            'select',
            title,
            extractedLang ?? 'unknown'
          ]);
          await nativePlayer.setProperty('sub-visibility', 'yes');
          debugPrint(
              'Downloaded subtitle track loaded via MPV sub-add: ${track.title} (language: $extractedLang)');
        } else {
          // 方法2：使用 SubtitleTrack.data() 作为备用
          final subtitleFile = File(subtitlePath);
          final subtitleContent = await subtitleFile.readAsString();

          final mediaKitTrack = SubtitleTrack.data(
            subtitleContent,
            title: title,
            language: extractedLang ?? 'unknown',
          );
          await player.setSubtitleTrack(mediaKitTrack);
          debugPrint(
              'Downloaded subtitle track loaded via data: ${track.title} (language: $extractedLang)');
        }
      } catch (e) {
        debugPrint('Error setting downloaded subtitle on player: $e');
        // 备用：尝试 URI 方式
        try {
          final fileUri = Uri.file(subtitlePath).toString();
          final mediaKitTrack = SubtitleTrack.uri(
            fileUri,
            title: title,
            language: extractedLang ?? 'unknown',
          );
          await player.setSubtitleTrack(mediaKitTrack);
          debugPrint(
              'Downloaded subtitle track loaded via URI (fallback): ${track.title}');
        } catch (e2) {
          debugPrint('Error setting downloaded subtitle via URI fallback: $e2');
        }
      }

      debugPrint('Loaded downloaded subtitle: ${track.title}');
      return track;
    } catch (e) {
      debugPrint('Error loading downloaded subtitle: $e');
      return null;
    }
  }

  /// 获取字幕下载服务
  SubtitleDownloadManager get downloadService =>
      SubtitleDownloadManager.instance;

  /// 检测字幕格式
  String _detectSubtitleFormat(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.srt':
        return 'srt';
      case '.ass':
        return 'ass';
      case '.ssa':
        return 'ssa';
      case '.vtt':
        return 'vtt';
      default:
        return 'unknown';
    }
  }

  /// 检查文件是否为 UTF-8 编码
  Future<bool> _isUtf8(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();

      // 简单的 UTF-8 检测
      try {
        utf8.decode(bytes);
        return true;
      } catch (e) {
        return false;
      }
    } catch (e) {
      debugPrint('Error checking file encoding: $e');
      return false;
    }
  }

  /// 转换文件编码为 UTF-8
  Future<String?> _convertToUtf8(String filePath) async {
    try {
      final file = File(filePath);
      final originalContent = await file.readAsBytes();

      // 尝试不同的编码进行转换
      final encodings = ['GBK', 'BIG5', 'SHIFT_JIS', 'EUC-KR', 'ISO-8859-1'];

      for (final encoding in encodings) {
        try {
          final convertedContent =
              await CharsetConverter.decode(encoding, originalContent);

          // 创建 UTF-8 版本的文件
          final utf8Path = '${filePath}_utf8.srt';
          final utf8File = File(utf8Path);
          await utf8File.writeAsString(convertedContent, encoding: utf8);

          debugPrint('Successfully converted subtitle from $encoding to UTF-8');
          return utf8Path;
        } catch (e) {
          // 继续尝试下一个编码
          continue;
        }
      }

      debugPrint('Failed to convert subtitle encoding with any known encoding');
      return filePath; // 返回原文件路径
    } catch (e) {
      debugPrint('Error converting subtitle encoding: $e');
      return null;
    }
  }

  /// 验证字幕文件
  Future<bool> validateSubtitleFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final content = await file.readAsString();
      return content.isNotEmpty;
    } catch (e) {
      debugPrint('Error validating subtitle file: $e');
      return false;
    }
  }

  /// 搜索目录中的字幕文件
  Future<List<String>> searchSubtitlesInDirectory(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        return [];
      }

      final subtitleFiles = <String>[];
      final subtitleExtensions = ['.srt', '.ass', '.ssa', '.vtt'];

      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final extension = path.extension(entity.path).toLowerCase();
          if (subtitleExtensions.contains(extension)) {
            subtitleFiles.add(entity.path);
          }
        }
      }

      debugPrint('Found ${subtitleFiles.length} subtitle files in directory');
      return subtitleFiles;
    } catch (e) {
      debugPrint('Error searching subtitle files: $e');
      return [];
    }
  }

  /// 清理临时文件
  Future<void> cleanup() async {
    // 清理编码转换过程中产生的临时文件
    // 可以根据需要实现
  }
}
