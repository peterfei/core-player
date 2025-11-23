import 'dart:math' as math;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';
import '../../../core/plugin_system/core_plugin.dart';
import '../../../core/plugin_system/plugin_interface.dart';

/// 主题管理插件
///
/// 功能：
/// - 多套预定义主题
/// - 自定义主题创建
/// - 主题导入导出
/// - 实时主题切换
/// - 字体和颜色管理
/// - 深色/浅色模式
/// - 动态主题元素
class ThemePlugin extends CorePlugin {
  static final _metadata = PluginMetadata(
    id: 'coreplayer.theme_manager',
    name: '主题管理插件',
    version: '1.0.0',
    description: '提供多套UI主题和个性化定制功能，支持实时主题切换和自定义主题创建',
    author: 'CorePlayer Team',
    icon: Icons.palette,
    capabilities: ['theme_management', 'custom_themes', 'theme_switching', 'color_customization'],
    license: PluginLicense.bsd,
  );

  /// 插件内部状态
  PluginState _internalState = PluginState.uninitialized;

  /// 当前激活的主题
  ThemeData? _currentTheme;

  /// 预定义主题集合
  final Map<String, AppTheme> _builtinThemes = {};

  /// 自定义主题集合
  final Map<String, AppTheme> _customThemes = {};

  /// 当前应用主题信息
  AppThemeInfo _currentThemeInfo = const AppThemeInfo(
    id: 'default',
    name: 'Default Theme',
    isDark: true,
    isCustom: false,
  );

  /// 主题变更事件流
  final StreamController<ThemeChangeEvent> _themeController =
      StreamController<ThemeChangeEvent>.broadcast();

  ThemePlugin();

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
    // 加载内置主题
    await _loadBuiltinThemes();

    // 加载自定义主题
    await _loadCustomThemes();

    // 应用默认主题
    await applyTheme('default');

