import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:archive/archive_io.dart';
import '../../models/update/update_models.dart';
import '../../core/plugin_system/plugin_metadata_loader.dart';
import 'backup_manager.dart';

/// 热更新安装器
/// 
/// 负责在不重启应用的情况下安装插件更新
class HotInstaller {
  /// 单例实例
  static final HotInstaller _instance = HotInstaller._internal();
  factory HotInstaller() => _instance;
  HotInstaller._internal();

  /// 备份管理器
  final BackupManager _backupManager = BackupManager();

  /// 插件卸载回调
  Future<void> Function(String pluginId)? onUnloadPlugin;

  /// 插件加载回调
  Future<void> Function(String pluginId, String pluginPath)? onLoadPlugin;

  /// 安装更新
  /// 
  /// [pluginId] 插件ID
  /// [version] 版本号
  /// [packagePath] 更新包路径
  /// [pluginInstallPath] 插件安装目录
  /// [createBackup] 是否创建备份
  Future<InstallResult> installUpdate({
    required String pluginId,
    required String version,
    required String packagePath,
    required String pluginInstallPath,
    bool createBackup = true,
  }) async {
    final startTime = DateTime.now();
    BackupInfo? backup;
    
    print('🔧 开始安装更新: $pluginId v$version');
    print('   更新包: $packagePath');
    print('   安装路径: $pluginInstallPath');
    
    try {
      // 步骤1: 验证更新包
      print('📦 验证更新包...');
      await _verifyPackage(packagePath);
      
      // 步骤2: 创建备份
      if (createBackup) {
        print('💾 创建备份...');
        final pluginDir = Directory(pluginInstallPath);
        if (await pluginDir.exists()) {
          // 获取当前版本(从某个配置文件或默认值)
          final currentVersion = await _getCurrentVersion(pluginInstallPath);
          
          backup = await _backupManager.createBackup(
            pluginId: pluginId,
            version: currentVersion,
            pluginPath: pluginInstallPath,
            description: '安装 v$version 前的自动备份',
          );
        }
      }
      
      // 步骤3: 卸载旧版本
      print('🗑️ 卸载旧版本...');
      await _unloadPlugin(pluginId);
      
      // 步骤4: 解压新版本
      print('📦 解压更新包...');
      await _extractPackage(packagePath, pluginInstallPath);
      
      // 步骤5: 验证安装
      print('✅ 验证安装...');
      await _verifyInstallation(pluginInstallPath);
      
      // 步骤6: 加载新版本
      print('🔄 加载新版本...');
      await _loadPlugin(pluginId, pluginInstallPath);
      
      final installDuration = DateTime.now().difference(startTime);
      
      print('✅ 安装成功: $pluginId v$version');
      print('   耗时: ${installDuration.inSeconds}秒');
      
      return InstallResult.success(
        pluginId: pluginId,
        version: version,
        backupCreated: backup != null,
        backupId: backup?.id,
        installDuration: installDuration,
      );
    } catch (e, stackTrace) {
      print('❌ 安装失败: $e');
      print(stackTrace);
      
      // 尝试回滚
      if (backup != null) {
        print('🔄 尝试回滚到备份版本...');
        try {
          await rollbackInstallation(
            pluginId: pluginId,
            backupInfo: backup,
            pluginInstallPath: pluginInstallPath,
          );
          
          return InstallResult.rolledBack(
            pluginId: pluginId,
            version: backup.version,
            backupId: backup.id,
            error: e.toString(),
          );
        } catch (rollbackError) {
          print('❌ 回滚失败: $rollbackError');
        }
      }
      
      return InstallResult.failed(
        pluginId: pluginId,
        version: version,
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        backupCreated: backup != null,
        backupId: backup?.id,
      );
    }
  }

