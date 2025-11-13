import 'package:shared_preferences/shared_preferences.dart';
import '../models/llm_provider.dart';
import '../models/regional_preference.dart';

class SettingsService {
  static const String _providerKey = 'selected_provider';
  static const String _apiKeyPrefix = 'api_key_';
  static const String _regionalPreferenceKey = 'regional_preference';
  static const String _sourceLanguageKey = 'source_language';
  static const String _targetLanguageKey = 'target_language';

  Future<LLMProvider> getSelectedProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final providerString = prefs.getString(_providerKey);
    
    if (providerString == null) {
      return LLMProvider.grok; // Default provider
    }
    
    return LLMProviderExtension.fromString(providerString);
  }

  Future<void> setSelectedProvider(LLMProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, provider.toString().split('.').last);
  }

  Future<String> getApiKey(LLMProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_apiKeyPrefix${provider.toString().split('.').last}';
    return prefs.getString(key) ?? '';
  }

  Future<void> setApiKey(LLMProvider provider, String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_apiKeyPrefix${provider.toString().split('.').last}';
    await prefs.setString(key, apiKey);
  }

  Future<RegionalPreference> getRegionalPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final preferenceString = prefs.getString(_regionalPreferenceKey);
    
    if (preferenceString == null) {
      return RegionalPreference.none; // Default preference
    }
    
    return RegionalPreferenceExtension.fromString(preferenceString);
  }

  Future<void> setRegionalPreference(RegionalPreference preference) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_regionalPreferenceKey, preference.toString().split('.').last);
  }

  Future<String> getSourceLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sourceLanguageKey) ?? 'Auto-detect'; // Default source language
  }

  Future<void> setSourceLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sourceLanguageKey, language);
  }

  Future<String> getTargetLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_targetLanguageKey) ?? 'English'; // Default target language
  }

  Future<void> setTargetLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_targetLanguageKey, language);
  }
}
