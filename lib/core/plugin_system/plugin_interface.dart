import 'package:flutter/material.dart';

/// 插件许可证类型
enum PluginLicense {
  mit('MIT'),
  apache('Apache-2.0'),
  gpl('GPL-3.0'),
  bsd('BSD-3-Clause'),
  proprietary('Proprietary'),
  unknown('Unknown');

  const PluginLicense(this.displayName);
  final String displayName;
}

/// 插件权限
enum PluginPermission {
  network('Network Access'),
  storage('Storage Access'),
  camera('Camera Access'),
  microphone('Microphone Access'),
  location('Location Access'),
  bluetooth('Bluetooth Access'),
  notifications('Notifications');

  const PluginPermission(this.displayName);
  final String displayName;
}

/// 插件元数据
@immutable
class PluginMetadata {
  final String id; // 唯一标识，如 'com.coreplayer.smb'
  final String name; // 显示名称
  final String version; // 语义化版本，如 '1.0.0'
  final String description; // 插件描述
  final String author; // 作者
  final IconData icon; // 插件图标
  final List<String> capabilities; // 能力标签
  final String? homepage; // 主页URL
  final String? repository; // 代码仓库
  final PluginLicense license; // 许可证信息
  final List<PluginPermission> permissions; // 所需权限
  final List<String> dependencies; // 插件依赖
  final String? minCoreVersion; // 最低核心版本要求
  final String? maxCoreVersion; // 最高核心版本限制

  const PluginMetadata({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.author,
    required this.icon,
    this.capabilities = const [],
    this.homepage,
    this.repository,
    this.license = PluginLicense.proprietary,
    this.permissions = const [],
    this.dependencies = const [],
    this.minCoreVersion,
    this.maxCoreVersion,
  });

  factory PluginMetadata.fromJson(Map<String, dynamic> json) {
    return PluginMetadata(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      description: json['description'] as String,
      author: json['author'] as String,
      icon: _getIconData(json['icon'] as String?),
      capabilities: List<String>.from(json['capabilities'] ?? []),
      homepage: json['homepage'] as String?,
      repository: json['repository'] as String?,
      license: _parseLicense(json['license'] as String?),
      permissions: _parsePermissions(List<String>.from(json['permissions'] ?? [])),
      dependencies: List<String>.from(json['dependencies'] ?? []),
      minCoreVersion: json['minCoreVersion'] as String?,
      maxCoreVersion: json['maxCoreVersion'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'description': description,
      'author': author,
      'icon': icon.codePoint.toString(),
      'capabilities': capabilities,
      'homepage': homepage,
      'repository': repository,
      'license': license.name,
      'permissions': permissions.map((p) => p.name).toList(),
      'dependencies': dependencies,
      'minCoreVersion': minCoreVersion,
      'maxCoreVersion': maxCoreVersion,
    };
  }

  /// 检查插件是否与指定核心版本兼容
  bool isCompatibleWith(String coreVersion) {
    if (minCoreVersion != null && _compareVersions(coreVersion, minCoreVersion!) < 0) {
      return false;
    }
    if (maxCoreVersion != null && _compareVersions(coreVersion, maxCoreVersion!) > 0) {
      return false;
    }
    return true;
  }

  /// 版本号比较
  static int _compareVersions(String version1, String version2) {
    final v1Parts = version1.split('.').map(int.parse).toList();
    final v2Parts = version2.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final v1Part = v1Parts.length > i ? v1Parts[i] : 0;
      final v2Part = v2Parts.length > i ? v2Parts[i] : 0;

      if (v1Part > v2Part) return 1;
      if (v1Part < v2Part) return -1;
    }
    return 0;
  }

  static IconData _getIconData(String? iconString) {
    if (iconString == null) return Icons.extension;
    try {
      final codePoint = int.parse(iconString);
      return IconData(codePoint, fontFamily: 'MaterialIcons');
    } catch (e) {
      return Icons.extension;
    }
  }

  static PluginLicense _parseLicense(String? licenseString) {
    if (licenseString == null) return PluginLicense.unknown;
    return PluginLicense.values.firstWhere(
      (license) => license.name.toLowerCase() == licenseString.toLowerCase(),
      orElse: () => PluginLicense.unknown,
    );
  }

  static List<PluginPermission> _parsePermissions(List<String> permissionStrings) {
    return permissionStrings
        .map((p) => PluginPermission.values.firstWhere(
              (perm) => perm.name.toLowerCase() == p.toLowerCase(),
              orElse: () => PluginPermission.network,
            ))
        .toList();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PluginMetadata &&
        other.id == id &&
        other.version == version;
  }

