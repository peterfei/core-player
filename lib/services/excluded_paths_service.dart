import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

class ExcludedPathsService {
  static const String _key = 'excluded_paths';
  static SharedPreferences? _prefs;
  static List<String> _excludedPaths = [];

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      
      // 尝试获取 StringList，如果类型不匹配则清空
      final stored = _prefs?.get(_key);
      if (stored is List) {
        // 确保列表中的元素都是字符串
        try {
          _excludedPaths = List<String>.from(stored);
        } catch (e) {
          print('⚠️ ExcludedPathsService: 列表元素类型不匹配，清空数据');
          await _prefs?.remove(_key);
          _excludedPaths = [];
        }
      } else if (stored != null) {
        // 如果存储的不是列表，清空它
        print('⚠️ ExcludedPathsService: 数据类型不是列表，清空数据');
        await _prefs?.remove(_key);
        _excludedPaths = [];
      } else {
        _excludedPaths = [];
      }
    } catch (e) {
      print('❌ ExcludedPathsService 初始化失败: $e');
      _excludedPaths = [];
    }
  }

  static List<String> getAllPaths() {
    return _excludedPaths;
  }

  static Future<void> addPath(String pathStr) async {
    if (!_excludedPaths.any((p) => path.equals(p, pathStr))) {
      _excludedPaths.add(pathStr);
      await _save();
    }
  }

  static Future<void> removePath(String pathStr) async {
    final originalLength = _excludedPaths.length;
    _excludedPaths.removeWhere((p) => path.equals(p, pathStr));
    
    if (_excludedPaths.length != originalLength) {
      await _save();
    }
  }

  static Future<void> clearAll() async {
    _excludedPaths.clear();
    await _save();
  }

  static Future<void> _save() async {
    await _prefs?.setStringList(_key, _excludedPaths);
  }

  static bool isExcluded(String targetPath) {
    // Check if targetPath matches or is inside any excluded path
    for (final excluded in _excludedPaths) {
      if (path.equals(targetPath, excluded)) return true;
      if (path.isWithin(excluded, targetPath)) return true;
    }
    return false;
  }
}
