import 'dart:async';
import 'dart:io';
import '../../models/update/update_models.dart';
import '../../core/plugin_system/plugin_metadata_loader.dart';
import 'update_detector.dart';
import 'update_downloader.dart';
import 'backup_manager.dart';
import 'hot_installer.dart';

/// 更新服务
/// 
/// 提供统一的插件更新API
class UpdateService {
  /// 单例实例
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  /// 更新检测器
  final UpdateDetector _detector = UpdateDetector();
  
  /// 更新下载器
  final UpdateDownloader _downloader = UpdateDownloader();
  
  /// 备份管理器
  final BackupManager _backupManager = BackupManager();
  
  /// 热更新安装器
  final HotInstaller _installer = HotInstaller();

  /// 是否已初始化
  bool _initialized = false;

  /// 初始化
  Future<void> initialize() async {
    if (_initialized) return;
    
    print('🚀 初始化更新服务...');
    
    await Future.wait([
      _detector.initialize(),
      _downloader.initialize(),
      _backupManager.initialize(),
    ]);
    
    _initialized = true;
    print('✅ 更新服务初始化完成');
  }

  /// 设置插件卸载回调
  void setPluginUnloadCallback(Future<void> Function(String) callback) {
    _installer.onUnloadPlugin = callback;
  }

  /// 设置插件加载回调
  void setPluginLoadCallback(Future<void> Function(String, String) callback) {
    _installer.onLoadPlugin = callback;
  }

  // ==================== 更新检测 ====================

  /// 检查单个插件更新
  Future<UpdateInfo?> checkUpdate({
    required String pluginId,
    required String currentVersion,
    bool forceRefresh = false,
  }) async {
    await initialize();
    return _detector.checkForUpdate(
      pluginId: pluginId,
      currentVersion: currentVersion,
      forceRefresh: forceRefresh,
    );
  }

  /// 检查所有插件更新
  Future<List<UpdateInfo>> checkAllUpdates({
    required Map<String, String> plugins,
    bool forceRefresh = false,
  }) async {
    await initialize();
    return _detector.checkAllUpdates(
      plugins: plugins,
      forceRefresh: forceRefresh,
    );
  }

  /// 比较版本号
  int compareVersions(String v1, String v2) {
    return _detector.compareVersions(v1, v2);
  }

  /// 检查版本兼容性
  bool isVersionCompatible({
    required String pluginVersion,
    String? minAppVersion,
    required String currentAppVersion,
  }) {
    return _detector.isVersionCompatible(
      pluginVersion: pluginVersion,
      minAppVersion: minAppVersion,
      currentAppVersion: currentAppVersion,
    );
  }

  // ==================== 下载管理 ====================

  /// 下载更新
  Future<String> downloadUpdate({
    required UpdateInfo updateInfo,
    void Function(DownloadProgress)? onProgress,
  }) async {
    await initialize();
    return _downloader.downloadUpdate(
      updateInfo: updateInfo,
      onProgress: onProgress,
    );
  }

  /// 暂停下载
  Future<void> pauseDownload(String pluginId) async {
    await _downloader.pauseDownload(pluginId);
  }

  /// 恢复下载
  Future<String> resumeDownload(String pluginId, UpdateInfo updateInfo) async {
    return _downloader.resumeDownload(pluginId, updateInfo);
  }

  /// 取消下载
  Future<void> cancelDownload(String pluginId) async {
    await _downloader.cancelDownload(pluginId);
  }

  /// 获取下载进度流
  Stream<DownloadProgress>? getDownloadProgress(String pluginId) {
    return _downloader.getProgressStream(pluginId);
  }

  /// 设置最大并发下载数
  void setMaxConcurrentDownloads(int max) {
    _downloader.setMaxConcurrentDownloads(max);
  }

  // ==================== 安装管理 ====================

  /// 安装更新
  Future<InstallResult> installUpdate({
    required String pluginId,
    required String version,
    required String packagePath,
    required String pluginInstallPath,
    bool createBackup = true,
  }) async {
    await initialize();
    return _installer.installUpdate(
      pluginId: pluginId,
      version: version,
      packagePath: packagePath,
      pluginInstallPath: pluginInstallPath,
      createBackup: createBackup,
    );
  }

  /// 回滚版本
  Future<InstallResult> rollbackVersion({
    required String pluginId,
    required BackupInfo backupInfo,
    required String pluginInstallPath,
  }) async {
    await initialize();
    return _installer.rollbackInstallation(
      pluginId: pluginId,
      backupInfo: backupInfo,
      pluginInstallPath: pluginInstallPath,
    );
  }

  /// 验证安装
  Future<bool> verifyInstallation({
    required String pluginId,
    required String pluginPath,
  }) async {
    return _installer.verifyInstallation(
      pluginId: pluginId,
      pluginPath: pluginPath,
    );
  }

  // ==================== 备份管理 ====================

  /// 创建备份
  Future<BackupInfo> createBackup({
    required String pluginId,
    required String version,
    required String pluginPath,
    String? description,
  }) async {
    await initialize();
    return _backupManager.createBackup(
      pluginId: pluginId,
      version: version,
      pluginPath: pluginPath,
      description: description,
    );
  }

  /// 列出备份
  Future<List<BackupInfo>> listBackups(String pluginId) async {
    await initialize();
    return _backupManager.listBackups(pluginId);
  }

  /// 恢复备份
  Future<void> restoreBackup({
    required BackupInfo backupInfo,
    required String targetPath,
  }) async {
    await initialize();
    return _backupManager.restoreBackup(
      backupInfo: backupInfo,
      targetPath: targetPath,
    );
  }

