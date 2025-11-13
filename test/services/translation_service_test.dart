import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:xai_translate/services/translation_service.dart';
import 'package:xai_translate/models/llm_provider.dart';
import 'package:xai_translate/models/regional_preference.dart';

import 'translation_service_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  group('TranslationService', () {
    late MockClient mockClient;
    late TranslationService translationService;

    setUp(() {
      mockClient = MockClient();
      translationService = TranslationService(client: mockClient);
    });

    test('should translate text using Grok provider', () async {
      // Arrange
      const text = 'Hello';
      const targetLanguage = 'Spanish';
      const apiKey = 'test_api_key';
      
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
        '{"choices":[{"message":{"content":"Hola"}}]}',
        200,
      ));

      // Act
      final result = await translationService.translate(
        text: text,
        sourceLanguage: 'English',
        targetLanguage: targetLanguage,
        provider: LLMProvider.grok,
        apiKey: apiKey,
      );

      // Assert
      expect(result, 'Hola');
      verify(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).called(1);
    });

    test('should translate text using OpenAI provider', () async {
      // Arrange
      const text = 'Hello';
      const targetLanguage = 'French';
      const apiKey = 'test_api_key';
      
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
        '{"choices":[{"message":{"content":"Bonjour"}}]}',
        200,
      ));

      // Act
      final result = await translationService.translate(
        text: text,
        sourceLanguage: 'English',
        targetLanguage: targetLanguage,
        provider: LLMProvider.openai,
        apiKey: apiKey,
      );

      // Assert
      expect(result, 'Bonjour');
    });

    test('should translate text using Gemini provider', () async {
      // Arrange
      const text = 'Hello';
      const targetLanguage = 'German';
      const apiKey = 'test_api_key';
      
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
        '{"candidates":[{"content":{"parts":[{"text":"Hallo"}]}}]}',
        200,
      ));

      // Act
      final result = await translationService.translate(
        text: text,
        sourceLanguage: 'English',
        targetLanguage: targetLanguage,
        provider: LLMProvider.gemini,
        apiKey: apiKey,
      );

      // Assert
      expect(result, 'Hallo');
    });

    test('should throw exception when API call fails', () async {
      // Arrange
      const text = 'Hello';
      const targetLanguage = 'Spanish';
      const apiKey = 'test_api_key';
      
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response('Error', 500));

      // Act & Assert
      expect(
        () => translationService.translate(
          text: text,
          targetLanguage: targetLanguage,
          provider: LLMProvider.grok,
          apiKey: apiKey,
        ),
        throwsException,
      );
    });

    test('should throw exception when API key is empty', () async {
      // Arrange
      const text = 'Hello';
      const targetLanguage = 'Spanish';
      const apiKey = '';

      // Act & Assert
      expect(
        () => translationService.translate(
          text: text,
          sourceLanguage: 'English',
          targetLanguage: targetLanguage,
          provider: LLMProvider.grok,
          apiKey: apiKey,
        ),
        throwsException,
      );
    });

    test('should detect source language when sourceLanguage is "Auto-detect"', () async {
      // Arrange
      const text = 'Bonjour';
      const sourceLanguage = 'Auto-detect';
      const targetLanguage = 'English';
      const apiKey = 'test_api_key';
      
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
        '{"choices":[{"message":{"content":"Hello"}}]}',
        200,
      ));

      // Act
      final result = await translationService.translate(
        text: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        provider: LLMProvider.grok,
        apiKey: apiKey,
      );

      // Assert
      expect(result, 'Hello');
    });

    test('should use specific source language when provided', () async {
      // Arrange
      const text = 'Hello';
      const sourceLanguage = 'English';
      const targetLanguage = 'Spanish';
      const apiKey = 'test_api_key';
      
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
        '{"choices":[{"message":{"content":"Hola"}}]}',
        200,
      ));

      // Act
      final result = await translationService.translate(
        text: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        provider: LLMProvider.grok,
        apiKey: apiKey,
      );

      // Assert
      expect(result, 'Hola');
      // Verify the prompt includes source language specification
      verify(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: argThat(contains('English'), named: 'body'),
      )).called(1);
    });

    test('should handle auto-detect with Gemini provider', () async {
      // Arrange
      const text = 'Hola';
      const sourceLanguage = 'Auto-detect';
      const targetLanguage = 'English';
      const apiKey = 'test_api_key';
      
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
        '{"candidates":[{"content":{"parts":[{"text":"Hello"}]}}]}',
        200,
      ));

      // Act
      final result = await translationService.translate(
        text: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        provider: LLMProvider.gemini,
        apiKey: apiKey,
      );

      // Assert
      expect(result, 'Hello');
    });

    test('should include regional preference T/N in translation with Singapore preference', () async {
      // Arrange
      const text = 'The book costs 50 USD';
      const targetLanguage = 'Spanish';
      const apiKey = 'test_api_key';
      
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
        '{"choices":[{"message":{"content":"El libro cuesta 50 USD (T/N: ~SGD 67)"}}]}',
        200,
      ));

      // Act
      final result = await translationService.translate(
        text: text,
        sourceLanguage: 'English',
        targetLanguage: targetLanguage,
        provider: LLMProvider.grok,
        apiKey: apiKey,
        regionalPreference: RegionalPreference.singapore,
      );

      // Assert
      expect(result, contains('T/N:'));
      expect(result, contains('SGD'));
    });

    test('should not include T/N when regional preference is none', () async {
      // Arrange
      const text = 'The book costs 50 USD';
      const targetLanguage = 'Spanish';
      const apiKey = 'test_api_key';
      
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
        '{"choices":[{"message":{"content":"El libro cuesta 50 USD"}}]}',
        200,
      ));

      // Act
      final result = await translationService.translate(
        text: text,
        sourceLanguage: 'English',
        targetLanguage: targetLanguage,
        provider: LLMProvider.grok,
        apiKey: apiKey,
        regionalPreference: RegionalPreference.none,
      );

      // Assert
      expect(result, isNot(contains('T/N:')));
    });

    test('should count words correctly for English text', () async {
      // Arrange
      const text = 'Hello world this is a test';
      const targetLanguage = 'Spanish';
      const apiKey = 'test_api_key';
      
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
        '{"choices":[{"message":{"content":"Hola mundo"}}]}',
        200,
      ));

      // Act
      final result = await translationService.translateWithStats(
        text: text,
        sourceLanguage: 'English',
        targetLanguage: targetLanguage,
        provider: LLMProvider.grok,
        apiKey: apiKey,
      );

      // Assert
      final stats = result['stats'];
      expect(stats.wordCount, 6); // "Hello world this is a test" = 6 words
    });

    test('should count characters for Chinese text', () async {
      // Arrange
      const text = '你好世界这是测试'; // Chinese characters
      const targetLanguage = 'English';
      const apiKey = 'test_api_key';
      
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
        '{"choices":[{"message":{"content":"Hello world this is a test"}}]}',
        200,
      ));

      // Act
      final result = await translationService.translateWithStats(
        text: text,
        sourceLanguage: 'Chinese',
        targetLanguage: targetLanguage,
        provider: LLMProvider.grok,
        apiKey: apiKey,
      );

      // Assert
      final stats = result['stats'];
      expect(stats.wordCount, 8); // Count of Chinese characters in the text
    });

    test('should count mixed Chinese and English text correctly', () async {
      // Arrange
      const text = '你好 world 测试'; // 2 Chinese chars + 1 English word + 2 Chinese chars
      const targetLanguage = 'Spanish';
      const apiKey = 'test_api_key';
      
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
        '{"choices":[{"message":{"content":"Hola mundo"}}]}',
        200,
      ));

      // Act
      final result = await translationService.translateWithStats(
        text: text,
        sourceLanguage: 'Chinese',
        targetLanguage: targetLanguage,
        provider: LLMProvider.grok,
        apiKey: apiKey,
      );

      // Assert
      final stats = result['stats'];
      expect(stats.wordCount, 5); // 4 Chinese characters + 1 English word
    });

    test('should count Japanese text correctly', () async {
      // Arrange
      const text = 'こんにちは世界'; // 7 Japanese characters (hiragana + kanji)
      const targetLanguage = 'English';
      const apiKey = 'test_api_key';
      
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
        '{"choices":[{"message":{"content":"Hello world"}}]}',
        200,
      ));

      // Act
      final result = await translationService.translateWithStats(
        text: text,
        sourceLanguage: 'Japanese',
        targetLanguage: targetLanguage,
        provider: LLMProvider.grok,
        apiKey: apiKey,
      );

      // Assert
      final stats = result['stats'];
      expect(stats.wordCount, 7); // 7 Japanese characters
    });

    test('should count Korean text correctly', () async {
      // Arrange
      const text = '안녕하세요 세계'; // Korean text with space (6 + 2 = 8 characters, but 2 space-separated groups)
      const targetLanguage = 'English';
      const apiKey = 'test_api_key';
      
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
        '{"choices":[{"message":{"content":"Hello world"}}]}',
        200,
      ));

      // Act
      final result = await translationService.translateWithStats(
        text: text,
        sourceLanguage: 'Korean',
        targetLanguage: targetLanguage,
        provider: LLMProvider.grok,
        apiKey: apiKey,
      );

      // Assert
      final stats = result['stats'];
      expect(stats.wordCount, 7); // 7 Korean characters (한글)
    });
  });
}
