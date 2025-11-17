/// 字幕轨道数据模型
/// 表示视频的一个字幕轨道，可以是内嵌字幕或外部字幕文件
class SubtitleTrack {
  /// 轨道ID
  final String id;

  /// 显示名称
  final String title;

  /// 语言代码 (e.g., 'zh', 'en', 'ja')
  final String language;

  /// 语言名称 (e.g., '简体中文', 'English')
  final String languageName;

  /// 是否为外部字幕
  final bool isExternal;

  /// 外部字幕文件路径
  final String? filePath;

  /// 字幕格式 (srt, ass, ssa, vtt)
  final String format;

  /// 是否为默认轨道
  final bool isDefault;

  /// 是否为强制字幕
  final bool isForced;

  const SubtitleTrack({
    required this.id,
    required this.title,
    required this.language,
    required this.languageName,
    this.isExternal = false,
    this.filePath,
    this.format = 'srt',
    this.isDefault = false,
    this.isForced = false,
  });

  /// 从 JSON 创建 SubtitleTrack
  factory SubtitleTrack.fromJson(Map<String, dynamic> json) {
    return SubtitleTrack(
      id: json['id'] as String,
      title: json['title'] as String,
      language: json['language'] as String,
      languageName: json['languageName'] as String,
      isExternal: json['isExternal'] as bool? ?? false,
      filePath: json['filePath'] as String?,
      format: json['format'] as String? ?? 'srt',
      isDefault: json['isDefault'] as bool? ?? false,
      isForced: json['isForced'] as bool? ?? false,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'language': language,
      'languageName': languageName,
      'isExternal': isExternal,
      'filePath': filePath,
      'format': format,
      'isDefault': isDefault,
      'isForced': isForced,
    };
  }

  /// 从 media_kit 的 Track 创建 SubtitleTrack
  factory SubtitleTrack.fromMediaKitTrack(dynamic track) {
    // media_kit 的 Track 对象可能包含不同的属性
    // 需要根据实际 API 调整
    try {
      return const SubtitleTrack(
        id: '',
        title: '未知字幕',
        language: 'unknown',
        languageName: '未知',
      );
    } catch (e) {
      // 如果解析失败，返回默认轨道
      return const SubtitleTrack(
        id: 'unknown',
        title: '未知字幕',
        language: 'unknown',
        languageName: '未知',
      );
    }
  }

  /// 创建外部字幕轨道
  factory SubtitleTrack.external({
    required String filePath,
    required String title,
    String language = 'unknown',
    String languageName = '外部字幕',
    String format = 'srt',
  }) {
    return SubtitleTrack(
      id: 'external_$filePath',
      title: title,
      language: language,
      languageName: languageName,
      isExternal: true,
      filePath: filePath,
      format: format,
    );
  }

  /// 创建关闭字幕选项
  static const SubtitleTrack disabled = SubtitleTrack(
    id: 'disabled',
    title: '关闭字幕',
    language: 'none',
    languageName: '无字幕',
    isExternal: false,
  );

  /// 获取语言名称
  static String _getLanguageName(String languageCode) {
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

  /// 检测字幕格式
  static String _detectFormat(String fileName) {
    final lowerFileName = fileName.toLowerCase();
    if (lowerFileName.endsWith('.srt')) return 'srt';
    if (lowerFileName.endsWith('.ass')) return 'ass';
    if (lowerFileName.endsWith('.ssa')) return 'ssa';
    if (lowerFileName.endsWith('.vtt')) return 'vtt';
    return 'unknown';
  }

  /// 复制并修改部分属性
  SubtitleTrack copyWith({
    String? id,
    String? title,
    String? language,
    String? languageName,
    bool? isExternal,
    String? filePath,
    String? format,
    bool? isDefault,
    bool? isForced,
  }) {
    return SubtitleTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      language: language ?? this.language,
      languageName: languageName ?? this.languageName,
      isExternal: isExternal ?? this.isExternal,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      isDefault: isDefault ?? this.isDefault,
      isForced: isForced ?? this.isForced,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubtitleTrack &&
        other.id == id &&
        other.title == title &&
        other.language == language &&
        other.isExternal == isExternal &&
        other.filePath == filePath &&
        other.format == format;
  }

  @override
  int get hashCode {
    return Object.hash(id, title, language, isExternal, filePath, format);
  }

  @override
  String toString() {
    return 'SubtitleTrack(id: $id, title: $title, language: $language, isExternal: $isExternal, format: $format)';
  }
}