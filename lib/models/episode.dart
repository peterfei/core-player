/// 集数（单个视频文件）数据模型
/// 代表剧集中的一个视频文件
class Episode {
  /// 唯一标识，使用视频文件路径的哈希值
  final String id;
  
  /// 所属剧集ID
  final String seriesId;
  
  /// 集数名称（视频文件名）
  final String name;
  
  /// 视频文件路径
  final String path;
  
  /// 文件大小（字节）
  final int size;
  
  /// 视频时长（秒，可选）
  final int? duration;
  
  /// 集数编号（从文件名解析，可选）
  final int? episodeNumber;
  
  /// 添加时间
  final DateTime addedAt;
  
  /// 上次播放位置（秒，可选）
  final int? playbackPosition;
  
  /// 缩略图路径（可选，通常是视频截图或 still.jpg）
  final String? thumbnailPath;
  
  /// 简介
  final String? overview;
  
  /// 评分
  final double? rating;
  
  /// 首播日期
  final DateTime? airDate;
  
  /// TMDB ID (可选)
  final int? tmdbId;
  
  /// TMDB 集数封面路径（still image，可选）
  final String? stillPath;

  /// 媒体源 ID (可选，用于识别 SMB 等外部源)
  final String? sourceId;

  Episode({
    required this.id,
    required this.seriesId,
    required this.name,
    required this.path,
    required this.size,
    this.duration,
    this.episodeNumber,
    required this.addedAt,
    this.playbackPosition,
    this.thumbnailPath,
    this.overview,
    this.rating,
    this.airDate,
    this.tmdbId,
    this.stillPath,
    this.sourceId,
  });

  /// 计算播放进度（0.0 - 1.0）
  double get progress {
    if (duration == null || duration == 0 || playbackPosition == null) {
      return 0.0;
    }
    return (playbackPosition! / duration!).clamp(0.0, 1.0);
  }

  /// 是否已观看完成
  bool get isCompleted {
    if (duration == null || playbackPosition == null) return false;
    return playbackPosition! >= (duration! * 0.9); // 播放到90%即视为完成
  }

  /// 复制并更新部分字段
  Episode copyWith({
    String? id,
    String? seriesId,
    String? name,
    String? path,
    int? size,
    int? duration,
    int? episodeNumber,
    DateTime? addedAt,
    int? playbackPosition,
    String? thumbnailPath,
    String? overview,
    double? rating,
    DateTime? airDate,
    int? tmdbId,
    String? stillPath,
    String? sourceId,
  }) {
    return Episode(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      name: name ?? this.name,
      path: path ?? this.path,
      size: size ?? this.size,
      duration: duration ?? this.duration,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      addedAt: addedAt ?? this.addedAt,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      overview: overview ?? this.overview,
      rating: rating ?? this.rating,
      airDate: airDate ?? this.airDate,
      tmdbId: tmdbId ?? this.tmdbId,
      stillPath: stillPath ?? this.stillPath,
      sourceId: sourceId ?? this.sourceId,
    );
  }

  @override
  String toString() => 'Episode(name: $name, number: $episodeNumber)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Episode && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
