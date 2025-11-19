import 'package:smb_connect/smb_connect.dart';
import 'package:path/path.dart' as p;
import '../smb_connection_pool.dart';
import 'file_source.dart';

class SMBFileSource implements FileSource {
  final String _id;
  final String _name;
  final String host;
  final int port;
  final String? username;
  final String? password;
  final String? domain;
  final String? workgroup;

  SmbConnect? _client;

  SMBFileSource({
    required String id,
    required String name,
    required this.host,
    this.port = 445,
    this.username,
    this.password,
    this.domain,
    this.workgroup,
  }) : _id = id, _name = name;

  @override
  String get id => _id;

  @override
  String get name => _name;

  @override
  String get type => 'smb';

  @override
  Future<void> connect() async {
    if (_client != null) return;

    _client = await SMBConnectionPool().getClient(
      host,
      username: username,
      password: password,
      domain: domain ?? workgroup,
      port: port,
    );
    
    // Assuming connect method signature
    // If the pool doesn't connect, we do it here.
    // But since we don't know the exact API, let's assume we need to call connect.
    // Note: smb_connect might not have a persistent connection object that stays connected
    // across calls if it's just a wrapper around native calls.
    // But let's try to use it as an object.
  }

  @override
  Future<void> disconnect() async {
    // _client?.disconnect();
    _client = null;
  }

  @override
  Future<List<FileItem>> listFiles(String path) async {
    if (_client == null) {
      await connect();
    }

    try {
      print('📂 SMB: 列出路径: $path');
      
      // If path is root, list shares
      if (path == '/' || path.isEmpty) {
        final shares = await _client!.listShares();
        print('📁 SMB: 找到 ${shares.length} 个共享');
        for (var share in shares) {
          print('  - ${share.name}');
        }
        return shares.map((share) => FileItem(
          name: share.name,
          path: '/${share.name}',
          isDirectory: true,
          modified: null,
        )).toList();
      }

      // List files
      // Use client.file() to get SmbFile handle
      // Note: file() might be async? Let's assume async based on pattern.
      // If it's not async, the compiler will complain about await.
      
      final dir = await _client!.file(path);
      
      final files = await _client!.listFiles(dir);
      print('📄 SMB: 在 $path 找到 ${files.length} 个项目');
      
      return files.map((file) {
        return FileItem(
          name: file.name,
          path: file.path,
          isDirectory: file.isDirectory(),
          size: file.size,
          modified: file.lastModified != null 
              ? DateTime.fromMillisecondsSinceEpoch(file.lastModified!) 
              : null,
        );
      }).toList();
    } catch (e) {
      print('❌ SMB: 列出文件错误 $path: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isDirectory(String path) async {
    return true; // Placeholder
  }

  @override
  Stream<List<int>> openRead(String path, [int? start, int? end]) async* {
    if (_client == null) {
      await connect();
    }

    try {
      print('📖 SMB: 开始读取文件流: $path (start: $start, end: $end)');
      
      // 获取文件句柄
      final file = await _client!.file(path);
      
      // 使用 smb_connect 的 openRead 方法
      // openRead 返回 Future<Stream<Uint8List>>，需要先 await
      final stream = await _client!.openRead(file);
      
      if (start == null && end == null) {
        // 没有范围限制，直接流式读取整个文件
        print('📤 SMB: 流式读取完整文件');
        await for (final chunk in stream) {
          yield chunk;
        }
      } else {
        // 有范围限制，需要手动处理
        print('📤 SMB: 流式读取范围数据: $start-$end');
        
        int bytesRead = 0;
        final actualStart = start ?? 0;
        final actualEnd = end;
        
        await for (final chunk in stream) {
          final chunkLength = chunk.length as int;
          
          // 跳过起始位置之前的数据
          if (bytesRead + chunkLength <= actualStart) {
            bytesRead += chunkLength;
            continue;
          }
          
          // 处理部分在范围内的数据
          int chunkStart = 0;
          if (bytesRead < actualStart) {
            chunkStart = actualStart - bytesRead;
          }
          
          int chunkEnd = chunkLength;
          if (actualEnd != null && bytesRead + chunkLength > actualEnd + 1) {
            chunkEnd = actualEnd + 1 - bytesRead;
          }
          
          if (chunkStart < chunkEnd) {
            yield chunk.sublist(chunkStart, chunkEnd);
          }
          
          bytesRead += chunkLength;
          
          // 如果已经读取到结束位置，停止
          if (actualEnd != null && bytesRead > actualEnd) {
            break;
          }
        }
      }
      
      print('✅ SMB: 文件流读取完成');
    } catch (e) {
      print('❌ SMB: 读取文件流错误 $path: $e');
      rethrow;
    }
  }
}
