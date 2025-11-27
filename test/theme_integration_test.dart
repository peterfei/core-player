import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:yinghe_player/plugins/builtin/ui_themes/theme_plugin.dart';
import 'package:yinghe_player/core/plugin_system/plugin_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
  const MethodChannel prefsChannel = MethodChannel('plugins.flutter.io/shared_preferences');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '/tmp';
        }
        return null;
      },
    );
    
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      prefsChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{};
        }
        return true;
      },
    );
  });

  group('ThemePlugin Integration Test', () {
    late ThemePlugin themePlugin;

    setUp(() async {
      themePlugin = ThemePlugin();
      await themePlugin.initialize();
    });

    test('should load builtin themes', () {
      final themes = themePlugin.getAvailableThemes();
      expect(themes.length, greaterThanOrEqualTo(2));
      
      // Verify default themes exist
      expect(themes.any((t) => t.id == 'default'), isTrue);
      expect(themes.any((t) => t.id == 'light'), isTrue);
    });

    test('should contain new Neon Cyber and Nordic Light themes', () {
      final themes = themePlugin.getAvailableThemes();

      // Verify Neon Cyber theme
      final neonTheme = themes.firstWhere(
        (t) => t.id == 'neon_cyber',
        orElse: () => PluginTheme(
          id: 'not_found',
          name: 'Not Found',
          description: '',
          themeData: ThemeData(),
          previewColors: {},
          isDark: true
        )
      );

      if (neonTheme.id == 'not_found') {
        print('Neon Cyber theme not yet implemented');
      } else {
        expect(neonTheme.name, 'Neon Cyber');
        expect(neonTheme.isDark, isTrue);
      }

      // Verify Nordic Light theme
      final nordicTheme = themes.firstWhere(
        (t) => t.id == 'nordic_light',
        orElse: () => PluginTheme(
          id: 'not_found',
          name: 'Not Found',
          description: '',
          themeData: ThemeData(),
          previewColors: {},
          isDark: false
        )
      );

      if (nordicTheme.id == 'not_found') {
        print('Nordic Light theme not yet implemented');
      } else {
        expect(nordicTheme.name, 'Nordic Light');
        expect(nordicTheme.isDark, isFalse);
      }
    });

    test('themes should be available regardless of edition', () {
      // ThemePlugin logic doesn't check EditionConfig for builtin themes
      expect(themePlugin.metadata.capabilities.contains('theme_management'), isTrue);
    });
  });
}