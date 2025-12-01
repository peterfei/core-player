import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/playback_history.dart';
import '../services/thumbnail_service.dart';
import '../services/simple_thumbnail_service.dart';
import '../services/macos_bookmark_service.dart';
import '../services/video_cache_service.dart';

class HistoryService {
  static const String _storageKey = 'playback_history';
  static const int _maxHistoryCount = 50;
  static const int _maxHistoryDays = 30;

  /// 保存播放历史记录
  static Future<void> saveHistory(PlaybackHistory history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final histories = await getHistories();

      // 检查是否已存在相同路径的记录
      final existingIndex =
          histories.indexWhere((h) => h.videoPath == history.videoPath);

      if (existingIndex != -1) {
        // 更新现有记录
        histories[existingIndex] = history.copyWith(
          lastPlayedAt: DateTime.now(),
          currentPosition: history.currentPosition,
          totalDuration: history.totalDuration,
        );
        // 移动到最上方
        final updatedHistory = histories.removeAt(existingIndex);
        histories.insert(0, updatedHistory);
      } else {
        // 添加新记录到最上方
        histories.insert(0, history);
      }

      // 限制历史记录数量
      if (histories.length > _maxHistoryCount) {
        histories.removeRange(_maxHistoryCount, histories.length);
      }

      // 清理过期记录
      _cleanExpiredHistories(histories);

      // 保存到本地存储
      final historiesJson = histories.map((h) => h.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(historiesJson));
    } catch (e) {
      print('保存播放历史失败: $e');
    }
  }

  /// 获取所有播放历史记录
  /// 
  /// [filterInvalid] 是否过滤无法访问的文件，默认为 false
  /// 设置为 false 可以保留暂时无法访问的文件记录（如外部硬盘未挂载）
  static Future<List<PlaybackHistory>> getHistories({
    bool filterInvalid = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historiesString = prefs.getString(_storageKey);

      if (historiesString == null || historiesString.isEmpty) {
        return [];
      }

      final historiesJson = jsonDecode(historiesString) as List;
      final histories = historiesJson
          .cast<Map<String, dynamic>>()
          .map((json) => PlaybackHistory.fromJson(json))
          .toList();

      // 按最后播放时间降序排序（最近播放的在前）
      histories.sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));

      // 只在明确要求时才过滤无法访问的文件
      if (filterInvalid) {
        final validHistories = await _filterValidHistories(histories);
        _cleanExpiredHistories(validHistories);
        return validHistories;
      }

      // 清理过期记录（但保留暂时无法访问的文件）
      _cleanExpiredHistories(histories);

      return histories;
    } catch (e) {
      print('获取播放历史失败: $e');
      return [];
    }
  }

  /// 删除单条历史记录
  static Future<void> deleteHistory(String historyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final histories = await getHistories();
      histories.removeWhere((h) => h.id == historyId);

      final historiesJson = histories.map((h) => h.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(historiesJson));
    } catch (e) {
      print('删除播放历史失败: $e');
    }
  }

  /// 清空所有历史记录
  static Future<void> clearAllHistories({
    bool clearThumbnails = false,
    bool clearVideoCache = false,
    bool clearNetworkCache = true,
  }) async {
    try {
      print('🧹 开始清空播放历史记录...');

      // 获取当前所有历史记录（用于清理相关缓存）
      final histories = await getHistories();
      print('📊 找到 ${histories.length} 条历史记录');

      // 清空历史记录
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      print('✅ 播放历史记录已清空');

      // 清理相关缓存
      await _cleanRelatedCaches(
        histories,
        clearThumbnails: clearThumbnails,
        clearVideoCache: clearVideoCache,
        clearNetworkCache: clearNetworkCache,
      );

      print('✅ 清空播放历史完成');
    } catch (e) {
      print('❌ 清空播放历史失败: $e');
      rethrow;
    }
  }

  /// 清理相关缓存
  static Future<void> _cleanRelatedCaches(
    List<PlaybackHistory> histories, {
    bool clearThumbnails = false,
    bool clearVideoCache = false,
    bool clearNetworkCache = true,
  }) async {
    try {
      if (clearThumbnails) {
        print('🗑️ 清理缩略图缓存...');

        // 清理网络缩略图缓存
        for (final history in histories) {
          if (history.thumbnailCachePath != null) {
            try {
              final file = File(history.thumbnailCachePath!);
              if (await file.exists()) {
                await file.delete();
                print('🗑️ 删除网络缩略图: ${history.thumbnailCachePath}');
              }
            } catch (e) {
              print('⚠️ 删除网络缩略图失败: ${history.thumbnailCachePath}, 错误: $e');
            }
          }
        }

        // 清理本地缩略图缓存（暂时注释掉，因为SimpleThumbnailService没有deleteThumbnail方法）
        // for (final history in histories) {
        //   if (history.sourceType != 'network') {
        //     await SimpleThumbnailService.deleteThumbnail(history.videoPath);
        //   }
        // }

        print('✅ 缩略图缓存清理完成');
      }

      if (clearVideoCache || clearNetworkCache) {
        print('💾 清理视频缓存...');
        final cacheService = VideoCacheService.instance;
        await cacheService.initialize();

        for (final history in histories) {
          // 清理网络视频缓存
          if (clearNetworkCache && history.isNetworkVideo && history.streamUrl != null) {
            try {
              await cacheService.removeCache(history.streamUrl!);
              print('💾 删除网络视频缓存: ${history.streamUrl}');
            } catch (e) {
              print('⚠️ 删除网络视频缓存失败: ${history.streamUrl}, 错误: $e');
            }
          }

          // 清理本地视频缓存
          if (clearVideoCache && !history.isNetworkVideo) {
            try {
              await cacheService.removeCache(history.videoPath);
              print('💾 删除本地视频缓存: ${history.videoPath}');
            } catch (e) {
              print('⚠️ 删除本地视频缓存失败: ${history.videoPath}, 错误: $e');
            }
          }
        }

        print('✅ 视频缓存清理完成');
      }
    } catch (e) {
      print('❌ 清理相关缓存失败: $e');
    }
  }

  /// 获取清理统计信息
  static Future<Map<String, dynamic>> getCleanupStats() async {
    try {
      final histories = await getHistories();
      final networkHistories = histories.where((h) => h.isNetworkVideo).toList();
      final localHistories = histories.where((h) => !h.isNetworkVideo).toList();

      // 获取视频缓存统计
      final cacheService = VideoCacheService.instance;
      await cacheService.initialize();
      final cacheStats = await cacheService.getStats();

      return {
        'histories': {
          'total': histories.length,
          'network': networkHistories.length,
          'local': localHistories.length,
        },
        'videoCache': {
          'totalSize': cacheStats.totalSize,
          'totalEntries': cacheStats.totalEntries,
          'completedEntries': cacheStats.completedEntries,
        },
        'thumbnails': {
          'networkThumbnails': histories.where((h) => h.thumbnailCachePath != null).length,
        },
      };
    } catch (e) {
      print('❌ 获取清理统计信息失败: $e');
      return {
        'error': e.toString(),
      };
    }
  }

  /// 根据视频路径获取历史记录
  static Future<PlaybackHistory?> getHistoryByPath(String videoPath) async {
    try {
      final histories = await getHistories();
      return histories.firstWhere((h) => h.videoPath == videoPath);
    } catch (e) {
      return null;
    }
  }

  /// 检查历史记录是否存在
  static Future<bool> historyExists(String videoPath) async {
    final history = await getHistoryByPath(videoPath);
    return history != null;
  }

  /// 清理过期历史记录
  static void _cleanExpiredHistories(List<PlaybackHistory> histories) {
    final now = DateTime.now();
    histories.removeWhere((history) {
      final daysDifference = now.difference(history.lastPlayedAt).inDays;
      return daysDifference > _maxHistoryDays;
    });
  }

  /// 过滤有效的历史记录（文件存在）
  static Future<List<PlaybackHistory>> _filterValidHistories(
      List<PlaybackHistory> histories) async {
    final validHistories = <PlaybackHistory>[];

    for (final history in histories) {
      if (await _fileExists(history)) {
        validHistories.add(history);
      }
    }

    return validHistories;
  }

  /// 检查文件是否存在
  static Future<bool> _fileExists(PlaybackHistory history) async {
    try {
      // Web 平台特殊处理
      if (kIsWeb) {
        return history.videoPath.startsWith('blob:') ||
            history.videoPath.startsWith('data:') ||
            history.videoPath.startsWith('http');
      }

      // 网络视频总是存在
      if (history.isNetworkVideo) {
        return true;
      }

      // 对于macOS本地视频，尝试使用书签恢复权限
      if (MacOSBookmarkService.isSupported && history.isLocalVideo) {
        // 如果有书签数据，先尝试恢复权限
        if (history.hasSecurityBookmark) {
          print('尝试使用书签恢复访问权限: ${history.videoPath}');
          final restoredPath =
              await MacOSBookmarkService.tryRestoreAccess(history.videoPath);
          if (restoredPath != null) {
            return await MacOSBookmarkService.fileExistsAtPath(
                history.videoPath);
          }
          print('书签恢复失败，降级到常规检查');
        }
      }

      // 降级到常规文件检查
      return await MacOSBookmarkService.fileExistsAtPath(history.videoPath);
    } catch (e) {
      print('检查文件存在性失败: ${history.videoPath} - $e');
      return false;
    }
  }

  /// 检查历史记录对应的文件是否可访问
  /// 
  /// 用于UI层判断是否需要显示"文件不可用"提示
  static Future<bool> isHistoryAccessible(PlaybackHistory history) async {
    return await _fileExists(history);
  }

  /// 生成唯一ID
  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// 创建新的历史记录
  static Future<PlaybackHistory> createHistory({
    required String videoPath,
    required String videoName,
    required int currentPosition,
    required int totalDuration,
    String? thumbnailPath,
    int watchCount = 1,
    DateTime? createdAt,
    int? fileSize,
    String sourceType = 'local',
    String? streamUrl,
    String? streamProtocol,
    bool isLiveStream = false,
    String? securityBookmark,
  }) async {
    final now = DateTime.now();

    // 如果是本地视频，尝试生成缩略图和获取文件大小
    String? finalThumbnailPath = thumbnailPath;
    int? finalFileSize = fileSize;

    if (sourceType == 'local') {
      finalThumbnailPath = thumbnailPath ??
          await SimpleThumbnailService.generateThumbnail(
            videoPath: videoPath,
            width: 320,
            height: 180,
            seekSeconds: 1.0,
            securityBookmark: securityBookmark,
          );
      finalFileSize = fileSize ?? await getFileSize(videoPath);
    } else {
      // 网络视频不需要生成本地缩略图
      finalThumbnailPath = null;
    }

    return PlaybackHistory(
      id: _generateId(),
      videoPath: videoPath,
      videoName: videoName,
      lastPlayedAt: now,
      currentPosition: currentPosition,
      totalDuration: totalDuration,
      thumbnailPath: finalThumbnailPath,
      watchCount: watchCount,
      createdAt: createdAt ?? now,
      fileSize: finalFileSize,
      sourceType: sourceType,
      streamUrl: streamUrl,
      streamProtocol: streamProtocol,
      isLiveStream: isLiveStream,
      securityBookmark: securityBookmark,
    );
  }

  /// 创建新的历史记录（异步版本）
  static Future<PlaybackHistory> createHistoryAsync({
    required String videoPath,
    required String videoName,
    required int currentPosition,
    required int totalDuration,
    String? thumbnailPath,
    int watchCount = 1,
    DateTime? createdAt,
    int? fileSize,
    String? securityBookmark,
  }) async {
    final now = DateTime.now();

    // 如果没有提供缩略图路径，尝试生成
    final finalThumbnailPath = thumbnailPath ??
        await SimpleThumbnailService.generateThumbnail(
          videoPath: videoPath,
          width: 320,
          height: 180,
          seekSeconds: 1.0,
          securityBookmark: securityBookmark,
        );

    // 获取文件大小
    final finalFileSize = fileSize ?? await getFileSize(videoPath);

    return PlaybackHistory(
      id: _generateId(),
      videoPath: videoPath,
      videoName: videoName,
      lastPlayedAt: now,
      currentPosition: currentPosition,
      totalDuration: totalDuration,
      thumbnailPath: finalThumbnailPath,
      watchCount: watchCount,
      createdAt: createdAt ?? now,
      fileSize: finalFileSize,
      securityBookmark: securityBookmark,
    );
  }

  /// 更新历史记录的播放进度
  static Future<void> updateProgress({
    required String videoPath,
    required int currentPosition,
    required int totalDuration,
    String? thumbnailPath,
    int? fileSize,
  }) async {
    final existingHistory = await getHistoryByPath(videoPath);

    if (existingHistory != null) {
      // 如果还没有缩略图，在后台生成
      final finalThumbnailPath = thumbnailPath ??
          existingHistory.thumbnailPath ??
          (await SimpleThumbnailService.generateThumbnail(
            videoPath: videoPath,
            width: 320,
            height: 180,
            seekSeconds: 1.0,
            securityBookmark: existingHistory.securityBookmark,
          ));

      // 更新现有记录，增加观看次数
      final updatedHistory = existingHistory.copyWith(
        lastPlayedAt: DateTime.now(),
        currentPosition: currentPosition,
        totalDuration: totalDuration,
        thumbnailPath: finalThumbnailPath,
        watchCount: existingHistory.watchCount + 1,
        fileSize: fileSize ?? existingHistory.fileSize,
      );
      await saveHistory(updatedHistory);
    }
  }

  /// 后台生成缩略图（不阻塞主流程）
  static Future<void> generateThumbnailInBackground(String videoPath) async {
    try {
      // Web平台跳过后台生成
      if (kIsWeb) {
        return;
      }

      // 延迟3秒后生成缩略图，避免影响视频启动
      await Future.delayed(const Duration(seconds: 3));

      final thumbnailPath = await ThumbnailService.getThumbnail(videoPath);

      // 如果缩略图不存在或为空，尝试重新生成
      if (thumbnailPath == null || !await File(thumbnailPath).exists()) {
        final generatedPath =
            await ThumbnailService.generateThumbnail(videoPath);
        if (generatedPath != null) {
          // 更新历史记录中的缩略图路径
          final existingHistory = await getHistoryByPath(videoPath);
          if (existingHistory != null &&
              existingHistory.thumbnailPath != generatedPath) {
            final updatedHistory = existingHistory.copyWith(
              thumbnailPath: generatedPath,
              lastPlayedAt: DateTime.now(),
            );
            await saveHistory(updatedHistory);
          }
        }
      }
    } catch (e) {
      print('后台生成缩略图失败: $e');
    }
  }

  /// 从文件名提取视频名称
  static String extractVideoName(String path) {
    try {
      final fileName = path.split('/').last;
      if (fileName.contains('.')) {
        return fileName.substring(0, fileName.lastIndexOf('.'));
      }
      return fileName;
    } catch (e) {
      return '未知视频';
    }
  }

  /// 获取历史记录统计信息
  static Future<Map<String, dynamic>> getStatistics() async {
    try {
      final histories = await getHistories();
      final totalWatchTime = histories.fold<int>(
        0,
        (sum, history) => sum + history.currentPosition,
      );

      final totalWatchCount = histories.fold<int>(
        0,
        (sum, history) => sum + history.watchCount,
      );

      return {
        'totalCount': histories.length,
        'totalWatchTime': totalWatchTime,
        'totalWatchCount': totalWatchCount,
        'completedCount': histories.where((h) => h.isCompleted).length,
        'recentCount': histories.where((h) {
          final daysDifference =
              DateTime.now().difference(h.lastPlayedAt).inDays;
          return daysDifference <= 7;
        }).length,
        'todayCount': histories.where((h) => h.isWatchedToday).length,
        'totalFileSize': histories.fold<int>(
          0,
          (sum, history) => sum + (history.fileSize ?? 0),
        ),
      };
    } catch (e) {
      return {
        'totalCount': 0,
        'totalWatchTime': 0,
        'totalWatchCount': 0,
        'completedCount': 0,
        'recentCount': 0,
        'todayCount': 0,
        'totalFileSize': 0,
      };
    }
  }

  /// 搜索历史记录
  static Future<List<PlaybackHistory>> searchHistories(String query) async {
    try {
      final histories = await getHistories();

      if (query.isEmpty) {
        return histories;
      }

      final lowercaseQuery = query.toLowerCase();
      return histories.where((history) {
        return history.videoName.toLowerCase().contains(lowercaseQuery) ||
            history.videoPath.toLowerCase().contains(lowercaseQuery);
      }).toList();
    } catch (e) {
      print('搜索历史记录失败: $e');
      return [];
    }
  }

  /// 按状态过滤历史记录
  static Future<List<PlaybackHistory>> filterByStatus(String status) async {
    try {
      final histories = await getHistories();

      switch (status.toLowerCase()) {
        case 'completed':
          return histories.where((h) => h.isCompleted).toList();
        case 'incomplete':
          return histories.where((h) => !h.isCompleted).toList();
        case 'recent':
          return histories.where((h) => h.isRecentlyWatched).toList();
        case 'today':
          return histories.where((h) => h.isWatchedToday).toList();
        default:
          return histories;
      }
    } catch (e) {
      print('过滤历史记录失败: $e');
      return [];
    }
  }

  /// 按时间范围过滤历史记录
  static Future<List<PlaybackHistory>> filterByDateRange(
      DateTime startDate, DateTime endDate) async {
    try {
      final histories = await getHistories();

      return histories.where((history) {
        return history.lastPlayedAt.isAfter(startDate) &&
            history.lastPlayedAt.isBefore(endDate);
      }).toList();
    } catch (e) {
      print('按日期过滤历史记录失败: $e');
      return [];
    }
  }

  /// 批量删除历史记录
  static Future<void> batchDeleteHistories(List<String> historyIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final histories = await getHistories();

      // 收集需要删除缩略图的路径
      final videosToDeleteThumbnails = <String>[];
      for (final history in histories) {
        if (historyIds.contains(history.id) && history.thumbnailPath != null) {
          videosToDeleteThumbnails.add(history.videoPath);
        }
      }

      histories.removeWhere((history) => historyIds.contains(history.id));

      final historiesJson = histories.map((h) => h.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(historiesJson));

      // 同时删除相关的缩略图
      for (final videoPath in videosToDeleteThumbnails) {
        await ThumbnailService.deleteThumbnail(videoPath);
      }
    } catch (e) {
      print('批量删除历史记录失败: $e');
    }
  }

  /// 获取文件大小
  static Future<int?> getFileSize(String filePath) async {
    try {
      if (kIsWeb) {
        // Web 平台返回空
        return null;
      }

      // 对于macOS，优先使用Bookmark服务获取文件大小
      if (MacOSBookmarkService.isSupported) {
        return await MacOSBookmarkService.fileSizeAtPath(filePath);
      }

      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 创建带书签的历史记录（新增方法）
  static Future<PlaybackHistory> createHistoryWithBookmark({
    required String videoPath,
    required String videoName,
    required int currentPosition,
    required int totalDuration,
    String? thumbnailCachePath,
    String? securityBookmark,
    int watchCount = 1,
    DateTime? createdAt,
    int? fileSize,
    String sourceType = 'local',
    String? streamUrl,
    String? streamProtocol,
    bool isLiveStream = false,
  }) async {
    final now = DateTime.now();

    // 如果是本地视频且支持书签，尝试创建安全书签
    String? finalBookmark = securityBookmark;
    int? finalFileSize = fileSize;

    if (MacOSBookmarkService.isSupported && sourceType == 'local') {
      // 如果没有提供书签，尝试创建
      if (finalBookmark == null || finalBookmark.isEmpty) {
        print('创建安全书签: $videoPath');
        finalBookmark = await MacOSBookmarkService.createBookmark(videoPath);
      }

      // 获取文件大小
      finalFileSize = fileSize ?? await getFileSize(videoPath);
    }

    return PlaybackHistory(
      id: _generateId(),
      videoPath: videoPath,
      videoName: videoName,
      lastPlayedAt: now,
      currentPosition: currentPosition,
      totalDuration: totalDuration,
      thumbnailCachePath: thumbnailCachePath,
      securityBookmark: finalBookmark,
      thumbnailGeneratedAt: thumbnailCachePath != null ? now : null,
      watchCount: watchCount,
      createdAt: createdAt ?? now,
      fileSize: finalFileSize,
      sourceType: sourceType,
      streamUrl: streamUrl,
      streamProtocol: streamProtocol,
      isLiveStream: isLiveStream,
    );
  }

  /// 更新历史记录的缩略图路径
  static Future<void> updateThumbnailPath(
      String historyId, String thumbnailPath) async {
    try {
      final histories = await getHistories();
      final index = histories.indexWhere((h) => h.id == historyId);

      if (index != -1) {
        final history = histories[index];
        final updatedHistory = history.copyWith(
          thumbnailCachePath: thumbnailPath,
          thumbnailGeneratedAt: DateTime.now(),
        );

        histories[index] = updatedHistory;

        final prefs = await SharedPreferences.getInstance();
        final historiesJson = histories.map((h) => h.toJson()).toList();
        await prefs.setString(_storageKey, jsonEncode(historiesJson));

        print('✅ 更新缩略图路径成功: ${history.videoName} -> $thumbnailPath');
      }
    } catch (e) {
      print('❌ 更新缩略图路径失败: $e');
    }
  }

  /// 根据视频路径更新缩略图（支持网络视频和本地视频）
  static Future<void> updateThumbnail(String videoPath, String thumbnailPath) async {
    try {
      final histories = await getHistories();
      final index = histories.indexWhere((h) => h.videoPath == videoPath);

      if (index != -1) {
        final history = histories[index];
        final updatedHistory = history.copyWith(
          thumbnailCachePath: thumbnailPath,
          thumbnailGeneratedAt: DateTime.now(),
        );

        histories[index] = updatedHistory;

        final prefs = await SharedPreferences.getInstance();
        final historiesJson = histories.map((h) => h.toJson()).toList();
        await prefs.setString(_storageKey, jsonEncode(historiesJson));

        print('✅ 根据视频路径更新缩略图成功: ${history.videoName} -> $thumbnailPath');
      } else {
        print('⚠️ 未找到匹配的历史记录: $videoPath');
      }
    } catch (e) {
      print('❌ 根据视频路径更新缩略图失败: $e');
    }
  }

  /// 更新历史记录的书签数据
  static Future<void> updateBookmark(
      String historyId, String bookmarkData) async {
    try {
      final histories = await getHistories();
      final index = histories.indexWhere((h) => h.id == historyId);

      if (index != -1) {
        final history = histories[index];
        final updatedHistory = history.copyWith(
          securityBookmark: bookmarkData,
        );

        histories[index] = updatedHistory;

        final prefs = await SharedPreferences.getInstance();
        final historiesJson = histories.map((h) => h.toJson()).toList();
        await prefs.setString(_storageKey, jsonEncode(historiesJson));

        print('✅ 更新书签数据成功: ${history.videoName}');
      }
    } catch (e) {
      print('❌ 更新书签数据失败: $e');
    }
  }

  /// 恢复文件访问权限
  static Future<String?> restoreFileAccess(PlaybackHistory history) async {
    if (!history.isLocalVideo || !MacOSBookmarkService.isSupported) {
      return history.videoPath;
    }

    if (history.hasSecurityBookmark) {
      return await MacOSBookmarkService.tryRestoreAccess(history.videoPath);
    }

    return history.videoPath;
  }

  /// 添加或更新历史记录（增强版，支持书签和缩略图）
  static Future<void> addOrUpdateHistory({
    required String videoPath,
    required String videoName,
    required int currentPosition,
    required int totalDuration,
    String? securityBookmark,
    String? thumbnailCachePath,
    int? watchCount,
    String? sourceType,
    String? streamUrl,
    String? streamProtocol,
    bool? isLiveStream,
  }) async {
    try {
      final histories = await getHistories();
      final now = DateTime.now();

      // 检查是否已存在相同路径的记录
      final existingIndex =
          histories.indexWhere((h) => h.videoPath == videoPath);

      PlaybackHistory history;
      if (existingIndex != -1) {
        // 更新现有记录
        final existingHistory = histories[existingIndex];
        history = existingHistory.copyWith(
          lastPlayedAt: now,
          currentPosition: currentPosition,
          totalDuration: totalDuration,
          watchCount: watchCount ?? existingHistory.watchCount + 1,
          securityBookmark:
              securityBookmark ?? existingHistory.securityBookmark,
          thumbnailCachePath:
              thumbnailCachePath ?? existingHistory.thumbnailCachePath,
          thumbnailGeneratedAt: thumbnailCachePath != null
              ? now
              : existingHistory.thumbnailGeneratedAt,
        );

        // 移动到最上方
        histories.removeAt(existingIndex);
        histories.insert(0, history);
      } else {
        // 创建新记录
        history = await createHistoryWithBookmark(
          videoPath: videoPath,
          videoName: videoName,
          currentPosition: currentPosition,
          totalDuration: totalDuration,
          securityBookmark: securityBookmark,
          thumbnailCachePath: thumbnailCachePath,
          watchCount: watchCount ?? 1,
          sourceType: sourceType ?? 'local',
          streamUrl: streamUrl,
          streamProtocol: streamProtocol,
          isLiveStream: isLiveStream ?? false,
        );

        histories.insert(0, history);
      }

      // 限制历史记录数量
      if (histories.length > _maxHistoryCount) {
        histories.removeRange(_maxHistoryCount, histories.length);
      }

      // 清理过期记录
      _cleanExpiredHistories(histories);

      // 保存到本地存储
      final prefs = await SharedPreferences.getInstance();
      final historiesJson = histories.map((h) => h.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(historiesJson));

      print('✅ 保存播放历史成功: $videoName');
    } catch (e) {
      print('❌ 保存播放历史失败: $e');
    }
  }

  /// 清理无效的缩略图缓存
  static Future<void> cleanupInvalidThumbnails() async {
    try {
      final histories = await getHistories();
      int cleanedCount = 0;

      for (final history in histories) {
        // 检查缓存缩略图是否存在
        if (history.thumbnailCachePath != null) {
          final thumbnailFile = File(history.thumbnailCachePath!);
          if (!await thumbnailFile.exists()) {
            // 缩略图文件不存在，更新历史记录
            await updateThumbnailPath(history.id, '');
            cleanedCount++;
          }
        }
      }

      if (cleanedCount > 0) {
        print('✅ 清理了 $cleanedCount 个无效的缩略图引用');
      }
    } catch (e) {
      print('❌ 清理无效缩略图失败: $e');
    }
  }
}
