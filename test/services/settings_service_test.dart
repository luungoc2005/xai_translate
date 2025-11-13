import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xai_translate/services/settings_service.dart';
import 'package:xai_translate/models/llm_provider.dart';
import 'package:xai_translate/models/regional_preference.dart';

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

    test('should return None as default regional preference', () async {
      // Arrange
      // Mock already set up in setUp()
      
      // Act
      final preference = await settingsService.getRegionalPreference();

      // Assert
      expect(preference, RegionalPreference.none);
    });

    test('should save and retrieve regional preference', () async {
      // Arrange
      // Mock already set up in setUp()
      
      // Act
      await settingsService.setRegionalPreference(RegionalPreference.singapore);
      final preference = await settingsService.getRegionalPreference();

      // Assert
      expect(preference, RegionalPreference.singapore);
    });

    test('should handle switching between regional preferences', () async {
      // Arrange
      // Mock already set up in setUp()
      
      // Act
      await settingsService.setRegionalPreference(RegionalPreference.singapore);
      var preference = await settingsService.getRegionalPreference();
      expect(preference, RegionalPreference.singapore);
      
      await settingsService.setRegionalPreference(RegionalPreference.none);
      preference = await settingsService.getRegionalPreference();

      // Assert
      expect(preference, RegionalPreference.none);
    });

    test('should return Auto-detect as default source language', () async {
      // Arrange
      // Mock already set up in setUp()
      
      // Act
      final sourceLanguage = await settingsService.getSourceLanguage();

      // Assert
      expect(sourceLanguage, 'Auto-detect');
    });

    test('should save and retrieve source language', () async {
      // Arrange
      // Mock already set up in setUp()
      
      // Act
      await settingsService.setSourceLanguage('English');
      final sourceLanguage = await settingsService.getSourceLanguage();

      // Assert
      expect(sourceLanguage, 'English');
    });

    test('should return English as default target language', () async {
      // Arrange
      // Mock already set up in setUp()
      
      // Act
      final targetLanguage = await settingsService.getTargetLanguage();

      // Assert
      expect(targetLanguage, 'English');
    });

    test('should save and retrieve target language', () async {
      // Arrange
      // Mock already set up in setUp()
      
      // Act
      await settingsService.setTargetLanguage('French');
      final targetLanguage = await settingsService.getTargetLanguage();

      // Assert
      expect(targetLanguage, 'French');
    });

    test('should persist both source and target language selections', () async {
      // Arrange
      // Mock already set up in setUp()
      
      // Act
      await settingsService.setSourceLanguage('German');
      await settingsService.setTargetLanguage('Japanese');
      
      final sourceLanguage = await settingsService.getSourceLanguage();
      final targetLanguage = await settingsService.getTargetLanguage();

      // Assert
      expect(sourceLanguage, 'German');
      expect(targetLanguage, 'Japanese');
    });

    test('should handle changing language selections multiple times', () async {
      // Arrange
      // Mock already set up in setUp()
      
      // Act
      await settingsService.setSourceLanguage('Chinese');
      await settingsService.setTargetLanguage('Korean');
      
      var source = await settingsService.getSourceLanguage();
      var target = await settingsService.getTargetLanguage();
      expect(source, 'Chinese');
      expect(target, 'Korean');
      
      await settingsService.setSourceLanguage('French');
      await settingsService.setTargetLanguage('Portuguese');
      
      source = await settingsService.getSourceLanguage();
      target = await settingsService.getTargetLanguage();

      // Assert
      expect(source, 'French');
      expect(target, 'Portuguese');
    });
  });
}
