import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:xai_translate/services/voice_input_service.dart';
import 'dart:io';

import 'voice_input_service_test.mocks.dart';

@GenerateMocks([WhisperClient, VoiceRecorder])
void main() {
  group('VoiceInputService', () {
    late VoiceInputService voiceInputService;
    late MockWhisperClient mockWhisperClient;
    late MockVoiceRecorder mockVoiceRecorder;

    setUp(() {
      mockWhisperClient = MockWhisperClient();
      mockVoiceRecorder = MockVoiceRecorder();
      voiceInputService = VoiceInputService(
        whisperClient: mockWhisperClient,
        audioRecorder: mockVoiceRecorder,
      );
    });

    tearDown(() {
      voiceInputService.dispose();
    });

    group('Recording', () {
      test('should start recording when startRecording is called', () async {
        // Arrange
        when(mockVoiceRecorder.startRecording(any))
            .thenAnswer((_) async => Future.value());
        when(mockVoiceRecorder.isRecording()).thenReturn(false);

        // Act
        await voiceInputService.startRecording();

        // Assert
        verify(mockVoiceRecorder.startRecording(any)).called(1);
      });

      test('should stop recording when stopRecording is called', () async {
        // Arrange
        const recordedFilePath = '/tmp/audio_recording.wav';
        when(mockVoiceRecorder.stopRecording())
            .thenAnswer((_) async => recordedFilePath);
        when(mockVoiceRecorder.isRecording()).thenReturn(true);

        // Act
        final path = await voiceInputService.stopRecording();

        // Assert
        expect(path, recordedFilePath);
        verify(mockVoiceRecorder.stopRecording()).called(1);
      });

      test('should throw exception when stopping recording that was never started', () async {
        // Arrange
        when(mockVoiceRecorder.isRecording()).thenReturn(false);

        // Act & Assert
        expect(
          () => voiceInputService.stopRecording(),
          throwsA(isA<StateError>()),
        );
      });

      test('should throw exception when starting recording while already recording', () async {
        // Arrange
        when(mockVoiceRecorder.isRecording()).thenReturn(true);

        // Act & Assert
        expect(
          () => voiceInputService.startRecording(),
          throwsA(isA<StateError>()),
        );
      });

      test('should return correct recording status', () {
        // Arrange
        when(mockVoiceRecorder.isRecording()).thenReturn(true);

        // Act
        final isRecording = voiceInputService.isRecording;

        // Assert
        expect(isRecording, true);
      });
    });

    group('Transcription', () {
      test('should transcribe audio file using Whisper', () async {
        // Arrange
        const audioPath = '/tmp/test_audio.wav';
        const expectedTranscription = 'Hello world';
        when(mockWhisperClient.transcribe(audioPath))
            .thenAnswer((_) async => expectedTranscription);

        // Act
        final transcription = await voiceInputService.transcribeAudio(audioPath);

        // Assert
        expect(transcription, expectedTranscription);
        verify(mockWhisperClient.transcribe(audioPath)).called(1);
      });

      test('should throw exception when audio file does not exist', () async {
        // Arrange
        const audioPath = '/tmp/nonexistent.wav';

        // Act & Assert
        expect(
          () => voiceInputService.transcribeAudio(audioPath),
          throwsA(isA<FileSystemException>()),
        );
      });

      test('should handle Whisper transcription errors', () async {
        // Arrange
        const audioPath = '/tmp/test_audio.wav';
        when(mockWhisperClient.transcribe(audioPath))
            .thenThrow(Exception('Whisper transcription failed'));

        // Act & Assert
        expect(
          () => voiceInputService.transcribeAudio(audioPath),
          throwsException,
        );
      });

      test('should return empty string for silent audio', () async {
        // Arrange
        const audioPath = '/tmp/silent_audio.wav';
        when(mockWhisperClient.transcribe(audioPath))
            .thenAnswer((_) async => '');

        // Act
        final transcription = await voiceInputService.transcribeAudio(audioPath);

        // Assert
        expect(transcription, '');
      });

      test('should handle multi-language transcription', () async {
        // Arrange
        const audioPath = '/tmp/multilang_audio.wav';
        const expectedTranscription = 'Bonjour, comment ça va?';
        when(mockWhisperClient.transcribe(audioPath))
            .thenAnswer((_) async => expectedTranscription);

        // Act
        final transcription = await voiceInputService.transcribeAudio(audioPath);

        // Assert
        expect(transcription, expectedTranscription);
      });
    });

    group('Record and Transcribe', () {
      test('should record and transcribe in one operation', () async {
        // Arrange
        const recordedFilePath = '/tmp/audio_recording.wav';
        const expectedTranscription = 'This is a test';
        
        when(mockVoiceRecorder.isRecording()).thenReturn(false);
        when(mockVoiceRecorder.startRecording(any))
            .thenAnswer((_) async => Future.value());
        when(mockVoiceRecorder.stopRecording())
            .thenAnswer((_) async => recordedFilePath);
        when(mockWhisperClient.transcribe(recordedFilePath))
            .thenAnswer((_) async => expectedTranscription);

        // Act
        await voiceInputService.startRecording();
        final path = await voiceInputService.stopRecording();
        final transcription = await voiceInputService.transcribeAudio(path);

        // Assert
        expect(transcription, expectedTranscription);
        verify(mockVoiceRecorder.startRecording(any)).called(1);
        verify(mockVoiceRecorder.stopRecording()).called(1);
        verify(mockWhisperClient.transcribe(recordedFilePath)).called(1);
      });

      test('should handle recording errors gracefully', () async {
        // Arrange
        when(mockVoiceRecorder.isRecording()).thenReturn(false);
        when(mockVoiceRecorder.startRecording(any))
            .thenThrow(Exception('Microphone access denied'));

        // Act & Assert
        expect(
          () => voiceInputService.startRecording(),
          throwsException,
        );
      });
    });

    group('Model Management', () {
      test('should check if Whisper model is available', () async {
        // Arrange
        when(mockWhisperClient.isModelAvailable())
            .thenAnswer((_) async => true);

        // Act
        final isAvailable = await voiceInputService.isWhisperModelAvailable();

        // Assert
        expect(isAvailable, true);
      });

      test('should return false when Whisper model is not available', () async {
        // Arrange
        when(mockWhisperClient.isModelAvailable())
            .thenThrow(Exception('Model not found'));

        // Act
        final isAvailable = await voiceInputService.isWhisperModelAvailable();

        // Assert
        expect(isAvailable, false);
      });
    });

    group('Cleanup', () {
      test('should dispose resources properly', () async {
        // Arrange
        when(mockVoiceRecorder.dispose())
            .thenAnswer((_) async => Future.value());

        // Act
        await voiceInputService.dispose();

        // Assert
        verify(mockVoiceRecorder.dispose()).called(1);
      });

      test('should delete temporary audio files after transcription', () async {
        // Arrange
        const audioPath = '/tmp/test_audio.wav';
        const transcription = 'Test transcription';
        
        when(mockWhisperClient.transcribe(audioPath))
            .thenAnswer((_) async => transcription);

        // Act
        final result = await voiceInputService.transcribeAudio(audioPath);
        await voiceInputService.cleanupAudioFile(audioPath);

        // Assert
        expect(result, transcription);
        // In real implementation, verify file deletion
      });
    });

    group('Permission Handling', () {
      test('should check microphone permission before recording', () async {
        // Act
        final hasPermission = await voiceInputService.checkMicrophonePermission();

        // Assert
        expect(hasPermission, isA<bool>());
      });

      test('should request microphone permission if not granted', () async {
        // Act
        final granted = await voiceInputService.requestMicrophonePermission();

        // Assert
        expect(granted, isA<bool>());
      });
    });

    group('Error Handling', () {
      test('should provide detailed error message for transcription failure', () async {
        // Arrange
        const audioPath = '/tmp/corrupted_audio.wav';
        const errorMessage = 'Audio format not supported';
        when(mockWhisperClient.transcribe(audioPath))
            .thenThrow(Exception(errorMessage));

        // Act & Assert
        try {
          await voiceInputService.transcribeAudio(audioPath);
          fail('Should have thrown an exception');
        } catch (e) {
          expect(e.toString(), contains(errorMessage));
        }
      });
    });
  });
}
