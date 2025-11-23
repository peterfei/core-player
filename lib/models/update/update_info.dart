/// 更新信息模型
/// 
/// 包含插件更新的所有相关信息
class UpdateInfo {
  /// 插件ID
  final String pluginId;
  
  /// 当前版本
  final String currentVersion;
  
  /// 最新版本
  final String latestVersion;
  
  /// 下载URL
  final String downloadUrl;
  
  /// 更新包大小(字节)
  final int packageSize;
  
  /// 更新日志
  final String changelog;
  
  /// 发布日期
  final DateTime releaseDate;
  
  /// 是否为安全更新
  final bool isSecurityUpdate;
  
  /// 最低应用版本要求
  final String? minAppVersion;
  
  /// 数字签名
  final String? signature;
  
  /// 是否为强制更新
  final bool isMandatory;
  
  /// 更新优先级 (1-5, 5最高)
  final int priority;

  const UpdateInfo({
    required this.pluginId,
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.packageSize,
    required this.changelog,
    required this.releaseDate,
    this.isSecurityUpdate = false,
    this.minAppVersion,
    this.signature,
    this.isMandatory = false,
    this.priority = 3,
  });

  /// 是否有可用更新
  bool get hasUpdate => latestVersion != currentVersion;

  /// 格式化的文件大小
  String get formattedSize {
    if (packageSize < 1024) {
      return '$packageSize B';
    } else if (packageSize < 1024 * 1024) {
      return '${(packageSize / 1024).toStringAsFixed(1)} KB';
    } else if (packageSize < 1024 * 1024 * 1024) {
      return '${(packageSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(packageSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'pluginId': pluginId,
      'currentVersion': currentVersion,
      'latestVersion': latestVersion,
      'downloadUrl': downloadUrl,
      'packageSize': packageSize,
      'changelog': changelog,
      'releaseDate': releaseDate.toIso8601String(),
      'isSecurityUpdate': isSecurityUpdate,
      'minAppVersion': minAppVersion,
      'signature': signature,
      'isMandatory': isMandatory,
      'priority': priority,
    };
  }

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      pluginId: json['pluginId'] as String,
      currentVersion: json['currentVersion'] as String,
      latestVersion: json['latestVersion'] as String,
      downloadUrl: json['downloadUrl'] as String,
      packageSize: json['packageSize'] as int,
      changelog: json['changelog'] as String,
      releaseDate: DateTime.parse(json['releaseDate'] as String),
      isSecurityUpdate: json['isSecurityUpdate'] as bool? ?? false,
      minAppVersion: json['minAppVersion'] as String?,
      signature: json['signature'] as String?,
      isMandatory: json['isMandatory'] as bool? ?? false,
      priority: json['priority'] as int? ?? 3,
    );
  }

  UpdateInfo copyWith({
    String? pluginId,
    String? currentVersion,
    String? latestVersion,
    String? downloadUrl,
    int? packageSize,
    String? changelog,
    DateTime? releaseDate,
    bool? isSecurityUpdate,
    String? minAppVersion,
    String? signature,
    bool? isMandatory,
    int? priority,
  }) {
    return UpdateInfo(
      pluginId: pluginId ?? this.pluginId,
      currentVersion: currentVersion ?? this.currentVersion,
      latestVersion: latestVersion ?? this.latestVersion,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      packageSize: packageSize ?? this.packageSize,
      changelog: changelog ?? this.changelog,
      releaseDate: releaseDate ?? this.releaseDate,
      isSecurityUpdate: isSecurityUpdate ?? this.isSecurityUpdate,
      minAppVersion: minAppVersion ?? this.minAppVersion,
      signature: signature ?? this.signature,
      isMandatory: isMandatory ?? this.isMandatory,
      priority: priority ?? this.priority,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UpdateInfo &&
        other.pluginId == pluginId &&
        other.latestVersion == latestVersion;
  }

  @override
  int get hashCode => Object.hash(pluginId, latestVersion);

  @override
  String toString() {
    return 'UpdateInfo(pluginId: $pluginId, $currentVersion → $latestVersion, size: $formattedSize)';
  }
}
