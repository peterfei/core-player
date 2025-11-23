import 'dart:async';
import 'dart:typed_data';
import 'package:smb_connect/smb_connect.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import '../../../core/plugin_system/media_server_plugin.dart';
import '../../../services/smb_connection_pool.dart';
import '../base/media_server_plugin.dart';

/// SMB 媒体服务器插件
///
/// 提供对 SMB/CIFS 网络共享的访问支持，
/// 包括浏览文件夹、扫描视频、流式播放等功能。
class SMBPlugin extends BaseMediaServerPlugin {
  final SMBConnectionPool _connectionPool = SMBConnectionPool();
  SmbConnect? _client;

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'com.coreplayer.smb',
    name: 'SMB/NAS',
    version: '1.0.0',
    description: 'SMB/CIFS 网络共享访问支持',
    author: 'CorePlayer Team',
    icon: Icons.folder_shared,
    capabilities: ['network-share', 'file-browsing', 'streaming'],
    permissions: [PluginPermission.network, PluginPermission.storage],
    homepage: 'https://core-player.com',
    repository: 'https://github.com/peterfei/core-player',
  );

  @override
  String get serverType => 'smb';

  @override
  List<String> get supportedProtocols => ['smb://'];

  @override
  PluginState get _state => _actualState;
  PluginState _actualState = PluginState.uninitialized;

  @override
  void _setStateInternal(PluginState state) {
    _actualState = state;
  }

  // ===== 连接管理 =====

  @override
  Future<ConnectionTestResult> testConnection(SMBServerConfig config) async {
    try {
      log('Testing SMB connection to ${config.host}:${config.port}');

      final startTime = DateTime.now();

      // 尝试建立连接
      final client = await SmbConnect.connectAuth(
        host: config.host,
        domain: config.domain ?? '',
        username: config.username,
        password: config.password,
      );

      final latency = DateTime.now().difference(startTime);

      // 测试访问共享目录
      final shares = await client.listShares();

      final serverInfo = {
        'host': config.host,
        'port': config.port,
        'domain': config.domain,
        'username': config.username,
        'shares': shares.map((s) => s.name).toList(),
        'shareCount': shares.length,
        'latencyMs': latency.inMilliseconds,
      };

      return ConnectionTestResult.success(
        message: 'Successfully connected to ${shares.length} shares',
        serverInfo: serverInfo,
        latency: latency,
      );
    } catch (e) {
      return _handleConnectionError(e, config);
    }
  }

  @override
  Future<void> doConnect(ServerConfig config) async {
    if (config is! SMBServerConfig) {
      throw ArgumentError('Expected SMBServerConfig, got ${config.runtimeType}');
    }

    _client = await _connectionPool.getClient(
      config.host,
      username: config.username,
      password: config.password,
      domain: config.domain,
      port: config.port,
    );

    log('Connected to SMB server: ${config.host}:${config.port}');
  }

  @override
  Future<void> doDisconnect() async {
    if (_client != null && currentConfig is SMBServerConfig) {
      final config = currentConfig as SMBServerConfig;
      await _connectionPool.closeClient(
        config.host,
        username: config.username,
        domain: config.domain,
        port: config.port,
      );
      _client = null;
    }
  }

  @override
  String? doValidateConfig(ServerConfig config) {
    if (config is! SMBServerConfig) {
      return 'Expected SMBServerConfig';
    }

    if (config.host.isEmpty) {
      return '服务器地址不能为空';
    }

    if (config.username.isEmpty) {
      return '用户名不能为空';
    }

    if (config.password.isEmpty) {
      return '密码不能为空';
    }

    if (config.port < 1 || config.port > 65535) {
      return '端口号必须在 1-65535 范围内';
    }

    if (config.share.isEmpty) {
      return '共享名称不能为空';
    }

    return null;
  }

  // ===== 媒体库操作 =====

  @override
  Future<List<MediaFolder>> getFolders() async {
    _ensureSMBConnected();

    try {
      final config = currentConfig as SMBServerConfig;
      final shares = await _client!.listShares();

      final folders = <MediaFolder>[];

      for (final share in shares) {
        // 尝试访问共享以验证是否可访问
        if (await _isShareAccessible(share.name)) {
          // 统计共享中的视频数量
          final videoCount = await _countVideosInShare(share.name);

          folders.add(MediaFolder(
            id: createFolderId(share.name, prefix: 'smb'),
            name: share.name,
            path: '/${share.name}',
            videoCount: videoCount,
          ));
        }
      }

      log('Found ${folders.length} accessible shares');
      return folders;
    } catch (e) {
      logError('Failed to get folders', e);
      rethrow;
    }
  }

  @override
  Future<List<VideoItem>> doScanVideos(MediaFolder? folder, ScanOptions options) async {
    _ensureSMBConnected();

    try {
      final folderPath = folder?.path ?? '/';
      final videoItems = <VideoItem>[];

      await _scanDirectory(folderPath, videoItems, options);

      log('Scanned ${videoItems.length} video files');
      return videoItems;
    } catch (e) {
      logError('Failed to scan videos', e);
      rethrow;
    }
  }

  @override
  Future<VideoMetadata?> doGetVideoMetadata(String videoId) async {
    try {
      // 从 videoId 解码文件路径
      final path = _decodeVideoId(videoId);

      final file = await _client!.file(path);

      return VideoMetadata(
        id: videoId,
        title: extractFileName(path),
        fileSize: file.size,
        resolution: _guessResolution(file.name),
      );
    } catch (e) {
      logError('Failed to get video metadata for $videoId', e);
      return null;
    }
  }

  @override
  Future<List<VideoItem>> doSearchVideos(String query, ScanOptions options) async {
    final allVideos = await doScanVideos(null, options);

    final queryLower = query.toLowerCase();
    return allVideos.where((video) {
      return video.title.toLowerCase().contains(queryLower) ||
             video.path.toLowerCase().contains(queryLower);
    }).toList();
  }

  @override
  Future<void> doRefreshLibrary(MediaFolder? folder) async {
    // SMB 插件不需要特殊的刷新逻辑
    // 下次扫描时会自动获取最新数据
    log('Library refresh completed');
  }

  // ===== 流媒体 =====

  @override
  Future<VideoStreamInfo> doGetVideoStream(String videoId, VideoQuality quality) async {
    _ensureSMBConnected();

    try {
      final path = _decodeVideoId(videoId);

      return VideoStreamInfo(
        url: 'smb://$path', // 实际使用时会通过代理服务
        streamType: StreamType.proxy,
        requiresProxy: true,
        quality: quality,
      );
    } catch (e) {
      logError('Failed to get video stream for $videoId', e);
      rethrow;
    }
  }

  @override
  Future<String?> doGetThumbnailUrl(String videoId) async {
    try {
      final path = _decodeVideoId(videoId);
      final config = currentConfig as SMBServerConfig;

      // SMB 不直接支持缩略图，返回本地代理 URL
      return 'http://localhost:8888/thumbnail/${Uri.encodeComponent(path)}';
    } catch (e) {
      logError('Failed to get thumbnail URL for $videoId', e);
      return null;
    }
  }

  @override
  Future<List<SubtitleTrack>> doGetSubtitleTracks(String videoId) async {
    try {
      final path = _decodeVideoId(videoId);
      final basePath = path.substring(0, path.lastIndexOf('.'));

      final subtitleTracks = <SubtitleTrack>[];

      // 常见字幕文件扩展名
      const subtitleExtensions = ['.srt', '.vtt', '.ass', '.ssa'];

      for (final ext in subtitleExtensions) {
        final subtitlePath = '$basePath$ext';
        if (await _fileExists(subtitlePath)) {
          subtitleTracks.add(SubtitleTrack(
            id: createVideoId(subtitlePath, prefix: 'subtitle'),
            language: _extractLanguageCode(subtitlePath),
            title: extractFileName(subtitlePath),
            format: ext.substring(1).toUpperCase(),
          ));
        }
      }

      return subtitleTracks;
    } catch (e) {
      logError('Failed to get subtitle tracks for $videoId', e);
      return [];
    }
  }

  @override
  Future<String?> doGetSubtitleContent(String videoId, String subtitleId) async {
    try {
      final path = _decodeVideoId(subtitleId);

      if (!await _fileExists(path)) {
        return null;
      }

      final file = await _client!.file(path);
      final content = await _readFileContent(file);

      return content;
    } catch (e) {
      logError('Failed to get subtitle content for $subtitleId', e);
      return null;
    }
  }

  // ===== 配置UI =====

  @override
  Widget buildAddServerScreen({
    required Function(ServerConfig) onSave,
    ServerConfig? initialConfig,
  }) {
    return SMBConfigScreen(
      onSave: onSave as Function(SMBServerConfig),
      initialConfig: initialConfig as SMBServerConfig?,
    );
  }

  @override
  Widget buildServerDetailScreen(ServerConfig config) {
    if (config is! SMBServerConfig) {
      return const SizedBox.shrink();
    }

    return SMBServerDetailScreen(config: config);
  }

  // ===== 私有方法 =====

  /// 确保 SMB 连接已建立
  void _ensureSMBConnected() {
    if (_client == null) {
      throw StateError('Not connected to SMB server');
    }
  }

  /// 处理连接错误
  ConnectionTestResult _handleConnectionError(dynamic error, SMBServerConfig config) {
    logError('SMB connection error', error);

    final errorMessage = error.toString().toLowerCase();

    if (errorMessage.contains('timeout') || errorMessage.contains('timed out')) {
      return ConnectionTestResult.timeout(
        message: 'Connection timeout to ${config.host}:${config.port}',
        suggestion: 'Check if the server is accessible and try again',
      );
    } else if (errorMessage.contains('authentication') ||
               errorMessage.contains('login') ||
               errorMessage.contains('credential') ||
               errorMessage.contains('access denied')) {
      return ConnectionTestResult.authenticationFailed(
        message: 'Authentication failed for ${config.host}',
        suggestion: 'Please check your username and password',
      );
    } else if (errorMessage.contains('not found') ||
               errorMessage.contains('unreachable') ||
               errorMessage.contains('no route')) {
      return ConnectionTestResult.serverNotFound(
        message: 'Server ${config.host} not found',
        suggestion: 'Please verify the server address and network connectivity',
      );
    } else {
      return ConnectionTestResult.networkError(
        message: 'Network error: ${error.toString()}',
        suggestion: 'Please check your network connection and server settings',
      );
    }
  }

  /// 检查共享是否可访问
  Future<bool> _isShareAccessible(String shareName) async {
    try {
      final files = await _client!.listFiles('/$shareName');
      return true;
    } catch (e) {
      log('Share $shareName is not accessible: $e');
      return false;
    }
  }

  /// 统计共享中的视频数量
  Future<int?> _countVideosInShare(String shareName) async {
    try {
      int count = 0;
      await _scanDirectory('/$shareName', [], ScanOptions(
        recursive: false,
        fileExtensions: supportedFileExtensions,
        includeHidden: false,
      ), countCallback: (items) {
        count = items.length;
      });
      return count;
    } catch (e) {
      log('Failed to count videos in share $shareName: $e');
      return null;
    }
  }

  /// 扫描目录查找视频文件
  Future<void> _scanDirectory(
    String path,
    List<VideoItem> videoItems,
    ScanOptions options, {
    Function(List<VideoItem>)? countCallback,
  }) async {
    if (path.isEmpty || path == '/') {
      // 列出共享
      final shares = await _client!.listShares();
      for (final share in shares) {
        if (await _isShareAccessible(share.name)) {
          final folder = MediaFolder(
            id: createFolderId(share.name, prefix: 'smb'),
            name: share.name,
            path: '/${share.name}',
          );

          if (options.recursive) {
            await _scanDirectory(folder.path, videoItems, options);
          }
        }
      }
      return;
    }

    try {
      final files = await _client!.listFiles(path);

      for (final file in files) {
        if (options.includeHidden || !file.name.startsWith('.')) {
          if (file.isDirectory()) {
            if (options.recursive) {
              // 检查深度限制
              final currentDepth = path.split('/').length - 1;
              if (options.maxDepth == null || currentDepth < options.maxDepth!) {
                await _scanDirectory(file.path, videoItems, options);
              }
            }
          } else if (isVideoFile(file.name)) {
            final videoItem = VideoItem(
              id: createVideoId(file.path, prefix: 'smb'),
              title: extractFileName(file.name),
              path: file.path,
              fileSize: file.size,
              createdAt: file.lastModified != null
                  ? DateTime.fromMillisecondsSinceEpoch(file.lastModified!)
                  : null,
              updatedAt: file.lastModified != null
                  ? DateTime.fromMillisecondsSinceEpoch(file.lastModified!)
                  : null,
            );

            videoItems.add(videoItem);

            // 检查最大结果限制
            if (options.maxResults != null && videoItems.length >= options.maxResults!) {
              break;
            }
          }
        }
      }

      countCallback?.call(videoItems);
    } catch (e) {
      logError('Failed to scan directory $path', e);
    }
  }

  /// 检查文件是否存在
  Future<bool> _fileExists(String path) async {
    try {
      final file = await _client!.file(path);
      return file.size >= 0; // 简单的存在性检查
    } catch (e) {
      return false;
    }
  }

  /// 读取文件内容
  Future<String> _readFileContent(SmbFile file) async {
    try {
      final chunks = <Uint8List>[];
      await for (final chunk in _client!.openRead(file)) {
        chunks.add(Uint8List.fromList(chunk));
      }

      final totalLength = chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
      final content = Uint8List(totalLength);

      int offset = 0;
      for (final chunk in chunks) {
        content.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      // 尝试不同的编码
      try {
        return String.fromCharCodes(content);
      } catch (e) {
        // 如果不是有效的 UTF-8，尝试其他编码或返回空字符串
        return '';
      }
    } catch (e) {
      logError('Failed to read file content', e);
      rethrow;
    }
  }

  /// 从视频 ID 解码文件路径
  String _decodeVideoId(String videoId) {
    // 简单的解码逻辑，实际实现可能需要更复杂的编码方案
    if (videoId.startsWith('smb_')) {
      return Uri.decodeComponent(videoId.substring(4));
    }
    return Uri.decodeComponent(videoId);
  }

  /// 提取语言代码
  String _extractLanguageCode(String subtitlePath) {
    final fileName = extractFileName(subtitlePath).toLowerCase();

    // 常见语言代码模式
    final patterns = [
      RegExp(r'\.([a-z]{2})\.\w+$'),
      RegExp(r'\.([a-z]{2})\-[a-z]{2}\.\w+$'),
      RegExp(r'\.([a-z]{3})\.\w+$'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(fileName);
      if (match != null) {
        return match.group(1) ?? 'unknown';
      }
    }

    return 'unknown';
  }

  /// 猜测视频分辨率
  String? _guessResolution(String fileName) {
    final name = fileName.toLowerCase();

    // 常见分辨率标识
    final patterns = {
      '4k': '3840x2160',
      '2160p': '3840x2160',
      '1080p': '1920x1080',
      '720p': '1280x720',
      '480p': '854x480',
      '360p': '640x360',
    };

    for (final entry in patterns.entries) {
      if (name.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  @override
  String _decodeConfig(String data) {
    // 实现 SMB 配置的解码逻辑
    // 这里简化处理，实际应该使用 JSON 解码
    return data;
  }
}

/// SMB 配置界面
class SMBConfigScreen extends StatefulWidget {
  final Function(SMBServerConfig) onSave;
  final SMBServerConfig? initialConfig;

  const SMBConfigScreen({
    Key? key,
    required this.onSave,
    this.initialConfig,
  }) : super(key: key);

  @override
  State<SMBConfigScreen> createState() => _SMBConfigScreenState();
}

class _SMBConfigScreenState extends State<SMBConfigScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _domainController;
  late TextEditingController _shareController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    final config = widget.initialConfig;
    _hostController = TextEditingController(text: config?.host ?? '');
    _portController = TextEditingController(text: config?.port.toString() ?? '445');
    _usernameController = TextEditingController(text: config?.username ?? '');
    _passwordController = TextEditingController(text: config?.password ?? '');
    _domainController = TextEditingController(text: config?.domain ?? '');
    _shareController = TextEditingController(text: config?.share ?? '');
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _domainController.dispose();
    _shareController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add SMB Server'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'Server Address',
                  hintText: '192.168.1.100',
                  prefixIcon: Icon(Icons.dns),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter server address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: '445',
                  prefixIcon: Icon(Icons.settings_ethernet),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter port number';
                  }
                  final port = int.tryParse(value);
                  if (port == null || port < 1 || port > 65535) {
                    return 'Please enter a valid port (1-65535)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _domainController,
                decoration: const InputDecoration(
                  labelText: 'Domain (Optional)',
                  hintText: 'WORKGROUP',
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _shareController,
                decoration: const InputDecoration(
                  labelText: 'Share Name',
                  hintText: 'videos',
                  prefixIcon: Icon(Icons.folder_shared),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter share name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _testConnection,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering),
                label: Text(_isLoading ? 'Testing...' : 'Test Connection'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveConfig,
                icon: const Icon(Icons.save),
                label: const Text('Save Configuration'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final config = SMBServerConfig(
        host: _hostController.text,
        port: int.parse(_portController.text),
        username: _usernameController.text,
        password: _passwordController.text,
        domain: _domainController.text.isEmpty ? null : _domainController.text,
        share: _shareController.text,
      );

      final plugin = SMBPlugin();
      await plugin.initialize();

      final result = await plugin.testConnection(config);

      if (mounted) {
        if (result.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Connection successful'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Connection failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed: $e'),
            backgroundColor: Colors.red,
          ),
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

  void _saveConfig() {
    if (!_formKey.currentState!.validate()) return;

    final config = SMBServerConfig(
      host: _hostController.text,
      port: int.parse(_portController.text),
      username: _usernameController.text,
      password: _passwordController.text,
      domain: _domainController.text.isEmpty ? null : _domainController.text,
      share: _shareController.text,
    );

    widget.onSave(config);
    Navigator.of(context).pop();
  }
}

/// SMB 服务器详情界面
class SMBServerDetailScreen extends StatelessWidget {
  final SMBServerConfig config;

  const SMBServerDetailScreen({
    Key? key,
    required this.config,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(config.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.dns),
              title: const Text('Server'),
              subtitle: Text(config.host),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_ethernet),
              title: const Text('Port'),
              subtitle: Text('${config.port}'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Username'),
              subtitle: Text(config.username),
            ),
          ),
          if (config.domain != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.business),
                title: const Text('Domain'),
                subtitle: Text(config.domain!),
              ),
            ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.folder_shared),
              title: const Text('Share'),
              subtitle: Text(config.share),
            ),
          ),
        ],
      ),
    );
  }
}