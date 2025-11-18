import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yinghe_player/screens/video_playback_settings_screen.dart';
import 'package:yinghe_player/services/settings_service.dart';

void main() {
  group('VideoPlaybackSettingsScreen Tests', () {
    // Helper function to wrap the screen in a MaterialApp
    Widget createTestableWidget(Widget child) {
      return MaterialApp(
        home: child,
      );
    }

    testWidgets('应加载并显示初始播放质量设置', (WidgetTester tester) async {
      // Arrange: Set initial mock value
      SharedPreferences.setMockInitialValues({
        'playback_quality_mode': PlaybackQualityMode.highQuality.name,
      });

      // Act
      await tester.pumpWidget(createTestableWidget(const VideoPlaybackSettingsScreen()));
      await tester.pumpAndSettle(); // Wait for async operations like _loadSettings

      // Assert
      // Find the "高质量模式" radio button
      final highQualityRadio = tester.widget<RadioListTile<PlaybackQualityMode>>(
        find.widgetWithText(RadioListTile<PlaybackQualityMode>, '高质量模式'),
      );

      // Check if its groupValue matches its value (i.e., it's selected)
      expect(highQualityRadio.groupValue, highQualityRadio.value);
      expect(find.text('优先使用最高画质，需要较好的硬件支持'), findsOneWidget);
    });

    testWidgets('选择新的播放质量模式时应更新UI并保存设置', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({}); // Start with default settings
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(createTestableWidget(const VideoPlaybackSettingsScreen()));
      await tester.pumpAndSettle();

      // Assert initial state (should be 'auto')
      expect(prefs.getString('playback_quality_mode'), isNull);

      // Act: Tap on "兼容模式"
      await tester.tap(find.text('兼容模式'));
      await tester.pumpAndSettle();

      // Assert UI update
      final compatibilityRadio = tester.widget<RadioListTile<PlaybackQualityMode>>(
        find.widgetWithText(RadioListTile<PlaybackQualityMode>, '兼容模式'),
      );
      expect(compatibilityRadio.groupValue, compatibilityRadio.value);

      // Assert that the setting was saved
      expect(prefs.getString('playback_quality_mode'), PlaybackQualityMode.compatibility.name);
    });

    testWidgets('重置按钮应将设置恢复为默认值', (WidgetTester tester) async {
      // Arrange: Start with a non-default value
      SharedPreferences.setMockInitialValues({
        'playback_quality_mode': PlaybackQualityMode.lowPower.name,
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(createTestableWidget(const VideoPlaybackSettingsScreen()));
      await tester.pumpAndSettle();

      // Assert initial state is "低功耗模式"
      expect(prefs.getString('playback_quality_mode'), PlaybackQualityMode.lowPower.name);
      final lowPowerRadio = tester.widget<RadioListTile<PlaybackQualityMode>>(
        find.widgetWithText(RadioListTile<PlaybackQualityMode>, '低功耗模式'),
      );
      expect(lowPowerRadio.groupValue, lowPowerRadio.value);

      // Act: Tap the reset button
      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();

      // Assert UI has reverted to "自动模式" (the default)
      final autoRadio = tester.widget<RadioListTile<PlaybackQualityMode>>(
        find.widgetWithText(RadioListTile<PlaybackQualityMode>, '自动模式'),
      );
      expect(autoRadio.groupValue, autoRadio.value);

      // Assert that the setting was removed from prefs (reset)
      expect(prefs.getString('playback_quality_mode'), isNull);
    });
  });
}