  /// 删除备份
  Future<void> deleteBackup(BackupInfo backupInfo) async {
    await _backupManager.deleteBackup(backupInfo);
  }

  // ==================== 完整更新流程 ====================

  /// 完整更新流程: 检测 → 下载 → 安装
  /// 
  /// [pluginId] 插件ID
  /// [currentVersion] 当前版本
  /// [pluginInstallPath] 插件安装路径
  /// [onProgress] 进度回调
  Future<InstallResult> performFullUpdate({
    required String pluginId,
    required String currentVersion,
    required String pluginInstallPath,
    void Function(String stage, double progress)? onProgress,
  }) async {
    await initialize();
    
    try {
      // 步骤1: 检查更新
      onProgress?.call('checking', 0.0);
      print('🔍 检查更新: $pluginId');
      
      final updateInfo = await checkUpdate(
        pluginId: pluginId,
        currentVersion: currentVersion,
        forceRefresh: true,
      );
      
      if (updateInfo == null || !updateInfo.hasUpdate) {
        print('✅ 已是最新版本');
        return InstallResult.success(
          pluginId: pluginId,
          version: currentVersion,
        );
      }
      
      onProgress?.call('checking', 1.0);
      print('🆕 发现新版本: ${updateInfo.latestVersion}');
      
      // 步骤2: 下载更新
      onProgress?.call('downloading', 0.0);
      print('📥 下载更新包...');
      
      final packagePath = await downloadUpdate(
        updateInfo: updateInfo,
        onProgress: (progress) {
          onProgress?.call('downloading', progress.percentage / 100);
        },
      );
      
      onProgress?.call('downloading', 1.0);
      print('✅ 下载完成: $packagePath');
      
      // 步骤3: 安装更新
      onProgress?.call('installing', 0.0);
      print('🔧 安装更新...');
      
      final result = await installUpdate(
        pluginId: pluginId,
        version: updateInfo.latestVersion,
        packagePath: packagePath,
        pluginInstallPath: pluginInstallPath,
        createBackup: true,
      );
      
      onProgress?.call('installing', 1.0);
      
      if (result.isSuccess) {
        print('✅ 更新完成: $pluginId v${updateInfo.latestVersion}');

        // 验证更新是否成功
        print('🔍 验证更新...');
        final isVerified = await _verifyUpdateSuccess(pluginId, updateInfo.latestVersion, pluginInstallPath);
        if (isVerified) {
          print('✅ 更新验证成功: $pluginId v${updateInfo.latestVersion}');
        } else {
          print('⚠️ 更新验证失败，但安装已成功');
        }
      } else {
        print('❌ 更新失败: ${result.error}');
      }

      return result;
    } catch (e, stackTrace) {
      print('❌ 更新流程失败: $e');
      print(stackTrace);

      return InstallResult.failed(
        pluginId: pluginId,
        version: currentVersion,
        error: e.toString(),
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// 验证更新是否成功
  Future<bool> _verifyUpdateSuccess(String pluginId, String expectedVersion, String pluginPath) async {
    try {
      // 方法1: 检查文件是否存在
      final pluginDir = Directory(pluginPath);
      if (!await pluginDir.exists()) {
        print('❌ 插件目录不存在: $pluginPath');
        return false;
      }

      // 方法2: 尝试加载插件元数据
      final loader = PluginMetadataLoader();
      final metadata = await loader.loadFromFile(pluginPath);

      if (metadata.version != expectedVersion) {
        print('❌ 版本不匹配: 期望 ${expectedVersion}, 实际 ${metadata.version}');
        return false;
      }

      print('✅ 元数据验证成功: ${metadata.name} v${metadata.version}');
      return true;
    } catch (e) {
      print('❌ 更新验证失败: $e');
      return false;
    }
  }

  /// 批量更新
  /// 
  /// [updates] 要更新的插件列表
  /// [pluginInstallPaths] 插件安装路径映射
  /// [onProgress] 进度回调
  Future<Map<String, InstallResult>> batchUpdate({
    required List<UpdateInfo> updates,
    required Map<String, String> pluginInstallPaths,
    void Function(String pluginId, String stage, double progress)? onProgress,
  }) async {
    await initialize();
    
    final results = <String, InstallResult>{};
    
    print('📦 批量更新: ${updates.length} 个插件');
    
    for (var i = 0; i < updates.length; i++) {
      final update = updates[i];
      final pluginId = update.pluginId;
      final installPath = pluginInstallPaths[pluginId];
      
      if (installPath == null) {
        print('⚠️ 未找到安装路径: $pluginId');
        results[pluginId] = InstallResult.failed(
          pluginId: pluginId,
          version: update.latestVersion,
          error: '未找到安装路径',
        );
        continue;
      }
      
      print('[${ i + 1}/${updates.length}] 更新: $pluginId');
      
      final result = await performFullUpdate(
        pluginId: pluginId,
        currentVersion: update.currentVersion,
        pluginInstallPath: installPath,
        onProgress: (stage, progress) {
          onProgress?.call(pluginId, stage, progress);
        },
      );
      
      results[pluginId] = result;
    }
    
    final successCount = results.values.where((r) => r.isSuccess).length;
    print('✅ 批量更新完成: $successCount/${updates.length} 成功');
    
    return results;
  }

  // ==================== 清理 ====================

  /// 清理所有缓存和临时文件
  Future<void> cleanup() async {
    await Future.wait([
      _detector.clearCache(),
      _downloader.cleanupDownloads(),
      _backupManager.cleanupAllBackups(),
    ]);
    
    print('🧹 清理完成');
  }
}
