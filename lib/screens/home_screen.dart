import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:yinghe_player/screens/player_screen.dart';
import 'package:yinghe_player/screens/settings_screen.dart';
import 'package:yinghe_player/widgets/history_list.dart';
import 'package:yinghe_player/widgets/url_input_dialog.dart';
import 'package:yinghe_player/services/history_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  int _historyCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistoryCount();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadHistoryCount() async {
    final histories = await HistoryService.getHistories();
    if (mounted) {
      setState(() {
        _historyCount = histories.length;
      });
    }
  }

  Future<void> _playNetworkVideo() async {
    final url = await showUrlInputDialog(context);
    if (url != null) {
      // 导航到播放器播放网络视频
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PlayerScreen.network(videoPath: url),
        ),
      );
    }
  }
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
    ).then((_) {
      // 返回时刷新历史记录数量
      _loadHistoryCount();
    });
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.home_outlined),
              text: '媒体库',
            ),
            Tab(
              icon: Icon(Icons.history),
              text: '播放历史',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 媒体库标签页
          const MediaLibraryTab(),
          // 播放历史标签页
          const HistoryListWidget(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 网络视频按钮
          FloatingActionButton(
            heroTag: 'network',
            onPressed: _playNetworkVideo,
            tooltip: '播放网络视频',
            backgroundColor: Colors.orange,
            child: const Icon(Icons.link),
          ),
          const SizedBox(height: 16),
          // 本地视频按钮
          FloatingActionButton(
            heroTag: 'local',
            onPressed: _pickAndPlayVideo,
            tooltip: '选择本地视频',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class MediaLibraryTab extends StatelessWidget {
  const MediaLibraryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_add,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            '媒体库为空',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '点击右下角的按钮添加视频',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: Colors.blue, size: 16),
              SizedBox(width: 4),
              Text('本地视频', style: TextStyle(color: Colors.grey, fontSize: 12)),
              SizedBox(width: 16),
              Icon(Icons.link, color: Colors.orange, size: 16),
              SizedBox(width: 4),
              Text('网络视频', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          SizedBox(height: 24),
          Text(
            '提示：播放的视频会自动记录到"播放历史"中',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
