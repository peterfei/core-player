import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yinghe_player/models/codec_info.dart';
import 'package:yinghe_player/services/codec_info_service.dart';

void main() {
  group('CodecInfoService Tests', () {
    late CodecInfoService codecInfoService;
    final List<CodecInfo> testCodecs = [
      const CodecInfo(
        codec: 'h264',
        profile: 'High',
        level: '4.1',
        bitDepth: 8,
        type: CodecType.video,
      ),
      const CodecInfo(
        codec: 'hevc',
        profile: 'Main 10',
        level: '5.1',
        bitDepth: 10,
        type: CodecType.video,
      ),
      const CodecInfo(
        codec: 'unsupported_codec',
        profile: 'N/A',
        level: 'N/A',
        bitDepth: 8,
        type: CodecType.video,
      ),
    ];

    setUp(() async {
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      codecInfoService = CodecInfoService();
      // Allow time for async constructor to complete
      await Future.delayed(Duration.zero);
    });

    test('初始化时缓存应为空', () async {
      final cachedInfo = await codecInfoService.getCachedCodecInfo();
      expect(cachedInfo, isEmpty);
    });

    test('updateCodecInfoCache 应保存编解码器信息', () async {
      await codecInfoService.updateCodecInfoCache(testCodecs);
      final cachedInfo = await codecInfoService.getCachedCodecInfo();
      expect(cachedInfo.length, testCodecs.length);
      expect(cachedInfo.first.codec, 'h264');

      // Verify persistence by creating a new service instance
      final newService = CodecInfoService();
      await Future.delayed(Duration.zero); // Allow init to complete
      final newCachedInfo = await newService.getCachedCodecInfo();
      expect(newCachedInfo.length, testCodecs.length);
      expect(newCachedInfo.first.codec, 'h264');
    });

    test('服务应从预填充的缓存中加载信息', () async {
      // Pre-populate the mock SharedPreferences
      final String jsonString =
          jsonEncode(testCodecs.map((e) => e.toJson()).toList());
      SharedPreferences.setMockInitialValues({
        'codecInfoCache': jsonString,
      });

      // Create a new service instance to trigger loading from cache
      final newService = CodecInfoService();
      await Future.delayed(Duration.zero); // Allow init to complete

      final cachedInfo = await newService.getCachedCodecInfo();
      expect(cachedInfo.length, testCodecs.length);
      expect(cachedInfo.first.codec, 'h264');
    });

    test('supportsCodec 应返回正确的支持状态', () async {
      await codecInfoService.updateCodecInfoCache(testCodecs);

      // CodecSupportStatus for 'h264' is fullySupported
      expect(await codecInfoService.supportsCodec('h264'), isTrue);
      // CodecSupportStatus for 'unsupported_codec' is unsupported
      expect(
          await codecInfoService.supportsCodec('unsupported_codec'), isFalse);
      // Codec not in the list
      expect(await codecInfoService.supportsCodec('vp9'), isFalse);
    });

    test('supportsFormat 应返回正确的支持状态', () async {
      await codecInfoService.updateCodecInfoCache(testCodecs);
      // Currently mirrors supportsCodec
      expect(await codecInfoService.supportsFormat('h264'), isTrue);
      expect(
          await codecInfoService.supportsFormat('unsupported_codec'), isFalse);
    });

    test('getFriendlyCodecName 应返回正确的名称', () {
      expect(codecInfoService.getFriendlyCodecName('h264'), 'H.264/AVC');
      expect(codecInfoService.getFriendlyCodecName('hevc'), 'HEVC/H.265');
      expect(codecInfoService.getFriendlyCodecName('unknown'), 'UNKNOWN');
    });
  });
}
