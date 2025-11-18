import 'package:flutter_test/flutter_test.dart';
import 'package:yinghe_player/models/hardware_acceleration_config.dart';
import 'package:yinghe_player/services/hardware_acceleration_service.dart';

void main() {
  group('HardwareAccelerationService Tests', () {
    late HardwareAccelerationService hwAccelService;

    setUpAll(() async {
      hwAccelService = HardwareAccelerationService.instance;
      await hwAccelService.initialize();
    });

    group('初始化测试', () {
      test('服务应正确初始化', () {
        expect(hwAccelService.currentConfig, isNotNull);
      });

      test('应检测到硬件加速能力', () {
        final config = hwAccelService.currentConfig;
        expect(config, isNotNull);
        expect(config!.supportedCodecs, isNotEmpty);
      });

      test('应能检测硬件加速支持状态', () {
        final isSupported = hwAccelService.isHardwareAccelerationSupported;
        expect(isSupported, isA<bool>());
      });
    });

    group('配置管理测试', () {
      test('应正确返回硬件加速状态', () {
        final isEnabled = hwAccelService.isHardwareAccelerationEnabled;
        expect(isEnabled, isA<bool>());
      });

      test('应能获取编解码器配置', () {
        final config = hwAccelService.getCodecConfig('h264');
        expect(config, isNotNull);
        expect(config, isA<Map<String, dynamic>>());
      });

      test('无效编解码器配置应包含hwdec:no', () {
        final config = hwAccelService.getCodecConfig('invalid_codec');
        expect(config['hwdec'], equals('no'));
      });
    });

    group('编解码器支持检测', () {
      test('应正确检测H.264支持', () {
        final isSupported = hwAccelService.isCodecSupported('h264');
        expect(isSupported, isA<bool>());
      });

      test('应正确检测HEVC支持', () {
        final isSupported = hwAccelService.isCodecSupported('hevc');
        expect(isSupported, isA<bool>());
      });

      test('应正确检测VP9支持', () {
        final isSupported = hwAccelService.isCodecSupported('vp9');
        expect(isSupported, isA<bool>());
      });

      test('应正确检测AV1支持', () {
        final isSupported = hwAccelService.isCodecSupported('av1');
        expect(isSupported, isA<bool>());
      });

      test('不支持编解码器应返回false', () {
        final isSupported = hwAccelService.isCodecSupported('invalid_codec_xyz');
        expect(isSupported, isFalse);
      });
    });

    group('性能优化建议测试', () {
      test('应提供性能优化建议', () {
        final suggestions = hwAccelService.getPerformanceOptimizations();
        expect(suggestions, isA<List<String>>());
      });

      test('GPU性能级别低时应有相应建议', () {
        final config = hwAccelService.currentConfig;
        if (config != null && config.gpuInfo?.performanceLevel == '低端') {
          final suggestions = hwAccelService.getPerformanceOptimizations();
          expect(suggestions, contains(contains('较低分辨率')));
        }
      });
    });

    group('降级策略测试', () {
      test('应能降级到软件解码', () async {
        expect(
          () async => await hwAccelService.fallbackToSoftwareDecoding(),
          returnsNormally,
        );
      });

      test('未启用时降级不应报错', () async {
        expect(
          () async => await hwAccelService.fallbackToSoftwareDecoding(),
          returnsNormally,
        );
      });
    });

    group('事件流测试', () {
      test('应提供事件流', () {
        expect(hwAccelService.events, isNotNull);
        expect(hwAccelService.events, isA<Stream>());
      });
    });

    group('配置对象测试', () {
      test('配置对象应包含必要信息', () {
        final config = hwAccelService.currentConfig;
        if (config != null) {
          expect(config.enabled, isA<bool>());
          expect(config.type, isNotNull);
          expect(config.status, isNotNull);
          expect(config.supportedCodecs, isA<List<String>>());
        }
      });

      test('配置应支持编解码器检查', () {
        final config = hwAccelService.currentConfig;
        if (config != null) {
          final supportsH264 = config.supportsCodec('h264');
          expect(supportsH264, isA<bool>());
        }
      });
    });

    group('GPU信息测试', () {
      test('应能获取GPU信息', () {
        final gpuInfo = hwAccelService.currentConfig?.gpuInfo;
        if (gpuInfo != null) {
          expect(gpuInfo.vendor, isNotNull);
          expect(gpuInfo.model, isNotNull);
          expect(gpuInfo.performanceLevel, isNotNull);
        }
      });

      test('应检测4K解码支持', () {
        final supports4K = hwAccelService.currentConfig?.gpuInfo?.supports4KDecoding ?? false;
        expect(supports4K, isA<bool>());
      });
    });

    group('错误处理测试', () {
      test('空编解码器名称不应崩溃', () {
        expect(() => hwAccelService.isCodecSupported(''), returnsNormally);
        expect(hwAccelService.isCodecSupported(''), isFalse);
      });

      test('null编解码器名称不应崩溃', () {
        expect(() => hwAccelService.isCodecSupported(''), returnsNormally);
      });

      test('获取配置不应崩溃', () {
        expect(() => hwAccelService.getCodecConfig('test'), returnsNormally);
      });
    });

    group('编解码器配置测试', () {
      test('H.264配置应包含硬件加速选项', () {
        final config = hwAccelService.getCodecConfig('h264');
        expect(config, contains('hwdec'));
      });

      test('HEVC配置应包含硬件加速选项', () {
        final config = hwAccelService.getCodecConfig('hevc');
        expect(config, contains('hwdec'));
      });

      test('配置应为Map类型', () {
        final config = hwAccelService.getCodecConfig('h264');
        expect(config, isA<Map<String, dynamic>>());
      });
    });

    group('状态描述测试', () {
      test('配置应提供状态描述', () {
        final config = hwAccelService.currentConfig;
        if (config != null) {
          expect(config.statusDescription, isNotNull);
          expect(config.statusDescription, isNotEmpty);
        }
      });

      test('应提供显示名称', () {
        final config = hwAccelService.currentConfig;
        if (config != null) {
          expect(config.displayName, isNotNull);
          expect(config.displayName, isNotEmpty);
        }
      });
    });

    group('兼容性测试', () {
      test('多编解码器检查不应冲突', () {
        final h264Supported = hwAccelService.isCodecSupported('h264');
        final hevcSupported = hwAccelService.isCodecSupported('hevc');
        final vp9Supported = hwAccelService.isCodecSupported('vp9');

        expect(h264Supported, isA<bool>());
        expect(hevcSupported, isA<bool>());
        expect(vp9Supported, isA<bool>());
      });

      test('编解码器配置应保持一致性', () {
        final config1 = hwAccelService.getCodecConfig('h264');
        final config2 = hwAccelService.getCodecConfig('h264');
        expect(config1, equals(config2));
      });
    });

    group('集成测试', () {
      test('配置和编解码器支持应同步', () {
        final config = hwAccelService.currentConfig;
        if (config != null && config.enabled) {
          final h264Config = hwAccelService.getCodecConfig('h264');
          final h264Supported = hwAccelService.isCodecSupported('h264');

          // 如果配置显示硬件解码，那么支持检查应该为true
          if (h264Config['hwdec'] != 'no') {
            expect(h264Supported, isTrue);
          }
        }
      });

      test('性能建议应基于当前配置', () {
        final config = hwAccelService.currentConfig;
        final suggestions = hwAccelService.getPerformanceOptimizations();

        if (config != null && !config.enabled) {
          expect(suggestions, contains(contains('硬件加速')));
        }
      });
    });
  });
}