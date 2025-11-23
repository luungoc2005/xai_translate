import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for handling voice input and transcription using platform speech-to-text
class VoiceInputService {
  final SpeechToText _speechToText;
  bool _isInitialized = false;
  StreamController<double>? _amplitudeController;
  
  VoiceInputService({SpeechToText? speechToText}) 
      : _speechToText = speechToText ?? SpeechToText();
  
  // State for continuous listening
  bool _isExplicitlyStopped = false;
  bool _isRestarting = false;
  String _accumulatedText = '';
  String _currentWords = '';
  Function(String)? _lastOnResult;
  String? _lastLanguage;

  /// Check if currently recording/listening
  bool get isRecording => _speechToText.isListening;

  /// Get audio amplitude stream for volume visualization
  Stream<double> getAmplitudeStream() {
    _amplitudeController ??= StreamController<double>.broadcast();
    return _amplitudeController!.stream;
  }

  /// Initialize the speech recognition service
  Future<bool> initialize() async {
    if (!_isInitialized) {
      _isInitialized = await _speechToText.initialize(
        onError: _onError,
        onStatus: _onStatus,
        debugLogging: true,
      );
    }
    return _isInitialized;
  }

  void _onError(SpeechRecognitionError error) {
    print('Speech recognition error: ${error.errorMsg} (permanent: ${error.permanent})');
  }

  void _onStatus(String status) {
    print('Speech recognition status: $status');
    if ((status == 'done' || status == 'notListening') && !_isExplicitlyStopped && _isInitialized && !_isRestarting) {
       _restartListening();
    }
  }

  void _restartListening() {
    if (_isRestarting) return;
    _isRestarting = true;
    
    // Manually accumulate current words before restarting to ensure they aren't lost
    if (_currentWords.isNotEmpty) {
      if (_accumulatedText.isNotEmpty) {
        _accumulatedText += ' ';
      }
      _accumulatedText += _currentWords;
      _currentWords = '';
      
      // Notify listener with updated accumulated text
      if (_lastOnResult != null) {
         _lastOnResult!(_accumulatedText);
      }
    }
    
    Future.delayed(const Duration(milliseconds: 50), () async {
         if (!_isExplicitlyStopped) {
            print('Restarting listening session...');
            try {
              // Use cancel to avoid duplicate final results since we manually accumulated
              await _speechToText.cancel();
            } catch (e) {
              print('Error canceling before restart: $e');
            }
            
            await _startListeningInternal();
         }
         _isRestarting = false;
    });
  }

  final Map<String, String> _localeMap = {
    'English': 'en_US',
    'Spanish': 'es_ES',
    'French': 'fr_FR',
    'German': 'de_DE',
    'Italian': 'it_IT',
    'Portuguese': 'pt_PT',
    'Russian': 'ru_RU',
    'Japanese': 'ja_JP',
    'Chinese': 'zh_CN',
    'Korean': 'ko_KR',
    'Arabic': 'ar_SA',
    'Hindi': 'hi_IN',
    'Vietnamese': 'vi_VN',
    'Malay': 'ms_MY',
    'Indonesian': 'id_ID',
  };

