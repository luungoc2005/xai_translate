import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../models/llm_provider.dart';
import '../models/regional_preference.dart';
import '../models/translation_stats.dart';
import '../models/conversation_message.dart';

class TranslationService {
  final http.Client client;

  TranslationService({http.Client? client}) : client = client ?? http.Client();

  /// Builds a comprehensive system prompt with all translation instructions
  String _buildSystemPrompt({
    String? sourceLanguage,
    required String targetLanguage,
    RegionalPreference regionalPreference = RegionalPreference.none,
    bool isImageTranslation = false,
    bool isFromWhisper = false,
  }) {
    String systemPrompt = 'You are a professional language translator.';
    
    // Base translation instruction
    if (isImageTranslation) {
      systemPrompt += ' Translate any text in the provided image to $targetLanguage.';
      
      // Add menu-specific instruction
      systemPrompt += '\n\n<menu_image_notes>';
      systemPrompt += '\nIf the image happens to be a menu, keep the original dish names in their original language and script (not romanized) in parentheses next to the translated names. Example: "Translated Dish Name (原始菜名)".';
      systemPrompt += '\n</menu_image_notes>';
    } else {
      if (sourceLanguage == null || sourceLanguage == 'Auto-detect') {
        systemPrompt += ' Translate the provided text to $targetLanguage.';
      } else {
        systemPrompt += ' Translate the provided text from $sourceLanguage to $targetLanguage.';
      }
    }

    // Add regional preference instructions if applicable
    if (regionalPreference != RegionalPreference.none) {
      final currency = regionalPreference.currency;
      final unitSystem = regionalPreference.unitSystem;
      final region = regionalPreference.name;
      
      systemPrompt += '\n\n<translator_notes>';
      systemPrompt += '\nAdd translator notes (T/N) in parentheses after any:';
      systemPrompt += '\n- Currency conversions: Convert and show in $currency. Example: "100 USD (T/N: ~$currency 135)". Do not convert if already in $currency.';
      systemPrompt += '\n- Unit conversions: Convert to $unitSystem units. Example: "5 miles (T/N: ~8 km)". Do not convert if units are already in $unitSystem.';
      systemPrompt += '\n- Temperature: Use Celsius. Example: "75°F (T/N: ~24°C)"';
      systemPrompt += '\n- Cultural/contextual hints relevant to $region context when helpful';
      systemPrompt += '\n\nProvide the translation with these inline T/N annotations to help readers in $region understand the content better.';
      systemPrompt += '\nIMPORTANT: Provide unit/currency conversions immediately next to the original values. Only provide the converted values, do NOT explain how to perform the conversions.';
      systemPrompt += '\n</translator_notes>';
    }

    // Add note about Whisper transcription if applicable
    if (isFromWhisper && !isImageTranslation) {
      systemPrompt += '\n\n<speech_to_text_notes>';
      systemPrompt += '\nThe input text was transcribed from speech using a speech-to-text model and may contain errors or phonetically similar incorrect words. Please infer the correct intended text from context and phonetic similarity before translating. Fix any obvious transcription errors to ensure accurate translation.';
      systemPrompt += '\n</speech_to_text_notes>';
    }

    systemPrompt += '\n\n<output_format>';
    systemPrompt += '\n1. Only respond with the translated text, nothing else.';
    systemPrompt += '\n2. You can format the output using markdown for better readability.';
    systemPrompt += '\n</output_format>';

    return systemPrompt;
  }

