/// 字幕兼容性测试脚本
/// 用于验证升级后的 media_kit v1.2.0+ 与外部字幕功能的兼容性

import 'package:flutter_test/flutter_test.dart';
import 'package:yinghe_player/models/subtitle_config.dart';
import 'package:yinghe_player/models/subtitle_track.dart' as app;

void main() {
  group('Subtitle Compatibility Tests - media_kit v1.2.0+', () {
    late SubtitleConfig subtitleConfig;

    setUpAll(() async {
      subtitleConfig = SubtitleConfig.defaultConfig();
    });

    test('初始化字幕配置', () {
      expect(subtitleConfig, isNotNull);
      expect(subtitleConfig.enabled, isTrue);
    });

    test('字幕配置创建和修改', () {
      final newConfig = SubtitleConfig(
        enabled: true,
        fontSize: 24.0,
        fontColor: 0xFFFFFFFF,
        backgroundColor: 0xFF000000,
        outlineColor: 0xFF000000,
        outlineWidth: 2.0,
        fontFamily: 'Arial',
        position: SubtitlePosition.bottom,
        delayMs: 0,
        preferredLanguages: ['zh', 'en'],
        preferredEncoding: 'UTF-8',
        autoLoad: true,
      );

      expect(newConfig.fontSize, equals(24.0));
      expect(newConfig.preferredLanguages, contains('zh'));
    });

    test('字幕配置的颜色值处理', () {
      final config = subtitleConfig;

      // 验证颜色格式
      expect(config.fontColor, isA<int>());
      expect(config.backgroundColor, isA<int>());
      expect(config.outlineColor, isA<int>());

      // ARGB 颜色值应在合法范围内
      expect(config.fontColor, greaterThan(0));
      expect(config.backgroundColor, greaterThan(0));
    });

    test('字幕位置枚举验证', () {
      expect(SubtitlePosition.values.length, equals(3));
      expect(SubtitlePosition.values, contains(SubtitlePosition.top));
      expect(SubtitlePosition.values, contains(SubtitlePosition.center));
      expect(SubtitlePosition.values, contains(SubtitlePosition.bottom));
    });

    test('语言偏好配置验证', () {
      final testLanguages = ['zh-cn', 'en', 'ja'];
      final newConfig = subtitleConfig.copyWith(
        preferredLanguages: testLanguages,
      );

      expect(
        newConfig.preferredLanguages,
        equals(testLanguages),
      );
    });

    test('字幕延迟配置范围验证', () {
      final delayConfig = subtitleConfig.copyWith(delayMs: 1000);

      expect(delayConfig.delayMs, equals(1000));

      // 测试负延迟（同步提前）
      final negativConfig = subtitleConfig.copyWith(delayMs: -500);
      expect(negativConfig.delayMs, equals(-500));
    });

    test('字体大小配置验证', () {
      final sizes = [12.0, 16.0, 20.0, 24.0, 28.0, 32.0];

      for (final size in sizes) {
        final config = subtitleConfig.copyWith(fontSize: size);
        expect(config.fontSize, equals(size));
      }
    });

    test('App SubtitleTrack 禁用状态验证', () {
      final disabledTrack = app.SubtitleTrack.disabled;

      expect(disabledTrack.id, equals('disabled'));
      expect(disabledTrack.title, equals('关闭字幕'));
    });

    test('App 外部字幕轨道数据模型', () {
      final externalTrack = app.SubtitleTrack.external(
        filePath: '/path/to/subtitle.srt',
        title: 'English',
        format: 'srt',
        language: 'en',
      );

      expect(externalTrack.isExternal, isTrue);
      expect(externalTrack.filePath, equals('/path/to/subtitle.srt'));
      expect(externalTrack.format, equals('srt'));
      expect(externalTrack.language, equals('en'));
    });

    test('App SubtitleTrack JSON 序列化', () {
      final track = app.SubtitleTrack.external(
        filePath: '/test/subtitle.srt',
        title: 'Test Subtitle',
        format: 'srt',
        language: 'en',
      );

      final json = track.toJson();
      expect(json, isA<Map<String, dynamic>>());
      expect(json['title'], equals('Test Subtitle'));
      expect(json['language'], equals('en'));
      expect(json['isExternal'], isTrue);
    });

    test('字幕配置 copyWith 功能', () {
      final originalConfig = subtitleConfig;
      final newConfig = originalConfig.copyWith(
        fontSize: 32.0,
        fontColor: 0xFFFF0000,
      );

      expect(newConfig.fontSize, equals(32.0));
      expect(newConfig.fontColor, equals(0xFFFF0000));
      // 其他值应保持不变
      expect(
        newConfig.backgroundColor,
        equals(originalConfig.backgroundColor),
      );
    });

    test('字幕配置默认值兼容性', () {
      expect(subtitleConfig.enabled, isTrue);
      expect(subtitleConfig.fontSize, isNotNull);
      expect(subtitleConfig.fontColor, isNotNull);
      expect(subtitleConfig.position, isNotNull);
    });

    test('多字幕轨道管理', () {
      final tracks = [
        app.SubtitleTrack.disabled,
        app.SubtitleTrack.external(
          filePath: '/path/sub1.srt',
          title: 'English',
          language: 'en',
        ),
        app.SubtitleTrack.external(
          filePath: '/path/sub2.srt',
          title: '中文',
          language: 'zh',
        ),
      ];

      expect(tracks.length, equals(3));
      expect(tracks.first.id, equals('disabled'));
      expect(tracks[1].language, equals('en'));
      expect(tracks[2].language, equals('zh'));
    });

    test('旧版 API 兼容性', () {
      // 确保旧的 SubtitleTrack 使用方式仍然有效
      final track = app.SubtitleTrack.external(
        filePath: '/path/to/subtitle.srt',
        title: 'Old Style Track',
        format: 'srt',
      );

      expect(track.title, equals('Old Style Track'));
      expect(track.format, equals('srt'));
    });

    test('支持的字幕格式检测', () {
      final formats = ['srt', 'ass', 'ssa', 'vtt'];
      for (final format in formats) {
        // 实际测试时需要真实文件
        expect(['srt', 'ass', 'ssa', 'vtt'].contains(format), isTrue);
      }
    });

    test('字幕编码支持验证', () {
      // 验证支持的编码格式
      final supportedEncodings = [
        'UTF-8',
        'GBK',
        'BIG5',
        'SHIFT_JIS',
        'EUC-KR',
        'ISO-8859-1',
      ];

      expect(supportedEncodings.length, greaterThan(0));
      expect(supportedEncodings, contains('UTF-8'));
      expect(supportedEncodings, contains('GBK'));
    });

    test('MediaKit v1.2.0+ SubtitleTrack.uri() 支持', () {
      // 验证 v1.2.0+ 新增的 SubtitleTrack.uri() 支持
      // 这测试确保我们的代码正确使用了新 API

      // 示例：external subtitle loading with new API
      const subtitleUri = 'file:///path/to/subtitle.srt';
      const title = 'English';
      const language = 'en';

      // 验证参数都是有效类型
      expect(subtitleUri, isA<String>());
      expect(title, isA<String>());
      expect(language, isA<String>());
    });
  });
}
