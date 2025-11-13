import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart' as record_pkg;
import 'package:path/path.dart' as path;
import 'whisper_platform.dart';

/// Service for handling voice input and transcription using local Whisper model
class VoiceInputService {
  final WhisperClient whisperClient;
  final VoiceRecorder audioRecorder;
  
  VoiceInputService({
    WhisperClient? whisperClient,
    VoiceRecorder? audioRecorder,
  })  : whisperClient = whisperClient ?? OnDeviceWhisperClient(),
        audioRecorder = audioRecorder ?? FlutterAudioRecorder();

  /// Check if currently recording
  bool get isRecording => audioRecorder.isRecording();

  /// Get audio amplitude stream for volume visualization
  Stream<double> getAmplitudeStream() {
    return audioRecorder.getAmplitudeStream();
  }

  /// Start recording audio from microphone
  Future<void> startRecording() async {
    if (isRecording) {
      throw StateError('Recording is already in progress');
    }

    // Check permission first
    final hasPermission = await checkMicrophonePermission();
    if (!hasPermission) {
      final granted = await requestMicrophonePermission();
      if (!granted) {
        throw Exception('Microphone permission denied');
      }
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${tempDir.path}/recording_$timestamp.wav';
    
    await audioRecorder.startRecording(outputPath);
  }

  /// Stop recording and return the file path
  Future<String> stopRecording() async {
    if (!isRecording) {
      throw StateError('No recording in progress');
    }

    final filePath = await audioRecorder.stopRecording();
    return filePath;
  }

  /// Transcribe audio file using Whisper model
  Future<String> transcribeAudio(String audioPath) async {
    // Check if file exists
    final file = File(audioPath);
    if (!await file.exists()) {
      throw FileSystemException('Audio file not found', audioPath);
    }

    try {
      final transcription = await whisperClient.transcribe(audioPath);
      return transcription.trim();
    } catch (e) {
      throw Exception('Transcription failed: ${e.toString()}');
    }
  }

  /// Check if Whisper model is available
  Future<bool> isWhisperModelAvailable() async {
    try {
      return await whisperClient.isModelAvailable();
    } catch (e) {
      return false;
    }
  }

  /// Check if microphone permission is granted
  Future<bool> checkMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Clean up temporary audio file
  Future<void> cleanupAudioFile(String audioPath) async {
    try {
      final file = File(audioPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Log error but don't throw - cleanup is non-critical
      print('Failed to cleanup audio file: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await audioRecorder.dispose();
  }
}

/// Interface for Whisper client implementation
abstract class WhisperClient {
  Future<String> transcribe(String audioPath);
  Future<bool> isModelAvailable();
}

/// Interface for audio recorder implementation
abstract class VoiceRecorder {
  Future<void> startRecording(String outputPath);
  Future<String> stopRecording();
  bool isRecording();
  Stream<double> getAmplitudeStream();
  Future<void> dispose();
}

/// On-device Whisper implementation using native platform integration
/// This loads a pre-compiled Whisper model and runs inference locally
class OnDeviceWhisperClient implements WhisperClient {
  final WhisperPlatform _platform = WhisperPlatform();
  bool _isInitialized = false;
  String? _modelPath;

  OnDeviceWhisperClient();

  /// Initialize the Whisper model
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Copy model from assets to documents if not exists
      await _ensureModelExists();
      
      if (_modelPath == null) {
        throw Exception('Model file not found');
      }
      
      // Initialize native Whisper context
      final success = await _platform.initialize(_modelPath!);
      if (!success) {
        throw Exception('Failed to initialize Whisper context');
      }
      
      _isInitialized = true;
      print('Whisper initialized successfully with model: $_modelPath');
    } catch (e) {
      print('Failed to initialize Whisper: $e');
      _isInitialized = false;
      rethrow;
    }
  }
  
  /// Ensure model file exists in documents directory
  Future<void> _ensureModelExists() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final whisperDir = Directory(path.join(appDir.path, 'whisper'));
      
      // Create whisper directory if it doesn't exist
      if (!await whisperDir.exists()) {
        await whisperDir.create(recursive: true);
      }
      
      final modelPath = path.join(whisperDir.path, 'ggml-base.bin');
      final modelFile = File(modelPath);
      
      // Copy from assets if not exists
      if (!await modelFile.exists()) {
        print('Copying model from assets to: $modelPath');
        final data = await rootBundle.load('assets/models/ggml-base.bin');
        await modelFile.writeAsBytes(data.buffer.asUint8List());
        print('Model copied successfully');
      }
      
      _modelPath = modelPath;
    } catch (e) {
      print('Error ensuring model exists: $e');
      rethrow;
    }
  }

