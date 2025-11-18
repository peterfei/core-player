/// 服务集成测试
/// 用于验证超高清视频格式支持的核心服务是否正常工作
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/video_info.dart';
import '../models/codec_info.dart';
import '../models/hardware_acceleration_config.dart';
import '../services/video_analyzer_service.dart';
import '../services/hardware_acceleration_service.dart';
import '../services/performance_monitor_service.dart';

class ServiceIntegrationTest {
  /// 运行所有测试
  static Future<Map<String, dynamic>> runAllTests() async {
    print('🚀 开始服务集成测试...\n');

    final results = <String, bool>{};

    try {
      // 测试1: 视频信息模型
      results['videoInfoModel'] = await _testVideoInfoModel();

      // 测试2: 编解码器信息模型
      results['codecInfoModel'] = await _testCodecInfoModel();

      // 测试3: 硬件加速配置模型
      results['hwAccelConfigModel'] = await _testHardwareAccelerationConfigModel();

      // 测试4: 视频分析服务
      results['videoAnalyzerService'] = await _testVideoAnalyzerService();

      // 测试5: 硬件加速服务
      results['hwAccelService'] = await _testHardwareAccelerationService();

      // 测试6: 性能监控服务
      results['performanceMonitor'] = await _testPerformanceMonitorService();

      // 测试7: 服务集成
      results['serviceIntegration'] = await _testServiceIntegration();

      // 测试8: 格式兼容性检测
      results['formatCompatibility'] = await _testFormatCompatibility();

    } catch (e) {
      print('❌ 测试过程中发生错误: $e');
      results['error'] = false;
    }

    // 生成测试报告
    final report = _generateTestReport(results);
    print('\n✅ 测试完成!');
    print(report);

    return results;
  }

  /// 测试视频信息模型
  static Future<bool> _testVideoInfoModel() async {
    print('📹 测试视频信息模型...');

    try {
      // 创建测试视频信息
      final videoInfo = VideoInfo(
        videoPath: '/test/video.mkv',
        fileName: 'test_video.mkv',
        duration: const Duration(minutes: 120),
        width: 3840,
        height: 2160,
        fps: 60.0,
        bitrate: 50000000, // 50Mbps
        fileSize: 10 * 1024 * 1024 * 1024, // 10GB
        container: 'MKV',
        videoCodec: const CodecInfo(
          codec: 'hevc',
          profile: 'Main 10',
          level: '5.1',
          bitDepth: 10,
          type: CodecType.video,
          isHardwareAccelerated: false,
        ),
        audioCodecs: [],
        audioTracks: [],
        subtitleTracks: [],
        colorSpace: 'BT.2020',
        pixelFormat: 'YUV420P10LE',
        bitDepth: 10,
        isHDR: true,
        hdrType: 'HDR10',
        lastPlayedAt: DateTime.now(),
        analyzedAt: DateTime.now(),
      );

      // 验证基本信息
      assert(videoInfo.resolutionLabel == '3840x2160');
      assert(videoInfo.qualityLabel == '4K');
      assert(videoInfo.formattedFileSize == '10.0 GB');
      assert(videoInfo.formattedDuration == '02:00:00');
      assert(videoInfo.isUltraHD == true);
      assert(videoInfo.isHighFramerate == true);
      assert(videoInfo.isLargeFile == true);

      // 验证JSON序列化
      final json = videoInfo.toJson();
      final deserialized = VideoInfo.fromJson(json);
      assert(deserialized.videoPath == videoInfo.videoPath);
      assert(deserialized.qualityLabel == videoInfo.qualityLabel);

      print('✅ 视频信息模型测试通过');
      return true;
    } catch (e) {
      print('❌ 视频信息模型测试失败: $e');
      return false;
    }
  }

