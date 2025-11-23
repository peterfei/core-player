
abstract class FileSource {
  String get id;
  String get name;
  String get type; // 'local', 'smb', 'webdav'
  
  Future<void> connect();
  Future<void> disconnect();
  Future<List<FileItem>> listFiles(String path);
  Future<bool> isDirectory(String path);
  
  /// 打开文件读取流
  /// [start] 起始字节位置（包含）
  /// [end] 结束字节位置（包含）
  Stream<List<int>> openRead(String path, [int? start, int? end]);

  /// 获取单个文件信息（用于直接获取大小，无需列出目录）
  Future<FileItem?> getFileInfo(String path);
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
