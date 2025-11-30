import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 排除路径管理服务
/// 用于管理用户不想在媒体库中看到的路径
class ExcludedPathsService {
  static const String _key = 'excluded_paths';
  static SharedPreferences? _prefs;
  
  /// 初始化服务
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// 添加排除路径
  static Future<void> addPath(String path) async {
    if (_prefs == null) await init();
    
    final paths = getAllPaths();
    if (!paths.contains(path)) {
      paths.add(path);
      await _savePaths(paths);
      print('✅ 已添加排除路径: $path');
    }
  }
  
  /// 移除排除路径（恢复）
  static Future<void> removePath(String path) async {
    if (_prefs == null) await init();
    
    final paths = getAllPaths();
    if (paths.remove(path)) {
      await _savePaths(paths);
      print('✅ 已移除排除路径: $path');
    }
  }
  
  /// 获取所有排除路径
  static List<String> getAllPaths() {
    if (_prefs == null) return [];
    
    final jsonString = _prefs!.getString(_key);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = json.decode(jsonString);
      return decoded.cast<String>();
    } catch (e) {
      print('❌ 解析排除路径列表失败: $e');
      return [];
    }
  }
  
  /// 检查路径是否被排除
  /// 支持前缀匹配：如果 path 以某个排除路径开头，则视为被排除
  static bool isExcluded(String path) {
    final excludedPaths = getAllPaths();
    
    for (final excludedPath in excludedPaths) {
      // 检查是否是该路径或其子路径
      if (path == excludedPath || path.startsWith('$excludedPath/')) {
        return true;
      }
    }
    
    return false;
  }
  
  /// 清空所有排除路径
  static Future<void> clearAll() async {
    if (_prefs == null) await init();
    
    await _prefs!.remove(_key);
    print('✅ 已清空所有排除路径');
  }
  
  /// 保存路径列表
  static Future<void> _savePaths(List<String> paths) async {
    final jsonString = json.encode(paths);
    await _prefs!.setString(_key, jsonString);
  }
  
  /// 获取排除路径数量
  static int getCount() {
    return getAllPaths().length;
  }
}