  @override
  int get hashCode => Object.hash(id, version);

  @override
  String toString() {
    return 'PluginMetadata(id: $id, name: $name, version: $version)';
  }
}

/// 插件状态
enum PluginState {
  uninitialized, // 未初始化
  initializing,  // 初始化中
  ready,         // 就绪
  active,        // 激活
  inactive,      // 未激活
  error,         // 错误
  disposed,      // 已释放
}

/// 插件状态扩展
extension PluginStateExtension on PluginState {
  /// 是否可以激活
  bool get canActivate => this == PluginState.ready || this == PluginState.inactive;

  /// 是否正在运行
  bool get isRunning => this == PluginState.active || this == PluginState.initializing;

  /// 是否有错误
  bool get hasError => this == PluginState.error;
}

/// 插件事件类型
enum PluginEventType {
  registered,    // 注册
  unregistered,  // 注销
  activated,     // 激活
  deactivated,   // 停用
  error,         // 错误
  disposed,      // 释放
}

/// 插件事件
@immutable
class PluginEvent {
  final String pluginId;
  final PluginEventType type;
  final DateTime timestamp;
  final Map<String, dynamic>? data;
  final String? error;

  PluginEvent._({
    required this.pluginId,
    required this.type,
    required this.timestamp,
    this.data,
    this.error,
  });

  factory PluginEvent.registered(String pluginId) => PluginEvent._(
    pluginId: pluginId,
    type: PluginEventType.registered,
    timestamp: DateTime.now(),
  );

  factory PluginEvent.unregistered(String pluginId) => PluginEvent._(
    pluginId: pluginId,
    type: PluginEventType.unregistered,
    timestamp: DateTime.now(),
  );

  factory PluginEvent.activated(String pluginId) => PluginEvent._(
    pluginId: pluginId,
    type: PluginEventType.activated,
    timestamp: DateTime.now(),
  );

  factory PluginEvent.deactivated(String pluginId) => PluginEvent._(
    pluginId: pluginId,
    type: PluginEventType.deactivated,
    timestamp: DateTime.now(),
  );

  factory PluginEvent.error(String pluginId, String error, {Map<String, dynamic>? data}) => PluginEvent._(
    pluginId: pluginId,
    type: PluginEventType.error,
    timestamp: DateTime.now(),
    error: error,
    data: data,
  );

  factory PluginEvent.disposed(String pluginId) => PluginEvent._(
    pluginId: pluginId,
    type: PluginEventType.disposed,
    timestamp: DateTime.now(),
  );

  @override
  String toString() {
    return 'PluginEvent(pluginId: $pluginId, type: $type, timestamp: $timestamp${error != null ? ', error: $error' : ''})';
  }
}

/// 插件异常基类
abstract class PluginException implements Exception {
  final String message;
  final String? pluginId;
  final dynamic originalError;

  PluginException(this.message, {this.pluginId, this.originalError});

  @override
  String toString() {
    final buffer = StringBuffer('PluginException: $message');
    if (pluginId != null) {
      buffer.write(' (Plugin: $pluginId)');
    }
    if (originalError != null) {
      buffer.write('\nCaused by: $originalError');
    }
    return buffer.toString();
  }
}

/// 插件初始化异常
class PluginInitializationException extends PluginException {
  PluginInitializationException(String message, {String? pluginId, dynamic originalError})
      : super(message, pluginId: pluginId, originalError: originalError);
}

/// 插件激活异常
class PluginActivationException extends PluginException {
  PluginActivationException(String message, {String? pluginId, dynamic originalError})
      : super(message, pluginId: pluginId, originalError: originalError);
}

/// 插件依赖异常
class PluginDependencyException extends PluginException {
  PluginDependencyException(String message, {String? pluginId, dynamic originalError})
      : super(message, pluginId: pluginId, originalError: originalError);
}

/// 功能不可用异常（社区版占位符）
class FeatureNotAvailableException extends PluginException {
  final String? upgradeUrl;

  FeatureNotAvailableException(String message, {this.upgradeUrl})
      : super(message);

  @override
  String toString() {
    final buffer = StringBuffer('FeatureNotAvailableException: $message');
    if (upgradeUrl != null) {
      buffer.write('\nUpgrade to Pro: $upgradeUrl');
    }
    return buffer.toString();
  }
}