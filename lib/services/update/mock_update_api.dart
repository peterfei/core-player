import '../../models/update/update_models.dart';

/// Mock更新API
///
/// 用于开发和测试环境,提供模拟的插件更新数据
class MockUpdateApi {
  /// 是否启用Mock模式
  /// 设置为false以使用真实的HTTP API (mock_server)
  static bool enabled = false;

  /// Mock插件更新数据库
  static final Map<String, MockPluginVersionInfo> _mockDatabase = {
    'com.coreplayer.smb': MockPluginVersionInfo(
      pluginId: 'com.coreplayer.smb',
      currentVersion: '1.0.0',
      latestVersion: '1.1.0',
      changelog: [
        '新增: 支持SMBv3协议',
        '优化: 提升大文件传输速度30%',
        '修复: 解决部分设备连接失败问题',
      ],
      downloadUrl: 'https://cdn.coreplayer.com/plugins/smb/1.1.0/package.zip',
      downloadSize: 5242880, // 5MB
      isSecurityUpdate: false,
      isMandatory: false,
      isBreakingChange: false,
      minAppVersion: '2.0.0',
      releaseDate: DateTime(2024, 1, 15),
      priority: 5,
    ),
    'com.coreplayer.emby': MockPluginVersionInfo(
      pluginId: 'com.coreplayer.emby',
      currentVersion: '1.0.0',
      latestVersion: '1.2.0',
      changelog: [
        '新增: 支持4K视频播放',
        '新增: 支持外挂字幕',
        '优化: 改进缓冲策略',
      ],
      downloadUrl: 'https://cdn.coreplayer.com/plugins/emby/1.2.0/package.zip',
      downloadSize: 3145728, // 3MB
      isSecurityUpdate: true,
      isMandatory: false,
      isBreakingChange: false,
      minAppVersion: '2.0.0',
      releaseDate: DateTime(2024, 1, 20),
      priority: 8,
    ),
    'third_party.youtube': MockPluginVersionInfo(
      pluginId: 'third_party.youtube',
      currentVersion: '2.0.0',
      latestVersion: '2.1.0',
      changelog: [
        '新增: 支持8K视频',
        '优化: 减少内存占用',
        '修复: 字幕同步问题',
      ],
      downloadUrl: 'https://cdn.coreplayer.com/plugins/youtube/2.1.0/package.zip',
      downloadSize: 4194304, // 4MB
      isSecurityUpdate: false,
      isMandatory: false,
      isBreakingChange: false,
      minAppVersion: '2.0.0',
      releaseDate: DateTime(2024, 1, 10),
      priority: 5,
    ),
  };

  /// 检查插件更新
  static UpdateInfo? checkUpdate({
    required String pluginId,
    required String currentVersion,
  }) {
    if (!enabled) return null;

    final mockInfo = _mockDatabase[pluginId];
    if (mockInfo == null) {
      return null; // 插件不存在
    }

    // 比较版本号
    if (_compareVersions(mockInfo.latestVersion, currentVersion) <= 0) {
      // 没有更新
      return UpdateInfo(
        pluginId: pluginId,
        currentVersion: currentVersion,
        latestVersion: currentVersion,
        changelog: '已是最新版本',
        downloadUrl: '',
        packageSize: 0,
        isSecurityUpdate: false,
        isMandatory: false,
        minAppVersion: mockInfo.minAppVersion,
        releaseDate: DateTime.now(),
        priority: 0,
      );
    }

    // 有更新
    return UpdateInfo(
      pluginId: pluginId,
      currentVersion: currentVersion,
      latestVersion: mockInfo.latestVersion,
      changelog: mockInfo.changelog.join('\n'),
      downloadUrl: mockInfo.downloadUrl,
      packageSize: mockInfo.downloadSize,
      isSecurityUpdate: mockInfo.isSecurityUpdate,
      isMandatory: mockInfo.isMandatory,
      minAppVersion: mockInfo.minAppVersion,
      releaseDate: mockInfo.releaseDate,
      priority: mockInfo.priority,
    );
  }

  /// 添加Mock插件数据
  static void addMockPlugin(MockPluginVersionInfo info) {
    _mockDatabase[info.pluginId] = info;
  }

  /// 移除Mock插件数据
  static void removeMockPlugin(String pluginId) {
    _mockDatabase.remove(pluginId);
  }

  /// 清空Mock数据
  static void clearAll() {
    _mockDatabase.clear();
  }

  /// 获取所有Mock插件
  static List<String> getAllPluginIds() {
    return _mockDatabase.keys.toList();
  }

  /// 简单的版本比较
  static int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) return p1 - p2;
    }

    return 0;
  }
}

/// Mock插件版本信息
class MockPluginVersionInfo {
  final String pluginId;
  final String currentVersion;
  final String latestVersion;
  final List<String> changelog;
  final String downloadUrl;
  final int downloadSize;
  final bool isSecurityUpdate;
  final bool isMandatory;
  final bool isBreakingChange;
  final String minAppVersion;
  final DateTime releaseDate;
  final int priority;

  MockPluginVersionInfo({
    required this.pluginId,
    required this.currentVersion,
    required this.latestVersion,
    required this.changelog,
    required this.downloadUrl,
    required this.downloadSize,
    required this.isSecurityUpdate,
    required this.isMandatory,
    required this.isBreakingChange,
    required this.minAppVersion,
    required this.releaseDate,
    required this.priority,
  });
}
