import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yinghe_player/plugins/builtin/ui_themes/theme_plugin.dart';
import 'package:yinghe_player/core/plugin_system/plugin_interface.dart';

void main() {
  group('ThemePlugin Tests', () {
    late ThemePlugin themePlugin;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      
      // Mock path_provider
      const MethodChannel('plugins.flutter.io/path_provider')
          .setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '.';
        }
        return null;
      });

      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      themePlugin = ThemePlugin();
    });

    tearDown(() async {
      await themePlugin.dispose();
    });

    test('Initializes with default theme when no setting exists', () async {
      await themePlugin.initialize();

      expect(themePlugin.state, PluginState.ready);
      expect(themePlugin.currentThemeInfo.id, 'default');
      expect(themePlugin.currentTheme, isNotNull);
    });

    test('Initializes with saved theme', () async {
      // Setup saved theme
      SharedPreferences.setMockInitialValues({
        'theme_id': 'midnight_blue',
      });

      await themePlugin.initialize();

      expect(themePlugin.state, PluginState.ready);
      expect(themePlugin.currentThemeInfo.id, 'midnight_blue');
      expect(themePlugin.currentTheme, isNotNull);
    });

    test('Falls back to default theme when saved theme is invalid', () async {
      // Setup invalid theme
      SharedPreferences.setMockInitialValues({
        'theme_id': 'invalid_theme_id',
      });

      await themePlugin.initialize();

      expect(themePlugin.state, PluginState.ready);
      expect(themePlugin.currentThemeInfo.id, 'default');
      expect(themePlugin.currentTheme, isNotNull);
      
      // Verify setting was corrected
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_id'), 'default');
    });

    test('applyTheme updates current theme and saves to settings', () async {
      await themePlugin.initialize();

      await themePlugin.applyTheme('forest_green');

      expect(themePlugin.currentThemeInfo.id, 'forest_green');
      
      // Verify setting was saved
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_id'), 'forest_green');
    });

    test('applyTheme throws exception for invalid theme id', () async {
      await themePlugin.initialize();

      expect(
        () => themePlugin.applyTheme('non_existent_theme'),
        throwsException,
      );
    });

    test('themeStream emits events on theme change', () async {
      await themePlugin.initialize();

      final events = <ThemeChangeEvent>[];
      final subscription = themePlugin.themeStream.listen(events.add);

      await themePlugin.applyTheme('sunset_orange');

      await Future.delayed(Duration.zero); // Wait for stream

      expect(events.length, 1);
      expect(events.first.themeId, 'sunset_orange');
      expect(events.first.theme.name, 'Sunset Orange');

      await subscription.cancel();
    });
  });
}
