import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yinghe_player/core/plugin_system/plugin_registry.dart';
import 'package:yinghe_player/core/plugin_system/plugin_loader.dart';
import 'package:yinghe_player/services/metadata_scraper_service.dart';
import 'package:yinghe_player/models/series.dart';
import 'package:yinghe_player/core/plugin_system/plugin_interface.dart';
import 'package:yinghe_player/core/plugin_system/edition_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    // Mock path_provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '/tmp';
        }
        return null;
      },
    );

    // Mock shared_preferences (used by PluginLoader)
    const MethodChannel prefsChannel = MethodChannel('plugins.flutter.io/shared_preferences');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      prefsChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{};
        }
        return null;
      },
    );

    // Initialize Plugin System via Loader ONLY ONCE for all tests in this file
    // Note: EditionConfig.currentEdition is controlled by --dart-define=EDITION=pro
    try {
      await initializePluginSystem(config: PluginLoadConfig(
        autoActivate: true,
        enableLazyLoading: false,
      ));
    } catch (e) {
      // If it's already initialized (late initialization error shouldn't happen here if run once),
      // or if initialization fails (we print it)
      print('Initialization error (expected if re-run): $e');
    }
  });

  test('PluginRegistry should contain MetadataScraperPlugin after initialization', () async {
    final registry = PluginRegistry();
    final pluginId = 'com.coreplayer.metadata_scraper';
    
    // Check metadata
    final metadata = registry.getMetadata(pluginId);
    
    // If we are in Community edition (default test run), this might be null if not registered.
    // If we are in Pro edition, it should be there.
    // We can check EditionConfig to know what to expect.
    
    if (EditionConfig.isProEdition) {
       expect(metadata, isNotNull, reason: 'Metadata Scraper plugin metadata should be registered in PRO edition');
       if (metadata != null) {
         expect(metadata.id, pluginId);
         expect(metadata.name, contains('元数据'));
       }
       
       // Check instance
       final plugin = registry.get(pluginId);
       expect(plugin, isNotNull, reason: 'Plugin instance should be registered in PRO edition');
    } else {
      // In community edition, the loader might NOT load it depending on logic in _getBuiltInPlugins
      // Let's check logic: _getProEditionPlugins is used only if !isCommunityEdition.
      // So in community, it should be null.
      expect(metadata, isNull, reason: 'Metadata Scraper should NOT be present in Community edition');
    }
  });
  
  test('MetadataScraperService delegates correctly', () async {
      // Create a dummy series
      final series = Series.fromPath('/tmp/test_series', 5);
      
      final result = await MetadataScraperService.scrapeSeries(series);
      
      print('Result success: ${result.success}');
      print('Result message: ${result.errorMessage}');
      
      if (EditionConfig.isProEdition) {
         // In Pro edition, the plugin is active.
         // It might fail due to "TMDB Service not initialized" which is expected as we didn't mock TMDB.
         // But it should NOT fail with "Pro edition only".
         expect(result.errorMessage, isNot(contains('自动刮削功能仅在专业版可用')));
         
         // Since we mocked path_provider, it might proceed further.
         // Likely it fails at TMDB init check or Network.
         // The important thing is delegation happened.
      } else {
         // In Community edition, the service facade handles the missing plugin.
         expect(result.success, isFalse);
         expect(result.errorMessage, contains('自动刮削功能仅在专业版可用'));
      }
  });
}
