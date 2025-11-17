import 'dart:convert';
import 'package:intl/intl.dart';

class PlaybackHistory {
  final String id;
  final String videoPath;
  final String videoName;
  final DateTime lastPlayedAt;
  final int currentPosition; // 当前播放进度，单位：秒
  final int totalDuration;   // 视频总时长，单位：秒

  const PlaybackHistory({
    required this.id,
    required this.videoPath,
    required this.videoName,
    required this.lastPlayedAt,
    required this.currentPosition,
    required this.totalDuration,
  });

  /// 从JSON创建对象
  factory PlaybackHistory.fromJson(Map<String, dynamic> json) {
    return PlaybackHistory(
      id: json['id'] as String,
      videoPath: json['videoPath'] as String,
      videoName: json['videoName'] as String,
      lastPlayedAt: DateTime.parse(json['lastPlayedAt'] as String),
      currentPosition: json['currentPosition'] as int,
      totalDuration: json['totalDuration'] as int,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoPath': videoPath,
      'videoName': videoName,
      'lastPlayedAt': lastPlayedAt.toIso8601String(),
      'currentPosition': currentPosition,
      'totalDuration': totalDuration,
    };
  }

  /// 从JSON字符串创建对象
  factory PlaybackHistory.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return PlaybackHistory.fromJson(json);
  }

  /// 转换为JSON字符串
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// 创建副本，用于更新字段
  PlaybackHistory copyWith({
    String? id,
    String? videoPath,
    String? videoName,
    DateTime? lastPlayedAt,
    int? currentPosition,
    int? totalDuration,
  }) {
    return PlaybackHistory(
      id: id ?? this.id,
      videoPath: videoPath ?? this.videoPath,
      videoName: videoName ?? this.videoName,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
    );
  }

  /// 获取播放进度百分比
  double get progressPercentage {
    if (totalDuration <= 0) return 0.0;
    return (currentPosition / totalDuration).clamp(0.0, 1.0);
  }

  /// 是否已看完视频（进度超过95%）
  bool get isCompleted {
    return progressPercentage >= 0.95;
  }

  /// 获取最后播放时间格式化字符串
  String get formattedLastPlayedAt {
    final now = DateTime.now();
    final difference = now.difference(lastPlayedAt);

    if (difference.inDays == 0) {
      // 今天
      return '今天 ${DateFormat('HH:mm').format(lastPlayedAt)}';
    } else if (difference.inDays == 1) {
      // 昨天
      return '昨天 ${DateFormat('HH:mm').format(lastPlayedAt)}';
    } else if (difference.inDays < 7) {
      // 一周内
      return '${difference.inDays}天前';
    } else {
      // 超过一周
      return DateFormat('yyyy-MM-dd').format(lastPlayedAt);
    }
  }

  /// 获取播放时长格式化字符串
  String get formattedCurrentPosition {
    return _formatDuration(currentPosition);
  }

  /// 获取总时长格式化字符串
  String get formattedTotalDuration {
    return _formatDuration(totalDuration);
  }

  /// 格式化时长显示
  String get formattedProgress {
    return '$formattedCurrentPosition / $formattedTotalDuration';
  }

  /// 格式化时长（秒 -> HH:mm:ss）
  static String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlaybackHistory &&
        other.id == id &&
        other.videoPath == videoPath;
  }

  @override
  int get hashCode => id.hashCode ^ videoPath.hashCode;

  @override
  String toString() {
    return 'PlaybackHistory('
        'id: $id, '
        'videoName: $videoName, '
        'lastPlayedAt: $lastPlayedAt, '
        'currentPosition: $currentPosition, '
        'totalDuration: $totalDuration'
        ')';
  }
}