import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xai_translate/services/settings_service.dart';
import 'package:xai_translate/models/llm_provider.dart';

@GenerateMocks([SharedPreferences])
void main() {
  group('SettingsService', () {
    late SettingsService settingsService;

    setUp(() {
      settingsService = SettingsService();
    });

    test('should return Grok as default provider', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      
      // Act
      final provider = await settingsService.getSelectedProvider();

      // Assert
      expect(provider, LLMProvider.grok);
    });

    test('should save and retrieve selected provider', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      
      // Act
      await settingsService.setSelectedProvider(LLMProvider.openai);
      final provider = await settingsService.getSelectedProvider();

      // Assert
      expect(provider, LLMProvider.openai);
    });

    test('should save and retrieve API key for provider', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      const apiKey = 'test_api_key_123';
      
      // Act
      await settingsService.setApiKey(LLMProvider.grok, apiKey);
      final retrievedKey = await settingsService.getApiKey(LLMProvider.grok);

      // Assert
      expect(retrievedKey, apiKey);
    });

    test('should return empty string when API key not set', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      
      // Act
      final retrievedKey = await settingsService.getApiKey(LLMProvider.gemini);

      // Assert
      expect(retrievedKey, '');
    });

    test('should save different API keys for different providers', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
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
  });
}
