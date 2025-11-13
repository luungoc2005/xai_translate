import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/tts_voice.dart';

class TTSService {
  final http.Client client;
  final Future<Directory> Function()? getTempDirectory;
  static const String _ttsEndpoint = 'https://api.openai.com/v1/audio/speech';

  TTSService({
    http.Client? client,
    this.getTempDirectory,
  }) : client = client ?? http.Client();

  /// Generate speech from text using OpenAI's TTS API
  /// Returns the file path of the generated audio file
  Future<String> generateSpeech({
    required String text,
    required String apiKey,
    required TTSVoice voice,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('OpenAI API key is required for TTS');
    }

    if (text.isEmpty) {
      throw Exception('Text cannot be empty');
    }

    try {
      // Make API request
      final response = await client.post(
        Uri.parse(_ttsEndpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'tts-1',
          'input': text,
          'voice': voice.apiValue,
          'response_format': 'mp3',
        }),
      );

      if (response.statusCode != 200) {
        final errorBody = response.body;
        throw Exception('TTS API error (${response.statusCode}): $errorBody');
      }

      // Save audio file to temporary directory
      final tempDir = getTempDirectory != null
          ? await getTempDirectory!()
          : await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final audioFile = File('${tempDir.path}/tts_$timestamp.mp3');
      await audioFile.writeAsBytes(response.bodyBytes);

      return audioFile.path;
    } catch (e) {
      throw Exception('Failed to generate speech: ${_getUserFriendlyErrorMessage(e)}');
    }
  }

  /// Clean up old TTS audio files to save storage
  Future<void> cleanupOldFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      
      for (var file in files) {
        if (file is File && file.path.contains('tts_') && file.path.endsWith('.mp3')) {
          try {
            await file.delete();
          } catch (e) {
            // Ignore individual file deletion errors
          }
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  String _getUserFriendlyErrorMessage(dynamic error) {
    final errorString = error.toString();

    // Network connectivity issues
    if (error is SocketException) {
      if (errorString.contains('Failed host lookup')) {
        return 'Unable to connect to OpenAI. Please check your internet connection.';
      }
      return 'Network error: Unable to reach OpenAI TTS service.';
    }

    // API key errors
    if (errorString.contains('401') || errorString.contains('Unauthorized')) {
      return 'Invalid OpenAI API key. Please check your settings.';
    }

    // Rate limiting
    if (errorString.contains('429') || errorString.contains('rate limit')) {
      return 'Rate limit exceeded. Please wait a moment before trying again.';
    }

    // Server errors
    if (errorString.contains('500') || errorString.contains('502') || errorString.contains('503')) {
      return 'OpenAI TTS service is temporarily unavailable. Please try again later.';
    }

    return errorString;
  }
}
