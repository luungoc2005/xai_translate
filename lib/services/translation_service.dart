import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/llm_provider.dart';

class TranslationService {
  final http.Client client;

  TranslationService({http.Client? client}) : client = client ?? http.Client();

  Future<String> translate({
    required String text,
    required String targetLanguage,
    required LLMProvider provider,
    required String apiKey,
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
          targetLanguage: targetLanguage,
          provider: provider,
          apiKey: apiKey,
        );
      case LLMProvider.gemini:
        return _translateWithGemini(
          text: text,
          targetLanguage: targetLanguage,
          apiKey: apiKey,
        );
    }
  }

  Future<String> _translateWithOpenAICompatible({
    required String text,
    required String targetLanguage,
    required LLMProvider provider,
    required String apiKey,
  }) async {
    final url = Uri.parse(provider.apiEndpoint);
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
            'content': 'Translate this text to $targetLanguage: $text',
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
    required String targetLanguage,
    required String apiKey,
  }) async {
    final url = Uri.parse('${LLMProvider.gemini.apiEndpoint}?key=$apiKey');
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
                'text': 'You are a professional translator. Translate the given text to the target language. Only respond with the translated text, nothing else.\n\nTranslate this text to $targetLanguage: $text',
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
