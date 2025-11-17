/// 网络流媒体信息模型
class StreamInfo {
  final String url; // 视频URL
  final String? title; // 视频标题
  final int? duration; // 视频时长（秒）
  final int? fileSize; // 文件大小（字节）
  final String? mimeType; // MIME类型
  final String protocol; // 协议类型 (http/hls/dash)
  final DateTime addedAt; // 添加时间
  final bool isLiveStream; // 是否为直播流

  StreamInfo({
    required this.url,
    this.title,
    this.duration,
    this.fileSize,
    this.mimeType,
    required this.protocol,
    required this.addedAt,
    this.isLiveStream = false,
  });

  /// 从URL创建StreamInfo
  factory StreamInfo.fromUrl(String url) {
    final protocol = _detectProtocol(url);
    return StreamInfo(
      url: url,
      protocol: protocol,
      addedAt: DateTime.now(),
      title: _extractTitleFromUrl(url),
    );
  }

  /// 检测协议类型
  static String _detectProtocol(String url) {
    if (url.toLowerCase().contains('.m3u8')) {
      return 'hls';
    } else if (url.toLowerCase().contains('.mpd')) {
      return 'dash';
    } else if (url.toLowerCase().startsWith('http://') ||
               url.toLowerCase().startsWith('https://')) {
      return 'http';
    } else {
      return 'unknown';
    }
  }

  /// 从URL提取标题
  static String? _extractTitleFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final pathSegments = uri.pathSegments;
    if (pathSegments.isEmpty) return null;

    final fileName = pathSegments.last;
    if (fileName.isEmpty) return uri.host;

    // 移除文件扩展名
    final lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex > 0) {
      return fileName.substring(0, lastDotIndex);
    }

    return fileName;
  }

  /// 是否为有效的URL
  bool get isValid => _isValidUrl(url);

  static bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) ||
             uri.path.endsWith('.m3u8') ||
             uri.path.endsWith('.mpd');
    } catch (e) {
      return false;
    }
  }

  /// 格式化文件大小
  String get formattedFileSize {
    if (fileSize == null) return '未知';

    const bytes = ['B', 'KB', 'MB', 'GB'];
    double size = fileSize!.toDouble();
    int unitIndex = 0;

    while (size >= 1024 && unitIndex < bytes.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${bytes[unitIndex]}';
  }

  /// 格式化时长
  String get formattedDuration {
    if (duration == null) return '未知';

    final hours = duration! ~/ 3600;
    final minutes = (duration! % 3600) ~/ 60;
    final seconds = duration! % 60;

    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'title': title,
      'duration': duration,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'protocol': protocol,
      'addedAt': addedAt.toIso8601String(),
      'isLiveStream': isLiveStream,
    };
  }

  /// 从JSON创建
  factory StreamInfo.fromJson(Map<String, dynamic> json) {
    return StreamInfo(
      url: json['url'],
      title: json['title'],
      duration: json['duration'],
      fileSize: json['fileSize'],
      mimeType: json['mimeType'],
      protocol: json['protocol'] ?? 'http',
      addedAt: DateTime.parse(json['addedAt']),
      isLiveStream: json['isLiveStream'] ?? false,
    );
  }

  /// 复制并更新
  StreamInfo copyWith({
    String? url,
    String? title,
    int? duration,
    int? fileSize,
    String? mimeType,
    String? protocol,
    DateTime? addedAt,
    bool? isLiveStream,
  }) {
    return StreamInfo(
      url: url ?? this.url,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      protocol: protocol ?? this.protocol,
      addedAt: addedAt ?? this.addedAt,
      isLiveStream: isLiveStream ?? this.isLiveStream,
    );
  }

  @override
  String toString() {
    return 'StreamInfo(url: $url, title: $title, protocol: $protocol, duration: $duration)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StreamInfo && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;
}