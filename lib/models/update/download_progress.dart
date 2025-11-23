/// 下载状态枚举
enum DownloadStatus {
  /// 等待中
  pending,
  
  /// 下载中
  downloading,
  
  /// 已暂停
  paused,
  
  /// 已完成
  completed,
  
  /// 失败
  failed,
  
  /// 已取消
  cancelled,
}

/// 下载进度模型
/// 
/// 跟踪插件更新包的下载进度
class DownloadProgress {
  /// 插件ID
  final String pluginId;
  
  /// 已下载字节数
  final int downloadedBytes;
  
  /// 总字节数
  final int totalBytes;
  
  /// 下载状态
  final DownloadStatus status;
  
  /// 下载速度 (字节/秒)
  final double speed;
  
  /// 错误信息
  final String? error;
  
  /// 开始时间
  final DateTime? startTime;
  
  /// 完成时间
  final DateTime? completedTime;

  const DownloadProgress({
    required this.pluginId,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.status,
    this.speed = 0.0,
    this.error,
    this.startTime,
    this.completedTime,
  });

  /// 下载百分比 (0-100)
  double get percentage {
    if (totalBytes <= 0) return 0.0;
    final progress = (downloadedBytes / totalBytes) * 100;
    return progress > 100 ? 100.0 : progress;
  }

  /// 是否完成
  bool get isCompleted => status == DownloadStatus.completed;

  /// 是否失败
  bool get isFailed => status == DownloadStatus.failed;

  /// 是否进行中
  bool get isInProgress => status == DownloadStatus.downloading;

  /// 是否可以恢复
  bool get canResume => status == DownloadStatus.paused || status == DownloadStatus.failed;

  /// 剩余字节数
  int get remainingBytes => totalBytes - downloadedBytes;

  /// 预计剩余时间
  Duration? get estimatedTimeRemaining {
    if (speed <= 0 || remainingBytes <= 0) return null;
    final seconds = remainingBytes / speed;
    return Duration(seconds: seconds.ceil());
  }

  /// 格式化的下载速度
  String get formattedSpeed {
    if (speed < 1024) {
      return '${speed.toStringAsFixed(0)} B/s';
    } else if (speed < 1024 * 1024) {
      return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  /// 格式化的剩余时间
  String? get formattedTimeRemaining {
    final remaining = estimatedTimeRemaining;
    if (remaining == null) return null;
    
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'pluginId': pluginId,
      'downloadedBytes': downloadedBytes,
      'totalBytes': totalBytes,
      'status': status.name,
      'speed': speed,
      'error': error,
      'startTime': startTime?.toIso8601String(),
      'completedTime': completedTime?.toIso8601String(),
    };
  }

  factory DownloadProgress.fromJson(Map<String, dynamic> json) {
    return DownloadProgress(
      pluginId: json['pluginId'] as String,
      downloadedBytes: json['downloadedBytes'] as int,
      totalBytes: json['totalBytes'] as int,
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.pending,
      ),
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      error: json['error'] as String?,
      startTime: json['startTime'] != null 
          ? DateTime.parse(json['startTime'] as String)
          : null,
      completedTime: json['completedTime'] != null
          ? DateTime.parse(json['completedTime'] as String)
          : null,
    );
  }

  DownloadProgress copyWith({
    String? pluginId,
    int? downloadedBytes,
    int? totalBytes,
    DownloadStatus? status,
    double? speed,
    String? error,
    DateTime? startTime,
    DateTime? completedTime,
  }) {
    return DownloadProgress(
      pluginId: pluginId ?? this.pluginId,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      status: status ?? this.status,
      speed: speed ?? this.speed,
      error: error ?? this.error,
      startTime: startTime ?? this.startTime,
      completedTime: completedTime ?? this.completedTime,
    );
  }

  @override
  String toString() {
    return 'DownloadProgress(pluginId: $pluginId, ${percentage.toStringAsFixed(1)}%, $formattedSpeed, status: ${status.name})';
  }
}
