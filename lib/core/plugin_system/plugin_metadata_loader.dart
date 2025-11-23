import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:flutter/material.dart';
import 'plugin_interface.dart';

/// 插件元数据加载器
/// 
/// 从 YAML 配置文件加载插件元数据
class PluginMetadataLoader {
  /// 从文件加载 metadata
  /// 
  /// [pluginPath] 插件目录路径
  /// 返回解析后的 PluginMetadata
  Future<PluginMetadata> loadFromFile(String pluginPath) async {
    final configFile = File('$pluginPath/plugin.yaml');
    
    if (!await configFile.exists()) {
      throw PluginMetadataLoadException(
        'Configuration file not found: ${configFile.path}',
      );
    }
    
    try {
      final yamlContent = await configFile.readAsString();
      return parseYaml(yamlContent);
    } catch (e) {
      throw PluginMetadataLoadException(
        'Failed to read configuration file: $e',
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
    return stringList.map((str) {
      try {
        return PluginPermission.values.firstWhere(
          (p) => p.name.toLowerCase() == str.toLowerCase(),
        );
      } catch (e) {
        print('⚠️ Unknown permission: $str, using network as default');
        return PluginPermission.network;
      }
    }).toList();
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
