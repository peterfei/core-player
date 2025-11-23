import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/update/update_models.dart';
import '../../config/plugin_update_api_config.dart';
import 'mock_update_api.dart';

/// 更新检测器
/// 
/// 负责检测插件是否有可用更新
class UpdateDetector {
  /// 单例实例
  static final UpdateDetector _instance = UpdateDetector._internal();
  factory UpdateDetector() => _instance;
  UpdateDetector._internal();


  
  /// 缓存过期时间 (1小时)
  static const Duration _cacheExpiration = Duration(hours: 1);
  
  /// 缓存键前缀
  static const String _cacheKeyPrefix = 'update_cache_';
  
  /// 最后检查时间键
  static const String _lastCheckKey = 'last_update_check';

  /// SharedPreferences实例
  SharedPreferences? _prefs;

  /// 初始化
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 检查单个插件的更新
  ///
  /// [pluginId] 插件ID
  /// [currentVersion] 当前版本
  /// [forceRefresh] 是否强制刷新(忽略缓存)
  Future<UpdateInfo?> checkForUpdate({
    required String pluginId,
    required String currentVersion,
    bool forceRefresh = false,
  }) async {
    await initialize();

    print('🔍 检查插件更新: $pluginId (当前版本: $currentVersion)');

    // 🔧 强制清除缓存并从API获取最新版本信息
    await clearPluginCache(pluginId);
    print('🔧 强制从API获取最新版本信息');
    forceRefresh = true;
    
    try {
      // 调用API检查更新
      final updateInfo = await _fetchUpdateFromApi(pluginId, currentVersion);
      
      if (updateInfo != null) {
        // 保存到缓存
        await _saveToCache(pluginId, updateInfo);
        
        if (updateInfo.hasUpdate) {
          print('🆕 发现新版本: ${updateInfo.latestVersion}');
        } else {
          print('✅ 已是最新版本');
        }
      }
      
      return updateInfo;
    } catch (e, stackTrace) {
      print('❌ 检查更新失败: $e');
      print(stackTrace);
      return null;
    }
  }

  /// 检查所有插件的更新
  /// 
  /// [plugins] 插件列表 (pluginId -> currentVersion)
  /// [forceRefresh] 是否强制刷新
  Future<List<UpdateInfo>> checkAllUpdates({
    required Map<String, String> plugins,
    bool forceRefresh = false,
  }) async {
    await initialize();
    
    print('🔍 批量检查更新: ${plugins.length}个插件');
    
    final updates = <UpdateInfo>[];
    
    // 并发检查所有插件
    final futures = plugins.entries.map((entry) {
      return checkForUpdate(
        pluginId: entry.key,
        currentVersion: entry.value,
        forceRefresh: forceRefresh,
      );
    });
    
    final results = await Future.wait(futures);
    
    // 过滤出有更新的插件
    for (final result in results) {
      if (result != null && result.hasUpdate) {
        updates.add(result);
      }
    }
    
    // 按优先级排序
    updates.sort((a, b) {
      // 安全更新优先
      if (a.isSecurityUpdate && !b.isSecurityUpdate) return -1;
      if (!a.isSecurityUpdate && b.isSecurityUpdate) return 1;
      
      // 强制更新优先
      if (a.isMandatory && !b.isMandatory) return -1;
      if (!a.isMandatory && b.isMandatory) return 1;
      
      // 按优先级排序
      return b.priority.compareTo(a.priority);
    });
    
    print('✅ 发现 ${updates.length} 个可用更新');
    
    // 更新最后检查时间
    await _updateLastCheckTime();
    
    return updates;
  }

  /// 比较版本号
  /// 
  /// 返回值:
  /// - 正数: v1 > v2
  /// - 0: v1 == v2
  /// - 负数: v1 < v2
  int compareVersions(String v1, String v2) {
    try {
      final version1 = Version.parse(v1);
      final version2 = Version.parse(v2);
      return version1.compareTo(version2);
    } catch (e) {
      print('⚠️ 版本号解析失败: $e');
      // 降级到字符串比较
      return v1.compareTo(v2);
    }
  }

  /// 检查版本兼容性
  /// 
  /// [pluginVersion] 插件版本
  /// [minAppVersion] 最低应用版本要求
  /// [currentAppVersion] 当前应用版本
  bool isVersionCompatible({
    required String pluginVersion,
    String? minAppVersion,
    required String currentAppVersion,
  }) {
    if (minAppVersion == null) return true;
    
    try {
      final minVersion = Version.parse(minAppVersion);
      final appVersion = Version.parse(currentAppVersion);
      return appVersion >= minVersion;
    } catch (e) {
      print('⚠️ 版本兼容性检查失败: $e');
      return false;
    }
  }

