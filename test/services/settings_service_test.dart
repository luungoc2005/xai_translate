import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xai_translate/services/settings_service.dart';
import 'package:xai_translate/models/llm_provider.dart';

@GenerateMocks([SharedPreferences])
void main() {
  group('SettingsService', () {
    late SettingsService settingsService;

    setUp(() {
      // Initialize mock shared preferences before each test
      SharedPreferences.setMockInitialValues({});
      settingsService = SettingsService();
    });

    test('should return Grok as default provider', () async {
      // Arrange
      // Mock already set up in setUp()
      
      // Act
      final provider = await settingsService.getSelectedProvider();

      // Assert
      expect(provider, LLMProvider.grok);
    });

    test('should save and retrieve selected provider', () async {
      // Arrange
      // Mock already set up in setUp()
      
      // Act
      await settingsService.setSelectedProvider(LLMProvider.openai);
      final provider = await settingsService.getSelectedProvider();

      // Assert
      expect(provider, LLMProvider.openai);
    });

    test('should save and retrieve API key for provider', () async {
      // Arrange
      // Mock already set up in setUp()
      const apiKey = 'test_api_key_123';
      
      // Act
      await settingsService.setApiKey(LLMProvider.grok, apiKey);
      final retrievedKey = await settingsService.getApiKey(LLMProvider.grok);

      // Assert
      expect(retrievedKey, apiKey);
    });

    test('should return empty string when API key not set', () async {
      // Arrange
      // Mock already set up in setUp()
      
      // Act
      final retrievedKey = await settingsService.getApiKey(LLMProvider.gemini);

      // Assert
      expect(retrievedKey, '');
    });

    test('should save different API keys for different providers', () async {
      // Arrange
      // Mock already set up in setUp()
      const grokKey = 'grok_key';
      const openaiKey = 'openai_key';
      const geminiKey = 'gemini_key';
      
      // Act
      await settingsService.setApiKey(LLMProvider.grok, grokKey);
      await settingsService.setApiKey(LLMProvider.openai, openaiKey);
      await settingsService.setApiKey(LLMProvider.gemini, geminiKey);
      
      final retrievedGrokKey = await settingsService.getApiKey(LLMProvider.grok);
      final retrievedOpenaiKey = await settingsService.getApiKey(LLMProvider.openai);
      final retrievedGeminiKey = await settingsService.getApiKey(LLMProvider.gemini);

      // Assert
      expect(retrievedGrokKey, grokKey);
      expect(retrievedOpenaiKey, openaiKey);
      expect(retrievedGeminiKey, geminiKey);
    });

    test('should handle saving settings without plugin exception', () async {
      // Arrange
      // Mock already set up in setUp()
      const testApiKey = 'test_key_xyz';
      
      // Act - This should not throw a MissingPluginException
      await settingsService.setSelectedProvider(LLMProvider.gemini);
      await settingsService.setApiKey(LLMProvider.gemini, testApiKey);
      
      // Assert
      final provider = await settingsService.getSelectedProvider();
      final apiKey = await settingsService.getApiKey(LLMProvider.gemini);
      
      expect(provider, LLMProvider.gemini);
      expect(apiKey, testApiKey);
    });

    test('should persist settings across multiple operations', () async {
      // Arrange
      // Mock already set up in setUp()
      
      // Act - Multiple save operations
      await settingsService.setSelectedProvider(LLMProvider.openai);
      await settingsService.setApiKey(LLMProvider.openai, 'key1');
      
      await settingsService.setSelectedProvider(LLMProvider.grok);
      await settingsService.setApiKey(LLMProvider.grok, 'key2');
      
      // Assert - Both should be retrievable
      final grokKey = await settingsService.getApiKey(LLMProvider.grok);
      final openaiKey = await settingsService.getApiKey(LLMProvider.openai);
      final currentProvider = await settingsService.getSelectedProvider();
      
      expect(currentProvider, LLMProvider.grok);
      expect(grokKey, 'key2');
      expect(openaiKey, 'key1');
    });
  });
}
