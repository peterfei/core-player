import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// macOS Security-Scoped Bookmarks 服务
/// 用于管理macOS平台上的文件访问权限持久化
class MacOSBookmarkService {
  static const MethodChannel _channel =
      MethodChannel('com.example.vidhub/bookmarks');
  static const String _bookmarksStorageKey = 'macos_file_bookmarks';
  static const String _bookmarksVersionKey = 'macos_bookmarks_version';

  /// 检查是否支持书签功能（仅macOS）
  static bool get isSupported => Platform.isMacOS;

  /// 初始化书签服务
  static Future<void> initialize() async {
    if (!isSupported) return;

    try {
      // 测试方法通道连接
      final result = await _channel.invokeMethod<String>('testConnection');
      print('✅ MacOSBookmarkService 初始化成功: $result');
    } catch (e) {
      print('⚠️ MacOSBookmarkService 初始化失败: $e');
      print('错误类型: ${e.runtimeType}');
      if (e is PlatformException) {
        print('PlatformException详情: ${e.code} - ${e.message}');
      }
    }
  }

  /// 创建文件的安全书签
  ///
  /// [filePath] 文件的绝对路径
  /// 返回 Base64编码的书签数据，失败时返回null
  static Future<String?> createBookmark(String filePath) async {
    if (!isSupported) return null;

    try {
      print('=== 开始创建书签 ===');
      print('文件路径: $filePath');

      // 检查文件是否存在
      final fileExists = await fileExistsAtPath(filePath);
      if (!fileExists) {
        print('❌ 文件不存在: $filePath');
        return null;
      }

      final result = await _channel.invokeMethod<String>('createBookmark', {
        'path': filePath,
      });

      if (result != null) {
        print('✅ 书签创建成功，长度: ${result.length}');
        // 缓存书签数据
        await _cacheBookmark(filePath, result);
      }

      return result;
    } catch (e) {
      print('❌ 创建书签失败: $e');
      return null;
    }
  }

  /// 恢复文件访问权限
  ///
  /// [bookmarkData] Base64编码的书签数据
  /// 返回 恢复的文件路径，失败时返回null
  static Future<String?> startAccessingSecurityScopedResource(
      String bookmarkData) async {
    if (!isSupported) return null;

    try {
      print('=== 开始恢复文件访问权限 ===');

      final result = await _channel.invokeMethod<String?>('startAccess', {
        'bookmark': bookmarkData,
      });

      if (result != null) {
        print('✅ 文件访问权限恢复成功: $result');
      } else {
        print('❌ 文件访问权限恢复失败');
      }

      return result;
    } catch (e) {
      print('❌ 恢复文件访问权限异常: $e');
      if (e is PlatformException && e.code == 'STALE_BOOKMARK') {
        print('⚠️ 书签已过期，需要重新创建');
      }
      return null;
    }
  }

  /// 停止访问特定文件
  ///
  /// [filePath] 文件路径
  static Future<void> stopAccessingSecurityScopedResource(
      String filePath) async {
    if (!isSupported) return;

    try {
      await _channel.invokeMethod('stopAccess', {
        'path': filePath,
      });
      print('✅ 已停止访问文件: $filePath');
    } catch (e) {
      print('⚠️ 停止访问文件失败: $e');
    }
  }

  /// 停止所有文件访问
  static Future<void> stopAllAccess() async {
    if (!isSupported) return;

    try {
      await _channel.invokeMethod('stopAllAccess');
      print('✅ 已停止所有文件访问');
    } catch (e) {
      print('⚠️ 停止所有访问失败: $e');
    }
  }

  /// 检查文件是否存在
  static Future<bool> fileExistsAtPath(String filePath) async {
    if (!isSupported) return File(filePath).existsSync();

    try {
      final result = await _channel.invokeMethod<bool>('fileExists', {
        'path': filePath,
      });
      return result ?? false;
    } catch (e) {
      print('⚠️ 检查文件存在性失败: $e');
      // 降级到Dart的File API
      return File(filePath).existsSync();
    }
  }

  /// 获取文件大小
  static Future<int?> fileSizeAtPath(String filePath) async {
    if (!isSupported) {
      try {
        return await File(filePath).length();
      } catch (e) {
        return null;
      }
    }

    try {
      final result = await _channel.invokeMethod<int>('fileSize', {
        'path': filePath,
      });
      return result;
    } catch (e) {
      print('⚠️ 获取文件大小失败: $e');
      return null;
    }
  }

