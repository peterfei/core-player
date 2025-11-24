import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// 配置迁移服务
///
/// 处理从旧版本到新版本的配置迁移，包括：
/// - 移除媒体服务器占位符配置
/// - 迁移插件配置到新的插件包系统
/// - 记录迁移日志
class ConfigMigration {
  static ConfigMigration? _instance;
  static ConfigMigration get instance {
    _instance ??= ConfigMigration._internal();
    return _instance!;
  }

  ConfigMigration._internal();

  /// 迁移日志文件
  static const String _migrationLogFile = 'migration.log';

  /// 当前迁移版本
  static const int _currentMigrationVersion = 1;

  /// 执行配置迁移
  Future<MigrationResult> performMigration() async {
    try {
      final result = MigrationResult();

      // 获取配置目录
      final configDir = await _getConfigDirectory();
      final logFile = File(path.join(configDir.path, _migrationLogFile));

      // 检查是否需要迁移
      final lastMigrationVersion = await _getLastMigrationVersion(configDir);
      if (lastMigrationVersion >= _currentMigrationVersion) {
        result.addLog('配置已是最新版本，无需迁移');
        return result;
      }

      result.addLog('开始配置迁移 (版本 $lastMigrationVersion → $_currentMigrationVersion)');

      // 执行迁移步骤
      await _removeMediaServerPlaceholderConfig(configDir, result);
      await _migratePluginConfig(configDir, result);
      await _updateMigrationVersion(configDir, result);

      result.success = true;
      result.addLog('配置迁移完成');

      // 保存迁移日志
      await _saveMigrationLog(logFile, result);

      return result;
    } catch (e) {
      final result = MigrationResult();
      result.success = false;
      result.addLog('配置迁移失败: $e');
      result.error = e.toString();
      return result;
    }
  }

  /// 获取配置目录
  Future<Directory> _getConfigDirectory() async {
    if (kIsWeb) {
      // Web 平台使用临时目录
      return Directory.systemTemp;
    }
    return await getApplicationSupportDirectory();
  }