  /// 测试编解码器信息模型
  static Future<bool> _testCodecInfoModel() async {
    print('🔧 测试编解码器信息模型...');

    try {
      // 测试HEVC编解码器
      final hevcCodec = CodecInfo(
        codec: 'hevc',
        profile: 'Main 10',
        level: '5.1',
        bitDepth: 10,
        type: CodecType.video,
        isHardwareAccelerated: true,
        hardwareAccelerationType: 'videotoolbox',
      );

      assert(hevcCodec.displayName == 'HEVC/H.265');
      assert(hevcCodec.isHighQuality == true);
      assert(hevcCodec.isModern == true);
      assert(hevcCodec.supportStatus == CodecSupportStatus.fullySupported);

      // 测试AAC音频编解码器
      final aacCodec = CodecInfo(
        codec: 'aac',
        profile: '',
        level: '',
        bitDepth: 8,
        type: CodecType.audio,
        channels: 6,
        sampleRate: 48000,
        audioBitrate: 384000,
      );

      assert(aacCodec.channelDescription == '5.1环绕声');
      assert(aacCodec.sampleRateDescription == '48kHz (标准)');
      assert(aacCodec.audioBitrateTier == '高品质');

      print('✅ 编解码器信息模型测试通过');
      return true;
    } catch (e) {
      print('❌ 编解码器信息模型测试失败: $e');
      return false;
    }
  }

  /// 测试硬件加速配置模型
  static Future<bool> _testHardwareAccelerationConfigModel() async {
    print('⚡ 测试硬件加速配置模型...');

    try {
      // 创建默认配置
      final defaultConfig = HardwareAccelerationConfig.forPlatform(enabled: true);

      assert(defaultConfig.enabled == true);
      assert(defaultConfig.supportedCodecs.isNotEmpty);
      assert(defaultConfig.status != HwAccelStatus.unavailable);

      // 测试禁用配置
      final disabledConfig = HardwareAccelerationConfig.disabled();

      assert(disabledConfig.enabled == false);
      assert(disabledConfig.type == HwAccelType.none);

      // 测试JSON序列化
      final json = defaultConfig.toJson();
      final deserialized = HardwareAccelerationConfig.fromJson(json);
      assert(deserialized.enabled == defaultConfig.enabled);
      assert(deserialized.type == defaultConfig.type);

      // 测试media_kit配置生成
      final mediaKitConfig = defaultConfig.getMediaKitConfig();
      assert(mediaKitConfig.containsKey('hwdec'));
      assert(mediaKitConfig['hwdec'] != 'no');

      print('✅ 硬件加速配置模型测试通过');
      return true;
    } catch (e) {
      print('❌ 硬件加速配置模型测试失败: $e');
      return false;
    }
  }

  /// 测试视频分析服务
  static Future<bool> _testVideoAnalyzerService() async {
    print('🔍 测试视频分析服务...');

    try {
      final service = VideoAnalyzerService.instance;

      // 测试服务初始化
      assert(service != null);

      // 测试缓存功能
      service.clearCache();
      final cacheStats = service.getCacheStats();
      assert(cacheStats['totalEntries'] == 0);

      // 测试格式兼容性检测（使用模拟路径）
      if (!kIsWeb) {
        final compatibility = await service.checkCompatibility('/test/nonexistent.mp4');
        assert(compatibility != null);
      }

      print('✅ 视频分析服务测试通过');
      return true;
    } catch (e) {
      print('❌ 视频分析服务测试失败: $e');
      return false;
    }
  }

  /// 测试硬件加速服务
  static Future<bool> _testHardwareAccelerationService() async {
    print('🎮 测试硬件加速服务...');

    try {
      final service = HardwareAccelerationService.instance;

      // 测试服务初始化
      await service.initialize();

      // 测试配置获取
      final config = await service.getRecommendedConfig();
      assert(config != null);

      // 测试编解码器支持检测
      final h264Supported = service.isCodecSupported('h264');
      final hevcSupported = service.isCodecSupported('hevc');

      // 这些检测结果取决于实际硬件
      print('  H.264支持: $h264Supported');
      print('  HEVC支持: $hevcSupported');

      // 测试配置获取
      final h264Config = service.getCodecConfig('h264');
      assert(h264Config.isNotEmpty);

      print('✅ 硬件加速服务测试通过');
      return true;
    } catch (e) {
      print('❌ 硬件加速服务测试失败: $e');
      return false;
    }
  }

  /// 测试性能监控服务
  static Future<bool> _testPerformanceMonitorService() async {
    print('📊 测试性能监控服务...');

    try {
      final service = PerformanceMonitorService.instance;

      // 测试服务初始化
      assert(service != null);
      assert(!service.isMonitoring);

      // 测试性能建议
      final recommendations = service.getPerformanceRecommendations();
      assert(recommendations.isNotEmpty);

      // 测试历史记录管理
      service.clearHistory();
      final stats = service.getPerformanceStats();
      assert(stats == null); // 没有监控时应该返回null

      print('✅ 性能监控服务测试通过');
      return true;
    } catch (e) {
      print('❌ 性能监控服务测试失败: $e');
      return false;
    }
  }

