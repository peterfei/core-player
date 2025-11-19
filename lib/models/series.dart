/// 剧集（电视剧/连续剧）数据模型
/// 代表一个包含多个视频文件的文件夹
class Series {
  /// 唯一标识，使用文件夹路径的哈希值
  final String id;
  
  /// 剧集名称（通常是文件夹名称）
  final String name;
  
  /// 文件夹路径
  final String folderPath;
  
  /// 集数统计
  final int episodeCount;
  
  /// 添加到媒体库的时间
  final DateTime addedAt;
  
  /// 封面图路径（本地文件路径）
  final String? thumbnailPath;
  
  /// 背景图路径（本地文件路径，通常是 fanart.jpg）
  final String? backdropPath;
  
  /// 简介
  final String? overview;
  
  /// 评分 (0.0 - 10.0)
  final double? rating;
  
  /// 发布年份/日期
  final DateTime? releaseDate;
  
  /// 最后播放时间（可选）
  final DateTime? lastPlayedAt;

  Series({
    required this.id,
    required this.name,
    required this.folderPath,
    required this.episodeCount,
    required this.addedAt,
    this.thumbnailPath,
    this.backdropPath,
    this.overview,
    this.rating,
    this.releaseDate,
    this.lastPlayedAt,
  });

  /// 从文件夹路径创建剧集对象
  factory Series.fromPath(String folderPath, int episodeCount) {
    // 从路径提取文件夹名称
    final parts = folderPath.split('/').where((p) => p.isNotEmpty).toList();
    final name = parts.isNotEmpty ? parts.last : '未命名';
    
    return Series(
      id: folderPath.hashCode.toString(),
      name: name,
      folderPath: folderPath,
      episodeCount: episodeCount,
      addedAt: DateTime.now(),
    );
  }

  /// 复制并更新部分字段
  Series copyWith({
    String? id,
    String? name,
    String? folderPath,
    int? episodeCount,
    DateTime? addedAt,
    String? thumbnailPath,
    String? backdropPath,
    String? overview,
    double? rating,
    DateTime? releaseDate,
    DateTime? lastPlayedAt,
  }) {
    return Series(
      id: id ?? this.id,
      name: name ?? this.name,
      folderPath: folderPath ?? this.folderPath,
      episodeCount: episodeCount ?? this.episodeCount,
      addedAt: addedAt ?? this.addedAt,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      backdropPath: backdropPath ?? this.backdropPath,
      overview: overview ?? this.overview,
      rating: rating ?? this.rating,
      releaseDate: releaseDate ?? this.releaseDate,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    );
  }

  @override
  String toString() => 'Series(name: $name, episodes: $episodeCount)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Series && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
