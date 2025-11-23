import 'dart:io';
import 'dart:convert';
import 'package:yaml/yaml.dart';
import 'package:flutter/material.dart';
import 'plugin_interface.dart';

/// 插件元数据加载器
///
/// 支持 YAML 和 JSON 两种配置文件格式
class PluginMetadataLoader {
  /// 从文件加载 metadata
  ///
  /// [pluginPath] 插件目录路径
  /// 返回解析后的 PluginMetadata
  Future<PluginMetadata> loadFromFile(String pluginPath) async {
    // 优先尝试 JSON 格式 (新版本)
    final jsonFile = File('$pluginPath/plugin.json');
    if (await jsonFile.exists()) {
      try {
        final jsonContent = await jsonFile.readAsString();
        return parseJson(jsonContent);
      } catch (e) {
        print('⚠️ Failed to read JSON config: $e, trying YAML...');
      }
    }

    // 回退到 YAML 格式 (旧版本)
    final yamlFile = File('$pluginPath/plugin.yaml');
    if (await yamlFile.exists()) {
      try {
        final yamlContent = await yamlFile.readAsString();
        return parseYaml(yamlContent);
      } catch (e) {
        throw PluginMetadataLoadException(
          'Failed to read YAML configuration file: $e',
        );
      }
    }

    // 如果都不存在，抛出异常
    throw PluginMetadataLoadException(
      'Configuration file not found: tried plugin.json and plugin.yaml in $pluginPath',
    );
  }
  
  /// 从 JSON 字符串解析 metadata
  ///
  /// [jsonContent] JSON 格式的配置内容
  /// 返回解析后的 PluginMetadata
  PluginMetadata parseJson(String jsonContent) {
    try {
      final Map<String, dynamic> doc = json.decode(jsonContent);

      // 验证必需字段
      _validateRequiredFieldsJson(doc);

      return PluginMetadata(
        id: doc['id'] as String,
        name: doc['name'] as String,
        version: doc['version'] as String,
        description: doc['description'] as String,
        author: doc['author'] as String? ?? 'Unknown',
        icon: _parseIcon(doc['icon'] as String?),
        capabilities: _parseStringList(doc['capabilities']),
        homepage: doc['homepage'] as String?,
        repository: doc['repository'] as String?,
        license: _parseLicense(doc['license'] as String?),
        permissions: _parsePermissions(doc['permissions']),
        dependencies: _parseStringList(doc['dependencies']),
        minCoreVersion: doc['minAppVersion'] as String? ?? doc['minCoreVersion'] as String? ?? '1.0.0',
        maxCoreVersion: doc['maxAppVersion'] as String?,
      );
    } catch (e) {
      throw PluginMetadataLoadException(
        'Failed to parse JSON configuration: $e',
      );
    }
  }

  /// 从 YAML 字符串解析 metadata
  ///
  /// [yamlContent] YAML 格式的配置内容
  /// 返回解析后的 PluginMetadata
  PluginMetadata parseYaml(String yamlContent) {
    try {
      final doc = loadYaml(yamlContent) as Map;
      
      // 验证必需字段
      _validateRequiredFields(doc);
      
      return PluginMetadata(
        id: doc['id'] as String,
        name: doc['name'] as String,
        version: doc['version'] as String,
        description: doc['description'] as String,
        author: doc['author'] as String? ?? 'Unknown',
        icon: _parseIcon(doc['icon'] as String?),
        capabilities: _parseStringList(doc['capabilities']),
        permissions: _parsePermissions(doc['permissions']),
        license: _parseLicense(doc['license'] as String?),
        homepage: doc['homepage'] as String?,
        repository: doc['repository'] as String?,
        dependencies: _parseStringList(doc['dependencies']),
      );
    } catch (e) {
      throw PluginMetadataLoadException(
        'Failed to parse YAML: $e',
      );
    }
  }
  
