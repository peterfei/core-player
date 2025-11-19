import 'dart:io';
import 'package:path/path.dart' as p;
import 'file_source.dart';

class LocalFileSource implements FileSource {
  @override
  final String id;
  @override
  final String name;
  @override
  final String type = 'local';

  LocalFileSource({required this.id, required this.name});

  @override
  Future<void> connect() async {
    // Local filesystem is always connected
  }

  @override
  Future<void> disconnect() async {
    // Nothing to do
  }

  @override
  Future<List<FileItem>> listFiles(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      return [];
    }

    final List<FileItem> items = [];
    try {
      await for (final entity in dir.list(followLinks: false)) {
        final stat = await entity.stat();
        items.add(FileItem(
          name: p.basename(entity.path),
          path: entity.path,
          isDirectory: stat.type == FileSystemEntityType.directory,
          size: stat.size,
          modified: stat.modified,
        ));
      }
    } catch (e) {
      print('Error listing local files: $e');
    }
    
    // Sort: Directories first, then files, alphabetically
    items.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    
    return items;
  }

  @override
  Future<bool> isDirectory(String path) async {
    return FileSystemEntity.isDirectory(path);
  }
}
