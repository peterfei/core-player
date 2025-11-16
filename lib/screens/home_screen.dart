import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:yinghe_player/screens/player_screen.dart';
import 'package:yinghe_player/screens/settings_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _pickAndPlayVideo() async {
    // Pick a file
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true, // 重要：确保获取文件数据
    );

    if (result != null) {
      if (!kIsWeb && result.files.single.path != null) {
        // 非 Web 平台：使用文件路径
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerScreen(
                videoFile: File(result.files.single.path!),
              ),
            ),
          );
        }
      } else if (kIsWeb && result.files.single.bytes != null) {
        // Web 平台：使用文件字节数据
        if (mounted) {
          // 对于 Web 平台，我们需要创建一个临时 URL
          final blob = Uri.dataFromBytes(
            result.files.single.bytes!,
            mimeType: result.files.single.extension != null
                ? 'video/${result.files.single.extension}'
                : 'video/mp4',
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerScreen(
                videoFile: File(''), // 传入空文件，我们将在播放器中处理 Web 情况
                webVideoUrl: blob.toString(),
                webVideoName: result.files.single.name,
              ),
            ),
          );
        }
      }
    }
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('影核播放器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _navigateToSettings,
          ),
        ],
      ),
      body: const Center(
        child: Text('媒体库为空'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndPlayVideo,
        tooltip: '选择视频',
        child: const Icon(Icons.add),
      ),
    );
  }
}
