import 'package:flutter/services.dart';

class WhisperPlatform {
  static const MethodChannel _channel = MethodChannel('whisper_channel');
  
  int? _contextPtr;
  
  /// Initialize Whisper with model file
  Future<bool> initialize(String modelPath) async {
    try {
      final ptr = await _channel.invokeMethod<int>('initContext', {
        'modelPath': modelPath,
      });
      
      if (ptr != null && ptr != 0) {
        _contextPtr = ptr;
        return true;
      }
      return false;
    } catch (e) {
      print('Failed to initialize Whisper: $e');
      return false;
    }
  }
  
  /// Transcribe audio file
  Future<String> transcribe(String audioPath) async {
    if (_contextPtr == null || _contextPtr == 0) {
      throw Exception('Whisper not initialized');
    }
    
    try {
      final result = await _channel.invokeMethod<String>('transcribe', {
        'contextPtr': _contextPtr,
        'audioPath': audioPath,
      });
      
      return result ?? '';
    } catch (e) {
      print('Failed to transcribe: $e');
      return '';
    }
  }
  
  /// Free Whisper resources
  Future<void> dispose() async {
    if (_contextPtr != null && _contextPtr != 0) {
      try {
        await _channel.invokeMethod('freeContext', {
          'contextPtr': _contextPtr,
        });
      } catch (e) {
        print('Failed to free context: $e');
      }
      _contextPtr = null;
    }
  }
  
  /// Get Whisper version
  Future<String> getVersion() async {
    try {
      final version = await _channel.invokeMethod<String>('getVersion');
      return version ?? 'unknown';
    } catch (e) {
      return 'error: $e';
    }
  }
}
