import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../models/llm_provider.dart';
import '../models/regional_preference.dart';
import '../models/translation_stats.dart';

class TranslationService {
  final http.Client client;

  TranslationService({http.Client? client}) : client = client ?? http.Client();

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

  String _buildTranslationPrompt({
    required String text,
    String? sourceLanguage,
    required String targetLanguage,
    RegionalPreference regionalPreference = RegionalPreference.none,
    bool isImageTranslation = false,
  }) {
    // Base translation instruction
    String instruction;
    
    if (isImageTranslation) {
      // For image translation, we ask the model to translate any text in the image
      if (text.isEmpty) {
        instruction = 'Translate all text visible in the following image to $targetLanguage.';
      } else {
        instruction = 'Translate all text visible in the following image to $targetLanguage. Additional context: $text';
      }
    } else {
      if (sourceLanguage == null || sourceLanguage == 'Auto-detect') {
        instruction = 'Translate this text to $targetLanguage: $text';
      } else {
        instruction = 'Translate this text from $sourceLanguage to $targetLanguage: $text';
      }
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
    const maxDimension = 2048;
    
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
        );
      case LLMProvider.gemini:
        return _translateWithGemini(
          text: text,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          apiKey: apiKey,
          regionalPreference: regionalPreference,
          image: image,
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
  }) async {
    try {
      final url = Uri.parse(provider.apiEndpoint);
      
      // Build translation instruction using centralized prompt function
      final translationInstruction = _buildTranslationPrompt(
        text: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        regionalPreference: regionalPreference,
        isImageTranslation: image != null,
      );
      
      // Build the user message content
      List<Map<String, dynamic>> contentParts = [];
      
      // Add text instruction
      contentParts.add({
        'type': 'text',
        'text': translationInstruction,
      });
      
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
              'content': 'You are a professional language translator. Translate the given text, image or photo to the target language. Only respond with the translated text, nothing else.',
            },
            {
              'role': 'user',
              'content': contentParts,
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

  Future<String> _translateWithGemini({
    required String text,
    String? sourceLanguage,
    required String targetLanguage,
    required String apiKey,
    RegionalPreference regionalPreference = RegionalPreference.none,
    File? image,
  }) async {
    try {
      final url = Uri.parse('${LLMProvider.gemini.apiEndpoint}?key=$apiKey');
      
      // Build translation instruction using centralized prompt function
      final translationInstruction = 'You are a professional translator. Translate the given text or image to the target language. Only respond with the translated text, nothing else.\n\n${_buildTranslationPrompt(
        text: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        regionalPreference: regionalPreference,
        isImageTranslation: image != null,
      )}';
      
      // Build the content parts
      List<Map<String, dynamic>> parts = [];
      
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
      
      // Add text instruction
      parts.add({
        'text': translationInstruction,
      });
      
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
}