  /// 获取缓存的 bookmark 数据
  static Future<String?> getCachedBookmark(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarks = prefs.getString(_bookmarksStorageKey);
      if (bookmarks == null) return null;

      final bookmarksMap = Map<String, String>.from(
          jsonDecode(Uri.decodeComponent(bookmarks)) as Map<String, dynamic>);
      return bookmarksMap[filePath];
    } catch (e) {
      print('⚠️ 获取缓存书签失败: $e');
      return null;
    }
  }

  /// 缓存 bookmark 数据
  static Future<void> _cacheBookmark(
      String filePath, String bookmarkData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String bookmarks = prefs.getString(_bookmarksStorageKey) ?? '{}';

      Map<String, String> bookmarksMap = {};
      try {
        bookmarksMap = Map<String, String>.from(
            jsonDecode(Uri.decodeComponent(bookmarks)) as Map<String, dynamic>);
      } catch (e) {
        // 如果解析失败，使用空map
      }

      bookmarksMap[filePath] = bookmarkData;

      // 将Map编码为JSON字符串存储
      final jsonString = Uri.encodeComponent(jsonEncode(bookmarksMap));
      await prefs.setString(_bookmarksStorageKey, jsonString);

      print('✅ 书签数据已缓存');
    } catch (e) {
      print('⚠️ 缓存书签数据失败: $e');
    }
  }

  /// 移除缓存的 bookmark 数据
  static Future<void> removeCachedBookmark(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarks = prefs.getString(_bookmarksStorageKey);
      if (bookmarks == null) return;

      Map<String, String> bookmarksMap = _parseBookmarks(bookmarks);
      
      if (bookmarksMap.containsKey(filePath)) {
        bookmarksMap.remove(filePath);

        // FIX: 使用 jsonEncode 而不是 toString()
        final jsonString = Uri.encodeComponent(jsonEncode(bookmarksMap));
        await prefs.setString(_bookmarksStorageKey, jsonString);

        print('✅ 已移除缓存的书签数据: $filePath');
      }
    } catch (e) {
      print('⚠️ 移除缓存书签失败: $e');
    }
  }

  /// 清理所有缓存的 bookmark 数据
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_bookmarksStorageKey);
      await prefs.remove(_bookmarksVersionKey);
      print('✅ 已清理所有书签缓存');
    } catch (e) {
      print('⚠️ 清理书签缓存失败: $e');
    }
  }

  /// 获取缓存的书签统计信息
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarks = prefs.getString(_bookmarksStorageKey);
      if (bookmarks == null) {
        return {'count': 0, 'totalSize': 0};
      }

      final bookmarksMap = _parseBookmarks(bookmarks);

      int totalSize = 0;
      for (final bookmarkData in bookmarksMap.values) {
        totalSize += bookmarkData.length;
      }

      return {
        'count': bookmarksMap.length,
        'totalSize': totalSize,
        'formattedSize': _formatFileSize(totalSize),
      };
    } catch (e) {
      print('⚠️ 获取缓存统计失败: $e');
      return {'count': 0, 'totalSize': 0};
    }
  }

  /// 格式化文件大小
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 尝试恢复文件访问权限
  /// 首先从缓存中查找bookmark，如果没有则返回null
  static Future<String?> tryRestoreAccess(String filePath) async {
    if (!isSupported) return filePath; // 非macOS平台直接返回

    try {
      // 从缓存中获取bookmark
      final bookmarkData = await getCachedBookmark(filePath);
      if (bookmarkData == null) {
        // print('⚠️ 没有找到缓存的书签数据: $filePath');
        return null;
      }

      // 恢复访问权限
      final restoredPath =
          await startAccessingSecurityScopedResource(bookmarkData);
      if (restoredPath != null) {
        return restoredPath;
      } else {
        // 如果恢复失败，移除无效的缓存
        await removeCachedBookmark(filePath);
        print('⚠️ 移除了无效的书签缓存: $filePath');
        return null;
      }
    } catch (e) {
      print('❌ 尝试恢复访问权限失败: $e');
      return null;
    }
  }

  /// 获取所有已缓存的书签路径（用于调试）
  static Future<List<String>> getBookmarkedPaths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarks = prefs.getString(_bookmarksStorageKey);
      if (bookmarks == null) return [];

      final bookmarksMap = _parseBookmarks(bookmarks);
      return bookmarksMap.keys.toList();
    } catch (e) {
      print('⚠️ 获取书签路径列表失败: $e');
      return [];
    }
  }

  /// 解析书签数据
  /// 包含错误处理和自动重置逻辑
  static Map<String, String> _parseBookmarks(String jsonString) {
    try {
      final decoded = Uri.decodeComponent(jsonString);
      // 尝试解析 JSON
      return Map<String, String>.from(
          jsonDecode(decoded) as Map<String, dynamic>);
    } catch (e) {
      print('⚠️ 书签数据格式错误: $e');
      print('⚠️ 检测到数据损坏，正在重置书签缓存...');
      // 自动清除损坏的缓存，防止持续报错
      clearCache();
      return {};
    }
  }
}
