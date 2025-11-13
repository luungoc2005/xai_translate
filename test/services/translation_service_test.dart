import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:xai_translate/services/translation_service.dart';
import 'package:xai_translate/models/llm_provider.dart';

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
          targetLanguage: targetLanguage,
          provider: LLMProvider.grok,
          apiKey: apiKey,
        ),
        throwsException,
      );
    });
  });
}
