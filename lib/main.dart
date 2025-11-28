import 'dart:async';
import 'package:flutter/foundation.dart';
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
import 'package:yinghe_player/services/subtitle_download_init.dart';
import 'package:yinghe_player/services/cover_fallback_service.dart';

import 'package:yinghe_player/services/codec_info_service.dart';
import 'package:yinghe_player/services/system_codec_detector_service.dart';
import 'package:yinghe_player/services/plugin_status_service.dart';
import 'package:yinghe_player/services/plugin_lazy_loader.dart';
import 'package:yinghe_player/services/global_error_handler.dart';
import 'package:yinghe_player/theme/app_theme.dart';
import 'package:yinghe_player/theme/design_tokens/design_tokens.dart';
import 'package:yinghe_player/core/plugin_system/plugin_loader.dart';
import 'package:yinghe_player/core/plugin_system/plugin_interface.dart';
import 'package:yinghe_player/core/plugin_system/config_migration.dart';
import 'package:yinghe_player/plugins/builtin/ui_themes/theme_plugin.dart';


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

  // 初始化全局错误处理器
  GlobalErrorHandler().initialize();

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
  ThemeData _currentTheme = AppTheme.darkTheme;
  StreamSubscription? _themeSubscription;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    _themeSubscription?.cancel();
    super.dispose();
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
      
      // 初始化封面回退服务
      await CoverFallbackService.initialize();

      // 初始化 TMDB 服务
      final tmdbApiKey = await SettingsService.getTMDBApiKey();
      final tmdbAccessToken = await SettingsService.getTMDBAccessToken();
      if ((tmdbApiKey != null && tmdbApiKey.isNotEmpty) || (tmdbAccessToken != null && tmdbAccessToken.isNotEmpty)) {
        TMDBService.init(tmdbApiKey ?? '', accessToken: tmdbAccessToken);
      }

      // 启动代理服务器
      await LocalProxyServer.instance.start();

      // 🔥 执行配置迁移（在插件系统初始化之前）
      try {
        final migration = ConfigMigration.instance;
        if (await migration.needsMigration()) {
          final result = await migration.performMigration();
          if (result.success) {
            print('Configuration migration completed successfully');
          } else {
            print('Configuration migration failed: ${result.error}');
          }
        }
      } catch (e) {
        print('Configuration migration error: $e');
        // 配置迁移失败不应该阻止应用启动
      }

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

        // 初始化字幕下载插件
        await initializeSubtitleDownloadPlugins();
        print('Subtitle download plugins initialized successfully');

        // 监听主题变更
        await _setupThemeListener();
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

  Future<void> _setupThemeListener() async {
    if (kDebugMode) {
      print('Setting up theme listener...');
    }
    try {
      // 从懒加载器获取主题插件
      var corePlugin = PluginLazyLoader().getPlugin('coreplayer.theme_manager');
      
      // 如果插件尚未加载，尝试加载它
      if (corePlugin == null) {
        if (kDebugMode) {
          print('ThemePlugin not found in cache, attempting to load...');
        }
        corePlugin = await PluginLazyLoader().loadPlugin('coreplayer.theme_manager');
      }

      if (corePlugin != null && corePlugin is ThemePlugin) {
        final themePlugin = corePlugin;
        // 激活插件(如果需要)
        if (themePlugin.state != PluginState.active) {
          if (kDebugMode) {
            print('Activating ThemePlugin...');
          }
          await themePlugin.activate();
        }

        // 等待插件初始化完成（轮询状态）
        // 确保 onInitialize 中的主题加载逻辑已执行
        if (kDebugMode) {
          print('Waiting for ThemePlugin initialization...');
        }
        int retry = 0;
        const maxRetries = 100; // 5 seconds
        while (themePlugin.state == PluginState.initializing || themePlugin.state == PluginState.uninitialized) {
          await Future.delayed(const Duration(milliseconds: 50));
          retry++;
          if (retry > maxRetries) {
             if (kDebugMode) {
               print('Timeout waiting for ThemePlugin initialization after ${maxRetries * 50}ms');
             }
             break; 
          }
        }

        if (themePlugin.state == PluginState.error) {
           if (kDebugMode) {
             print('ThemePlugin initialization failed with error state');
           }
           // Fallback or handle error if needed, currently we just proceed or log
        }

        // 设置初始主题
        if (themePlugin.currentTheme != null) {
          setState(() {
            _currentTheme = themePlugin.currentTheme!;
          });
          if (kDebugMode) {
            print('Initial theme applied: ${themePlugin.currentThemeInfo.name}');
          }
        } else {
          if (kDebugMode) {
            print('Warning: ThemePlugin initialized but currentTheme is null');
          }
        }

        // 监听主题变更
        _themeSubscription = themePlugin.themeStream.listen((event) {
          if (mounted) {
            setState(() {
              _currentTheme = event.theme.themeData;
            });
            if (kDebugMode) {
              print('Theme updated to: ${event.theme.name} (ID: ${event.themeId})');
            }
          }
        });

        if (kDebugMode) {
          print('Theme listener setup successfully');
        }
      } else {
        if (kDebugMode) {
          print('ThemePlugin not found or failed to load');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to setup theme listener: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget childWidget;

    if (!_initialized) {
      childWidget = MaterialApp(
        title: 'CorePlayer',
        theme: _currentTheme,
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
    } else {
      childWidget = MaterialApp(
        title: 'CorePlayer',
        theme: _currentTheme,
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

    // 包装全局错误监听器
    return GlobalErrorListener(
      child: childWidget,
    );
  }
}