    setStateInternal(PluginState.ready);
    print('ThemePlugin initialized');
  }

  @override
  Future<void> onActivate() async {
    setStateInternal(PluginState.active);
    print('ThemePlugin activated - Theme management enabled');
  }

  @override
  Future<void> onDeactivate() async {
    setStateInternal(PluginState.ready);
    print('ThemePlugin deactivated');
  }

  @override
  Future<void> onDispose() async {
    _currentTheme = null;
    _builtinThemes.clear();
    _customThemes.clear();
    _themeController.close();
    setStateInternal(PluginState.disposed);
  }

  @override
  Future<bool> healthCheck() async {
    try {
      return _currentTheme != null;
    } catch (e) {
      return false;
    }
  }

  /// 加载内置主题
  Future<void> _loadBuiltinThemes() async {
    _builtinThemes.addAll({
      'default': AppTheme(
        id: 'default',
        name: 'Default Theme',
        description: 'CorePlayer 默认主题',
        themeData: _buildDefaultTheme(isDark: true),
        previewColors: {
          'primary': Colors.blue,
          'secondary': Colors.orange,
          'background': Color(0xFF121212),
          'surface': Color(0xFF1E1E1E),
        },
        isDark: true,
      ),
      'light': AppTheme(
        id: 'light',
        name: 'Light Theme',
        description: '明亮色调主题',
        themeData: _buildDefaultTheme(isDark: false),
        previewColors: {
          'primary': Colors.blue,
          'secondary': Colors.orange,
          'background': Colors.white,
          'surface': Color(0xFFF5F5F5),
        },
        isDark: false,
      ),
      'midnight_blue': AppTheme(
        id: 'midnight_blue',
        name: 'Midnight Blue',
        description: '深夜蓝色主题',
        themeData: _buildMidnightBlueTheme(),
        previewColors: {
          'primary': Color(0xFF1E88E5),
          'secondary': Color(0xFF26C6DA),
          'background': Color(0xFF0D1B2A),
          'surface': Color(0xFF1A237E),
        },
        isDark: true,
      ),
      'forest_green': AppTheme(
        id: 'forest_green',
        name: 'Forest Green',
        description: '森林绿色主题',
        themeData: _buildForestGreenTheme(),
        previewColors: {
          'primary': Color(0xFF2E7D32),
          'secondary': Color(0xFF66BB6A),
          'background': Color(0xFF1B5E20),
          'surface': Color(0xFF2E7D32),
        },
        isDark: true,
      ),
      'sunset_orange': AppTheme(
        id: 'sunset_orange',
        name: 'Sunset Orange',
        description: '日落橙色主题',
        themeData: _buildSunsetOrangeTheme(),
        previewColors: {
          'primary': Color(0xFFF57C00),
          'secondary': Color(0xFFFF9800),
          'background': Color(0xFF3E2723),
          'surface': Color(0xFF5D4037),
        },
        isDark: true,
      ),
    });
  }

  /// 加载自定义主题
  Future<void> _loadCustomThemes() async {
    try {
      // 实际实现会从本地存储加载
      // 这里是简化实现
      if (kDebugMode) {
        print('Loading custom themes...');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load custom themes: $e');
      }
    }
  }

  /// 应用主题
  Future<void> applyTheme(String themeId) async {
    AppTheme? theme;

    // 优先查找自定义主题
    theme = _customThemes[themeId];
    theme ??= _builtinThemes[themeId];

    if (theme == null) {
      throw Exception('Theme not found: $themeId');
    }

    _currentTheme = theme.themeData;
    _currentThemeInfo = AppThemeInfo(
      id: theme.id,
      name: theme.name,
      isDark: theme.isDark,
      isCustom: _customThemes.containsKey(themeId),
    );

    // 发送主题变更事件
    _themeController.add(ThemeChangeEvent(
      themeId: themeId,
      theme: theme,
      timestamp: DateTime.now(),
    ));

    if (kDebugMode) {
      print('Applied theme: ${theme.name}');
    }
  }

  /// 获取所有可用主题
  List<AppTheme> getAvailableThemes() {
    final themes = <AppTheme>[];
    themes.addAll(_builtinThemes.values);
    themes.addAll(_customThemes.values);
    return themes;
  }

  /// 获取内置主题
  Map<String, AppTheme> get getBuiltinThemes => Map.unmodifiable(_builtinThemes);

  /// 获取自定义主题
  Map<String, AppTheme> get getCustomThemes => Map.unmodifiable(_customThemes);

  /// 创建自定义主题
  String createCustomTheme({
    required String name,
    required String description,
    required Color primaryColor,
    required Color secondaryColor,
    required Color backgroundColor,
    required Color surfaceColor,
    bool isDark = true,
    String? fontFamily,
  }) {
    final themeId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final themeData = _buildCustomTheme(
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      backgroundColor: backgroundColor,
      surfaceColor: surfaceColor,
      isDark: isDark,
      fontFamily: fontFamily,
    );

    final theme = AppTheme(
      id: themeId,
      name: name,
      description: description,
      themeData: themeData,
      previewColors: {
        'primary': primaryColor,
        'secondary': secondaryColor,
        'background': backgroundColor,
        'surface': surfaceColor,
      },
      isDark: isDark,
      isCustom: true,
      createdAt: DateTime.now(),
    );

    _customThemes[themeId] = theme;
    return themeId;
  }

  /// 更新自定义主题
  Future<void> updateCustomTheme(String themeId, AppTheme updatedTheme) async {
    if (!_customThemes.containsKey(themeId)) {
      throw Exception('Custom theme not found: $themeId');
    }

    updatedTheme = updatedTheme.copyWith(
      id: themeId,
      isCustom: true,
      updatedAt: DateTime.now(),
    );

    _customThemes[themeId] = updatedTheme;

    // 如果当前主题是被更新的主题，重新应用
    if (_currentThemeInfo.id == themeId) {
      _currentTheme = updatedTheme.themeData;
      _themeController.add(ThemeChangeEvent(
        themeId: themeId,
        theme: updatedTheme,
        timestamp: DateTime.now(),
      ));
    }

    // 保存自定义主题
    await _saveCustomThemes();
  }

  /// 删除自定义主题
  Future<void> deleteCustomTheme(String themeId) async {
    if (!_customThemes.containsKey(themeId)) {
      throw Exception('Custom theme not found: $themeId');
    }

    _customThemes.remove(themeId);

    // 如果删除的是当前主题，切换到默认主题
    if (_currentThemeInfo.id == themeId) {
      await applyTheme('default');
    }

    // 保存自定义主题
    await _saveCustomThemes();

    if (kDebugMode) {
      print('Deleted custom theme: $themeId');
    }
  }

  /// 导出主题
  Future<Map<String, dynamic>> exportTheme(String themeId) async {
    AppTheme? theme;
    theme = _customThemes[themeId];
    theme ??= _builtinThemes[themeId];

    if (theme == null) {
      throw Exception('Theme not found: $themeId');
    }

    return {
      'version': '1.0.0',
      'theme': theme.toJson(),
      'exportDate': DateTime.now().toIso8601String(),
    };
  }

  /// 导入主题
  Future<String> importTheme(Map<String, dynamic> themeData) async {
    try {
      final themeJson = themeData['theme'];
      if (themeJson == null) {
        throw Exception('Invalid theme data');
      }

      final theme = AppTheme.fromJson(themeJson);

      // 检查主题ID是否冲突
      var newId = theme.id;
      if (_customThemes.containsKey(newId) || _builtinThemes.containsKey(newId)) {
        newId = 'imported_${DateTime.now().millisecondsSinceEpoch}';
      }

      final importedTheme = theme.copyWith(
        id: newId,
        isCustom: true,
        importedAt: DateTime.now(),
      );

      _customThemes[newId] = importedTheme;
      await _saveCustomThemes();

      if (kDebugMode) {
        print('Imported theme: ${theme.name} as $newId');
      }

      return newId;
    } catch (e) {
      throw Exception('导入主题失败: $e');
    }
  }

  /// 保存自定义主题
  Future<void> _saveCustomThemes() async {
    try {
      // 实际实现会保存到本地存储
      final themesData = _customThemes.values
          .map((theme) => theme.toJson())
          .toList();

      final data = {
        'version': '1.0.0',
        'themes': themesData,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      // 这里应该调用实际的存储API
      if (kDebugMode) {
        print('Saving ${_customThemes.length} custom themes');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save custom themes: $e');
      }
    }
  }

  /// 获取主题变更事件流
  Stream<ThemeChangeEvent> get themeStream => _themeController.stream;

  /// 获取当前主题信息
  AppThemeInfo get currentThemeInfo => _currentThemeInfo;

  /// 获取当前主题
  ThemeData? get currentTheme => _currentTheme;

  /// 生成随机主题配色
  Map<String, Color> generateRandomColorScheme({bool isDark = true}) {
    final random = math.Random();

    // 生成主色调
    final hue = random.nextDouble() * 360;
    final primary = HSLColor.fromAHSL(1.0, hue, 0.7, 0.5).toColor();

    // 生成互补色
    final complementary = HSLColor.fromAHSL(1.0, (hue + 180) % 360, 0.7, 0.5).toColor();

    // 生成背景色
    final background = isDark ? Colors.black : Colors.white;

    // 生成表面色
    final surface = isDark
        ? Color.lerp(background, primary, 0.1)
        : Color.lerp(background, primary, 0.05);

    return {
      'primary': primary,
      'secondary': complementary,
      'background': background,
      'surface': surface ?? Colors.grey,
    };
  }

  /// 构建默认主题
  ThemeData _buildDefaultTheme({required bool isDark}) {
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? Color(0xFF121212) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 2,
      ),
      cardTheme: CardThemeData(
        color: isDark ? Color(0xFF1E1E1E) : Colors.white,
        elevation: 2,
      ),
    );
  }

  /// 构建午夜蓝色主题
  ThemeData _buildMidnightBlueTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF1E88E5),
        secondary: Color(0xFF26C6DA),
        surface: Color(0xFF1A237E),
        background: Color(0xFF0D1B2A),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
    );
  }

  /// 构建森林绿色主题
  ThemeData _buildForestGreenTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF2E7D32),
        secondary: Color(0xFF66BB6A),
        surface: Color(0xFF2E7D32),
        background: Color(0xFF1B5E20),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
    );
  }

  /// 构建日落橙色主题
  ThemeData _buildSunsetOrangeTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFF57C00),
        secondary: Color(0xFFFF9800),
        surface: Color(0xFF5D4037),
        background: Color(0xFF3E2723),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF5D4037),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
    );
  }

  /// 构建自定义主题
  ThemeData _buildCustomTheme({
    required Color primaryColor,
    required Color secondaryColor,
    required Color backgroundColor,
    required Color surfaceColor,
    required bool isDark,
    String? fontFamily,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 2,
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 2,
      ),
      fontFamily: fontFamily,
    );
  }

  /// 获取主题统计信息
  ThemeStats getThemeStats() {
    return ThemeStats(
      totalThemes: _builtinThemes.length + _customThemes.length,
      builtinThemes: _builtinThemes.length,
      customThemes: _customThemes.length,
      activeTheme: _currentThemeInfo.name,
      isDarkMode: _currentThemeInfo.isDark,
    );
  }
}

