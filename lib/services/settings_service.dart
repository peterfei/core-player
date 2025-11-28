import 'package:shared_preferences/shared_preferences.dart';
import 'tmdb_service.dart';

enum PlaybackQualityMode {
  auto,
  highQuality,
  lowPower,
  compatibility,
}

class SettingsService {
  static const String _historyEnabledKey = 'history_enabled';
  static const String _maxHistoryCountKey = 'max_history_count';
  static const String _autoCleanDaysKey = 'auto_clean_days';
  static const String _thumbnailsEnabledKey = 'thumbnails_enabled';
  static const String _firstLaunchKey = 'first_launch';
  static const String _playbackQualityModeKey = 'playback_quality_mode';
  static const String _performanceAlertsEnabledKey = 'performance_alerts_enabled';
  static const String _tmdbApiKey = 'tmdb_api_key';
  static const String _tmdbAccessToken = 'tmdb_access_token';
  static const String _autoScrapeEnabledKey = 'auto_scrape_enabled';
  static const String _themeIdKey = 'theme_id'; // 主题ID
  // 用户提供的默认 Key
  static const String _defaultTmdbApiKey = '7881c04fb4405464297402a783614152';
  static const String _defaultTmdbAccessToken = 'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI3ODgxYzA0ZmI0NDA1NDY0Mjk3NDAyYTc4MzYxNDE1MiIsIm5iZiI6MTYzMzQxMTkxNy45MzUwMDAyLCJzdWIiOiI2MTViZTM0ZDFjNjM1YjAwNDQ4M2YxNTQiLCJzY29wZXMiOlsiYXBpX3JlYWQiXSwidmVyc2lvbiI6MX0.-Vlwm0cNIraTqijZXpPXuXZ-SDj56fyqucDvoU1oCjg';

  // 默认设置值
  static const bool _defaultHistoryEnabled = true;
  static const int _defaultMaxHistoryCount = 50;
  static const int _defaultAutoCleanDays = 30;
  static const bool _defaultThumbnailsEnabled = true;
  static const PlaybackQualityMode _defaultPlaybackQualityMode = PlaybackQualityMode.auto;
  static const bool _defaultPerformanceAlertsEnabled = false; // 默认关闭
  static const bool _defaultAutoScrapeEnabled = true; // 默认开启自动刮削
  static const String _defaultThemeId = 'default'; // 默认主题ID

