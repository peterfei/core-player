import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';

class PlaybackHistory {
  final String id;
  final String videoPath;
  final String videoName;
  final DateTime lastPlayedAt;
  final int currentPosition; // 当前播放进度，单位：秒
  final int totalDuration;   // 视频总时长，单位：秒
  final String? thumbnailPath; // 缩略图路径
  final int watchCount;       // 观看次数
  final DateTime createdAt;   // 创建时间
  final int? fileSize;        // 文件大小（字节）

  // 网络视频相关字段
  final String sourceType;    // "local" | "network"
  final String? streamUrl;    // 网络视频URL
  final String? streamProtocol; // 流协议类型 (http/hls/dash)
  final bool isLiveStream;    // 是否直播流

  // macOS沙盒缩略图相关字段
  final String? thumbnailCachePath; // 缓存的缩略图路径（应用沙盒内）
  final String? securityBookmark;   // macOS安全书签数据（Base64编码）
  final DateTime? thumbnailGeneratedAt; // 缩略图生成时间

  const PlaybackHistory({
    required this.id,
    required this.videoPath,
    required this.videoName,
    required this.lastPlayedAt,
    required this.currentPosition,
    required this.totalDuration,
    this.thumbnailPath, // 保持向后兼容
    this.watchCount = 1,
    required this.createdAt,
    this.fileSize,
    this.sourceType = 'local',
    this.streamUrl,
    this.streamProtocol,
    this.isLiveStream = false,
    this.thumbnailCachePath,
    this.securityBookmark,
    this.thumbnailGeneratedAt,
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
      thumbnailPath: json['thumbnailPath'] as String?, // 保持向后兼容
      watchCount: json['watchCount'] as int? ?? 1,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.parse(json['lastPlayedAt'] as String), // 向后兼容
      fileSize: json['fileSize'] as int?,
      sourceType: json['sourceType'] as String? ?? 'local',
      streamUrl: json['streamUrl'] as String?,
      streamProtocol: json['streamProtocol'] as String?,
      isLiveStream: json['isLiveStream'] as bool? ?? false,
      thumbnailCachePath: json['thumbnailCachePath'] as String?,
      securityBookmark: json['securityBookmark'] as String?,
      thumbnailGeneratedAt: json['thumbnailGeneratedAt'] != null
          ? DateTime.parse(json['thumbnailGeneratedAt'] as String)
          : null,
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
      'thumbnailPath': thumbnailPath, // 保持向后兼容
      'watchCount': watchCount,
      'createdAt': createdAt.toIso8601String(),
      'fileSize': fileSize,
      'sourceType': sourceType,
      'streamUrl': streamUrl,
      'streamProtocol': streamProtocol,
      'isLiveStream': isLiveStream,
      'thumbnailCachePath': thumbnailCachePath,
      'securityBookmark': securityBookmark,
      'thumbnailGeneratedAt': thumbnailGeneratedAt?.toIso8601String(),
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
    String? thumbnailPath,
    int? watchCount,
    DateTime? createdAt,
    int? fileSize,
    String? sourceType,
    String? streamUrl,
    String? streamProtocol,
    bool? isLiveStream,
    String? thumbnailCachePath,
    String? securityBookmark,
    DateTime? thumbnailGeneratedAt,
  }) {
    return PlaybackHistory(
      id: id ?? this.id,
      videoPath: videoPath ?? this.videoPath,
      videoName: videoName ?? this.videoName,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      watchCount: watchCount ?? this.watchCount,
      createdAt: createdAt ?? this.createdAt,
      fileSize: fileSize ?? this.fileSize,
      sourceType: sourceType ?? this.sourceType,
      streamUrl: streamUrl ?? this.streamUrl,
      streamProtocol: streamProtocol ?? this.streamProtocol,
      isLiveStream: isLiveStream ?? this.isLiveStream,
      thumbnailCachePath: thumbnailCachePath ?? this.thumbnailCachePath,
      securityBookmark: securityBookmark ?? this.securityBookmark,
      thumbnailGeneratedAt: thumbnailGeneratedAt ?? this.thumbnailGeneratedAt,
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

  /// 获取文件大小格式化字符串
  String get formattedFileSize {
    if (fileSize == null) return '未知大小';
    return _formatFileSize(fileSize!);
  }

  /// 格式化文件大小
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 获取观看次数格式化字符串
  String get formattedWatchCount {
    return '观看 $watchCount 次';
  }

  /// 判断是否为最近观看（7天内）
  bool get isRecentlyWatched {
    final now = DateTime.now();
    final difference = now.difference(lastPlayedAt);
    return difference.inDays <= 7;
  }

  /// 判断是否为今天观看
  bool get isWatchedToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final watchDay = DateTime(lastPlayedAt.year, lastPlayedAt.month, lastPlayedAt.day);
    return watchDay.isAtSameMomentAs(today);
  }

  /// 获取视频文件扩展名
  String get fileExtension {
    final lastDotIndex = videoPath.lastIndexOf('.');
    if (lastDotIndex == -1) return '';
    return videoPath.substring(lastDotIndex + 1).toLowerCase();
  }

  /// 判断是否为常见视频格式
  bool get isCommonVideoFormat {
    final commonFormats = ['mp4', 'avi', 'mov', 'mkv', 'wmv', 'flv', 'webm', 'm4v'];
    return commonFormats.contains(fileExtension);
  }

  /// 判断是否为网络视频
  bool get isNetworkVideo => sourceType == 'network';

  /// 判断是否为本地视频
  bool get isLocalVideo => sourceType == 'local';

  /// 获取媒体源类型显示文本
  String get sourceTypeDisplay {
    switch (sourceType) {
      case 'network':
        return isLiveStream ? '直播' : '网络';
      case 'local':
      default:
        return '本地';
    }
  }

  /// 获取协议类型显示文本
  String get protocolTypeDisplay {
    switch (streamProtocol) {
      case 'hls':
        return 'HLS';
      case 'dash':
        return 'DASH';
      case 'http':
        return 'HTTP';
      default:
        return isNetworkVideo ? '网络' : '本地';
    }
  }

  /// 是否有缓存的缩略图
  bool get hasCachedThumbnail {
    // 优先使用新的缓存路径
    if (thumbnailCachePath != null && File(thumbnailCachePath!).existsSync()) {
      return true;
    }

    // 向后兼容：检查旧的缩略图路径
    if (thumbnailPath != null && File(thumbnailPath!).existsSync()) {
      return true;
    }

    return false;
  }

  /// 获取有效的缩略图路径
  String? get effectiveThumbnailPath {
    // 优先使用新的缓存路径
    if (thumbnailCachePath != null && File(thumbnailCachePath!).existsSync()) {
      return thumbnailCachePath;
    }

    // 向后兼容：使用旧的缩略图路径
    if (thumbnailPath != null && File(thumbnailPath!).existsSync()) {
      return thumbnailPath;
    }

    return null;
  }

  /// 检查是否有安全书签（仅macOS相关）
  bool get hasSecurityBookmark {
    return Platform.isMacOS && securityBookmark != null && securityBookmark!.isNotEmpty;
  }

  /// 是否需要更新书签（用于macOS）
  bool get needsBookmarkUpdate {
    if (!Platform.isMacOS || !isLocalVideo) return false;
    return securityBookmark == null || securityBookmark!.isEmpty;
  }

  /// 检查缩略图是否过期（超过30天）
  bool get isThumbnailStale {
    if (thumbnailGeneratedAt == null) return true;
    final age = DateTime.now().difference(thumbnailGeneratedAt!);
    return age.inDays > 30;
  }

  /// 检查视频文件是否存在（对于本地视频）
  Future<bool> get videoFileExists async {
    if (isNetworkVideo) return true; // 网络视频总是存在

    try {
      return await File(videoPath).exists();
    } catch (e) {
      return false;
    }
  }

  /// 获取视频文件实际大小（可能更新缓存值）
  Future<int?> get actualFileSize async {
    if (fileSize != null) return fileSize;

    try {
      if (await File(videoPath).exists()) {
        return await File(videoPath).length();
      }
    } catch (e) {
      // 忽略错误
    }
    return null;
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