/// 应用主题
class AppTheme {
  final String id;
  final String name;
  final String description;
  final ThemeData themeData;
  final Map<String, Color> previewColors;
  final bool isDark;
  final bool isCustom;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? importedAt;

  const AppTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.themeData,
    required this.previewColors,
    required this.isDark,
    this.isCustom = false,
    this.createdAt,
    this.updatedAt,
    this.importedAt,
  });

  AppTheme copyWith({
    String? id,
    String? name,
    String? description,
    ThemeData? themeData,
    Map<String, Color>? previewColors,
    bool? isDark,
    bool? isCustom,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? importedAt,
  }) {
    return AppTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      themeData: themeData ?? this.themeData,
      previewColors: previewColors ?? this.previewColors,
      isDark: isDark ?? this.isDark,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      importedAt: importedAt ?? this.importedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'previewColors': previewColors.map((key, value) => MapEntry(
        key, value.value
      )),
      'isDark': isDark,
      'isCustom': isCustom,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'importedAt': importedAt?.toIso8601String(),
    };
  }

  factory AppTheme.fromJson(Map<String, dynamic> json) {
    return AppTheme(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      themeData: ThemeData(), // 简化实现
      previewColors: Map<String, Color>.from(
        (json['previewColors'] ?? {}).map((key, value) => MapEntry(
          key,
          Color(value),
        )),
      ),
      isDark: json['isDark'] ?? true,
      isCustom: json['isCustom'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      importedAt: json['importedAt'] != null
          ? DateTime.parse(json['importedAt'])
          : null,
    );
  }
}

