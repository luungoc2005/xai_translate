import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:xai_translate/services/tts_service.dart';
import 'package:xai_translate/models/tts_voice.dart';
import 'dart:io';

import 'tts_service_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('TTSService', () {
    late MockClient mockClient;
    late TTSService ttsService;
    late Directory tempDir;

    setUp(() async {
      mockClient = MockClient();
      // Create a temporary directory for testing
      tempDir = Directory.systemTemp.createTempSync('tts_test_');
      ttsService = TTSService(
        client: mockClient,
        getTempDirectory: () async => tempDir,
      );
    });

    tearDown(() async {
      // Clean up test directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should generate speech successfully', () async {
      // Arrange
      const text = 'Hello world';
      const apiKey = 'test_api_key';
      const voice = TTSVoice.alloy;
      final fakeAudioData = List<int>.generate(100, (i) => i);
      
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response.bytes(
        fakeAudioData,
        200,
      ));

      // Act
      final result = await ttsService.generateSpeech(
        text: text,
        apiKey: apiKey,
        voice: voice,
      );

      // Assert
      expect(result, isNotEmpty);
      expect(result, contains('tts_'));
      expect(result, endsWith('.mp3'));
      
      // Verify API call
      verify(mockClient.post(
        Uri.parse('https://api.openai.com/v1/audio/speech'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: anyNamed('body'),
      )).called(1);
    });

    test('should throw exception when API key is empty', () async {
      // Arrange
      const text = 'Hello world';
      const apiKey = '';
      const voice = TTSVoice.nova;

      // Act & Assert
      expect(
        () => ttsService.generateSpeech(
          text: text,
          apiKey: apiKey,
          voice: voice,
        ),
        throwsException,
      );
    });

    test('should throw exception when text is empty', () async {
      // Arrange
      const text = '';
      const apiKey = 'test_api_key';
      const voice = TTSVoice.onyx;

      // Act & Assert
      expect(
        () => ttsService.generateSpeech(
          text: text,
          apiKey: apiKey,
          voice: voice,
        ),
        throwsException,
      );
    });

    test('should throw exception when API call fails', () async {
      // Arrange
      const text = 'Hello world';
      const apiKey = 'test_api_key';
      const voice = TTSVoice.shimmer;
      
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
        '{"error":"Invalid API key"}',
        401,
      ));

      // Act & Assert
      expect(
        () => ttsService.generateSpeech(
          text: text,
          apiKey: apiKey,
          voice: voice,
        ),
        throwsException,
      );
    });

    test('should use correct voice parameter', () async {
      // Arrange
      const text = 'Test message';
      const apiKey = 'test_api_key';
      const voice = TTSVoice.fable;
      final fakeAudioData = List<int>.generate(50, (i) => i);
      
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response.bytes(
        fakeAudioData,
        200,
      ));

      // Act
      await ttsService.generateSpeech(
        text: text,
        apiKey: apiKey,
        voice: voice,
      );

      // Assert - Verify the voice parameter is included in the request
      final captured = verify(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: captureAnyNamed('body'),
      )).captured;
      
      expect(captured[0], contains('"voice":"fable"'));
    });
  });

  group('TTSVoiceExtension', () {
    test('should return correct API value for each voice', () {
      expect(TTSVoice.alloy.apiValue, 'alloy');
      expect(TTSVoice.echo.apiValue, 'echo');
      expect(TTSVoice.fable.apiValue, 'fable');
      expect(TTSVoice.onyx.apiValue, 'onyx');
      expect(TTSVoice.nova.apiValue, 'nova');
      expect(TTSVoice.shimmer.apiValue, 'shimmer');
    });

    test('should return correct name for each voice', () {
      expect(TTSVoice.alloy.name, 'Alloy');
      expect(TTSVoice.echo.name, 'Echo');
      expect(TTSVoice.fable.name, 'Fable');
      expect(TTSVoice.onyx.name, 'Onyx');
      expect(TTSVoice.nova.name, 'Nova');
      expect(TTSVoice.shimmer.name, 'Shimmer');
    });

    test('should return correct description for each voice', () {
      expect(TTSVoice.alloy.description, 'Neutral, balanced voice');
      expect(TTSVoice.echo.description, 'Male, warm voice');
      expect(TTSVoice.fable.description, 'British, expressive voice');
      expect(TTSVoice.onyx.description, 'Male, deep voice');
      expect(TTSVoice.nova.description, 'Female, energetic voice');
      expect(TTSVoice.shimmer.description, 'Female, soft voice');
    });

    test('should convert from string correctly', () {
      expect(TTSVoiceExtension.fromString('alloy'), TTSVoice.alloy);
      expect(TTSVoiceExtension.fromString('echo'), TTSVoice.echo);
      expect(TTSVoiceExtension.fromString('fable'), TTSVoice.fable);
      expect(TTSVoiceExtension.fromString('onyx'), TTSVoice.onyx);
      expect(TTSVoiceExtension.fromString('nova'), TTSVoice.nova);
      expect(TTSVoiceExtension.fromString('shimmer'), TTSVoice.shimmer);
    });

    test('should handle case-insensitive string conversion', () {
      expect(TTSVoiceExtension.fromString('ALLOY'), TTSVoice.alloy);
      expect(TTSVoiceExtension.fromString('Echo'), TTSVoice.echo);
      expect(TTSVoiceExtension.fromString('SHIMMER'), TTSVoice.shimmer);
    });

    test('should default to alloy for invalid string', () {
      expect(TTSVoiceExtension.fromString('invalid'), TTSVoice.alloy);
      expect(TTSVoiceExtension.fromString(''), TTSVoice.alloy);
    });
  });
}
