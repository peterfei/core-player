
abstract class FileSource {
  String get id;
  String get name;
  String get type; // 'local', 'smb', 'webdav'
  
  Future<void> connect();
  Future<void> disconnect();
  Future<List<FileItem>> listFiles(String path);
  Future<bool> isDirectory(String path);
}

class FileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? modified;

  FileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.modified,
  });
}
