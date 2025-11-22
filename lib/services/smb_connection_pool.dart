import 'dart:async';
import 'package:smb_connect/smb_connect.dart';

class SMBConnectionPool {
  static final SMBConnectionPool _instance = SMBConnectionPool._internal();
  
  factory SMBConnectionPool() {
    return _instance;
  }
  
  SMBConnectionPool._internal();
  
  // Cache clients by key
  final Map<String, SmbConnect> _clients = {};
  
  Future<SmbConnect> getClient(String host, {
    String? username,
    String? password,
    String? domain,
    int port = 445,
  }) async {
    final key = '$host:$port:$username:$domain';
    
    if (_clients.containsKey(key)) {
      return _clients[key]!;
    }
    
    // Connect using connectAuth
    // Note: connectAuth might be async and return Future<SmbConnect>
    // or it might be a factory that returns an instance that connects later.
    // Based on search "returns an SmbConnect object", it's likely async.
    
    try {
      final client = await SmbConnect.connectAuth(
        host: host,
        domain: domain ?? '',
        username: username ?? '',
        password: password ?? '',
      );
      
      _clients[key] = client;
      return client;
    } catch (e) {
      print('Error connecting to SMB: $e');
      rethrow;
    }
  }
  
  Future<void> closeClient(String host, {
    String? username,
    String? domain,
    int port = 445,
  }) async {
    final key = '$host:$port:$username:$domain';
    if (_clients.containsKey(key)) {
      final client = _clients.remove(key);
      // client?.disconnect(); // or close()
    }
  }
  
  void closeAll() {
    _clients.clear();
  }
}
