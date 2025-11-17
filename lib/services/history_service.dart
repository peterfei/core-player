import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playback_history.dart';

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
      final existingIndex = histories.indexWhere((h) => h.videoPath == history.videoPath);

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
  static Future<List<PlaybackHistory>> getHistories() async {
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

      // 清理不存在的文件
      final validHistories = await _filterValidHistories(histories);

      // 清理过期记录
      _cleanExpiredHistories(validHistories);

      return validHistories;
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
  static Future<void> clearAllHistories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      print('清空播放历史失败: $e');
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
  static Future<List<PlaybackHistory>> _filterValidHistories(List<PlaybackHistory> histories) async {
    final validHistories = <PlaybackHistory>[];

    for (final history in histories) {
      if (await _fileExists(history.videoPath)) {
        validHistories.add(history);
      }
    }

    return validHistories;
  }

  /// 检查文件是否存在
  static Future<bool> _fileExists(String path) async {
    try {
      // Web 平台特殊处理
      if (path.startsWith('blob:') || path.startsWith('data:')) {
        return true;
      }

      final file = File(path);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// 生成唯一ID
  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// 创建新的历史记录
  static PlaybackHistory createHistory({
    required String videoPath,
    required String videoName,
    required int currentPosition,
    required int totalDuration,
  }) {
    return PlaybackHistory(
      id: _generateId(),
      videoPath: videoPath,
      videoName: videoName,
      lastPlayedAt: DateTime.now(),
      currentPosition: currentPosition,
      totalDuration: totalDuration,
    );
  }

  /// 更新历史记录的播放进度
  static Future<void> updateProgress({
    required String videoPath,
    required int currentPosition,
    required int totalDuration,
  }) async {
    final existingHistory = await getHistoryByPath(videoPath);

    if (existingHistory != null) {
      // 更新现有记录
      final updatedHistory = existingHistory.copyWith(
        lastPlayedAt: DateTime.now(),
        currentPosition: currentPosition,
        totalDuration: totalDuration,
      );
      await saveHistory(updatedHistory);
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

      return {
        'totalCount': histories.length,
        'totalWatchTime': totalWatchTime,
        'completedCount': histories.where((h) => h.isCompleted).length,
        'recentCount': histories.where((h) {
          final daysDifference = DateTime.now().difference(h.lastPlayedAt).inDays;
          return daysDifference <= 7;
        }).length,
      };
    } catch (e) {
      return {
        'totalCount': 0,
        'totalWatchTime': 0,
        'completedCount': 0,
        'recentCount': 0,
      };
    }
  }
}