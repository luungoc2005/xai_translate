import 'package:shared_preferences/shared_preferences.dart';
import '../models/llm_provider.dart';

class SettingsService {
  static const String _providerKey = 'selected_provider';
  static const String _apiKeyPrefix = 'api_key_';

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
}