  /// 获取最后检查时间
  Future<DateTime?> getLastCheckTime() async {
    await initialize();
    final timestamp = _prefs?.getInt(_lastCheckKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// 清除缓存
  Future<void> clearCache() async {
    await initialize();
    final keys = _prefs?.getKeys() ?? {};
    for (final key in keys) {
      if (key.startsWith(_cacheKeyPrefix)) {
        await _prefs?.remove(key);
      }
    }
    print('🧹 更新缓存已清除');
  }

  /// 强制清除所有更新相关缓存
  Future<void> forceClearAllUpdateCache() async {
    await initialize();
    final keys = _prefs?.getKeys() ?? {};

    // 清除所有更新相关缓存
    for (final key in keys) {
      if (key.startsWith(_cacheKeyPrefix) || key.startsWith('update_cache_')) {
        await _prefs?.remove(key);
      }
      if (key == _lastCheckKey) {
        await _prefs?.remove(key);
      }
    }

    print('🧹 强制清除所有更新缓存完成');
  }

  /// 强制清除特定插件的缓存
  Future<void> clearPluginCache(String pluginId) async {
    await initialize();
    final cacheKey = '$_cacheKeyPrefix$pluginId';
    await _prefs?.remove(cacheKey);
    print('🧹 已清除插件缓存: $pluginId');
  }

  // ==================== 私有方法 ====================

  /// 从API获取更新信息
  Future<UpdateInfo?> _fetchUpdateFromApi(
    String pluginId,
    String currentVersion,
  ) async {
    // 🔧 开发模式: 使用Mock数据
    if (MockUpdateApi.enabled) {
      print('🔧 使用Mock数据检查更新');
      await Future.delayed(const Duration(milliseconds: 500)); // 模拟网络延迟
      final mockResult = MockUpdateApi.checkUpdate(
        pluginId: pluginId,
        currentVersion: currentVersion,
      );

      if (mockResult != null) {
        return mockResult;
      } else {
        print('⚠️ Mock数据库中无此插件: $pluginId');
        return null;
      }
    }

    // 🌐 生产模式: 使用真实API
    final url = Uri.parse(PluginUpdateApiConfig.updateCheckUrl(pluginId));

    try {
      print('🌐 请求真实API: $url');
      final response = await http.get(
        url,
        headers: {
          ...PluginUpdateApiConfig.getHeaders(),
          'X-Current-Version': currentVersion,
        },
      ).timeout(PluginUpdateApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('✅ 从API获取到更新信息');
        return UpdateInfo.fromJson(data);
      } else if (response.statusCode == 404) {
        print('⚠️ 插件不存在: $pluginId (404)');
        return null;
      } else {
        print('❌ API返回错误: ${response.statusCode}');
        return null;
      }
    } on TimeoutException {
      print('❌ 请求超时 - API服务器可能未运行');
      return null;
    } catch (e) {
      print('❌ 网络请求失败: $e');
      print('💡 提示: 确保插件更新服务器在 ${PluginUpdateApiConfig.baseUrl} 运行');
      return null;
    }
  }

  /// 从缓存获取更新信息
  Future<UpdateInfo?> _getFromCache(String pluginId) async {
    final cacheKey = '$_cacheKeyPrefix$pluginId';
    final cached = _prefs?.getString(cacheKey);
    
    if (cached == null) return null;
    
    try {
      final data = json.decode(cached) as Map<String, dynamic>;
      final cachedTime = DateTime.parse(data['cachedAt'] as String);
      
      // 检查是否过期
      if (DateTime.now().difference(cachedTime) > _cacheExpiration) {
        print('⚠️ 缓存已过期');
        await _prefs?.remove(cacheKey);
        return null;
      }
      
      return UpdateInfo.fromJson(data['updateInfo'] as Map<String, dynamic>);
    } catch (e) {
      print('⚠️ 缓存解析失败: $e');
      await _prefs?.remove(cacheKey);
      return null;
    }
  }

  /// 保存到缓存
  Future<void> _saveToCache(String pluginId, UpdateInfo updateInfo) async {
    final cacheKey = '$_cacheKeyPrefix$pluginId';
    final data = {
      'cachedAt': DateTime.now().toIso8601String(),
      'updateInfo': updateInfo.toJson(),
    };
    
    await _prefs?.setString(cacheKey, json.encode(data));
  }

  /// 更新最后检查时间
  Future<void> _updateLastCheckTime() async {
    await _prefs?.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
  }
}
