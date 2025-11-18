import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:yinghe_player/screens/home_screen.dart';
import 'package:yinghe_player/services/video_cache_service.dart';
import 'package:yinghe_player/services/local_proxy_server.dart';

import 'package:yinghe_player/services/codec_info_service.dart';
import 'package:yinghe_player/services/system_codec_detector_service.dart';

void main() {
  // Initialize media_kit
  MediaKit.ensureInitialized();

  // 捕获 Flutter 框架错误(包括键盘事件错误)
  FlutterError.onError = (FlutterErrorDetails details) {
    // 过滤键盘事件相关错误
    if (details.exception.toString().contains('KeyDownEvent') &&
        details.exception.toString().contains('already pressed')) {
      // 静默处理键盘事件错误,减少控制台噪音
      return;
    }

    // 其他错误正常处理
    FlutterError.dumpErrorToConsole(details);
  };

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize services
      await CodecInfoService.instance.initialize();
      final codecDetector = SystemCodecDetectorService();
      final codecs = await codecDetector.detectSupportedCodecs();
      await CodecInfoService.instance.updateCodecInfoCache(codecs);

      // 异步初始化缓存服务
      await VideoCacheService.instance.initialize();

      // 启动代理服务器
      await LocalProxyServer.instance.start();

      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e) {
      print('Failed to initialize services: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _initialized = true; // 即使出错也显示应用
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return MaterialApp(
        title: '影核播放器',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                SizedBox(height: 20),
                Text(
                  '正在初始化缓存服务...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: '影核播放器',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: _error != null
          ? Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 64,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '缓存服务初始化失败',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '应用将在无缓存模式下运行',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _error = null;
                        });
                      },
                      child: const Text('继续使用'),
                    ),
                  ],
                ),
              ),
            )
          : const HomeScreen(),
    );
  }
}
