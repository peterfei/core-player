import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../theme/design_tokens/design_tokens.dart';
import '../models/media_server_config.dart';
import '../services/media_server_service.dart';
import '../services/file_source_factory.dart';
import '../services/media_scanner_service.dart';
import '../services/media_library_service.dart';
import '../services/file_source/file_source.dart';
import '../services/auto_scraper_service.dart';
import '../services/series_service.dart';
import '../services/macos_bookmark_service.dart';
import '../core/plugin_system/edition_config.dart';
import 'add_server_page.dart';
import 'shared_folder_management_page.dart';

class MediaServerListPage extends StatefulWidget {
  const MediaServerListPage({super.key});

  @override
  State<MediaServerListPage> createState() => _MediaServerListPageState();
}

class _MediaServerListPageState extends State<MediaServerListPage> {
  List<MediaServerConfig> _servers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  Future<void> _loadServers() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final servers = MediaServerService.getServers();
      if (mounted) {
        setState(() {
          _servers = servers;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading servers: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addLocalFolder() async {
    try {
      // 使用文件选择器选择文件夹
      final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      
      if (selectedDirectory == null) {
        return; // 用户取消了选择
      }

      print('📁 用户选择了文件夹: $selectedDirectory');

      // 在 macOS 上创建 Security Scoped Bookmark
      if (Platform.isMacOS) {
        final bookmark = await MacOSBookmarkService.createBookmark(selectedDirectory);
        if (bookmark != null) {
          print('✅ 已为文件夹创建书签: $selectedDirectory');
        } else {
          print('⚠️ 创建书签失败,但继续扫描');
        }
      }

      // 显示扫描进度对话框
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            '正在扫描',
            style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.medium),
              Text(
                '正在扫描本地文件夹...',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );

      // 扫描文件夹
      final directory = Directory(selectedDirectory);
      final List<ScannedVideo> scannedVideos = [];
      
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final ext = path.extension(entity.path).toLowerCase();
          const videoExtensions = {'.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.ts', '.m2ts', '.mpg', '.mpeg'};
          
          if (videoExtensions.contains(ext)) {
            final stat = await entity.stat();
            scannedVideos.add(ScannedVideo(
              path: entity.path,
              name: path.basename(entity.path),
              sourceId: 'local',
              size: stat.size,
              addedAt: DateTime.now(),
            ));
          }
        }
      }

      // 保存到媒体库
      await MediaLibraryService.addVideos(scannedVideos);

      // 更新剧集分组
      final allVideos = MediaLibraryService.getAllVideos();
      await SeriesService.processAndSaveSeries(allVideos);

      if (mounted) {
        Navigator.of(context).pop(); // 关闭扫描进度对话框
        
        // 检查是否启用自动刮削
        const autoScrapeEnabled = true;
        
        if (autoScrapeEnabled && scannedVideos.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '后台刮削已开始,共 ${scannedVideos.length} 个视频',
                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 3),
            ),
          );
          
          // 后台执行刮削
          AutoScraperService.autoScrapeVideos(
            scannedVideos,
            onProgress: (current, total, status) {
              print('🤖 刮削进度: $current/$total - $status');
            },
          ).then((result) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '自动刮削完成: $result',
                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                  ),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 4),
                ),
              );
              _loadServers();
            }
          }).catchError((error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('自动刮削失败: $error'),
                  backgroundColor: AppColors.error,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('扫描完成,添加了 ${scannedVideos.length} 个视频'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // 关闭进度对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('扫描失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _scanServer(MediaServerConfig config) async {
    // 创建 FileSource
    final source = FileSourceFactory.createFromConfig(config);
    
    if (source == null) {
      if (mounted) {
        String message = '不支持的服务器类型: ${config.type}';

        // 检查是否是社区版SMB限制
        if (config.type.toLowerCase() == 'smb' && EditionConfig.isCommunityEdition) {
          _showUpgradeDialog(context);
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      return;
    }

    // 连接并获取共享列表（仅对 SMB）
    List<String>? sharesToScan;
    if (config.type.toLowerCase() == 'smb') {
      try {
        await source.connect();
        final shares = await source.listFiles('/');
        await source.disconnect();
        
        if (!mounted) return;
        
        // 显示共享选择对话框
        final selectedShare = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(
              '选择要扫描的共享',
              style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimary),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.select_all, color: AppColors.primary),
                    title: Text(
                      '扫描所有共享',
                      style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
                    ),
                    onTap: () => Navigator.pop(context, 'ALL'),
                  ),
                  const Divider(),
                  ...shares.map((share) => ListTile(
                    leading: const Icon(Icons.folder_shared, color: AppColors.textSecondary),
                    title: Text(
                      share.name,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                    ),
                    onTap: () => Navigator.pop(context, share.path),
                  )),
                ],
              ),
            ),
          ),
        );
        
        if (selectedShare == null) return; // 用户取消
        
        if (selectedShare == 'ALL') {
          sharesToScan = shares.map((s) => s.path).toList();
        } else {
          sharesToScan = [selectedShare];
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('获取共享列表失败: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    } else {
      // 非 SMB 服务器，从根目录扫描
      sharesToScan = ['/'];
    }

    // 更新服务器配置，保存或合并共享文件夹列表
    final existingFolders = config.sharedFolders ?? [];
    final allFolders = {...existingFolders, ...sharesToScan}.toList();
    final updatedConfig = config.copyWith(sharedFolders: allFolders);
    await MediaServerService.updateServer(updatedConfig);

    // 显示扫描进度对话框
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          '正在扫描',
          style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.medium),
            Text(
              '正在扫描 ${config.name}...\n扫描 ${sharesToScan?.length ?? 0} 个共享',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );

    try {
      final allFiles = <FileItem>[];
      
      // 扫描所有选定的共享
      for (final sharePath in sharesToScan) {
        print('🔍 扫描共享: $sharePath');
        final files = await MediaScannerService.instance.scanSource(source, sharePath);
        allFiles.addAll(files);
      }
      
      // 保存到媒体库
      final scannedVideos = allFiles.map((f) => ScannedVideo(
        path: f.path,
        name: f.name,
        sourceId: source.id,
        size: f.size,
        addedAt: DateTime.now(),
      )).toList();
      
      await MediaLibraryService.addVideos(scannedVideos);

      // Update Series Grouping
      final allVideos = MediaLibraryService.getAllVideos();
      await SeriesService.processAndSaveSeries(allVideos);

      if (mounted) {
        Navigator.of(context).pop(); // 关闭扫描进度对话框
        
        // 检查是否启用自动刮削
        // final autoScrapeEnabled = await SettingsService.getAutoScrapeEnabled();
        const autoScrapeEnabled = true; // 强制启用自动刮削
        
        if (autoScrapeEnabled && scannedVideos.isNotEmpty) {
          // 立即显示开始通知
          if (!mounted) return;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '后台刮削已开始，共 ${scannedVideos.length} 个剧集',
                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 3),
            ),
          );
          
          // 后台执行刮削，不阻塞UI
          AutoScraperService.autoScrapeVideos(
            scannedVideos,
            onProgress: (current, total, status) {
              print('🤖 刮削进度: $current/$total - $status');
            },
          ).then((result) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '自动刮削完成: $result',
                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                  ),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 4),
                ),
              );
              _loadServers(); // 刷新列表
            }
          }).catchError((error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('自动刮削失败: $error'),
                  backgroundColor: AppColors.error,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          });
        } else {
          // 没有启用自动刮削，直接显示扫描完成
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('扫描完成，添加了 ${allFiles.length} 个视频'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // 关闭进度对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('扫描失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _manageSharedFolders(MediaServerConfig config) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SharedFolderManagementPage(server: config),
      ),
    );
    
    // 返回后刷新服务器列表
    _loadServers();
  }

  Future<void> _deleteServer(MediaServerConfig config) async {
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          '删除服务器',
          style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          '确定要删除 ${config.name} 吗？',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await MediaServerService.removeServer(config.id);
        _loadServers(); // 重新加载列表
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('服务器已删除')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          '影视服务器',
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: _loadServers,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 已添加的服务器部分
                  if (_servers.isNotEmpty) ...[
                    Text(
                      '已添加的服务器',
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    ..._servers.map((server) => _buildServerCard(server)),
                    const SizedBox(height: AppSpacing.large),
                    const Divider(height: AppSpacing.large),
                  ],
                  
                  // 添加新服务器部分
                  Text(
                    '连接到...',
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  _buildProviderItem(
                    context,
                    'Emby',
                    'assets/icons/emby.png',
                    Colors.green,
                    'emby',
                  ),
                  _buildProviderItem(
                    context,
                    'Jellyfin',
                    'assets/icons/jellyfin.png',
                    Colors.purple,
                    'jellyfin',
                  ),
                  _buildProviderItem(
                    context,
                    'Plex',
                    'assets/icons/plex.png',
                    Colors.orange,
                    'plex',
                  ),
                  _buildProviderItem(
                    context,
                    '飞牛私有云',
                    'assets/icons/feiniu.png',
                    Colors.blue,
                    'feiniu',
                  ),
                  _buildProviderItem(
                    context,
                    '群晖 NAS',
                    'assets/icons/synology.png',
                    Colors.blueGrey,
                    'synology',
                  ),
                  const Divider(height: AppSpacing.large),
                  Text(
                    '本地文件夹',
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  _buildLocalFolderItem(context),
                  const Divider(height: AppSpacing.large),
                  Text(
                    '网络共享',
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  _buildProviderItem(
                    context,
                    'SMB',
                    'assets/icons/smb.png',
                    Colors.indigo,
                    'smb',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildServerCard(MediaServerConfig server) {
    final sharedFolders = server.sharedFolders ?? [];
    
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: AppSpacing.medium),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getServerColor(server.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Icon(
                    Icons.dns,
                    color: _getServerColor(server.type),
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.medium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.micro),
                      Text(
                        '${server.type.toUpperCase()} • ${server.url}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.error,
                  onPressed: () => _deleteServer(server),
                  tooltip: '删除',
                ),
              ],
            ),
            
            // 显示共享文件夹列表
            if (sharedFolders.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.medium),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.small),
              Text(
                '已添加的共享文件夹 (${sharedFolders.length})',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              ...sharedFolders.take(3).map((folder) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_outlined,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(
                      child: Text(
                        folder,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
              if (sharedFolders.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '  +${sharedFolders.length - 3} 个更多...',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
            
            const SizedBox(height: AppSpacing.medium),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _scanServer(server),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('扫描媒体库'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                if (sharedFolders.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _manageSharedFolders(server),
                      icon: const Icon(Icons.folder_special_outlined, size: 18),
                      label: const Text('管理共享'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.secondary,
                        side: BorderSide(color: AppColors.secondary),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getServerColor(String type) {
    switch (type.toLowerCase()) {
      case 'emby':
        return Colors.green;
      case 'jellyfin':
        return Colors.purple;
      case 'plex':
        return Colors.orange;
      case 'smb':
        return Colors.indigo;
      case 'feiniu':
        return Colors.blue;
      case 'synology':
        return Colors.blueGrey;
      default:
        return AppColors.primary;
    }
  }

  Widget _buildLocalFolderItem(BuildContext context) {
    return InkWell(
      onTap: _addLocalFolder,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.medium,
          horizontal: AppSpacing.small,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: const Icon(Icons.folder_open, color: Colors.blue, size: 20),
            ),
            const SizedBox(width: AppSpacing.medium),
            Text(
              '本地文件夹',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderItem(
    BuildContext context,
    String name,
    String iconPath,
    Color iconColor,
    String type,
  ) {
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddServerPage(serverType: type, serverName: name),
          ),
        );
        // 返回后刷新列表
        _loadServers();
      },
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.medium,
          horizontal: AppSpacing.small,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Icon(Icons.dns, color: iconColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.medium),
            Text(
              name,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('专业版功能'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.upgrade, size: 48, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'SMB/CIFS 网络共享仅在专业版中可用',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              '升级到专业版，解锁以下功能：',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Column(
              children: [
                _FeatureItem(Icons.share, 'SMB/CIFS 网络共享'),
                _FeatureItem(Icons.cloud, 'Emby/Jellyfin/Plex 支持'),
                _FeatureItem(Icons.hd, '4K/8K 超高清播放'),
                _FeatureItem(Icons.subtitles, '高级字幕支持'),
                _FeatureItem(Icons.equalizer, '专业音效处理'),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '立即升级，享受完整的媒体管理体验！',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('暂时跳过'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: 实现升级按钮功能
              // 可以使用 url_launcher 包打开升级链接
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('升级功能即将开放')),
              );
            },
            child: const Text('立即升级'),
          ),
        ],
      ),
    );
  }
}

/// 功能项显示组件
class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureItem(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