  /// Converts technical exceptions into user-friendly error messages
  String _getUserFriendlyErrorMessage(dynamic error) {
    final errorString = error.toString();
    
    // Network connectivity issues
    if (error is SocketException) {
      if (errorString.contains('Failed host lookup')) {
        return 'Unable to connect to the translation service. Please check your internet connection and try again.';
      }
      return 'Network error: Unable to reach the translation service. Please check your connection.';
    }
    
    // HTTP client errors
    if (error is http.ClientException) {
      return 'Connection error: Could not connect to the translation service.';
    }
    
    // Timeout errors
    if (errorString.contains('TimeoutException') || errorString.contains('timed out')) {
      return 'Request timed out. The service is taking too long to respond. Please try again.';
    }
    
    // API key errors
    if (errorString.contains('401') || errorString.contains('Unauthorized')) {
      return 'Invalid API key. Please check your API key in settings.';
    }
    
    // Rate limiting
    if (errorString.contains('429') || errorString.contains('rate limit')) {
      return 'Rate limit exceeded. Please wait a moment before trying again.';
    }
    
    // Server errors
    if (errorString.contains('500') || errorString.contains('502') || errorString.contains('503')) {
      return 'The translation service is temporarily unavailable. Please try again later.';
    }
    
    // API response errors
    if (errorString.contains('Translation failed:')) {
      return errorString.replaceAll('Exception: ', '');
    }
    
    // Generic fallback
    return 'Translation failed: ${errorString.replaceAll('Exception: ', '')}';
  }



  /// Scales down an image if it's too large, maintaining aspect ratio
  /// Target max dimension is 2048px for good quality while saving bandwidth
  Future<List<int>> _scaleImageIfNeeded(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    final image = img.decodeImage(imageBytes);
    
    if (image == null) {
      // If we can't decode, return original bytes
      return imageBytes;
    }

    // Define max dimension (2048px is a good balance for AI vision models)
    const maxDimension = 1024;
    
    // Check if scaling is needed
    if (image.width <= maxDimension && image.height <= maxDimension) {
      // Image is already small enough, return original bytes
      return imageBytes;
    }

    // Calculate new dimensions maintaining aspect ratio
    int newWidth, newHeight;
    if (image.width > image.height) {
      newWidth = maxDimension;
      newHeight = (image.height * maxDimension / image.width).round();
    } else {
      newHeight = maxDimension;
      newWidth = (image.width * maxDimension / image.height).round();
    }

    // Resize the image
    final resized = img.copyResize(image, width: newWidth, height: newHeight);
    
    // Encode back to JPEG with 85% quality (good balance between size and quality)
    final resizedBytes = img.encodeJpg(resized, quality: 85);
    
    return resizedBytes;
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
    File? image,
    bool isFromWhisper = false,
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
      image: image,
      isFromWhisper: isFromWhisper,
    );
    
    final endTime = DateTime.now();
    final responseTimeMs = endTime.difference(startTime).inMilliseconds;
    
    final stats = TranslationStats(
      provider: provider,
      sourceLanguage: sourceLanguage ?? 'Auto-detect',
      wordCount: wordCount,
      imageCount: image != null ? 1 : 0,
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
    File? image,
    bool isFromWhisper = false,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('API key is required');
    }

