import 'package:flutter_test/flutter_test.dart';
import '../lib/services/video_analyzer_service.dart';
import '../lib/services/hardware_acceleration_service.dart';
import '../lib/services/performance_monitor_service.dart';
import '../lib/models/video_info.dart';
import '../lib/models/hardware_acceleration_config.dart';

void main() {
  group('超高清视频支持集成测试', () {
    late VideoAnalyzerService videoAnalyzer;
    late HardwareAccelerationService hwAccelService;
    late PerformanceMonitorService perfService;

    setUpAll(() async {
      // 初始化所有服务
      videoAnalyzer = VideoAnalyzerService.instance;
      hwAccelService = HardwareAccelerationService.instance;
      perfService = PerformanceMonitorService.instance;

      await hwAccelService.initialize();
    });

    test('视频分析服务初始化', () {
      expect(videoAnalyzer, isNotNull);
      expect(videoAnalyzer.cache, isNotNull);
    });

    test('硬件加速服务初始化', () {
      expect(hwAccelService, isNotNull);
      expect(hwAccelService.isInitialized, isTrue);
      expect(hwAccelService.events, isNotNull);
    });

    test('性能监控服务初始化', () {
      expect(perfService, isNotNull);
      expect(perfService.metricsStream, isNotNull);
      expect(perfService.recommendationStream, isNotNull);
    });

    test('硬件加速配置检查', () async {
      // 测试获取推荐配置
      final config = await hwAccelService.getRecommendedConfig();
      expect(config, isNotNull);
      expect(config.supportedCodecs, isNotEmpty);

      // 测试当前配置状态
      final currentConfig = hwAccelService.currentConfig;
      expect(currentConfig, isNotNull);
      expect(currentConfig.enabled, isA<bool>());
      expect(currentConfig.displayName, isA<String>());
    });

    test('编解码器支持检测', () async {
      // 测试常见编解码器支持
      final codecs = ['h264', 'hevc', 'vp9', 'av1'];

      for (final codec in codecs) {
        final isSupported = await hwAccelService.isCodecSupported(codec);
        print('编解码器 $codec 支持状态: ${isSupported ? '✅' : '❌'}');
        expect(isSupported, isA<bool>());
      }
    });

    test('性能指标采集测试', () async {
      // 创建模拟视频信息用于测试
      final testVideoInfo = VideoInfo(
        videoPath: '/test/path/video.mp4',
        duration: const Duration(minutes: 10),
        width: 1920,
        height: 1080,
        fps: 30.0,
        fileSize: 500000000, // 500MB
        format: 'mp4',
        videoCodec: CodecInfo.h264(),
        audioCodecs: [CodecInfo.aac()],
        analyzedAt: DateTime.now(),
      );

      // 测试性能评级
      expect(testVideoInfo.qualityRating, isA<String>());
      expect(testVideoInfo.qualityTags, isA<List<String>>());

      print('测试视频质量评级: ${testVideoInfo.qualityRating}');
      print('测试视频标签: ${testVideoInfo.qualityTags.join(', ')}');
    });

    test('硬件加速配置序列化', () {
      final config = HardwareAccelerationConfig.videoToolbox(
        supportedCodecs: ['h264', 'hevc'],
        gpuInfo: const GPUInfo(
          vendor: 'Test Vendor',
          model: 'Test GPU',
          driverVersion: '1.0',
          maxTextureSize: 4096,
          maxRenderTargets: 8,
          supportsHardwareDecoding: true,
          supportsHardwareEncoding: false,
        ),
        enabled: true,
      );

      // 测试JSON序列化
      final json = config.toJson();
      expect(json, isNotEmpty);
      expect(json['type'], equals('videotoolbox'));
      expect(json['enabled'], equals(true));
      expect(json['supportedCodecs'], contains('h264'));
      expect(json['supportedCodecs'], contains('hevc'));

      // 测试JSON反序列化
      final restoredConfig = HardwareAccelerationConfig.fromJson(json);
      expect(restoredConfig.type, equals(config.type));
      expect(restoredConfig.enabled, equals(config.enabled));
      expect(restoredConfig.supportedCodecs, equals(config.supportedCodecs));
      expect(restoredConfig.displayName, equals(config.displayName));

      print('硬件加速配置序列化测试: ✅');
      print('配置类型: ${restoredConfig.displayName}');
      print('支持编解码器: ${restoredConfig.supportedCodecs.join(', ')}');
    });

    test('视频格式兼容性检查', () {
      // 测试4K/8K视频识别
      final video4K = VideoInfo(
        videoPath: '/test/4k.mp4',
        duration: const Duration(minutes: 5),
        width: 3840,
        height: 2160,
        fps: 60.0,
        fileSize: 2000000000, // 2GB
        format: 'mkv',
        videoCodec: CodecInfo.hevc(),
        audioCodecs: [CodecInfo.aac()],
        analyzedAt: DateTime.now(),
      );

      final video8K = VideoInfo(
        videoPath: '/test/8k.mp4',
        duration: const Duration(minutes: 3),
        width: 7680,
        height: 4320,
        fps: 24.0,
        fileSize: 5000000000, // 5GB
        format: 'mkv',
        videoCodec: CodecInfo.hevc(),
        audioCodecs: [CodecInfo.aac()],
        analyzedAt: DateTime.now(),
      );

      // 验证4K/8K识别
      expect(video4K.is4K, isTrue);
      expect(video4K.is8K, isFalse);
      expect(video4K.isUltraHD, isTrue);
      expect(video4K.isHighFramerate, isTrue);

      expect(video8K.is8K, isTrue);
      expect(video8K.is4K, isFalse);
      expect(video8K.isUltraHD, isTrue);
      expect(video8K.isLargeFile, isTrue);

      print('4K视频识别: ${video4K.is4K ? "✅" : "❌"}');
      print('8K视频识别: ${video8K.is8K ? "✅" : "❌"}');
      print('大文件识别: ${video8K.isLargeFile ? "✅" : "❌"}');
    });

    test('性能监控指标计算', () {
      // 创建测试性能指标
      final metrics = PerformanceMetrics(
        fps: 59.8,
        targetFps: 60.0,
        droppedFramePercentage: 0.5,
        cpuUsage: 45.2,
        memoryUsage: 512,
        gpuUsage: 35.8,
        bufferPercentage: 75.0,
        decoderType: '硬件解码 (VideoToolbox)',
        timestamp: DateTime.now(),
      );

      // 验证性能评级
      expect(metrics.isExcellentPerformance, isTrue);
      expect(metrics.isPoorPerformance, isFalse);
      expect(metrics.frameDropRate, closeTo(0.005, 0.001));

      print('性能评级: ${metrics.isExcellentPerformance ? "优秀" : "一般"}');
      print('帧率: ${metrics.fps}/${metrics.targetFps}');
      print('丢帧率: ${metrics.droppedFramePercentage}%');
      print('CPU使用: ${metrics.cpuUsage}%');
      print('内存使用: ${metrics.memoryUsage}MB');
      print('解码器类型: ${metrics.decoderType}');
    });
  });

  group('服务健康检查', () {
    test('所有服务可用性检查', () async {
      final services = {
        'VideoAnalyzerService': VideoAnalyzerService.instance,
        'HardwareAccelerationService': HardwareAccelerationService.instance,
        'PerformanceMonitorService': PerformanceMonitorService.instance,
      };

      print('\n📊 服务健康检查报告:');

      for (final entry in services.entries) {
        final serviceName = entry.key;
        final service = entry.value;

        try {
          if (service is HardwareAccelerationService) {
            final isInitialized = service.isInitialized;
            final config = service.currentConfig;
            print(
                '  $serviceName: ${isInitialized ? "✅" : "❌"} (已初始化: $isInitialized, 硬件加速: ${config?.enabled ?? false})');
          } else {
            print('  $serviceName: ✅ (已就绪)');
          }
        } catch (e) {
          print('  $serviceName: ❌ (错误: $e)');
        }
      }
    });
  });
}
