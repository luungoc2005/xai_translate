import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:xai_translate/services/voice_input_service.dart';

@GenerateMocks([SpeechToText])
import 'voice_input_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceInputService', () {
    late VoiceInputService voiceInputService;
    late MockSpeechToText mockSpeechToText;

    setUp(() {
      // Mock permission handler channel
      const MethodChannel('flutter.baseflow.com/permissions/methods')
          .setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'checkPermissionStatus') {
          return 1; // PermissionStatus.granted
        }
        return null;
      });

      mockSpeechToText = MockSpeechToText();
      voiceInputService = VoiceInputService(speechToText: mockSpeechToText);
    });

    tearDown(() {
      voiceInputService.dispose();
    });

    test('initialize should call SpeechToText.initialize', () async {
      when(mockSpeechToText.initialize(
        onError: anyNamed('onError'),
        onStatus: anyNamed('onStatus'),
        debugLogging: anyNamed('debugLogging'),
      )).thenAnswer((_) async => true);

      final result = await voiceInputService.initialize();

      expect(result, true);
      verify(mockSpeechToText.initialize(
        onError: anyNamed('onError'),
        onStatus: anyNamed('onStatus'),
        debugLogging: anyNamed('debugLogging'),
      )).called(1);
    });

    test('startListening should initialize and start listening', () async {
      when(mockSpeechToText.initialize(
        onError: anyNamed('onError'),
        onStatus: anyNamed('onStatus'),
        debugLogging: anyNamed('debugLogging'),
      )).thenAnswer((_) async => true);

      when(mockSpeechToText.listen(
        onResult: anyNamed('onResult'),
        listenFor: anyNamed('listenFor'),
        pauseFor: anyNamed('pauseFor'),
        localeId: anyNamed('localeId'),
        onSoundLevelChange: anyNamed('onSoundLevelChange'),
        cancelOnError: anyNamed('cancelOnError'),
        partialResults: anyNamed('partialResults'),
        onDevice: anyNamed('onDevice'),
        listenMode: anyNamed('listenMode'),
        sampleRate: anyNamed('sampleRate'),
      )).thenAnswer((_) async => null);
      
      when(mockSpeechToText.locales()).thenAnswer((_) async => []);

      await voiceInputService.startListening(onResult: (_) {});

      verify(mockSpeechToText.initialize(
        onError: anyNamed('onError'),
        onStatus: anyNamed('onStatus'),
        debugLogging: anyNamed('debugLogging'),
      )).called(1);

      verify(mockSpeechToText.listen(
        onResult: anyNamed('onResult'),
        listenFor: anyNamed('listenFor'),
        pauseFor: anyNamed('pauseFor'),
        localeId: anyNamed('localeId'),
        onSoundLevelChange: anyNamed('onSoundLevelChange'),
        cancelOnError: anyNamed('cancelOnError'),
        partialResults: anyNamed('partialResults'),
        onDevice: anyNamed('onDevice'),
        listenMode: anyNamed('listenMode'),
        sampleRate: anyNamed('sampleRate'),
      )).called(1);
    });

    test('stopListening should call SpeechToText.cancel', () async {
      when(mockSpeechToText.cancel()).thenAnswer((_) async => null);

      await voiceInputService.stopListening();

      verify(mockSpeechToText.cancel()).called(1);
    });

    test('isRecording should return SpeechToText.isListening', () {
      when(mockSpeechToText.isListening).thenReturn(true);
      expect(voiceInputService.isRecording, true);

      when(mockSpeechToText.isListening).thenReturn(false);
      expect(voiceInputService.isRecording, false);
    });
    
    test('startListening with language should map to correct locale', () async {
      when(mockSpeechToText.initialize(
        onError: anyNamed('onError'),
        onStatus: anyNamed('onStatus'),
        debugLogging: anyNamed('debugLogging'),
      )).thenAnswer((_) async => true);

      when(mockSpeechToText.listen(
        onResult: anyNamed('onResult'),
        listenFor: anyNamed('listenFor'),
        pauseFor: anyNamed('pauseFor'),
        localeId: anyNamed('localeId'),
        onSoundLevelChange: anyNamed('onSoundLevelChange'),
        cancelOnError: anyNamed('cancelOnError'),
        partialResults: anyNamed('partialResults'),
        onDevice: anyNamed('onDevice'),
        listenMode: anyNamed('listenMode'),
        sampleRate: anyNamed('sampleRate'),
      )).thenAnswer((_) async => null);
      
      when(mockSpeechToText.locales()).thenAnswer((_) async => []);

      await voiceInputService.startListening(
        onResult: (_) {},
        language: 'Spanish',
      );

      verify(mockSpeechToText.listen(
        onResult: anyNamed('onResult'),
        listenFor: anyNamed('listenFor'),
        pauseFor: anyNamed('pauseFor'),
        localeId: 'es_ES', // Should map Spanish to es_ES
        onSoundLevelChange: anyNamed('onSoundLevelChange'),
        cancelOnError: anyNamed('cancelOnError'),
        partialResults: anyNamed('partialResults'),
        onDevice: anyNamed('onDevice'),
        listenMode: anyNamed('listenMode'),
        sampleRate: anyNamed('sampleRate'),
      )).called(1);
    });
  });
}
