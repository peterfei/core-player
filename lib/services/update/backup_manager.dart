import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive_io.dart';
import 'package:uuid/uuid.dart';
import '../../models/update/update_models.dart';

/// 备份管理器
/// 
/// 负责管理插件备份和恢复
class BackupManager {
  /// 单例实例
  static final BackupManager _instance = BackupManager._internal();
  factory BackupManager() => _instance;
  BackupManager._internal();

  /// 备份目录
  Directory? _backupDir;

  /// UUID生成器
  final _uuid = const Uuid();

  /// 最大备份数量
  static const int _maxBackups = 3;

  /// 初始化
  Future<void> initialize() async {
    if (_backupDir != null) return;
    
    final appDir = await getApplicationDocumentsDirectory();
    _backupDir = Directory(path.join(appDir.path, 'plugin_backups'));
    
    if (!await _backupDir!.exists()) {
      await _backupDir!.create(recursive: true);
    }
    
    print('📁 备份目录: ${_backupDir!.path}');
  }

  /// 创建备份
  /// 
  /// [pluginId] 插件ID
  /// [version] 插件版本
  /// [pluginPath] 插件目录路径
  /// [description] 备份描述
  Future<BackupInfo> createBackup({
    required String pluginId,
    required String version,
    required String pluginPath,
    String? description,
  }) async {
    await initialize();
    
    print('📦 创建备份: $pluginId v$version');
    print('   源路径: $pluginPath');
    
    final backupId = _uuid.v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupFileName = '${pluginId}_${version}_$timestamp.zip';
    final backupPath = path.join(_backupDir!.path, backupFileName);
    
    try {
      // 压缩插件目录
      final pluginDir = Directory(pluginPath);
      if (!await pluginDir.exists()) {
        throw Exception('插件目录不存在: $pluginPath');
      }
      
      // 创建压缩文件
      final encoder = ZipFileEncoder();
      encoder.create(backupPath);
      
      // 添加目录中的所有文件
      await encoder.addDirectory(pluginDir);
      encoder.close();
      
      final backupFile = File(backupPath);
      final backupSize = await backupFile.length();
      
      // 统计文件数量
      final fileCount = await _countFiles(pluginDir);
      
      final backupInfo = BackupInfo(
        id: backupId,
        pluginId: pluginId,
        version: version,
        backupPath: backupPath,
        backupSize: backupSize,
        createdAt: DateTime.now(),
        description: description,
        isAutoBackup: description == null,
        fileCount: fileCount,
      );
      
      print('✅ 备份创建成功');
      print('   备份ID: $backupId');
      print('   文件大小: ${backupInfo.formattedSize}');
      print('   文件数量: $fileCount');
      
      // 清理旧备份
      await _cleanupOldBackups(pluginId);
      
      return backupInfo;
    } catch (e, stackTrace) {
      print('❌ 备份创建失败: $e');
      print(stackTrace);
      
      // 清理失败的备份文件
      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
      
      rethrow;
    }
  }

  /// 恢复备份
  /// 
  /// [backupInfo] 备份信息
  /// [targetPath] 目标路径
  Future<void> restoreBackup({
    required BackupInfo backupInfo,
    required String targetPath,
  }) async {
    await initialize();
    
    print('📦 恢复备份: ${backupInfo.pluginId} v${backupInfo.version}');
    print('   备份文件: ${backupInfo.backupPath}');
    print('   目标路径: $targetPath');
    
    try {
      final backupFile = File(backupInfo.backupPath);
      if (!await backupFile.exists()) {
        throw Exception('备份文件不存在: ${backupInfo.backupPath}');
      }
      
      // 确保目标目录存在
      final targetDir = Directory(targetPath);
      if (await targetDir.exists()) {
        // 清空目标目录
        await targetDir.delete(recursive: true);
      }
      await targetDir.create(recursive: true);
      
      // 解压备份文件
      final bytes = await backupFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
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
      
      print('✅ 备份恢复成功');
      print('   恢复文件数: ${archive.length}');
    } catch (e, stackTrace) {
      print('❌ 备份恢复失败: $e');
      print(stackTrace);
      rethrow;
    }
  }

  /// 列出插件的所有备份
  /// 
  /// [pluginId] 插件ID
  Future<List<BackupInfo>> listBackups(String pluginId) async {
    await initialize();
    
    final backups = <BackupInfo>[];
    
    if (!await _backupDir!.exists()) {
      return backups;
    }
    
    await for (final entity in _backupDir!.list()) {
      if (entity is File && entity.path.endsWith('.zip')) {
        final fileName = path.basename(entity.path);
        
        // 检查文件名是否匹配插件ID
        if (fileName.startsWith('${pluginId}_')) {
          try {
            // 解析文件名获取信息
            final parts = fileName.replaceAll('.zip', '').split('_');
            if (parts.length >= 3) {
              final version = parts[1];
              final timestamp = int.tryParse(parts[2]);
              
              if (timestamp != null) {
                final stat = await entity.stat();
                
                backups.add(BackupInfo(
                  id: fileName,
                  pluginId: pluginId,
                  version: version,
                  backupPath: entity.path,
                  backupSize: stat.size,
                  createdAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
                  isAutoBackup: true,
                ));
              }
            }
          } catch (e) {
            print('⚠️ 解析备份文件失败: $fileName - $e');
          }
        }
      }
    }
    
    // 按创建时间倒序排序
    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    print('📋 找到 ${backups.length} 个备份: $pluginId');
    
    return backups;
  }

  /// 删除备份
  /// 
  /// [backupInfo] 备份信息
  Future<void> deleteBackup(BackupInfo backupInfo) async {
    final backupFile = File(backupInfo.backupPath);
    if (await backupFile.exists()) {
      await backupFile.delete();
      print('🗑️ 已删除备份: ${backupInfo.id}');
    }
  }

  /// 清理所有备份
  Future<void> cleanupAllBackups() async {
    await initialize();
    
    if (await _backupDir!.exists()) {
      await _backupDir!.delete(recursive: true);
      await _backupDir!.create();
    }
    
    print('🧹 所有备份已清理');
  }

  // ==================== 私有方法 ====================

  /// 清理旧备份(保留最近N个)
  Future<void> _cleanupOldBackups(String pluginId) async {
    final backups = await listBackups(pluginId);
    
    if (backups.length > _maxBackups) {
      final toDelete = backups.sublist(_maxBackups);
      
      for (final backup in toDelete) {
        await deleteBackup(backup);
      }
      
      print('🧹 清理了 ${toDelete.length} 个旧备份');
    }
  }

  /// 统计目录中的文件数量
  Future<int> _countFiles(Directory dir) async {
    int count = 0;
    
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        count++;
      }
    }
    
    return count;
  }
}