  /// 获取上次迁移版本
  Future<int> _getLastMigrationVersion(Directory configDir) async {
    try {
      final versionFile = File(path.join(configDir.path, '.migration_version'));
      if (!await versionFile.exists()) {
        return 0;
      }

      final content = await versionFile.readAsString();
      return int.tryParse(content.trim()) ?? 0;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get last migration version: $e');
      }
      return 0;
    }
  }

  /// 更新迁移版本
  Future<void> _updateMigrationVersion(Directory configDir, MigrationResult result) async {
    try {
      final versionFile = File(path.join(configDir.path, '.migration_version'));
      await versionFile.writeAsString(_currentMigrationVersion.toString());
      result.addLog('更新迁移版本到 $_currentMigrationVersion');
    } catch (e) {
      result.addLog('更新迁移版本失败: $e');
      throw e;
    }
  }

  /// 移除媒体服务器占位符配置
  Future<void> _removeMediaServerPlaceholderConfig(Directory configDir, MigrationResult result) async {
    try {
      final configFiles = [
        'plugins_config.json',
        'media_server_config.json',
        'mediaserver_settings.json',
      ];

      for (final configFile in configFiles) {
        final file = File(path.join(configDir.path, configFile));
        if (await file.exists()) {
          try {
            final content = await file.readAsString();
            final config = jsonDecode(content) as Map<String, dynamic>;

            // 检查是否包含占位符插件配置
            bool hasPlaceholder = false;
            if (config.containsKey('plugins')) {
              final plugins = config['plugins'] as List<dynamic>;
              hasPlaceholder = plugins.any((plugin) =>
                plugin['id'] == 'com.coreplayer.media_server.placeholder' ||
                plugin['id'] == 'builtin.media_server'
              );
            }

            if (hasPlaceholder) {
              // 移除占位符配置
              final updatedPlugins = (config['plugins'] as List<dynamic>)
                  .where((plugin) =>
                      plugin['id'] != 'com.coreplayer.media_server.placeholder' &&
                      plugin['id'] != 'builtin.media_server')
                  .toList();

              config['plugins'] = updatedPlugins;

              // 备份原文件
              final backupFile = File(path.join(configDir.path, '${configFile}.backup'));
              await file.copy(backupFile.path);

              // 写入更新后的配置
              await file.writeAsString(jsonEncode(config));

              result.addLog('移除媒体服务器占位符配置: $configFile');
              result.addLog('原配置已备份到: ${configFile}.backup');
            }
          } catch (e) {
            result.addLog('处理配置文件 $configFile 失败: $e');
          }
        }
      }
    } catch (e) {
      result.addLog('移除媒体服务器占位符配置失败: $e');
      // 不抛出异常，继续其他迁移步骤
    }
  }

  /// 迁移插件配置到插件包系统
  Future<void> _migratePluginConfig(Directory configDir, MigrationResult result) async {
    try {
      final configFile = File(path.join(configDir.path, 'plugins_config.json'));
      if (!await configFile.exists()) {
        result.addLog('插件配置文件不存在，跳过插件迁移');
        return;
      }

      final content = await configFile.readAsString();
      final config = jsonDecode(content) as Map<String, dynamic>;

      // 检查并迁移插件配置
      if (config.containsKey('plugins')) {
        final plugins = config['plugins'] as List<dynamic>;
        int migratedCount = 0;

        for (final plugin in plugins) {
          final pluginId = plugin['id'] as String;

          // 迁移 HEVC 解码器配置
          if (pluginId == 'hevc_decoder' || pluginId == 'coreplayer.pro.decoder.hevc') {
            await _migrateHEVCPluginConfig(configDir, plugin, result);
            migratedCount++;
          }

          // 迁移其他插件配置...
          // TODO: 添加其他插件的迁移逻辑
        }

        result.addLog('迁移了 $migratedCount 个插件配置');
      }
    } catch (e) {
      result.addLog('插件配置迁移失败: $e');
      // 不抛出异常，继续其他迁移步骤
    }
  }

  /// 迁移 HEVC 插件配置
  Future<void> _migrateHEVCPluginConfig(Directory configDir, Map<String, dynamic> pluginConfig, MigrationResult result) async {
    try {
      // 创建新的插件配置目录
      final pluginConfigDir = Directory(path.join(configDir.path, 'plugins'));
      if (!await pluginConfigDir.exists()) {
        await pluginConfigDir.create(recursive: true);
      }

      // 保存 HEVC 插件配置
      final hevcConfigFile = File(path.join(pluginConfigDir.path, 'hevc_decoder.json'));
      final hevcConfig = {
        'id': 'coreplayer.pro.decoder.hevc',
        'name': 'HEVC/H.265 高级解码器',
        'version': '2.2.0',
        'enabled': pluginConfig['enabled'] ?? true,
        'config': pluginConfig['config'] ?? {},
        'migrated_at': DateTime.now().toIso8601String(),
        'migrated_from': 'lazy_loader_config',
      };

      await hevcConfigFile.writeAsString(jsonEncode(hevcConfig));
      result.addLog('迁移 HEVC 解码器配置到插件包系统');
    } catch (e) {
      result.addLog('HEVC 插件配置迁移失败: $e');
    }
  }

  /// 保存迁移日志
  Future<void> _saveMigrationLog(File logFile, MigrationResult result) async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      final logEntry = '''
=== 迁移日志 $timestamp ===
成功: ${result.success}
版本: ${result.fromVersion} → ${result.toVersion}
日志:
${result.logs.join('\n')}
${result.error != null ? '\n错误: ${result.error}' : ''}
''';

      // 追加到日志文件
      await logFile.writeAsString(logEntry, mode: FileMode.append);

      // 只保留最近10次迁移记录
      final lines = await logFile.readAsLines();
      if (lines.length > 1000) { // 假设每次迁移约100行
        final startIndex = lines.length - 1000;
        final recentLogs = lines.sublist(startIndex);
        await logFile.writeAsString(recentLogs.join('\n'));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save migration log: $e');
      }
    }
  }

  /// 检查是否需要迁移
  Future<bool> needsMigration() async {
    try {
      final configDir = await _getConfigDirectory();
      final lastVersion = await _getLastMigrationVersion(configDir);
      return lastVersion < _currentMigrationVersion;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to check migration status: $e');
      }
      return false;
    }
  }
}

/// 迁移结果
class MigrationResult {
  bool success = false;
  int fromVersion = 0;
  int toVersion = 0;
  List<String> logs = [];
  String? error;

  void addLog(String message) {
    final timestamp = DateTime.now().toIso8601String();
    logs.add('[$timestamp] $message');
    print('[ConfigMigration] $message');
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'fromVersion': fromVersion,
      'toVersion': toVersion,
      'logs': logs,
      'error': error,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}