    if (text.isEmpty && image == null) {
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
          image: image,
          isFromWhisper: isFromWhisper,
        );
      case LLMProvider.gemini:
        return _translateWithGemini(
          text: text,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          apiKey: apiKey,
          regionalPreference: regionalPreference,
          image: image,
          isFromWhisper: isFromWhisper,
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
    File? image,
    bool isFromWhisper = false,
  }) async {
    try {
      final url = Uri.parse(provider.apiEndpoint);
      
      // Build comprehensive system prompt
      final systemPrompt = _buildSystemPrompt(
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        regionalPreference: regionalPreference,
        isImageTranslation: image != null,
        isFromWhisper: isFromWhisper,
      );
      
      // Build the user message content (only the content to translate)
      List<Map<String, dynamic>> contentParts = [];
      
      if (image != null) {
        // Scale and add image as base64
        final imageBytes = await _scaleImageIfNeeded(image);
        final base64Image = base64Encode(imageBytes);
        // Always use JPEG mime type after scaling (unless original was PNG and not scaled)
        final extension = image.path.split('.').last.toLowerCase();
        final originalBytes = await image.readAsBytes();
        final mimeType = (imageBytes.length == originalBytes.length && extension == 'png') 
            ? 'image/png' 
            : 'image/jpeg';
        
        contentParts.add({
          'type': 'image_url',
          'image_url': {
            'url': 'data:$mimeType;base64,$base64Image',
          },
        });
      }
      
      // Add text to translate (or additional context for images)
      if (text.isNotEmpty) {
        contentParts.add({
          'type': 'text',
          'text': text,
        });
      }
      
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
              'content': systemPrompt,
            },
            {
              'role': 'user',
              'content': contentParts,
            },
          ],
        }),
      ).timeout(Duration(seconds: image != null ? 180 : 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      } else {
        throw Exception('Translation failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception(_getUserFriendlyErrorMessage(e));
    }
  }

  Future<String> _translateWithGemini({
    required String text,
    String? sourceLanguage,
    required String targetLanguage,
    required String apiKey,
    RegionalPreference regionalPreference = RegionalPreference.none,
    File? image,
    bool isFromWhisper = false,
  }) async {
    try {
      final url = Uri.parse('${LLMProvider.gemini.apiEndpoint}/${LLMProvider.gemini.model}:generateContent?key=$apiKey');
      
      // Build comprehensive system prompt
      final systemPrompt = _buildSystemPrompt(
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        regionalPreference: regionalPreference,
        isImageTranslation: image != null,
        isFromWhisper: isFromWhisper,
      );
      
      // Build the content parts (only the content to translate)
      List<Map<String, dynamic>> parts = [];
      
      // Add system instructions as first text part
      parts.add({
        'text': systemPrompt,
      });
      
      if (image != null) {
        // Scale and add image as inline data
        final imageBytes = await _scaleImageIfNeeded(image);
        final base64Image = base64Encode(imageBytes);
        // Always use JPEG mime type after scaling (unless original was PNG and not scaled)
        final extension = image.path.split('.').last.toLowerCase();
        final originalBytes = await image.readAsBytes();
        final mimeType = (imageBytes.length == originalBytes.length && extension == 'png') 
            ? 'image/png' 
            : 'image/jpeg';
        
        parts.add({
          'inline_data': {
            'mime_type': mimeType,
            'data': base64Image,
          },
        });
      }
      
      // Add text to translate (or additional context for images)
      if (text.isNotEmpty) {
        parts.add({
          'text': text,
        });
      }
      
      final response = await client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': parts,
            },
          ],
        }),
      ).timeout(Duration(seconds: image != null ? 180 : 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'].toString().trim();
      } else {
        throw Exception('Translation failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception(_getUserFriendlyErrorMessage(e));
    }
  }

  /// Translate text with conversation history context for better contextual translations in conversation mode
  Future<String> translateInConversationMode({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    required LLMProvider provider,
    required String apiKey,
    RegionalPreference regionalPreference = RegionalPreference.none,
    List<ConversationMessage> conversationHistory = const [],
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
        return _translateInConversationModeOpenAICompatible(
          text: text,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          provider: provider,
          apiKey: apiKey,
          regionalPreference: regionalPreference,
          conversationHistory: conversationHistory,
        );
      case LLMProvider.gemini:
        return _translateInConversationModeGemini(
          text: text,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          apiKey: apiKey,
          regionalPreference: regionalPreference,
          conversationHistory: conversationHistory,
        );
    }
  }

  /// Auto-detect which of two languages the text is in and translate to the other in conversation mode
  Future<Map<String, String>> translateInConversationModeWithAutoDetect({
    required String text,
    required String language1,
    required String language2,
    required LLMProvider provider,
    required String apiKey,
    RegionalPreference regionalPreference = RegionalPreference.none,
    List<ConversationMessage> conversationHistory = const [],
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('API key is required');
    }

    if (text.isEmpty) {
      return {'detectedLanguage': language1, 'translation': ''};
    }

    switch (provider) {
      case LLMProvider.grok:
      case LLMProvider.openai:
        return _translateInConversationModeWithAutoDetectOpenAICompatible(
          text: text,
          language1: language1,
          language2: language2,
          provider: provider,
          apiKey: apiKey,
          regionalPreference: regionalPreference,
          conversationHistory: conversationHistory,
        );
      case LLMProvider.gemini:
        return _translateInConversationModeWithAutoDetectGemini(
          text: text,
          language1: language1,
          language2: language2,
          apiKey: apiKey,
          regionalPreference: regionalPreference,
          conversationHistory: conversationHistory,
        );
    }
  }

  Future<String> _translateInConversationModeOpenAICompatible({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    required LLMProvider provider,
    required String apiKey,
    RegionalPreference regionalPreference = RegionalPreference.none,
    List<ConversationMessage> conversationHistory = const [],
  }) async {
    try {
      final url = Uri.parse(provider.apiEndpoint);
      
      // Build system prompt with conversation history
      String systemPrompt = 'You are a professional language translator in a conversation mode. Translate between $sourceLanguage and $targetLanguage.';
      
      if (regionalPreference != RegionalPreference.none) {
        final currency = regionalPreference.currency;
        final unitSystem = regionalPreference.unitSystem;
        systemPrompt += '\n\nAdd translator notes (T/N) for currency (convert to $currency), units (convert to $unitSystem), and cultural context when relevant.';
      }
      
      // Add conversation history to system prompt
      if (conversationHistory.isNotEmpty) {
        systemPrompt += '\n\nConversation history for context:';
        for (final msg in conversationHistory) {
          final role = msg.isUserInput ? 'User' : 'Assistant';
          systemPrompt += '\n$role (${msg.language}): ${msg.text}';
        }
      }
      
      systemPrompt += '\n\nUse the conversation history above to maintain context and improve translation accuracy. Only respond with the translated text, nothing else.';
      
      // Build messages array with only system prompt and current message
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
              'content': systemPrompt,
            },
            {
              'role': 'user',
              'content': '$sourceLanguage: $text',
            },
          ],
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      } else {
        throw Exception('Translation failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception(_getUserFriendlyErrorMessage(e));
    }
  }

  Future<String> _translateInConversationModeGemini({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    required String apiKey,
    RegionalPreference regionalPreference = RegionalPreference.none,
    List<ConversationMessage> conversationHistory = const [],
  }) async {
    try {
      final url = Uri.parse('${LLMProvider.gemini.apiEndpoint}/${LLMProvider.gemini.model}:generateContent?key=$apiKey');
      
      // Build system prompt with conversation history
      String systemPrompt = 'You are a professional language translator in a conversation mode. Translate between $sourceLanguage and $targetLanguage.';
      
      if (regionalPreference != RegionalPreference.none) {
        final currency = regionalPreference.currency;
        final unitSystem = regionalPreference.unitSystem;
        systemPrompt += '\n\nAdd translator notes (T/N) for currency (convert to $currency), units (convert to $unitSystem), and cultural context when relevant.';
      }
      
      // Add conversation history to system prompt
      if (conversationHistory.isNotEmpty) {
        systemPrompt += '\n\nConversation history for context:';
        for (final msg in conversationHistory) {
          final role = msg.isUserInput ? 'User' : 'Assistant';
          systemPrompt += '\n$role (${msg.language}): ${msg.text}';
        }
      }
      
      systemPrompt += '\n\nUse the conversation history above to maintain context and improve translation accuracy. Only respond with the translated text, nothing else.';
      systemPrompt += '\n\nNow translate this message:';
      
      List<Map<String, dynamic>> parts = [
        {'text': systemPrompt},
        {'text': '$sourceLanguage: $text'},
      ];
      
      final response = await client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': parts,
            },
          ],
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'].toString().trim();
      } else {
        throw Exception('Translation failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception(_getUserFriendlyErrorMessage(e));
    }
  }

  Future<Map<String, String>> _translateInConversationModeWithAutoDetectOpenAICompatible({
    required String text,
    required String language1,
    required String language2,
    required LLMProvider provider,
    required String apiKey,
    RegionalPreference regionalPreference = RegionalPreference.none,
    List<ConversationMessage> conversationHistory = const [],
  }) async {
    try {
      final url = Uri.parse(provider.apiEndpoint);
      
      // Build system prompt for auto-detection with conversation history
      String systemPrompt = 'You are a professional language translator in a conversation mode. You will receive text in either $language1 or $language2, and you must:';
      systemPrompt += '\n1. Detect which language the input text is in';
      systemPrompt += '\n2. Translate it to the other language ($language1 -> $language2, or $language2 -> $language1)';
      systemPrompt += '\n3. Respond in JSON format: {"detectedLanguage": "<detected language>", "translation": "<translated text>"}';
      
      if (regionalPreference != RegionalPreference.none) {
        final currency = regionalPreference.currency;
        final unitSystem = regionalPreference.unitSystem;
        systemPrompt += '\n\nAdd translator notes (T/N) for currency (convert to $currency), units (convert to $unitSystem), and cultural context when relevant.';
      }
      
      // Add conversation history to system prompt
      if (conversationHistory.isNotEmpty) {
        systemPrompt += '\n\nConversation history for context:';
        for (final msg in conversationHistory) {
          final role = msg.isUserInput ? 'User' : 'Assistant';
          systemPrompt += '\n$role (${msg.language}): ${msg.text}';
        }
      }
      
      systemPrompt += '\n\nUse the conversation history above to maintain context and improve translation accuracy.';
      
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
              'content': systemPrompt,
            },
            {
              'role': 'user',
              'content': text,
            },
          ],
          'response_format': {'type': 'json_object'},
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'].toString();
        final result = jsonDecode(content);
        return {
          'detectedLanguage': result['detectedLanguage'].toString(),
          'translation': result['translation'].toString(),
        };
      } else {
        throw Exception('Translation failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception(_getUserFriendlyErrorMessage(e));
    }
  }

  Future<Map<String, String>> _translateInConversationModeWithAutoDetectGemini({
    required String text,
    required String language1,
    required String language2,
    required String apiKey,
    RegionalPreference regionalPreference = RegionalPreference.none,
    List<ConversationMessage> conversationHistory = const [],
  }) async {
    try {
      final url = Uri.parse('${LLMProvider.gemini.apiEndpoint}/${LLMProvider.gemini.model}:generateContent?key=$apiKey');
      
      // Build system prompt for auto-detection with conversation history
      String systemPrompt = 'You are a professional language translator in a conversation mode. You will receive text in either $language1 or $language2, and you must:';
      systemPrompt += '\n1. Detect which language the input text is in';
      systemPrompt += '\n2. Translate it to the other language ($language1 -> $language2, or $language2 -> $language1)';
      systemPrompt += '\n3. Respond in JSON format: {"detectedLanguage": "<detected language>", "translation": "<translated text>"}';
      
      if (regionalPreference != RegionalPreference.none) {
        final currency = regionalPreference.currency;
        final unitSystem = regionalPreference.unitSystem;
        systemPrompt += '\n\nAdd translator notes (T/N) for currency (convert to $currency), units (convert to $unitSystem), and cultural context when relevant.';
      }
      
      // Add conversation history to system prompt
      if (conversationHistory.isNotEmpty) {
        systemPrompt += '\n\nConversation history for context:';
        for (final msg in conversationHistory) {
          final role = msg.isUserInput ? 'User' : 'Assistant';
          systemPrompt += '\n$role (${msg.language}): ${msg.text}';
        }
      }
      
      systemPrompt += '\n\nUse the conversation history above to maintain context and improve translation accuracy. IMPORTANT: Respond ONLY with valid JSON, no other text.';
      systemPrompt += '\n\nNow detect the language and translate this message:';
      
      List<Map<String, dynamic>> parts = [
        {'text': systemPrompt},
        {'text': text},
      ];
      
      final response = await client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': parts,
            },
          ],
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['candidates'][0]['content']['parts'][0]['text'].toString().trim();
        
        // Try to parse JSON response
        try {
          final result = jsonDecode(content);
          return {
            'detectedLanguage': result['detectedLanguage'].toString(),
            'translation': result['translation'].toString(),
          };
        } catch (e) {
          // If JSON parsing fails, try to extract from text
          // This is a fallback for when Gemini doesn't return pure JSON
          final detectedMatch = RegExp(r'"detectedLanguage"\s*:\s*"([^"]+)"').firstMatch(content);
          final translationMatch = RegExp(r'"translation"\s*:\s*"([^"]+)"').firstMatch(content);
          
          if (detectedMatch != null && translationMatch != null) {
            return {
              'detectedLanguage': detectedMatch.group(1)!,
              'translation': translationMatch.group(1)!,
            };
          }
          
          throw Exception('Failed to parse auto-detect response from Gemini');
        }
      } else {
        throw Exception('Translation failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception(_getUserFriendlyErrorMessage(e));
    }
  }
}

