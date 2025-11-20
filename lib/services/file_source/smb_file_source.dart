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
      
      Stream<List<int>> stream;
      bool nativeSeekUsed = false;
      
      if (start != null && start > 0) {
        try {
          // 尝试使用位置参数 (start, end)
          // 根据错误日志: Found: openRead(SmbFile, [int?, int?])
          // 注意: Dart 的 openRead 通常 end 是 exclusive 的，而 HTTP Range 是 inclusive 的
          // 所以我们需要 +1
          final effectiveEnd = end != null ? end + 1 : null;
          print('🔍 SMB: 尝试使用原生 seek (start: $start, end: $effectiveEnd)...');
          
          // 使用 dynamic 调用以匹配发现的签名
          stream = await (_client! as dynamic).openRead(file, start, effectiveEnd);
          
          nativeSeekUsed = true;
          print('✅ SMB: 原生 seek 调用成功');
        } catch (e) {
          print('⚠️ SMB: 原生 seek 失败: $e');
          print('🔄 SMB: 降级到流式跳过模式 (可能较慢)');
          stream = await _client!.openRead(file);
        }
      } else {
        // 如果没有 start，或者 start 为 0，尝试直接调用带参数的 openRead (0, end)
        // 或者回退到无参数调用
        if (end != null) {
           try {
              final effectiveEnd = end + 1;
              print('🔍 SMB: 尝试使用原生 seek (start: 0, end: $effectiveEnd)...');
              stream = await (_client! as dynamic).openRead(file, 0, effectiveEnd);
              nativeSeekUsed = true;
           } catch (e) {
              stream = await _client!.openRead(file);
           }
        } else {
           stream = await _client!.openRead(file);
        }
      }
      
      if (start == null && end == null) {
        // 没有范围限制，直接流式读取整个文件
        print('📤 SMB: 流式读取完整文件');
        await for (final chunk in stream) {
          yield chunk;
        }
      } else {
        // 有范围限制，需要手动处理
        print('📤 SMB: 流式读取范围数据: $start-$end');
        
        int bytesRead = nativeSeekUsed ? (start ?? 0) : 0;
        final actualStart = start ?? 0;
        final actualEnd = end;
        
        // 缓冲区配置
        const int bufferSize = 64 * 1024; // 64KB buffer
        List<int> buffer = [];
        
        await for (final chunk in stream) {
          final chunkLength = chunk.length;
          
          // 如果使用了原生 seek，不需要跳过数据，除非 offset 不准确
          // 如果没使用原生 seek，需要跳过起始位置之前的数据
          if (!nativeSeekUsed && bytesRead + chunkLength <= actualStart) {
            bytesRead += chunkLength;
            continue;
          }
          
          // 处理部分在范围内的数据
          int chunkStart = 0;
          if (!nativeSeekUsed && bytesRead < actualStart) {
            chunkStart = actualStart - bytesRead;
          }
          
          int chunkEnd = chunkLength;
          if (actualEnd != null && bytesRead + chunkLength > actualEnd + 1) {
            chunkEnd = actualEnd + 1 - bytesRead;
          }
          
          if (chunkStart < chunkEnd) {
            // 优化：避免不必要的复制
            if (chunkStart == 0 && chunkEnd == chunkLength) {
              // 完整 chunk
              if (buffer.isEmpty && chunkLength >= bufferSize) {
                // 如果缓冲区为空且当前块足够大，直接发送
                yield chunk;
              } else {
                // 否则添加到缓冲区
                buffer.addAll(chunk);
              }
            } else {
              // 部分 chunk
              buffer.addAll(chunk.sublist(chunkStart, chunkEnd));
            }
            
            // 当缓冲区达到阈值时发送
            if (buffer.length >= bufferSize) {
              yield buffer;
              buffer = [];
            }
          }
          
          bytesRead += chunkLength;
          
          // 如果已经读取到结束位置，停止
          if (actualEnd != null && bytesRead > actualEnd) {
            break;
          }
        }
        
        // 发送剩余的缓冲数据
        if (buffer.isNotEmpty) {
          yield buffer;
        }
      }
      
      print('✅ SMB: 文件流读取完成');
    } catch (e) {
      print('❌ SMB: 读取文件流错误 $path: $e');
      rethrow;
    }
  }
}
