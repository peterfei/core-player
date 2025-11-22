import 'package:flutter_test/flutter_test.dart';
import 'package:yinghe_player/services/file_source/smb_file_source.dart';
import 'package:yinghe_player/services/smb_connection_pool.dart';

void main() {
  group('SMBFileSource', () {
    test('should initialize correctly', () {
      final source = SMBFileSource(
        id: 'test-id',
        name: 'Test SMB',
        host: '192.168.1.100',
        username: 'user',
        password: 'password',
      );

      expect(source.id, 'test-id');
      expect(source.name, 'Test SMB');
      expect(source.type, 'smb');
      expect(source.host, '192.168.1.100');
      expect(source.port, 445);
    });

    test('should use custom port', () {
      final source = SMBFileSource(
        id: 'test-id',
        name: 'Test SMB',
        host: '192.168.1.100',
        port: 1445,
      );

      expect(source.port, 1445);
    });
    
    // Note: Deep testing requires mocking SMBClient which is hard without dependency injection
    // or an interface wrapper. For now we test initialization logic.
  });
  
  group('SMBConnectionPool', () {
    test('should be a singleton', () {
      final pool1 = SMBConnectionPool();
      final pool2 = SMBConnectionPool();
      
      expect(pool1, same(pool2));
    });
  });
}
