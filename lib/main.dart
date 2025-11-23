import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yinghe_player/screens/home_screen.dart';
import 'package:yinghe_player/services/video_cache_service.dart';
import 'package:yinghe_player/services/local_proxy_server.dart';
import 'package:yinghe_player/services/media_server_service.dart';
import 'package:yinghe_player/services/media_library_service.dart';
import 'package:yinghe_player/services/metadata_store_service.dart';
import 'package:yinghe_player/services/tmdb_service.dart';
import 'package:yinghe_player/services/settings_service.dart';

import 'package:yinghe_player/services/codec_info_service.dart';
import 'package:yinghe_player/services/system_codec_detector_service.dart';
import 'package:yinghe_player/services/plugin_status_service.dart';
import 'package:yinghe_player/theme/app_theme.dart';
import 'package:yinghe_player/theme/design_tokens/design_tokens.dart';
import 'package:yinghe_player/core/plugin_system/plugin_loader.dart';


void main() async {
  // Initialize media_kit
  MediaKit.ensureInitialized();

  // Initialize window_manager
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

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

      // 初始化影视服务器服务
      await MediaServerService.initialize();

      // 初始化媒体库服务
      await MediaLibraryService.init();
      await MetadataStoreService.init();

      // 初始化 TMDB 服务
      final tmdbApiKey = await SettingsService.getTMDBApiKey();
      final tmdbAccessToken = await SettingsService.getTMDBAccessToken();
      if ((tmdbApiKey != null && tmdbApiKey.isNotEmpty) || (tmdbAccessToken != null && tmdbAccessToken.isNotEmpty)) {
        TMDBService.init(tmdbApiKey ?? '', accessToken: tmdbAccessToken);
      }

      // 启动代理服务器
      await LocalProxyServer.instance.start();

      // 初始化插件系统
      try {
        await initializePluginSystem(config: PluginLoadConfig(
          autoActivate: false, // 暂时禁用自动激活
          enableLazyLoading: false,
          loadTimeout: const Duration(seconds: 10),
          maxConcurrentLoads: 2,
        ));
        print('Plugin system initialized successfully');

        // 初始化插件状态服务
        await PluginStatusService().initialize();
        print('Plugin status service initialized successfully');
      } catch (e) {
        print('Failed to initialize plugin system: $e');
        // 插件系统初始化失败不应该阻止应用启动
      }

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
        title: 'CorePlayer',
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                SizedBox(height: 20),
                Text(
                  '正在初始化应用和插件系统...',
                  style: AppTextStyles.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'CorePlayer',
      theme: AppTheme.darkTheme,
      home: _error != null
          ? Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 64,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '缓存服务初始化失败',
                      style: AppTextStyles.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '应用将在无缓存模式下运行',
                      style: AppTextStyles.bodyMedium,
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
