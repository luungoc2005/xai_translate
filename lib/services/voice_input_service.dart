import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for handling voice input and transcription using platform speech-to-text
class VoiceInputService {
  final SpeechToText _speechToText;
  final bool _isAndroid;
  bool _isInitialized = false;
  StreamController<double>? _amplitudeController;
  static const MethodChannel _channel = MethodChannel('com.example.xai_translate/speech');
  bool _usingNativeAndroid = false;
  
  VoiceInputService({SpeechToText? speechToText, bool? isAndroid}) 
      : _speechToText = speechToText ?? SpeechToText(),
        _isAndroid = isAndroid ?? Platform.isAndroid {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onResult':
        final Map<dynamic, dynamic> args = call.arguments;
        final String text = args['text'] as String;
        final bool isFinal = args['final'] as bool;
        _handleNativeResult(text, isFinal);
        break;
      case 'onSoundLevelChanged':
        final double level = (call.arguments as num).toDouble();
        _handleNativeSoundLevel(level);
        break;
      case 'onError':
        print('Native speech error: ${call.arguments}');
        _handleNativeError(call.arguments.toString());
        break;
    }
  }

  void _handleNativeError(String error) {
    // If we encounter an error (like timeout or no match) but have partial text,
    // we should commit it to accumulated text so it's not lost when the
    // recognizer restarts and overwrites _currentWords.
    if (_currentWords.isNotEmpty) {
       print('Committing partial text due to error: "$_currentWords"');
       String total = _accumulatedText;
       if (total.isNotEmpty) {
         total += ' ';
       }
       total += _currentWords;
       _accumulatedText = total;
       _currentWords = '';
       
       if (_lastOnResult != null) {
          _lastOnResult!(_accumulatedText);
       }
    } else {
       // Filter out common continuous listening errors from verbose logging
       // 7 = ERROR_NO_MATCH (Silence/Unrecognized)
       // 6 = ERROR_SPEECH_TIMEOUT (No speech input)
       if (error != '7' && error != '6') {
          print('Native error $error received but no partial text to commit');
       }
    }
  }

  void _handleNativeResult(String text, bool isFinal) {
    if (_isExplicitlyStopped || _isRestarting) return;
    
    _currentWords = text;
    String total = _accumulatedText;
    if (total.isNotEmpty && _currentWords.isNotEmpty) {
       total += ' ';
    }
    total += _currentWords;
    
    if (_lastOnResult != null) {
       _lastOnResult!(total);
    }
    
    if (isFinal) {
       _accumulatedText = total;
       _currentWords = '';
    }
  }

  void _handleNativeSoundLevel(double level) {
     if (_amplitudeController != null && !_amplitudeController!.isClosed) {
       double normalized = (level + 2) / 12.0; 
       normalized = normalized.clamp(0.0, 1.0);
       _amplitudeController!.add(normalized);
     }
  }
  
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
    List<String>? alternativeLocales,
    bool prioritizeAlternatives = false,
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

    if (_isAndroid && alternativeLocales != null && alternativeLocales.isNotEmpty) {
        _usingNativeAndroid = true;
        await _startNativeListening(language, alternativeLocales, prioritizeAlternatives);
    } else {
        _usingNativeAndroid = false;
        await _startListeningInternal();
    }
  }

  Future<void> _startNativeListening(String? primaryLanguage, List<String> alternatives, bool prioritizeAlternatives) async {
      List<String> locales = [];
      
      if (prioritizeAlternatives) {
          // Add alternatives first (Target Language) to make them primary for detection
          for (var lang in alternatives) {
              String? mapped = _localeMap[lang];
              if (mapped != null) {
                  String formatted = mapped.replaceAll('_', '-');
                  if (!locales.contains(formatted)) {
                      locales.add(formatted);
                  }
              }
          }

          // Add primary language (Native Language) as secondary
          if (primaryLanguage != null) {
              String? mapped = _localeMap[primaryLanguage];
              if (mapped != null) {
                 String formatted = mapped.replaceAll('_', '-');
                 if (!locales.contains(formatted)) locales.add(formatted);
              }
          }
      } else {
          // Add primary language (Native Language) first
          if (primaryLanguage != null) {
              String? mapped = _localeMap[primaryLanguage];
              if (mapped != null) locales.add(mapped.replaceAll('_', '-'));
          }
          
          // Add alternatives (Target Language) as secondary
          for (var lang in alternatives) {
              String? mapped = _localeMap[lang];
              if (mapped != null) {
                  String formatted = mapped.replaceAll('_', '-');
                  if (!locales.contains(formatted)) {
                      locales.add(formatted);
                  }
              }
          }
      }
      
      if (locales.isEmpty) {
          locales.add('en-US');
      }

      try {
          await _channel.invokeMethod('startListening', {'locales': locales});
      } catch (e) {
          print('Error starting native listening: $e');
      }
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

    if (_usingNativeAndroid) {
        try {
            await _channel.invokeMethod('stopListening');
        } catch (e) {
            print('Error stopping native listening: $e');
        }
    } else {
        // Use cancel instead of stop to prevent the engine from sending a "final" result 
        // that might be truncated/segmented.
        await _speechToText.cancel();
    }
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

