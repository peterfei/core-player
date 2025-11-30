import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

class ExcludedPathsService {
  static const String _key = 'excluded_paths';
  static SharedPreferences? _prefs;
  static List<String> _excludedPaths = [];

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _excludedPaths = _prefs?.getStringList(_key) ?? [];
  }

  static List<String> getAllPaths() {
    return _excludedPaths;
  }

  static Future<void> addPath(String pathStr) async {
    if (!_excludedPaths.contains(pathStr)) {
      _excludedPaths.add(pathStr);
      await _save();
    }
  }

  static Future<void> removePath(String pathStr) async {
    if (_excludedPaths.contains(pathStr)) {
      _excludedPaths.remove(pathStr);
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
    // Check if targetPath starts with any excluded path
    // Normalize paths to ensure consistent comparison
    // We check if targetPath is equal to or inside an excluded path.
    
    for (final excluded in _excludedPaths) {
      if (targetPath == excluded) return true;
      if (path.isWithin(excluded, targetPath)) return true;
    }
    return false;
  }
}