  /// 回滚安装
  /// 
  /// [pluginId] 插件ID
  /// [backupInfo] 备份信息
  /// [pluginInstallPath] 插件安装目录
  Future<InstallResult> rollbackInstallation({
    required String pluginId,
    required BackupInfo backupInfo,
    required String pluginInstallPath,
  }) async {
    print('🔄 回滚安装: $pluginId -> v${backupInfo.version}');
    
    try {
      // 卸载当前版本
      await _unloadPlugin(pluginId);
      
      // 恢复备份
      await _backupManager.restoreBackup(
        backupInfo: backupInfo,
        targetPath: pluginInstallPath,
      );
      
      // 重新加载插件
      await _loadPlugin(pluginId, pluginInstallPath);
      
      print('✅ 回滚成功');
      
      return InstallResult.rolledBack(
        pluginId: pluginId,
        version: backupInfo.version,
        backupId: backupInfo.id,
      );
    } catch (e, stackTrace) {
      print('❌ 回滚失败: $e');
      print(stackTrace);
      
      return InstallResult.failed(
        pluginId: pluginId,
        version: backupInfo.version,
        error: e.toString(),
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// 验证安装
  /// 
  /// [pluginId] 插件ID
  /// [pluginPath] 插件路径
  Future<bool> verifyInstallation({
    required String pluginId,
    required String pluginPath,
  }) async {
    try {
      await _verifyInstallation(pluginPath);
      return true;
    } catch (e) {
      print('❌ 验证失败: $e');
      return false;
    }
  }

  // ==================== 私有方法 ====================

  /// 验证更新包
  Future<void> _verifyPackage(String packagePath) async {
    final file = File(packagePath);
    
    if (!await file.exists()) {
      throw Exception('更新包不存在: $packagePath');
    }
    
    // 验证是否为有效的zip文件
    try {
      final bytes = await file.readAsBytes();
      ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw Exception('无效的更新包格式: $e');
    }
  }

  /// 解压更新包
  Future<void> _extractPackage(String packagePath, String targetPath) async {
    final file = File(packagePath);
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    
    // 确保目标目录存在
    final targetDir = Directory(targetPath);
    if (await targetDir.exists()) {
      await targetDir.delete(recursive: true);
    }
    await targetDir.create(recursive: true);
    
    // 解压所有文件
    for (final file in archive) {
      final filename = file.name;
      final filePath = path.join(targetPath, filename);
      
      if (file.isFile) {
        final outFile = File(filePath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(filePath).create(recursive: true);
      }
    }
    
    print('📦 解压完成: ${archive.length} 个文件');
  }

  /// 验证安装
  Future<void> _verifyInstallation(String pluginPath) async {
    final pluginDir = Directory(pluginPath);
    
    if (!await pluginDir.exists()) {
      throw Exception('插件目录不存在');
    }
    
    // 检查必要的文件(根据实际插件结构调整)
    // 例如: plugin.yaml, lib/main.dart 等
    final hasFiles = await pluginDir.list().length > 0;
    
    if (!hasFiles) {
      throw Exception('插件目录为空');
    }
  }

  /// 卸载插件
  Future<void> _unloadPlugin(String pluginId) async {
    if (onUnloadPlugin != null) {
      await onUnloadPlugin!(pluginId);
    } else {
      print('⚠️ 未设置插件卸载回调');
    }
  }

  /// 加载插件
  Future<void> _loadPlugin(String pluginId, String pluginPath) async {
    if (onLoadPlugin != null) {
      await onLoadPlugin!(pluginId, pluginPath);
    } else {
      print('⚠️ 未设置插件加载回调');
    }
  }

  /// 获取当前版本
  Future<String> _getCurrentVersion(String pluginPath) async {
    try {
      final loader = PluginMetadataLoader();
      final metadata = await loader.loadFromFile(pluginPath);
      return metadata.version;
    } catch (e) {
      print('⚠️ 无法从配置文件读取版本号: $e');
      // 如果读取失败,返回默认版本
      return '0.0.0';
    }
  }
}
