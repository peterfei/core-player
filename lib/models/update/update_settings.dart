/// 检查频率枚举
enum CheckFrequency {
  /// 每天
  daily,
  
  /// 每周
  weekly,
  
  /// 每月
  monthly,
  
  /// 手动
  manual,
}

/// 安装时机枚举
enum InstallTiming {
  /// 立即安装
  immediate,
  
  /// 用户空闲时
  onIdle,
  
  /// 下次启动时
  onNextLaunch,
  
  /// 手动安装
  manual,
}

/// 更新设置模型
/// 
/// 配置插件自动更新的行为
class UpdateSettings {
  /// 是否启用自动检查更新
  final bool autoCheckEnabled;
  
  /// 检查频率
  final CheckFrequency checkFrequency;
  
  /// 是否自动下载更新
  final bool autoDownloadEnabled;
  
  /// 是否仅在WiFi下下载
  final bool wifiOnlyDownload;
  
  /// 是否自动安装更新
  final bool autoInstallEnabled;
  
  /// 安装时机
  final InstallTiming installTiming;
  
  /// 是否显示更新通知
  final bool showNotifications;
  
  /// 是否自动安装安全更新
  final bool autoInstallSecurityUpdates;
  
  /// 最大并发下载数
  final int maxConcurrentDownloads;
  
  /// 是否在低电量时暂停
  final bool pauseOnLowBattery;
  
  /// 低电量阈值 (百分比)
  final int lowBatteryThreshold;

  const UpdateSettings({
    this.autoCheckEnabled = true,
    this.checkFrequency = CheckFrequency.daily,
    this.autoDownloadEnabled = false,
    this.wifiOnlyDownload = true,
    this.autoInstallEnabled = false,
    this.installTiming = InstallTiming.manual,
    this.showNotifications = true,
    this.autoInstallSecurityUpdates = false,
    this.maxConcurrentDownloads = 3,
    this.pauseOnLowBattery = true,
    this.lowBatteryThreshold = 20,
  });

  /// 默认设置
  factory UpdateSettings.defaults() {
    return const UpdateSettings();
  }

  /// 激进设置 (自动更新所有)
  factory UpdateSettings.aggressive() {
    return const UpdateSettings(
      autoCheckEnabled: true,
      checkFrequency: CheckFrequency.daily,
      autoDownloadEnabled: true,
      wifiOnlyDownload: false,
      autoInstallEnabled: true,
      installTiming: InstallTiming.onIdle,
      showNotifications: true,
      autoInstallSecurityUpdates: true,
      maxConcurrentDownloads: 5,
      pauseOnLowBattery: false,
    );
  }

  /// 保守设置 (全部手动)
  factory UpdateSettings.conservative() {
    return const UpdateSettings(
      autoCheckEnabled: false,
      checkFrequency: CheckFrequency.manual,
      autoDownloadEnabled: false,
      wifiOnlyDownload: true,
      autoInstallEnabled: false,
      installTiming: InstallTiming.manual,
      showNotifications: false,
      autoInstallSecurityUpdates: false,
      maxConcurrentDownloads: 1,
      pauseOnLowBattery: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'autoCheckEnabled': autoCheckEnabled,
      'checkFrequency': checkFrequency.name,
      'autoDownloadEnabled': autoDownloadEnabled,
      'wifiOnlyDownload': wifiOnlyDownload,
      'autoInstallEnabled': autoInstallEnabled,
      'installTiming': installTiming.name,
      'showNotifications': showNotifications,
      'autoInstallSecurityUpdates': autoInstallSecurityUpdates,
      'maxConcurrentDownloads': maxConcurrentDownloads,
      'pauseOnLowBattery': pauseOnLowBattery,
      'lowBatteryThreshold': lowBatteryThreshold,
    };
  }

  factory UpdateSettings.fromJson(Map<String, dynamic> json) {
    return UpdateSettings(
      autoCheckEnabled: json['autoCheckEnabled'] as bool? ?? true,
      checkFrequency: CheckFrequency.values.firstWhere(
        (e) => e.name == json['checkFrequency'],
        orElse: () => CheckFrequency.daily,
      ),
      autoDownloadEnabled: json['autoDownloadEnabled'] as bool? ?? false,
      wifiOnlyDownload: json['wifiOnlyDownload'] as bool? ?? true,
      autoInstallEnabled: json['autoInstallEnabled'] as bool? ?? false,
      installTiming: InstallTiming.values.firstWhere(
        (e) => e.name == json['installTiming'],
        orElse: () => InstallTiming.manual,
      ),
      showNotifications: json['showNotifications'] as bool? ?? true,
      autoInstallSecurityUpdates: json['autoInstallSecurityUpdates'] as bool? ?? false,
      maxConcurrentDownloads: json['maxConcurrentDownloads'] as int? ?? 3,
      pauseOnLowBattery: json['pauseOnLowBattery'] as bool? ?? true,
      lowBatteryThreshold: json['lowBatteryThreshold'] as int? ?? 20,
    );
  }

  UpdateSettings copyWith({
    bool? autoCheckEnabled,
    CheckFrequency? checkFrequency,
    bool? autoDownloadEnabled,
    bool? wifiOnlyDownload,
    bool? autoInstallEnabled,
    InstallTiming? installTiming,
    bool? showNotifications,
    bool? autoInstallSecurityUpdates,
    int? maxConcurrentDownloads,
    bool? pauseOnLowBattery,
    int? lowBatteryThreshold,
  }) {
    return UpdateSettings(
      autoCheckEnabled: autoCheckEnabled ?? this.autoCheckEnabled,
      checkFrequency: checkFrequency ?? this.checkFrequency,
      autoDownloadEnabled: autoDownloadEnabled ?? this.autoDownloadEnabled,
      wifiOnlyDownload: wifiOnlyDownload ?? this.wifiOnlyDownload,
      autoInstallEnabled: autoInstallEnabled ?? this.autoInstallEnabled,
      installTiming: installTiming ?? this.installTiming,
      showNotifications: showNotifications ?? this.showNotifications,
      autoInstallSecurityUpdates: autoInstallSecurityUpdates ?? this.autoInstallSecurityUpdates,
      maxConcurrentDownloads: maxConcurrentDownloads ?? this.maxConcurrentDownloads,
      pauseOnLowBattery: pauseOnLowBattery ?? this.pauseOnLowBattery,
      lowBatteryThreshold: lowBatteryThreshold ?? this.lowBatteryThreshold,
    );
  }

  @override
  String toString() {
    return 'UpdateSettings(autoCheck: $autoCheckEnabled, autoDownload: $autoDownloadEnabled, autoInstall: $autoInstallEnabled)';
  }
}
