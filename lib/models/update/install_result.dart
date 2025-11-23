/// 安装结果枚举
enum InstallResultStatus {
  /// 成功
  success,
  
  /// 失败
  failed,
  
  /// 已回滚
  rolledBack,
}

/// 安装结果模型
/// 
/// 记录插件安装的结果和相关信息
class InstallResult {
  /// 插件ID
  final String pluginId;
  
  /// 安装状态
  final InstallResultStatus status;
  
  /// 安装的版本
  final String version;
  
  /// 安装时间
  final DateTime timestamp;
  
  /// 错误信息
  final String? error;
  
  /// 错误堆栈
  final String? stackTrace;
  
  /// 是否创建了备份
  final bool backupCreated;
  
  /// 备份ID
  final String? backupId;
  
  /// 安装耗时
  final Duration? installDuration;

  const InstallResult({
    required this.pluginId,
    required this.status,
    required this.version,
    required this.timestamp,
    this.error,
    this.stackTrace,
    this.backupCreated = false,
    this.backupId,
    this.installDuration,
  });

  /// 是否成功
  bool get isSuccess => status == InstallResultStatus.success;

  /// 是否失败
  bool get isFailed => status == InstallResultStatus.failed;

  /// 是否已回滚
  bool get isRolledBack => status == InstallResultStatus.rolledBack;

  Map<String, dynamic> toJson() {
    return {
      'pluginId': pluginId,
      'status': status.name,
      'version': version,
      'timestamp': timestamp.toIso8601String(),
      'error': error,
      'stackTrace': stackTrace,
      'backupCreated': backupCreated,
      'backupId': backupId,
      'installDuration': installDuration?.inMilliseconds,
    };
  }

  factory InstallResult.fromJson(Map<String, dynamic> json) {
    return InstallResult(
      pluginId: json['pluginId'] as String,
      status: InstallResultStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => InstallResultStatus.failed,
      ),
      version: json['version'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      error: json['error'] as String?,
      stackTrace: json['stackTrace'] as String?,
      backupCreated: json['backupCreated'] as bool? ?? false,
      backupId: json['backupId'] as String?,
      installDuration: json['installDuration'] != null
          ? Duration(milliseconds: json['installDuration'] as int)
          : null,
    );
  }

  /// 创建成功结果
  factory InstallResult.success({
    required String pluginId,
    required String version,
    bool backupCreated = false,
    String? backupId,
    Duration? installDuration,
  }) {
    return InstallResult(
      pluginId: pluginId,
      status: InstallResultStatus.success,
      version: version,
      timestamp: DateTime.now(),
      backupCreated: backupCreated,
      backupId: backupId,
      installDuration: installDuration,
    );
  }

  /// 创建失败结果
  factory InstallResult.failed({
    required String pluginId,
    required String version,
    required String error,
    String? stackTrace,
    bool backupCreated = false,
    String? backupId,
  }) {
    return InstallResult(
      pluginId: pluginId,
      status: InstallResultStatus.failed,
      version: version,
      timestamp: DateTime.now(),
      error: error,
      stackTrace: stackTrace,
      backupCreated: backupCreated,
      backupId: backupId,
    );
  }

  /// 创建回滚结果
  factory InstallResult.rolledBack({
    required String pluginId,
    required String version,
    required String backupId,
    String? error,
  }) {
    return InstallResult(
      pluginId: pluginId,
      status: InstallResultStatus.rolledBack,
      version: version,
      timestamp: DateTime.now(),
      error: error,
      backupCreated: true,
      backupId: backupId,
    );
  }

  @override
  String toString() {
    return 'InstallResult(pluginId: $pluginId, status: ${status.name}, version: $version)';
  }
}
