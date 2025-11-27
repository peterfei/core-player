import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/plugin_system/subtitle_download_plugin.dart';

/// 字幕下载管理器
///
/// 管理字幕下载插件,提供统一的字幕搜索和下载接口
class SubtitleDownloadManager {
  static final SubtitleDownloadManager instance = SubtitleDownloadManager._internal();

  factory SubtitleDownloadManager() => instance;
  SubtitleDownloadManager._internal();

  /// 已注册的字幕下载插件
  final List<SubtitleDownloadPlugin> _plugins = [];

  /// 当前活跃的插件
  SubtitleDownloadPlugin? _activePlugin;

  /// 插件变化通知
  final StreamController<List<SubtitleDownloadPlugin>> _pluginsController =
      StreamController<List<SubtitleDownloadPlugin>>.broadcast();

  /// 活跃插件变化通知
  final StreamController<SubtitleDownloadPlugin?> _activePluginController =
      StreamController<SubtitleDownloadPlugin?>.broadcast();

  /// 插件列表变化流
  Stream<List<SubtitleDownloadPlugin>> get pluginsStream =>
      _pluginsController.stream;

  /// 活跃插件变化流
  Stream<SubtitleDownloadPlugin?> get activePluginStream =>
      _activePluginController.stream;

  /// 注册字幕下载插件
  ///
  /// [plugin] 要注册的插件
  /// 如果插件ID已存在,将替换旧插件
  void registerPlugin(SubtitleDownloadPlugin plugin) {
    // 检查是否已存在相同ID的插件
    final existingIndex = _plugins.indexWhere(
      (p) => p.staticMetadata.id == plugin.staticMetadata.id,
    );

    if (existingIndex != -1) {
      _plugins[existingIndex] = plugin;
      if (kDebugMode) {
        print('SubtitleDownloadManager: Replaced plugin ${plugin.staticMetadata.id}');
      }
    } else {
      _plugins.add(plugin);
      if (kDebugMode) {
        print('SubtitleDownloadManager: Registered plugin ${plugin.staticMetadata.id}');
      }
    }

    // 如果是第一个插件,自动设为活跃插件
    if (_activePlugin == null && _plugins.isNotEmpty) {
      _activePlugin = _plugins.first;
      _activePluginController.add(_activePlugin);
    }

    _pluginsController.add(List.unmodifiable(_plugins));
  }

  /// 注销字幕下载插件
  ///
  /// [pluginId] 插件ID
  void unregisterPlugin(String pluginId) {
    final initialLength = _plugins.length;
    _plugins.removeWhere((p) => p.staticMetadata.id == pluginId);
    final removed = initialLength - _plugins.length;

    if (removed > 0) {
      if (kDebugMode) {
        print('SubtitleDownloadManager: Unregistered plugin $pluginId');
      }

      // 如果移除的是活跃插件,切换到第一个可用插件
      if (_activePlugin?.staticMetadata.id == pluginId) {
        _activePlugin = _plugins.isNotEmpty ? _plugins.first : null;
        _activePluginController.add(_activePlugin);
      }

      _pluginsController.add(List.unmodifiable(_plugins));
    }
  }

  /// 获取所有可用插件
  List<SubtitleDownloadPlugin> getAvailablePlugins() {
    return List.unmodifiable(_plugins);
  }

  /// 获取活跃插件
  SubtitleDownloadPlugin? getActivePlugin() {
    return _activePlugin;
  }

  /// 设置活跃插件
  ///
  /// [pluginId] 插件ID
  /// 返回是否设置成功
  bool setActivePlugin(String pluginId) {
    final plugin = _plugins.firstWhere(
      (p) => p.staticMetadata.id == pluginId,
      orElse: () => throw ArgumentError('Plugin not found: $pluginId'),
    );

    if (plugin != _activePlugin) {
      _activePlugin = plugin;
      _activePluginController.add(_activePlugin);

      if (kDebugMode) {
        print('SubtitleDownloadManager: Active plugin set to ${plugin.displayName}');
      }

      return true;
    }

    return false;
  }

