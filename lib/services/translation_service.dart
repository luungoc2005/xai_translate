import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/llm_provider.dart';
import '../models/regional_preference.dart';
import '../models/translation_stats.dart';

class TranslationService {
  final http.Client client;

  TranslationService({http.Client? client}) : client = client ?? http.Client();

  String _buildTranslationPrompt({
    required String text,
    String? sourceLanguage,
    required String targetLanguage,
    RegionalPreference regionalPreference = RegionalPreference.none,
  }) {
    // Base translation instruction
    String instruction;
    if (sourceLanguage == null || sourceLanguage == 'Auto-detect') {
      instruction = 'Translate this text to $targetLanguage: $text';
    } else {
      instruction = 'Translate this text from $sourceLanguage to $targetLanguage: $text';
    }

    // Add regional preference instructions if applicable
    if (regionalPreference != RegionalPreference.none) {
      final currency = regionalPreference.currency;
      final unitSystem = regionalPreference.unitSystem;
      final region = regionalPreference.name;
      
      instruction += '\n\nIMPORTANT: Add translator notes (T/N) in parentheses after any:';
      instruction += '\n- Currency conversions: Convert and show in $currency. Example: "100 USD (T/N: ~$currency 135)". Do not convert if already in $currency.';
      instruction += '\n- Unit conversions: Convert to $unitSystem units. Example: "5 miles (T/N: ~8 km)". Do not convert if units are already in $unitSystem.';
      instruction += '\n- Temperature: Use Celsius. Example: "75°F (T/N: ~24°C)"';
      instruction += '\n- Cultural/contextual hints relevant to $region context when helpful';
      instruction += '\n\nProvide the translation with these inline T/N annotations to help readers in $region understand the content better.';
    }

    return instruction;
  }

  int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    
    // Check if text contains CJK (Chinese, Japanese, Korean) characters
    final cjkPattern = RegExp(r'[\u4E00-\u9FFF\u3400-\u4DBF\u3040-\u309F\u30A0-\u30FF\uAC00-\uD7AF]');
    final hasCJK = cjkPattern.hasMatch(trimmed);
    
    if (hasCJK) {
      // For CJK languages, count characters (excluding spaces and punctuation)
      // Also count space-separated words for mixed content
      int totalCount = 0;
      
      // Split by spaces to handle mixed content
      final segments = trimmed.split(RegExp(r'\s+'));
      
      for (final segment in segments) {
        if (segment.isEmpty) continue;
        
        // Check if this segment contains CJK characters
        if (cjkPattern.hasMatch(segment)) {
          // Count CJK characters in this segment
          totalCount += cjkPattern.allMatches(segment).length;
        } else {
          // Non-CJK segment (like English word), count as 1 word
          totalCount += 1;
        }
      }
      
      return totalCount;
    } else {
      // For non-CJK languages, count space-separated words
      return trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    }
  }

  Future<Map<String, dynamic>> translateWithStats({
    required String text,
    String? sourceLanguage,
    required String targetLanguage,
    required LLMProvider provider,
    required String apiKey,
    RegionalPreference regionalPreference = RegionalPreference.none,
  }) async {
    final startTime = DateTime.now();
    final wordCount = _countWords(text);
    
    final translation = await translate(
      text: text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      provider: provider,
      apiKey: apiKey,
      regionalPreference: regionalPreference,
    );
    
    final endTime = DateTime.now();
    final responseTimeMs = endTime.difference(startTime).inMilliseconds;
    
    final stats = TranslationStats(
      provider: provider,
      sourceLanguage: sourceLanguage ?? 'Auto-detect',
      wordCount: wordCount,
      responseTimeMs: responseTimeMs,
      regionalPreferenceEnabled: regionalPreference != RegionalPreference.none,
      timestamp: endTime,
    );
    
    return {
      'translation': translation,
      'stats': stats,
    };
  }

  Future<String> translate({
    required String text,
    String? sourceLanguage,
    required String targetLanguage,
    required LLMProvider provider,
    required String apiKey,
    RegionalPreference regionalPreference = RegionalPreference.none,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('API key is required');
    }

    if (text.isEmpty) {
      return '';
    }

    switch (provider) {
      case LLMProvider.grok:
      case LLMProvider.openai:
        return _translateWithOpenAICompatible(
          text: text,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          provider: provider,
          apiKey: apiKey,
          regionalPreference: regionalPreference,
        );
      case LLMProvider.gemini:
        return _translateWithGemini(
          text: text,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          apiKey: apiKey,
          regionalPreference: regionalPreference,
        );
    }
  }

  Future<String> _translateWithOpenAICompatible({
    required String text,
    String? sourceLanguage,
    required String targetLanguage,
    required LLMProvider provider,
    required String apiKey,
    RegionalPreference regionalPreference = RegionalPreference.none,
  }) async {
    final url = Uri.parse(provider.apiEndpoint);
    
    // Build translation instruction using centralized prompt function
    final translationInstruction = _buildTranslationPrompt(
      text: text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      regionalPreference: regionalPreference,
    );
    
    final response = await client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': provider.model,
        'messages': [
          {
            'role': 'system',
            'content': 'You are a professional translator. Translate the given text to the target language. Only respond with the translated text, nothing else.',
          },
          {
            'role': 'user',
            'content': translationInstruction,
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'].toString().trim();
    } else {
      throw Exception('Translation failed: ${response.statusCode} ${response.body}');
    }
  }

  Future<String> _translateWithGemini({
    required String text,
    String? sourceLanguage,
    required String targetLanguage,
    required String apiKey,
    RegionalPreference regionalPreference = RegionalPreference.none,
  }) async {
    final url = Uri.parse('${LLMProvider.gemini.apiEndpoint}?key=$apiKey');
    
    // Build translation instruction using centralized prompt function
    final translationInstruction = 'You are a professional translator. Translate the given text to the target language. Only respond with the translated text, nothing else.\n\n${_buildTranslationPrompt(
      text: text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      regionalPreference: regionalPreference,
    )}';
    
    final response = await client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text': translationInstruction,
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'].toString().trim();
    } else {
      throw Exception('Translation failed: ${response.statusCode} ${response.body}');
    }
  }
}
