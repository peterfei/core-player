import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:yinghe_player/services/file_source/smb_file_source.dart';

class VLCTestScreen extends StatefulWidget {
  const VLCTestScreen({super.key});

  @override
  State<VLCTestScreen> createState() => _VLCTestScreenState();
}

class _VLCTestScreenState extends State<VLCTestScreen> {
  late final Player _player;
  late final VideoController _controller;
  final TextEditingController _urlController = TextEditingController();
  bool _isPlayerInitialized = false;
  String _statusMessage = 'Initializing...';
  String? _errorMessage;
  
  // Proxy related
  HttpServer? _proxyServer;
  String? _proxyUrl;
  SMBFileSource? _currentSource;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    // Pre-fill with encoded URL
    // Original: /迅雷/下载/zmqs.2023.BD1080p.gysy.zysz.mp4
    const rawPath = '/迅雷/下载/zmqs.2023.BD1080p.gysy.zysz.mp4';
    // Encode path segments
    final encodedPath = Uri.encodeFull(rawPath);
    _urlController.text = 'smb://peterfei:Yjnui!109@192.168.3.101$encodedPath';
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _statusMessage = 'Initializing media_kit...';
      _errorMessage = null;
    });

    try {
      // Create a Player instance with configuration
      _player = Player(
        configuration: const PlayerConfiguration(
          logLevel: MPVLogLevel.debug, // Enable debug logs
        ),
      );
      
      // Set MPV properties to bypass proxy
      if (_player.platform is NativePlayer) {
        final nativePlayer = _player.platform as NativePlayer;
        
        print('MPV: Checking initial http-proxy: ${await nativePlayer.getProperty('http-proxy')}');
        
        // Try to force empty proxy
        await nativePlayer.setProperty('http-proxy', '');
        
        // Also try to set stream-lavf-o to clear http_proxy for ffmpeg
        // Format for stream-lavf-o is Key=Value,Key=Value
        await nativePlayer.setProperty('stream-lavf-o', 'http_proxy=');
        
        // Optimize for network playback
        await nativePlayer.setProperty('cache', 'yes');
        await nativePlayer.setProperty('demuxer-max-bytes', '${256 * 1024 * 1024}'); // 256MB
        await nativePlayer.setProperty('demuxer-readahead-secs', '60');
        await nativePlayer.setProperty('hwdec', 'auto');
        
        print('MPV: Set http-proxy to empty. Current: ${await nativePlayer.getProperty('http-proxy')}');
        print('MPV: Set stream-lavf-o to http_proxy=');
        print('MPV: Enabled cache and hwdec');
      } else {
        print('MPV: Player is not NativePlayer, cannot set properties');
      }

      // Create a VideoController instance
      _controller = VideoController(_player);
      
      // Listen to player logs
      _player.stream.log.listen((event) {
        print('MPV: [${event.level}] ${event.prefix}: ${event.text}');
      });

      _player.stream.error.listen((event) {
        print('MPV Error: $event');
        setState(() {
          _errorMessage = 'Player Error: $event';
        });
      });
      
      setState(() {
        _isPlayerInitialized = true;
        _statusMessage = 'Ready (media_kit)';
      });
    } catch (e, stack) {
      print('Error initializing media_kit: $e');
      print(stack);
      setState(() {
        _isPlayerInitialized = false;
        _statusMessage = 'Initialization Failed';
        _errorMessage = '$e\n$stack';
      });
    }
  }

  @override
  void dispose() {
    _stopProxy();
    _player.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _stopProxy() async {
    await _proxyServer?.close(force: true);
    _proxyServer = null;
    _currentSource?.disconnect();
    _currentSource = null;
  }

  /// 获取本机的实际 IP 地址（非 loopback）
  Future<String> _getLocalIPAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final interface in interfaces) {
        if (interface.name.toLowerCase().contains('lo')) continue;
        for (final addr in interface.addresses) {
          if (addr.address.startsWith('192.168.') || addr.address.startsWith('10.')) {
            return addr.address;
          }
        }
      }
      
      // Fallback
      for (final interface in interfaces) {
        if (!interface.name.toLowerCase().contains('lo') && interface.addresses.isNotEmpty) {
          return interface.addresses.first.address;
        }
      }
      
      return '127.0.0.1';
    } catch (e) {
      print('Error getting local IP: $e');
      return '127.0.0.1';
    }
  }

  Future<void> _startProxy(String smbUrl) async {
    await _stopProxy();

    setState(() {
      _statusMessage = 'Starting internal proxy...';
    });

    try {
      final uri = Uri.parse(smbUrl);
      final userInfo = uri.userInfo.split(':');
      final username = userInfo.isNotEmpty ? userInfo[0] : null;
      final password = userInfo.length > 1 ? userInfo[1] : null;
      final host = uri.host;
      final port = uri.hasPort ? uri.port : 445;
      final path = Uri.decodeFull(uri.path);

      print('SMB Config: Host=$host, User=$username, Path=$path');

      _currentSource = SMBFileSource(
        id: 'test_smb',
        name: 'Test SMB',
        host: host,
        port: port,
        username: username,
        password: password,
      );

      await _currentSource!.connect();
      print('SMB Connected');
      
      // Fetch file size
      int fileSize = 0;
      try {
        final parentPath = path.substring(0, path.lastIndexOf('/'));
        final fileName = path.substring(path.lastIndexOf('/') + 1);
        
        print('Listing parent: $parentPath to find $fileName');
        final files = await _currentSource!.listFiles(parentPath.isEmpty ? '/' : parentPath);
        final fileItem = files.firstWhere((f) => f.name == fileName || f.path == path, orElse: () => throw Exception('File not found'));
        fileSize = fileItem.size;
        print('File size: $fileSize');
      } catch (e) {
        print('Error getting file size: $e');
      }

      // Use localhost for testing to avoid firewall/interface issues and potentially bypass proxy
      final localIp = 'localhost'; 
      _proxyServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final proxyPort = _proxyServer!.port;
      _proxyUrl = 'http://$localIp:$proxyPort/stream';

      print('Proxy started at $_proxyUrl');

      _proxyServer!.listen((HttpRequest request) async {
        print('Proxy Request: ${request.method} ${request.uri}');
        
        if (request.uri.path == '/ping') {
          request.response.write('pong');
          await request.response.close();
          return;
        }

        if (request.method == 'HEAD') {
           request.response.headers.contentType = ContentType('video', 'mp4');
           request.response.headers.add('Accept-Ranges', 'bytes');
           if (fileSize > 0) {
             request.response.headers.contentLength = fileSize;
           }
           await request.response.close();
           return;
        }
        
        try {
          request.response.headers.contentType = ContentType('video', 'mp4');
          request.response.headers.add('Access-Control-Allow-Origin', '*');
          request.response.headers.add('Accept-Ranges', 'bytes');

          final rangeHeader = request.headers.value('range');
          int start = 0;
          int? end;

          if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
            final parts = rangeHeader.substring(6).split('-');
            if (parts.isNotEmpty && parts[0].isNotEmpty) {
              start = int.parse(parts[0]);
            }
            if (parts.length > 1 && parts[1].isNotEmpty) {
              end = int.parse(parts[1]);
            }
          }
          
          if (end == null && fileSize > 0) {
            end = fileSize - 1;
          }

          print('Streaming range: $start - $end (Total: $fileSize)');
          
          if (start > 0 || (end != null && end! < (fileSize - 1))) {
             request.response.statusCode = HttpStatus.partialContent;
             if (fileSize > 0) {
                final actualEnd = end ?? (fileSize - 1);
                request.response.headers.add('Content-Range', 'bytes $start-$actualEnd/$fileSize');
                request.response.headers.contentLength = actualEnd - start + 1;
             }
          } else {
             request.response.statusCode = HttpStatus.ok;
             if (fileSize > 0) {
               request.response.headers.contentLength = fileSize;
             }
          }

          final stream = _currentSource!.openRead(path, start, end);
          await request.response.addStream(stream);
        } catch (e) {
          print('Proxy Error: $e');
          try {
            if (!request.response.headers.chunkedTransferEncoding) {
               request.response.statusCode = HttpStatus.internalServerError;
               request.response.write('Error: $e');
            }
          } catch (_) {}
        } finally {
          await request.response.close();
        }
      }, onError: (e) {
        print('HttpServer Error: $e');
      });

    } catch (e) {
      print('Error starting proxy: $e');
      setState(() {
        _errorMessage = 'Proxy Error: $e';
      });
      rethrow;
    }
  }

  Future<void> _playVideo() async {
    if (!_isPlayerInitialized) return;
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    FocusScope.of(context).unfocus();

    try {
      await _startProxy(url);

      if (_proxyUrl != null) {
        print('Playing Proxy URL: $_proxyUrl');
        setState(() {
          _statusMessage = 'Opening media stream...';
        });
        
        final media = Media(_proxyUrl!);
        await _player.open(media);
        
        setState(() {
          _statusMessage = 'Playing via Proxy';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMB Proxy Test (media_kit)'),
        actions: [
          if (_proxyUrl != null)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy Proxy URL',
              onPressed: () {
                print('Proxy URL: $_proxyUrl');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Proxy URL copied to console: $_proxyUrl')),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Status Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8.0),
            color: _errorMessage != null ? Colors.red.shade100 : Colors.grey.shade200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: $_statusMessage', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                if (_proxyUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('Proxy: $_proxyUrl', style: const TextStyle(fontSize: 10, color: Colors.blue)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      labelText: 'SMB URL',
                      hintText: 'smb://user:pass@host/share/file.mkv',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _urlController.clear();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isPlayerInitialized ? _playVideo : null,
                  child: const Text('Play'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isPlayerInitialized
                ? Video(
                    controller: _controller,
                    controls: MaterialVideoControls,
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}
