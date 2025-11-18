import 'package:flutter_test/flutter_test.dart';
import 'package:yinghe_player/services/video_analyzer_service.dart';
import 'package:yinghe_player/models/video_info.dart';
import 'package:yinghe_player/models/codec_info.dart';

void main() {
  group('VideoAnalyzerService Tests', () {
    late VideoAnalyzerService analyzerService;

    setUpAll(() async {
      analyzerService = VideoAnalyzerService.instance;
      await analyzerService.initialize();
    });

    tearDown(() {
      analyzerService.clearCache();
    });

    group('初始化测试', () {
      test('服务应正确初始化', () {
        expect(analyzerService.isInitialized, isTrue);
      });

      test('应能获取支持的格式列表', () {
        final supportedFormats = analyzerService.getSupportedFormats();
        expect(supportedFormats, isNotEmpty);
        expect(supportedFormats, contains('mp4'));
        expect(supportedFormats, contains('mkv'));
        expect(supportedFormats, contains('avi'));
      });

      test('应能获取支持的编解码器列表', () {
        final supportedCodecs = analyzerService.getSupportedCodecs();
        expect(supportedCodecs, isNotEmpty);
        expect(supportedCodecs, contains('h264'));
        expect(supportedCodecs, contains('hevc'));
        expect(supportedCodecs, contains('vp9'));
      });
    });

    group('文件扩展名检测', () {
      test('应正确识别视频文件扩展名', () {
        expect(analyzerService.isVideoFile('test.mp4'), isTrue);
        expect(analyzerService.isVideoFile('test.mkv'), isTrue);
        expect(analyzerService.isVideoFile('test.avi'), isTrue);
        expect(analyzerService.isVideoFile('test.mov'), isTrue);
        expect(analyzerService.isVideoFile('test.webm'), isTrue);
      });

      test('应拒绝非视频文件扩展名', () {
        expect(analyzerService.isVideoFile('test.txt'), isFalse);
        expect(analyzerService.isVideoFile('test.jpg'), isFalse);
        expect(analyzerService.isVideoFile('test.mp3'), isFalse);
        expect(analyzerService.isVideoFile('test.pdf'), isFalse);
      });

      test('应处理大写扩展名', () {
        expect(analyzerService.isVideoFile('TEST.MP4'), isTrue);
        expect(analyzerService.isVideoFile('test.MKV'), isTrue);
        expect(analyzerService.isVideoFile('test.AVI'), isTrue);
      });

      test('应处理无扩展名文件', () {
        expect(analyzerService.isVideoFile('test'), isFalse);
        expect(analyzerService.isVideoFile('test.'), isFalse);
      });
    });

    group('编解码器检测', () {
      test('应正确检测H.264编解码器', () {
        final codec = analyzerService.detectVideoCodec('test_h264.mp4');
        expect(codec?.codec, equals('h264'));
      });

      test('应正确检测HEVC编解码器', () {
        final codec = analyzerService.detectVideoCodec('test_hevc.mp4');
        expect(codec?.codec, equals('hevc'));
      });

      test('应正确检测VP9编解码器', () {
        final codec = analyzerService.detectVideoCodec('test_vp9.webm');
        expect(codec?.codec, equals('vp9'));
      });

      test('应正确检测AV1编解码器', () {
        final codec = analyzerService.detectVideoCodec('test_av1.webm');
        expect(codec?.codec, equals('av1'));
      });

      test('未知编解码器应返回null', () {
        final codec = analyzerService.detectVideoCodec('test_unknown.xyz');
        expect(codec, isNull);
      });
    });

    group('分辨率检测', () {
      test('应能从文件名检测分辨率', () {
        expect(analyzerService.detectResolution('test_720p.mp4'), equals('1280x720'));
        expect(analyzerService.detectResolution('test_1080p.mkv'), equals('1920x1080'));
        expect(analyzerService.detectResolution('test_4k.mp4'), equals('3840x2160'));
        expect(analyzerService.detectResolution('test_8k.mp4'), equals('7680x4320'));
      });

      test('应能从数字检测分辨率', () {
        expect(analyzerService.detectResolution('test_1280x720.mp4'), equals('1280x720'));
        expect(analyzerService.detectResolution('test_1920x1080.mkv'), equals('1920x1080'));
        expect(analyzerService.detectResolution('test_3840x2160.mp4'), equals('3840x2160'));
      });

      test('未知分辨率应返回空字符串', () {
        expect(analyzerService.detectResolution('test_video.mp4'), equals(''));
        expect(analyzerService.detectResolution('test_999p.mp4'), equals(''));
      });
    });

    group('质量检测', () {
      test('应能检测视频质量标签', () {
        expect(analyzerService.detectQuality('test_720p.mp4'), equals('HD'));
        expect(analyzerService.detectQuality('test_1080p.mkv'), equals('Full HD'));
        expect(analyzerService.detectQuality('test_4k.mp4'), equals('4K UHD'));
        expect(analyzerService.detectQuality('test_8k.mp4'), equals('8K UHD'));
        expect(analyzerService.detectQuality('test_480p.mp4'), equals('SD'));
      });

      test('应能检测HDR内容', () {
        expect(analyzerService.isHDRVideo('test_hdr.mp4'), isTrue);
        expect(analyzerService.isHDRVideo('test_4k_hdr.mkv'), isTrue);
        expect(analyzerService.isHDRVideo('test_sdr.mp4'), isFalse);
        expect(analyzerService.isHDRVideo('test.mp4'), isFalse);
      });

      test('应能检测高帧率内容', () {
        expect(analyzerService.isHighFramerate('test_60fps.mp4'), isTrue);
        expect(analyzerService.isHighFramerate('test_120fps.mkv'), isTrue);
        expect(analyzerService.isHighFramerate('test_30fps.mp4'), isFalse);
        expect(analyzerService.isHighFramerate('test.mp4'), isFalse);
      });
    });

    group('视频信息分析', () {
      test('应能创建基础视频信息', () {
        final videoInfo = analyzerService.createBasicVideoInfo(
          'test_1080p.mp4',
          'test_1080p.mp4',
          '/path/to/test_1080p.mp4',
        );

        expect(videoInfo, isNotNull);
        expect(videoInfo.fileName, equals('test_1080p.mp4'));
        expect(videoInfo.displayName, equals('test_1080p'));
        expect(videoInfo.filePath, equals('/path/to/test_1080p.mp4'));
        expect(videoInfo.resolution, equals('1920x1080'));
        expect(videoInfo.qualityLabel, equals('Full HD'));
        expect(videoInfo.isHD, isTrue);
        expect(videoInfo.isUHD, isFalse);
      });

      test('应能检测4K视频', () {
        final videoInfo = analyzerService.createBasicVideoInfo(
          'test_4k.mp4',
          'test_4k.mp4',
          '/path/to/test_4k.mp4',
        );

        expect(videoInfo.isUHD, isTrue);
        expect(videoInfo.qualityLabel, equals('4K UHD'));
      });

      test('应能检测HDR视频', () {
        final videoInfo = analyzerService.createBasicVideoInfo(
          'test_4k_hdr.mp4',
          'test_4k_hdr.mp4',
          '/path/to/test_4k_hdr.mp4',
        );

        expect(videoInfo.isHDR, isTrue);
        expect(videoInfo.hdrType, isNotNull);
      });

      test('应能检测高帧率视频', () {
        final videoInfo = analyzerService.createBasicVideoInfo(
          'test_60fps.mp4',
          'test_60fps.mp4',
          '/path/to/test_60fps.mp4',
        );

        expect(videoInfo.isHighFramerate, isTrue);
      });
    });

    group('格式兼容性测试', () {
      test('应能检查格式兼容性', () {
        final compatibility = analyzerService.checkFormatCompatibility('test.mp4');
        expect(compatibility, isNotNull);
        expect(compatibility.isSupported, isTrue);
        expect(compatibility.containerFormat, equals('mp4'));
      });

      test('应能检查编解码器兼容性', () {
        final h264Compatibility = analyzerService.checkCodecCompatibility('h264');
        expect(h264Compatibility.isSupported, isTrue);

        final hevcCompatibility = analyzerService.checkCodecCompatibility('hevc');
        expect(hevcCompatibility.isSupported, isA<bool>());

        final invalidCompatibility = analyzerService.checkCodecCompatibility('invalid');
        expect(invalidCompatibility.isSupported, isFalse);
      });

      test('应能提供格式建议', () {
        final suggestions = analyzerService.getFormatRecommendations('4K');
        expect(suggestions, isNotEmpty);
        expect(suggestions, contains('mp4'));
        expect(suggestions, contains('mkv'));
      });

      test('应能提供编解码器建议', () {
        final suggestions = analyzerService.getCodecRecommendations('4K');
        expect(suggestions, isNotEmpty);
        expect(suggestions, contains('hevc'));
        expect(suggestions, contains('vp9'));
      });
    });

    group('缓存测试', () {
      test('应能缓存分析结果', () {
        final filePath = '/test/cache_video.mp4';
        final videoInfo = analyzerService.createBasicVideoInfo(
          'cache_video.mp4',
          'cache_video.mp4',
          filePath,
        );

        // 应该能够从缓存获取
        final cachedInfo = analyzerService.getCachedVideoInfo(filePath);
        expect(cachedInfo, isNotNull);
        expect(cachedInfo!.fileName, equals('cache_video.mp4'));
      });

      test('应能清除缓存', () {
        analyzerService.clearCache();
        final cachedInfo = analyzerService.getCachedVideoInfo('/nonexistent.mp4');
        expect(cachedInfo, isNull);
      });

      test('缓存大小应有限制', () {
        // 创建大量视频信息
        for (int i = 0; i < 150; i++) {
          analyzerService.createBasicVideoInfo(
            'test_$i.mp4',
            'test_$i.mp4',
            '/test/test_$i.mp4',
          );
        }

        // 缓存不应该无限增长
        expect(analyzerService.getCacheSize(), lessThan(120));
      });
    });

    group('错误处理测试', () {
      test('空文件路径不应导致崩溃', () {
        expect(
          () => analyzerService.createBasicVideoInfo('', '', ''),
          returnsNormally,
        );
      });

      test('null文件路径不应导致崩溃', () {
        expect(
          () => analyzerService.createBasicVideoInfo(null, null, null),
          returnsNormally,
        );
      });

      test('无效编解码器不应导致崩溃', () {
        final compatibility = analyzerService.checkCodecCompatibility('invalid_codec_12345');
        expect(compatibility.isSupported, isFalse);
      });

      test('无效格式不应导致崩溃', () {
        final compatibility = analyzerService.checkFormatCompatibility('invalid.xyz');
        expect(compatibility.isSupported, isFalse);
      });
    });

    group('性能测试', () {
      test('分析速度应足够快', () async {
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 100; i++) {
          analyzerService.createBasicVideoInfo(
            'performance_test_$i.mp4',
            'performance_test_$i.mp4',
            '/test/performance_test_$i.mp4',
          );
        }

        stopwatch.stop();

        // 100次分析应该在1秒内完成
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });

      test('编解码器检测应高效', () {
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 1000; i++) {
          analyzerService.detectVideoCodec('test_video_$i.mp4');
        }

        stopwatch.stop();

        // 1000次检测应该在500毫秒内完成
        expect(stopwatch.elapsedMilliseconds, lessThan(500));
      });
    });

    group('多轨道检测', () {
      test('应能检测多音轨视频', () {
        final hasMultipleTracks = analyzerService.hasMultipleAudioTracks('test_multi_audio.mkv');
        expect(hasMultipleTracks, isA<bool>());
      });

      test('应能检测字幕轨道', () {
        final hasSubtitles = analyzerService.hasSubtitleTracks('test_with_subs.mkv');
        expect(hasSubtitles, isA<bool>());
      });

      test('应能获取轨道数量', () {
        final audioTrackCount = analyzerService.getAudioTrackCount('test_multi_audio.mkv');
        expect(audioTrackCount, greaterThanOrEqualTo(0));

        final subtitleTrackCount = analyzerService.getSubtitleTrackCount('test_with_subs.mkv');
        expect(subtitleTrackCount, greaterThanOrEqualTo(0));
      });
    });

    group('流媒体检测', () {
      test('应能检测网络视频流', () {
        expect(analyzerService.isNetworkStream('http://example.com/video.mp4'), isTrue);
        expect(analyzerService.isNetworkStream('https://example.com/video.mkv'), isTrue);
        expect(analyzerService.isNetworkStream('ftp://example.com/video.avi'), isTrue);
        expect(analyzerService.isNetworkStream('/local/video.mp4'), isFalse);
      });

      test('应能获取流媒体类型', () {
        expect(analyzerService.getStreamType('http://example.com/video.mp4'), equals('HTTP'));
        expect(analyzerService.getStreamType('https://example.com/video.mkv'), equals('HTTPS'));
        expect(analyzerService.getStreamType('/local/video.mp4'), equals('Local'));
      });
    });
  });
}