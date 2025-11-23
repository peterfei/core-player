/// 备份信息模型
/// 
/// 记录插件备份的元数据
class BackupInfo {
  /// 备份ID (唯一标识)
  final String id;
  
  /// 插件ID
  final String pluginId;
  
  /// 插件版本
  final String version;
  
  /// 备份文件路径
  final String backupPath;
  
  /// 备份大小(字节)
  final int backupSize;
  
  /// 创建时间
  final DateTime createdAt;
  
  /// 备份描述
  final String? description;
  
  /// 是否为自动备份
  final bool isAutoBackup;
  
  /// 备份的文件数量
  final int fileCount;

  const BackupInfo({
    required this.id,
    required this.pluginId,
    required this.version,
    required this.backupPath,
    required this.backupSize,
    required this.createdAt,
    this.description,
    this.isAutoBackup = true,
    this.fileCount = 0,
  });

  /// 格式化的备份大小
  String get formattedSize {
    if (backupSize < 1024) {
      return '$backupSize B';
    } else if (backupSize < 1024 * 1024) {
      return '${(backupSize / 1024).toStringAsFixed(1)} KB';
    } else if (backupSize < 1024 * 1024 * 1024) {
      return '${(backupSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(backupSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// 备份年龄
  Duration get age => DateTime.now().difference(createdAt);

  /// 格式化的备份年龄
  String get formattedAge {
    final days = age.inDays;
    final hours = age.inHours % 24;
    final minutes = age.inMinutes % 60;
    
    if (days > 0) {
      return '$days天前';
    } else if (hours > 0) {
      return '$hours小时前';
    } else if (minutes > 0) {
      return '$minutes分钟前';
    } else {
      return '刚刚';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pluginId': pluginId,
      'version': version,
      'backupPath': backupPath,
      'backupSize': backupSize,
      'createdAt': createdAt.toIso8601String(),
      'description': description,
      'isAutoBackup': isAutoBackup,
      'fileCount': fileCount,
    };
  }

  factory BackupInfo.fromJson(Map<String, dynamic> json) {
    return BackupInfo(
      id: json['id'] as String,
      pluginId: json['pluginId'] as String,
      version: json['version'] as String,
      backupPath: json['backupPath'] as String,
      backupSize: json['backupSize'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      description: json['description'] as String?,
      isAutoBackup: json['isAutoBackup'] as bool? ?? true,
      fileCount: json['fileCount'] as int? ?? 0,
    );
  }

  BackupInfo copyWith({
    String? id,
    String? pluginId,
    String? version,
    String? backupPath,
    int? backupSize,
    DateTime? createdAt,
    String? description,
    bool? isAutoBackup,
    int? fileCount,
  }) {
    return BackupInfo(
      id: id ?? this.id,
      pluginId: pluginId ?? this.pluginId,
      version: version ?? this.version,
      backupPath: backupPath ?? this.backupPath,
      backupSize: backupSize ?? this.backupSize,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
      isAutoBackup: isAutoBackup ?? this.isAutoBackup,
      fileCount: fileCount ?? this.fileCount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BackupInfo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'BackupInfo(id: $id, pluginId: $pluginId, version: $version, size: $formattedSize)';
  }
}