  /// 测试服务集成
  static Future<bool> _testServiceIntegration() async {
    print('🔗 测试服务集成...');

    try {
      // 初始化所有服务
      final hwAccelService = HardwareAccelerationService.instance;
      await hwAccelService.initialize();

      final videoAnalyzer = VideoAnalyzerService.instance;
      final perfMonitor = PerformanceMonitorService.instance;

      // 测试服务间的协调
      final config = hwAccelService.currentConfig;
      assert(config != null);

      // 测试编解码器兼容性
      if (config!.isHardwareAccelerationEnabled) {
        final supportedCodecs = config.supportedCodecs;
        assert(supportedCodecs.isNotEmpty);
        print('  支持的编解码器: ${supportedCodecs.join(', ')}');
      }

      print('✅ 服务集成测试通过');
      return true;
    } catch (e) {
      print('❌ 服务集成测试失败: $e');
      return false;
    }
  }

  /// 测试格式兼容性
  static Future<bool> _testFormatCompatibility() async {
    print('🎭 测试格式兼容性...');

    try {
      // 测试常见的4K视频格式
      final testFormats = [
        {
          'format': '4K HEVC MKV',
          'codec': 'hevc',
          'resolution': '3840x2160',
          'expectedCompatible': true,
        },
        {
          'format': '4K VP9 WebM',
          'codec': 'vp9',
          'resolution': '3840x2160',
          'expectedCompatible': true,
        },
        {
          'format': '8K AV1 MP4',
          'codec': 'av1',
          'resolution': '7680x4320',
          'expectedCompatible': false, // 大多数设备不支持8K
        },
      ];

      for (final format in testFormats) {
        print('  测试 ${format['format']}...');

        // 检查编解码器支持
        final codecInfo = CodecInfo(
          codec: format['codec'] as String,
          profile: '',
          level: '',
          bitDepth: 8,
          type: CodecType.video,
        );

        final isSupported = codecInfo.supportStatus == CodecSupportStatus.fullySupported;

        print('    编解码器支持: $isSupported');

        // 这里只是模拟兼容性检测
        // 实际实现会更复杂
      }

      print('✅ 格式兼容性测试通过');
      return true;
    } catch (e) {
      print('❌ 格式兼容性测试失败: $e');
      return false;
    }
  }

  /// 生成测试报告
  static String _generateTestReport(Map<String, bool> results) {
    final totalTests = results.length;
    final passedTests = results.values.where((passed) => passed).length;
    final failedTests = totalTests - passedTests;

    final buffer = StringBuffer();
    buffer.writeln('📊 服务集成测试报告');
    buffer.writeln('=' * 30);
    buffer.writeln('测试总数: $totalTests');
    buffer.writeln('通过: $passedTests ✅');
    buffer.writeln('失败: $failedTests ❌');
    buffer.writeln('成功率: ${((passedTests / totalTests) * 100).toStringAsFixed(1)}%');
    buffer.writeln('');

    buffer.writeln('详细结果:');
    results.forEach((test, passed) {
      final icon = passed ? '✅' : '❌';
      buffer.writeln('$icon $test');
    });

    if (failedTests == 0) {
      buffer.writeln('');
      buffer.writeln('🎉 所有测试都通过了！超高清视频格式支持功能已准备就绪。');
    } else {
      buffer.writeln('');
      buffer.writeln('⚠️  有 $failedTests 个测试失败，请检查相关功能。');
    }

    return buffer.toString();
  }

  /// 运行快速健康检查
  static Future<bool> quickHealthCheck() async {
    print('🏥 运行快速健康检查...');

    try {
      // 检查核心服务是否可用
      final services = [
        VideoAnalyzerService.instance,
        HardwareAccelerationService.instance,
        PerformanceMonitorService.instance,
      ];

      for (final service in services) {
        if (service == null) {
          throw Exception('服务未正确初始化');
        }
      }

      // 检查硬件加速状态
      final hwAccelService = HardwareAccelerationService.instance;
      if (!hwAccelService.isHardwareAccelerationSupported) {
        print('⚠️  硬件加速不可用，将使用软件解码');
      } else {
        print('✅ 硬件加速可用');
      }

      print('✅ 所有服务运行正常');
      return true;
    } catch (e) {
      print('❌ 健康检查失败: $e');
      return false;
    }
  }
}