/// 应用主题信息
class AppThemeInfo {
  final String id;
  final String name;
  final bool isDark;
  final bool isCustom;

  const AppThemeInfo({
    required this.id,
    required this.name,
    required this.isDark,
    required this.isCustom,
  });
}

/// 主题变更事件
class ThemeChangeEvent {
  final String themeId;
  final AppTheme theme;
  final DateTime timestamp;

  const ThemeChangeEvent({
    required this.themeId,
    required this.theme,
    required this.timestamp,
  });
}

/// 主题统计
class ThemeStats {
  final int totalThemes;
  final int builtinThemes;
  final int customThemes;
  final String activeTheme;
  final bool isDarkMode;

  const ThemeStats({
    required this.totalThemes,
    required this.builtinThemes,
    required this.customThemes,
    required this.activeTheme,
    required this.isDarkMode,
  });
}

/// HSL颜色扩展
extension HSLColorExtension on HSLColor {
  Color toColor() {
    final h = hue / 360;
    final s = saturation;
    final l = lightness;
    final c = (1 - (2 * l - 1).abs()) * s;
    final x = c * (1 - ((h * 6).floor() % 2 - 1).abs());
    final m = l + c / 2;

    double r, g, b;
    if (h < 1/6) {
      r = c; g = x; b = 0;
    } else if (h < 2/6) {
      r = x; g = c; b = 0;
    } else if (h < 3/6) {
      r = 0; g = c; b = x;
    } else if (h < 4/6) {
      r = 0; g = x; b = c;
    } else if (h < 5/6) {
      r = x; g = 0; b = c;
    } else {
      r = c; g = 0; b = x;
    }

    return Color.fromRGBO(
      ((r + m) * 255).round(),
      ((g + m) * 255).round(),
      ((b + m) * 255).round(),
      1,
    );
  }
}