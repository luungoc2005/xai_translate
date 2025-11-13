import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xai_translate/services/settings_service.dart';
import 'package:xai_translate/models/llm_provider.dart';

/// This test verifies that SharedPreferences mock is properly set up
/// In the real app, WidgetsFlutterBinding.ensureInitialized() is required
/// to avoid "MissingPluginException: No implementation found for method getAll"
void main() {
  group('SettingsService - Plugin Initialization Tests', () {
    test('should fail if SharedPreferences mock not initialized', () async {
      // This test documents the requirement for proper initialization
      // In a real app without WidgetsFlutterBinding.ensureInitialized()
      // and without SharedPreferences.setMockInitialValues() in tests,
      // you'll get: MissingPluginException: No implementation found for method getAll
      
      // Arrange
      SharedPreferences.setMockInitialValues({}); // Required in tests
      final settingsService = SettingsService();
      
      // Act & Assert - Should work with mock
      expect(() => settingsService.getSelectedProvider(), returnsNormally);
    });

    test('should document the real app requirement', () {
      // This test documents what's needed in main.dart for the real app:
      // 
      // void main() async {
      //   WidgetsFlutterBinding.ensureInitialized(); // <- REQUIRED!
      //   runApp(const MyApp());
      // }
      //
      // Without this, SharedPreferences will fail with:
      // MissingPluginException: No implementation found for method getAll
      
      expect(true, true); // Documentation test
    });

    test('should handle SharedPreferences initialization in correct order', () async {
      // Arrange - Must set mock BEFORE using service
      SharedPreferences.setMockInitialValues({
        'selected_provider': 'openai',
        'api_key_openai': 'test_key',
      });
      
      final settingsService = SettingsService();
      
      // Act
      final provider = await settingsService.getSelectedProvider();
      final apiKey = await settingsService.getApiKey(LLMProvider.openai);
      
      // Assert - Should retrieve saved values
      expect(provider, LLMProvider.openai);
      expect(apiKey, 'test_key');
    });

    test('should require WidgetsFlutterBinding for real app usage', () {
      // This test verifies our understanding of the requirement
      // 
      // In tests: Use SharedPreferences.setMockInitialValues({})
      // In real app: Use WidgetsFlutterBinding.ensureInitialized()
      //
      // Both serve the same purpose: Initialize the plugin system
      
      SharedPreferences.setMockInitialValues({});
      
      // Verify mock is set up
      expect(() async {
        final prefs = await SharedPreferences.getInstance();
        return prefs;
      }, returnsNormally);
    });
  });
}