  // TMDB 设置
  static Future<String?> getTMDBApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tmdbApiKey) ?? _defaultTmdbApiKey;
  }

  static Future<String?> getTMDBAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tmdbAccessToken) ?? _defaultTmdbAccessToken;
  }

  static Future<void> setTMDBApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tmdbApiKey, apiKey);
    final accessToken = await getTMDBAccessToken();
    TMDBService.init(apiKey, accessToken: accessToken);
  }

  static Future<void> setTMDBAccessToken(String accessToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tmdbAccessToken, accessToken);
    final apiKey = await getTMDBApiKey();
    TMDBService.init(apiKey ?? '', accessToken: accessToken);
  }

  // 历史记录设置
  static Future<bool> isHistoryEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_historyEnabledKey) ?? _defaultHistoryEnabled;
  }

  static Future<void> setHistoryEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_historyEnabledKey, enabled);
  }

  static Future<int> getMaxHistoryCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_maxHistoryCountKey) ?? _defaultMaxHistoryCount;
  }

  static Future<void> setMaxHistoryCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxHistoryCountKey, count.clamp(1, 200));
  }

  static Future<int> getAutoCleanDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_autoCleanDaysKey) ?? _defaultAutoCleanDays;
  }

  static Future<void> setAutoCleanDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoCleanDaysKey, days.clamp(7, 365));
  }

  static Future<bool> isThumbnailsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_thumbnailsEnabledKey) ?? _defaultThumbnailsEnabled;
  }

  static Future<void> setThumbnailsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_thumbnailsEnabledKey, enabled);
  }

  // 播放质量模式设置
  static Future<PlaybackQualityMode> getPlaybackQualityMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeString = prefs.getString(_playbackQualityModeKey);
    return PlaybackQualityMode.values.firstWhere(
      (e) => e.name == modeString,
      orElse: () => _defaultPlaybackQualityMode,
    );
  }

  static Future<void> setPlaybackQualityMode(PlaybackQualityMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playbackQualityModeKey, mode.name);
  }

  // 性能提示设置
  static Future<bool> isPerformanceAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_performanceAlertsEnabledKey) ?? _defaultPerformanceAlertsEnabled;
  }

  static Future<void> setPerformanceAlertsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_performanceAlertsEnabledKey, enabled);
  }

  // 自动刮削设置
  static Future<bool> getAutoScrapeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoScrapeEnabledKey) ?? _defaultAutoScrapeEnabled;
  }

  static Future<void> setAutoScrapeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoScrapeEnabledKey, enabled);
  }

  // 主题设置
  static Future<String> getThemeId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeIdKey) ?? _defaultThemeId;
  }

  static Future<void> setThemeId(String themeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeIdKey, themeId);
  }


  // 应用设置
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstLaunchKey) ?? true;
  }

  static Future<void> setFirstLaunchCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, false);
  }

  // 重置所有设置
  static Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyEnabledKey);
    await prefs.remove(_maxHistoryCountKey);
    await prefs.remove(_autoCleanDaysKey);
    await prefs.remove(_thumbnailsEnabledKey);
    await prefs.remove(_playbackQualityModeKey);
    await prefs.remove(_performanceAlertsEnabledKey);
    await prefs.remove(_themeIdKey);
  }

  // 获取所有设置
  static Future<Map<String, dynamic>> getAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'historyEnabled':
          prefs.getBool(_historyEnabledKey) ?? _defaultHistoryEnabled,
      'maxHistoryCount':
          prefs.getInt(_maxHistoryCountKey) ?? _defaultMaxHistoryCount,
      'autoCleanDays': prefs.getInt(_autoCleanDaysKey) ?? _defaultAutoCleanDays,
      'thumbnailsEnabled':
          prefs.getBool(_thumbnailsEnabledKey) ?? _defaultThumbnailsEnabled,
      'playbackQualityMode':
          (prefs.getString(_playbackQualityModeKey) ?? _defaultPlaybackQualityMode.name),
      'performanceAlertsEnabled':
          prefs.getBool(_performanceAlertsEnabledKey) ?? _defaultPerformanceAlertsEnabled,
    };
  }

  // 批量更新设置
  static Future<void> updateSettings(Map<String, dynamic> settings) async {
    for (final entry in settings.entries) {
      switch (entry.key) {
        case 'historyEnabled':
          if (entry.value is bool) {
            await setHistoryEnabled(entry.value);
          }
          break;
        case 'maxHistoryCount':
          if (entry.value is int) {
            await setMaxHistoryCount(entry.value);
          }
          break;
        case 'autoCleanDays':
          if (entry.value is int) {
            await setAutoCleanDays(entry.value);
          }
          break;
        case 'thumbnailsEnabled':
          if (entry.value is bool) {
            await setThumbnailsEnabled(entry.value);
          }
          break;
        case 'playbackQualityMode':
          if (entry.value is String) {
            final mode = PlaybackQualityMode.values.firstWhere(
              (e) => e.name == entry.value,
              orElse: () => _defaultPlaybackQualityMode,
            );
            await setPlaybackQualityMode(mode);
          }
          break;
        case 'performanceAlertsEnabled':
          if (entry.value is bool) {
            await setPerformanceAlertsEnabled(entry.value);
          }
          break;
      }
    }
  }

  // 设置验证
  static bool isValidMaxHistoryCount(int count) {
    return count >= 1 && count <= 200;
  }

  static bool isValidAutoCleanDays(int days) {
    return days >= 7 && days <= 365;
  }

  // 格式化方法
  static String formatMaxHistoryCount(int count) {
    return '$count 条记录';
  }

  static String formatAutoCleanDays(int days) {
    if (days == 7) return '1 周';
    if (days == 30) return '1 个月';
    if (days == 90) return '3 个月';
    if (days == 180) return '6 个月';
    return '$days 天';
  }

  static String formatPlaybackQualityMode(PlaybackQualityMode mode) {
    switch (mode) {
      case PlaybackQualityMode.auto:
        return '自动模式';
      case PlaybackQualityMode.highQuality:
        return '高质量模式';
      case PlaybackQualityMode.lowPower:
        return '低功耗模式';
      case PlaybackQualityMode.compatibility:
        return '兼容模式';
    }
  }

  // 获取设置描述
  static String getSettingDescription(String key, dynamic value) {
    switch (key) {
      case 'historyEnabled':
        return value == true ? '启用播放历史记录' : '禁用播放历史记录';
      case 'maxHistoryCount':
        return '最多保存 $value 条历史记录';
      case 'autoCleanDays':
        return '超过 ${formatAutoCleanDays(value)} 自动清理';
      case 'thumbnailsEnabled':
        return value == true ? '生成视频缩略图' : '不生成视频缩略图';
      case 'playbackQualityMode':
        return '播放质量: ${formatPlaybackQualityMode(PlaybackQualityMode.values.firstWhere((e) => e.name == value))}';
      default:
        return '';
    }
  }
}