  /// 根据插件ID获取插件
  ///
  /// [pluginId] 插件ID
  SubtitleDownloadPlugin? getPluginById(String pluginId) {
    try {
      return _plugins.firstWhere((p) => p.staticMetadata.id == pluginId);
    } catch (e) {
      return null;
    }
  }

  /// 搜索字幕(使用当前活跃插件)
  ///
  /// [query] 搜索关键词
  /// [language] 语言代码
  /// [page] 页码
  /// [limit] 每页结果数量
  Future<List<SubtitleSearchResult>> searchSubtitles({
    required String query,
    String? language,
    int page = 1,
    int limit = 20,
  }) async {
    if (_activePlugin == null) {
      throw StateError('No active subtitle download plugin');
    }

    if (kDebugMode) {
      print('SubtitleDownloadManager.searchSubtitles:');
      print('  Active plugin: ${_activePlugin!.staticMetadata.id}');
      print('  Plugin name: ${_activePlugin!.displayName}');
      print('  Query: $query');
    }

    try {
      return await _activePlugin!.searchSubtitles(
        query: query,
        language: language,
        page: page,
        limit: limit,
      );
    } catch (e) {
      if (kDebugMode) {
        print('SubtitleDownloadManager: Search failed: $e');
        print('  Exception type: ${e.runtimeType}');
      }
      rethrow;
    }
  }

  /// 使用指定插件搜索字幕
  ///
  /// [pluginId] 插件ID
  /// [query] 搜索关键词
  /// [language] 语言代码
  /// [page] 页码
  /// [limit] 每页结果数量
  Future<List<SubtitleSearchResult>> searchSubtitlesWithPlugin({
    required String pluginId,
    required String query,
    String? language,
    int page = 1,
    int limit = 20,
  }) async {
    final plugin = getPluginById(pluginId);
    if (plugin == null) {
      throw ArgumentError('Plugin not found: $pluginId');
    }

    return await plugin.searchSubtitles(
      query: query,
      language: language,
      page: page,
      limit: limit,
    );
  }

  /// 下载字幕(使用当前活跃插件)
  ///
  /// [result] 搜索结果
  /// [targetPath] 目标视频路径
  /// 返回下载的字幕文件路径,失败返回 null
  Future<String?> downloadSubtitle(
    SubtitleSearchResult result,
    String targetPath,
  ) async {
    if (_activePlugin == null) {
      throw StateError('No active subtitle download plugin');
    }

    try {
      return await _activePlugin!.downloadSubtitle(result, targetPath);
    } catch (e) {
      if (kDebugMode) {
        print('SubtitleDownloadManager: Download failed: $e');
      }
      rethrow;
    }
  }

  /// 使用指定插件下载字幕
  ///
  /// [pluginId] 插件ID
  /// [result] 搜索结果
  /// [targetPath] 目标视频路径
  Future<String?> downloadSubtitleWithPlugin({
    required String pluginId,
    required SubtitleSearchResult result,
    required String targetPath,
  }) async {
    final plugin = getPluginById(pluginId);
    if (plugin == null) {
      throw ArgumentError('Plugin not found: $pluginId');
    }

    return await plugin.downloadSubtitle(result, targetPath);
  }

  /// 获取支持的语言列表(使用当前活跃插件)
  List<SubtitleLanguage> getSupportedLanguages() {
    if (_activePlugin == null) {
      return SubtitleLanguage.common;
    }

    return _activePlugin!.getSupportedLanguages();
  }

  /// 获取插件统计信息
  Map<String, dynamic> getStatistics() {
    return {
      'totalPlugins': _plugins.length,
      'activePlugin': _activePlugin?.staticMetadata.id,
      'plugins': _plugins.map((p) => {
        'id': p.staticMetadata.id,
        'name': p.displayName,
        'state': p.state.toString(),
        'requiresNetwork': p.requiresNetwork,
      }).toList(),
    };
  }

  /// 释放资源
  Future<void> dispose() async {
    await _pluginsController.close();
    await _activePluginController.close();
    _plugins.clear();
    _activePlugin = null;

    if (kDebugMode) {
      print('SubtitleDownloadManager: Disposed');
    }
  }
}
