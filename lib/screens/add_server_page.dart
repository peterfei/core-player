import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../theme/design_tokens/design_tokens.dart';
import '../models/media_server_config.dart';
import '../services/media_server_service.dart';
import '../services/file_source/smb_file_source.dart';
import '../services/file_source_factory.dart';
import '../services/media_scanner_service.dart';
import '../services/media_library_service.dart';
import '../services/file_source/file_source.dart';
import '../services/auto_scraper_service.dart';
import '../services/settings_service.dart';

class AddServerPage extends StatefulWidget {
  final String serverType;
  final String serverName;

  const AddServerPage({
    super.key,
    required this.serverType,
    required this.serverName,
  });

  @override
  State<AddServerPage> createState() => _AddServerPageState();
}

class _AddServerPageState extends State<AddServerPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _tokenController = TextEditingController();
  final _domainController = TextEditingController();
  final _portController = TextEditingController(text: '445');
  bool _isLoading = false;

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _tokenController.dispose();
    _domainController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _saveServer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 验证连接
      if (_isSmbServer) {
        await _testSmbConnection();
      }

      final config = MediaServerConfig(
        id: const Uuid().v4(),
        type: widget.serverType,
        name: widget.serverName,
        url: _isSmbServer ? _parseHost(_urlController.text) : _urlController.text,
        username: _usernameController.text,
        token: _tokenController.text,
        domain: _domainController.text.isEmpty ? null : _domainController.text,
        port: _portController.text.isEmpty ? null : int.tryParse(_portController.text),
        sharedFolders: [], // 初始为空，扫描时会更新
      );

      await MediaServerService.addServer(config);

      if (mounted) {
        // 询问是否立即扫描
        final shouldScan = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(
              '服务器添加成功',
              style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimary),
            ),
            content: Text(
              '是否立即扫描媒体文件？',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('稍后', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('立即扫描'),
              ),
            ],
          ),
        );

        if (shouldScan == true) {
          // 立即扫描
          await _scanServer(config);
        } else {
          // 不扫描，直接返回
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 解析主机名，去除协议前缀和端口号
  String _parseHost(String input) {
    String host = input.trim();
    
    // 去除协议前缀 (http://, https://, smb://, etc.)
    final protocolPattern = RegExp(r'^[a-zA-Z]+://');
    host = host.replaceFirst(protocolPattern, '');
    
    // 分离主机名和端口号
    // 如果用户输入了 host:port 格式，我们只取主机名部分
    // 注意：IPv6 地址用 [] 包裹，如 [::1]:445
    if (host.contains('[')) {
      // IPv6 格式
      final match = RegExp(r'\[([^\]]+)\]').firstMatch(host);
      if (match != null) {
        return match.group(1)!;
      }
    }
    
    // IPv4 或域名格式，取冒号之前的部分
    final colonIndex = host.indexOf(':');
    if (colonIndex != -1) {
      host = host.substring(0, colonIndex);
    }
    
    return host;
  }

  Future<void> _testSmbConnection() async {
    final source = SMBFileSource(
      id: 'test',
      name: 'test',
      host: _parseHost(_urlController.text),
      port: int.tryParse(_portController.text) ?? 445,
      username: _usernameController.text.isEmpty ? null : _usernameController.text,
      password: _tokenController.text.isEmpty ? null : _tokenController.text,
      domain: _domainController.text.isEmpty ? null : _domainController.text,
    );

    try {
      await source.connect();
      // 尝试列出共享以验证连接
      await source.listFiles('/');
      await source.disconnect();
    } catch (e) {
      throw Exception('SMB 连接失败: $e');
    }
  }

  Future<void> _scanServer(MediaServerConfig config) async {
    // 创建 FileSource
    final source = FileSourceFactory.createFromConfig(config);
    
    if (source == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('不支持的服务器类型: ${config.type}')),
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

    // 更新服务器配置，保存共享文件夹列表
    final updatedConfig = config.copyWith(sharedFolders: sharesToScan);
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

      if (mounted) {
        Navigator.of(context).pop(); // 关闭扫描进度对话框
        
        // 检查是否启用自动刮削
        final autoScrapeEnabled = await SettingsService.getAutoScrapeEnabled();
        
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
          
          // 立即返回上一页，不等待刮削完成
          Navigator.of(context).pop();
          
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
          // 没有启用自动刮削，直接返回
          Navigator.of(context).pop();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '扫描完成，添加了 ${allFiles.length} 个视频',
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // 关闭进度对话框
        Navigator.of(context).pop(); // 返回上一页
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('扫描失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  bool get _isSmbServer => widget.serverType.toLowerCase() == 'smb';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          '添加 ${widget.serverName}',
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(
                controller: _urlController,
                label: _isSmbServer ? '服务器地址 (主机名或IP)' : '服务器地址 (URL)',
                hint: _isSmbServer ? '192.168.1.100 或 nas.local' : 'http://example.com:8096',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入服务器地址';
                  }
                  if (!_isSmbServer && !Uri.parse(value).isAbsolute) {
                    return '请输入有效的 URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.medium),
              if (_isSmbServer) ...{
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _portController,
                        label: '端口',
                        hint: '445',
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final port = int.tryParse(value);
                            if (port == null || port < 1 || port > 65535) {
                              return '无效端口';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.medium),
                    Expanded(
                      child: _buildTextField(
                        controller: _domainController,
                        label: '工作组/域 (可选)',
                        hint: 'WORKGROUP',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.medium),
              },
              _buildTextField(
                controller: _usernameController,
                label: '用户名',
              ),
              const SizedBox(height: AppSpacing.medium),
              _buildTextField(
                controller: _tokenController,
                label: '密码 / Token',
                obscureText: true,
              ),
              const SizedBox(height: AppSpacing.xLarge),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveServer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.medium),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        '连接',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyLarge.copyWith(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.medium,
              vertical: AppSpacing.medium,
            ),
          ),
        ),
      ],
    );
  }
}
