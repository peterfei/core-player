import 'package:hive/hive.dart';

part 'subtitle_config.g.dart';

/// 字幕位置枚举
@HiveType(typeId: 11)
enum SubtitlePosition {
  @HiveField(0)
  top,
  @HiveField(1)
  center,
  @HiveField(2)
  bottom,
}

/// 字幕配置数据模型
/// 使用 Hive 持久化存储用户字幕偏好设置
@HiveType(typeId: 10)
class SubtitleConfig {
  @HiveField(0)
  final bool enabled; // 是否启用字幕

  @HiveField(1)
  final double fontSize; // 字体大小 (24-72)

  @HiveField(2)
  final String fontFamily; // 字体名称

  @HiveField(3)
  final int fontColor; // 字体颜色 (ARGB)

  @HiveField(4)
  final int backgroundColor; // 背景颜色 (ARGB)

  @HiveField(5)
  final double backgroundOpacity; // 背景透明度 (0.0-1.0)

  @HiveField(6)
  final int outlineColor; // 描边颜色

  @HiveField(7)
  final double outlineWidth; // 描边宽度

  @HiveField(8)
  final SubtitlePosition position; // 字幕位置

  @HiveField(9)
  final int delayMs; // 时间偏移（毫秒）

  @HiveField(10)
  final bool autoLoad; // 自动加载同名字幕

  @HiveField(11)
  final List<String> preferredLanguages; // 首选语言列表

  @HiveField(12)
  final String preferredEncoding; // 首选编码

  const SubtitleConfig({
    this.enabled = true,
    this.fontSize = 36.0,
    this.fontFamily = 'sans-serif',
    this.fontColor = 0xFFFFFFFF, // 白色
    this.backgroundColor = 0x80000000, // 半透明黑色
    this.backgroundOpacity = 0.5,
    this.outlineColor = 0xFF000000, // 黑色描边
    this.outlineWidth = 2.0,
    this.position = SubtitlePosition.bottom,
    this.delayMs = 0,
    this.autoLoad = true,
    this.preferredLanguages = const ['zh', 'zh-CN', 'zh-TW', 'en'],
    this.preferredEncoding = 'UTF-8',
  });

  /// 默认配置
  static SubtitleConfig defaultConfig() => const SubtitleConfig();