  /// 验证必需字段
  void _validateRequiredFields(Map doc) {
    final requiredFields = ['id', 'name', 'version', 'description'];
    
    for (final field in requiredFields) {
      if (!doc.containsKey(field) || doc[field] == null) {
        throw PluginMetadataLoadException(
          'Missing required field: $field',
        );
      }
    }
    
    // 验证版本号格式
    final version = doc['version'] as String;
    final versionPattern = RegExp(r'^\d+\.\d+\.\d+$');
    if (!versionPattern.hasMatch(version)) {
      throw PluginMetadataLoadException(
        'Invalid version format: $version. Expected format: x.y.z',
      );
    }
  }

  /// 验证 JSON 必需字段
  void _validateRequiredFieldsJson(Map<String, dynamic> doc) {
    final requiredFields = ['id', 'name', 'version', 'description'];

    for (final field in requiredFields) {
      if (!doc.containsKey(field) || doc[field] == null) {
        throw PluginMetadataLoadException(
          'Missing required field: $field',
        );
      }
    }

    // 验证版本号格式
    final version = doc['version'] as String;
    final versionPattern = RegExp(r'^\d+\.\d+\.\d+$');
    if (!versionPattern.hasMatch(version)) {
      throw PluginMetadataLoadException(
        'Invalid version format: $version. Expected format: x.y.z',
      );
    }
  }
  
  /// 解析图标
  IconData _parseIcon(String? iconName) {
    if (iconName == null) return Icons.extension;
    
    // 简单的图标映射
    final iconMap = {
      'network_check': Icons.network_check,
      'cloud': Icons.cloud,
      'storage': Icons.storage,
      'video_library': Icons.video_library,
      'subtitles': Icons.subtitles,
      'audio_file': Icons.audio_file,
      'settings': Icons.settings,
      'extension': Icons.extension,
    };
    
    return iconMap[iconName] ?? Icons.extension;
  }
  
  /// 解析字符串列表
  List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }
  
  /// 解析权限列表
  List<PluginPermission> _parsePermissions(dynamic value) {
    final stringList = _parseStringList(value);
    final permissions = <PluginPermission>[];
    final availablePermissions = PluginPermission.values.map((p) => p.name).join(', ');

    for (final str in stringList) {
      try {
        final permission = PluginPermission.values.firstWhere(
          (p) => p.name.toLowerCase() == str.toLowerCase(),
        );
        permissions.add(permission);
      } catch (e) {
        print('⚠️ Unknown permission: $str');
        print('   Available permissions: $availablePermissions');
        print('   Using network permission as fallback');
        permissions.add(PluginPermission.network);
      }
    }

    print('✅ Parsed ${permissions.length} permissions: ${permissions.map((p) => p.name).join(', ')}');
    return permissions;
  }
  
  /// 解析许可证类型
  PluginLicense _parseLicense(String? value) {
    if (value == null) return PluginLicense.mit;
    
    try {
      return PluginLicense.values.firstWhere(
        (l) => l.name.toLowerCase() == value.toLowerCase(),
      );
    } catch (e) {
      print('⚠️ Unknown license: $value, using MIT as default');
      return PluginLicense.mit;
    }
  }
  
  /// 验证 metadata 完整性
  bool validate(PluginMetadata metadata) {
    try {
      // 检查必需字段
      if (metadata.id.isEmpty) return false;
      if (metadata.name.isEmpty) return false;
      if (metadata.version.isEmpty) return false;
      if (metadata.description.isEmpty) return false;
      
      // 验证版本号格式
      final versionPattern = RegExp(r'^\d+\.\d+\.\d+$');
      if (!versionPattern.hasMatch(metadata.version)) return false;
      
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// 插件元数据加载异常
class PluginMetadataLoadException implements Exception {
  final String message;
  
  PluginMetadataLoadException(this.message);
  
  @override
  String toString() => 'PluginMetadataLoadException: $message';
}