  @override
  Future<String> transcribe(String audioPath) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final transcription = await _platform.transcribe(audioPath);
      return transcription.trim();
    } catch (e) {
      throw Exception('On-device transcription failed: ${e.toString()}');
    }
  }

  @override
  Future<bool> isModelAvailable() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final whisperDir = Directory(path.join(appDir.path, 'whisper'));
      final modelPath = path.join(whisperDir.path, 'ggml-base.bin');
      final modelFile = File(modelPath);
      
      // Also check if model exists in assets
      try {
        await rootBundle.load('assets/models/ggml-base.bin');
        print('Model found in assets');
        return true; // Model is in assets, can be copied
      } catch (e) {
        print('Model not in assets: $e');
      }
      
      final exists = await modelFile.exists();
      if (!exists) {
        print('Whisper model not found at: $modelPath');
        print('Expected location: ${whisperDir.path}');
        print('Download models from: https://huggingface.co/ggerganov/whisper.cpp');
        print('Or use: https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin');
      }
      
      return exists;
    } catch (e) {
      return false;
    }
  }

  Future<void> dispose() async {
    if (_isInitialized) {
      await _platform.dispose();
      _isInitialized = false;
      _modelPath = null;
    }
  }
}

/// Concrete implementation of VoiceRecorder using record package
class FlutterAudioRecorder implements VoiceRecorder {
  final record_pkg.AudioRecorder _recorder;
  bool _isCurrentlyRecording = false;
  String? _currentRecordingPath;

  FlutterAudioRecorder() : _recorder = record_pkg.AudioRecorder();

  @override
  bool isRecording() {
    return _isCurrentlyRecording;
  }

  @override
  Stream<double> getAmplitudeStream() {
    // Return amplitude stream from the recorder
    // The record package provides amplitude as a stream
    return _recorder.onAmplitudeChanged(const Duration(milliseconds: 200)).map((amp) {
      // Normalize amplitude to 0.0 - 1.0 range
      // amp.current is typically in dB, ranging from -160 (silence) to 0 (max)
      final normalized = (amp.current + 60).clamp(0, 60) / 60;
      return normalized;
    });
  }

  @override
  Future<void> startRecording(String outputPath) async {
    if (isRecording()) {
      throw StateError('Already recording');
    }

    // Check if device supports recording
    if (!await _recorder.hasPermission()) {
      throw Exception('Recording permission not granted');
    }
    
    _currentRecordingPath = outputPath;
    _isCurrentlyRecording = true;
    
    await _recorder.start(
      const record_pkg.RecordConfig(
        encoder: record_pkg.AudioEncoder.wav,
        bitRate: 128000,
        sampleRate: 16000,
      ),
      path: outputPath,
    );
  }

  @override
  Future<String> stopRecording() async {
    if (!isRecording()) {
      throw StateError('Not recording');
    }
    
    final path = await _recorder.stop();
    final recordingPath = _currentRecordingPath!;
    _isCurrentlyRecording = false;
    _currentRecordingPath = null;
    
    return path ?? recordingPath;
  }

  @override
  Future<void> dispose() async {
    if (isRecording()) {
      await stopRecording();
    }
    await _recorder.dispose();
  }
}