  /// 从 JSON 创建 SubtitleConfig
  factory SubtitleConfig.fromJson(Map<String, dynamic> json) {
    return SubtitleConfig(
      enabled: json['enabled'] as bool? ?? true,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 36.0,
      fontFamily: json['fontFamily'] as String? ?? 'sans-serif',
      fontColor: json['fontColor'] as int? ?? 0xFFFFFFFF,
      backgroundColor: json['backgroundColor'] as int? ?? 0x80000000,
      backgroundOpacity: (json['backgroundOpacity'] as num?)?.toDouble() ?? 0.5,
      outlineColor: json['outlineColor'] as int? ?? 0xFF000000,
      outlineWidth: (json['outlineWidth'] as num?)?.toDouble() ?? 2.0,
      position: _parsePosition(json['position'] as String?) ?? SubtitlePosition.bottom,
      delayMs: json['delayMs'] as int? ?? 0,
      autoLoad: json['autoLoad'] as bool? ?? true,
      preferredLanguages: (json['preferredLanguages'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? ['zh', 'zh-CN', 'zh-TW', 'en'],
      preferredEncoding: json['preferredEncoding'] as String? ?? 'UTF-8',
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'fontSize': fontSize,
      'fontFamily': fontFamily,
      'fontColor': fontColor,
      'backgroundColor': backgroundColor,
      'backgroundOpacity': backgroundOpacity,
      'outlineColor': outlineColor,
      'outlineWidth': outlineWidth,
      'position': position.name,
      'delayMs': delayMs,
      'autoLoad': autoLoad,
      'preferredLanguages': preferredLanguages,
      'preferredEncoding': preferredEncoding,
    };
  }

  /// 解析字幕位置
  static SubtitlePosition? _parsePosition(String? positionName) {
    if (positionName == null) return null;
    try {
      return SubtitlePosition.values.firstWhere(
        (e) => e.name == positionName,
      );
    } catch (e) {
      return null;
    }
  }

  /// 复制并修改部分属性
  SubtitleConfig copyWith({
    bool? enabled,
    double? fontSize,
    String? fontFamily,
    int? fontColor,
    int? backgroundColor,
    double? backgroundOpacity,
    int? outlineColor,
    double? outlineWidth,
    SubtitlePosition? position,
    int? delayMs,
    bool? autoLoad,
    List<String>? preferredLanguages,
    String? preferredEncoding,
  }) {
    return SubtitleConfig(
      enabled: enabled ?? this.enabled,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      fontColor: fontColor ?? this.fontColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      outlineColor: outlineColor ?? this.outlineColor,
      outlineWidth: outlineWidth ?? this.outlineWidth,
      position: position ?? this.position,
      delayMs: delayMs ?? this.delayMs,
      autoLoad: autoLoad ?? this.autoLoad,
      preferredLanguages: preferredLanguages ?? this.preferredLanguages,
      preferredEncoding: preferredEncoding ?? this.preferredEncoding,
    );
  }

  /// 获取 ARGB 颜色的透明度分量
  int get fontAlpha => (fontColor >> 24) & 0xFF;
  int get fontRed => (fontColor >> 16) & 0xFF;
  int get fontGreen => (fontColor >> 8) & 0xFF;
  int get fontBlue => fontColor & 0xFF;

  /// 获取背景颜色的透明度分量
  int get backgroundAlpha => (backgroundColor >> 24) & 0xFF;
  int get backgroundRed => (backgroundColor >> 16) & 0xFF;
  int get backgroundGreen => (backgroundColor >> 8) & 0xFF;
  int get backgroundBlue => backgroundColor & 0xFF;

  /// 获取描边颜色的透明度分量
  int get outlineAlpha => (outlineColor >> 24) & 0xFF;
  int get outlineRed => (outlineColor >> 16) & 0xFF;
  int get outlineGreen => (outlineColor >> 8) & 0xFF;
  int get outlineBlue => outlineColor & 0xFF;

  /// 创建 ARGB 颜色值
  static int createARGB(int alpha, int red, int green, int blue) {
    return ((alpha & 0xFF) << 24) |
           ((red & 0xFF) << 16) |
           ((green & 0xFF) << 8) |
           (blue & 0xFF);
  }

  /// 预设的字体颜色
  static const Map<String, int> presetColors = {
    '白色': 0xFFFFFFFF,
    '黑色': 0xFF000000,
    '黄色': 0xFFFFFF00,
    '红色': 0xFFFF0000,
    '绿色': 0xFF00FF00,
    '蓝色': 0xFF0000FF,
    '青色': 0xFF00FFFF,
    '品红': 0xFFFF00FF,
  };

  /// 预设的字体大小
  static const List<double> presetFontSizes = [
    24.0, 28.0, 32.0, 36.0, 40.0, 44.0, 48.0, 52.0, 56.0, 60.0, 64.0, 68.0, 72.0
  ];

  /// 预设的语言偏好
  static const Map<String, List<String>> presetLanguagePreferences = {
    '中文优先': ['zh', 'zh-CN', 'zh-TW', 'en'],
    '英文优先': ['en', 'zh', 'zh-CN', 'zh-TW'],
    '仅中文': ['zh', 'zh-CN', 'zh-TW'],
    '仅英文': ['en'],
    '全部语言': ['zh', 'zh-CN', 'zh-TW', 'en', 'ja', 'ko', 'fr', 'de'],
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubtitleConfig &&
        other.enabled == enabled &&
        other.fontSize == fontSize &&
        other.fontFamily == fontFamily &&
        other.fontColor == fontColor &&
        other.backgroundColor == backgroundColor &&
        other.backgroundOpacity == backgroundOpacity &&
        other.outlineColor == outlineColor &&
        other.outlineWidth == outlineWidth &&
        other.position == position &&
        other.delayMs == delayMs &&
        other.autoLoad == autoLoad &&
        other.preferredEncoding == preferredEncoding &&
        _listEquals(other.preferredLanguages, preferredLanguages);
  }

  /// 比较两个列表是否相等
  static bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    return Object.hash(
      enabled,
      fontSize,
      fontFamily,
      fontColor,
      backgroundColor,
      backgroundOpacity,
      outlineColor,
      outlineWidth,
      position,
      delayMs,
      autoLoad,
      preferredEncoding,
      Object.hashAll(preferredLanguages),
    );
  }

  @override
  String toString() {
    return 'SubtitleConfig('
        'enabled: $enabled, '
        'fontSize: $fontSize, '
        'fontFamily: $fontFamily, '
        'position: $position, '
        'delayMs: $delayMs, '
        'autoLoad: $autoLoad'
        ')';
  }
}