  /// Start listening for speech and stream results
  Future<void> startListening({
    required Function(String) onResult,
    String? language,
  }) async {
    // Request permission if not granted
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        throw Exception('Microphone permission denied');
      }
    }

    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        throw Exception('Failed to initialize speech recognition');
      }
    }

    // Reset state
    _isExplicitlyStopped = false;
    _isRestarting = false;
    _accumulatedText = '';
    _currentWords = '';
    _lastOnResult = onResult;
    _lastLanguage = language;

    await _startListeningInternal();
  }

  Future<void> _startListeningInternal() async {
    if (_isInitialized) {
      try {
        String? localeId;
        String? language = _lastLanguage;
        
        // Try to find the best matching locale
        if (language != null) {
          var mapped = _localeMap[language];
          if (mapped != null) {
            try {
              var locales = await _speechToText.locales();
              if (locales.any((l) => l.localeId == mapped)) {
                localeId = mapped;
              } else {
                // Fallback to matching language code
                var langCode = mapped.split('_')[0];
                var match = locales.cast<LocaleName?>().firstWhere(
                  (l) => l!.localeId.startsWith(langCode),
                  orElse: () => null
                );
                if (match != null) {
                    localeId = match.localeId;
                    print('Mapped locale $mapped not found, using $localeId');
                } else {
                    localeId = mapped;
                    print('No matching locale found for $langCode, using $mapped');
                }
              }
            } catch (e) {
              print('Error getting locales: $e');
              localeId = mapped; // Fallback to mapped even if check fails
            }
          }
        }
        
        print('Starting listening with locale: $localeId (language: $language)');

        await _speechToText.listen(
          onResult: (result) {
            if (_isExplicitlyStopped || _isRestarting) return;

            print('Speech result: ${result.recognizedWords} (final: ${result.finalResult})');
            
            String newWords = result.recognizedWords;
            
            // Workaround for Android SpeechRecognizer dropping text on final result
            // If the final result is significantly shorter than the last partial, keep the partial
            if (result.finalResult && _currentWords.length > newWords.length + 5) {
               print('Detected text drop in final result. Using last partial: "$_currentWords" vs "$newWords"');
               newWords = _currentWords;
            }
            
            _currentWords = newWords;
            String total = _accumulatedText;
            if (total.isNotEmpty && _currentWords.isNotEmpty) {
               total += ' ';
            }
            total += _currentWords;
            
            if (_lastOnResult != null) {
               _lastOnResult!(total);
            }
            
            if (result.finalResult) {
               _accumulatedText = total;
               _currentWords = '';
            }
          },
          onSoundLevelChange: (level) {
             if (_amplitudeController != null && !_amplitudeController!.isClosed) {
               // Android might return dB values (e.g. -2 to 10)
               // Normalize assuming range -2 to 10 roughly
               double normalized;
               if (level > 0) {
                  normalized = (level / 10.0).clamp(0.0, 1.0);
               } else {
                  // Map -2..0 to 0..0.2
                  normalized = ((level + 2) / 10.0).clamp(0.0, 1.0);
               }
               
               // Boost the signal for better visibility
               // Apply a curve to make lower values more visible
               // y = x^0.5 (square root) boosts small values
               if (normalized > 0) {
                 normalized = (normalized * 2.0).clamp(0.0, 1.0);
               }
               
               _amplitudeController!.add(normalized);
             }
          },
          localeId: localeId,
          onDevice: true,
          listenFor: const Duration(seconds: 300), // Increased to 5 minutes
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        );
      } catch (e) {
        print('Error starting speech listen: $e');
      }
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    _isExplicitlyStopped = true;
    
    // Commit current partial text to ensure we don't lose it or get it replaced by a truncated final result
    if (_currentWords.isNotEmpty) {
       if (_accumulatedText.isNotEmpty) {
         _accumulatedText += ' ';
       }
       _accumulatedText += _currentWords;
       _currentWords = '';
       
       if (_lastOnResult != null) {
          _lastOnResult!(_accumulatedText);
       }
    }

    // Use cancel instead of stop to prevent the engine from sending a "final" result 
    // that might be truncated/segmented.
    await _speechToText.cancel();
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _speechToText.cancel();
    await _amplitudeController?.close();
  }

  /// Check if model is available (kept for compatibility)
  Future<bool> isWhisperModelAvailable() async {
    return true;
  }

  /// Clean up audio file (kept for compatibility)
  Future<void> cleanupAudioFile(String audioPath) async {
    // No-op
  }
  
  /// Start recording (legacy adapter)
  Future<void> startRecording() async {
     throw UnimplementedError('Use startListening instead');
  }

  /// Stop recording (legacy adapter)
  Future<String> stopRecording() async {
    await stopListening();
    return ''; 
  }
  
  /// Transcribe audio (legacy adapter)
  Future<String> transcribeAudio(String audioPath) async {
    return ''; 
  }
}

