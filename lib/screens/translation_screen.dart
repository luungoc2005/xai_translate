import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../models/llm_provider.dart';
import '../models/translation_history_item.dart';
import '../services/translation_service.dart';
import '../services/settings_service.dart';
import '../services/history_service.dart';
import '../services/stats_service.dart';
import '../services/voice_input_service.dart';
import 'settings_screen.dart';
import 'history_screen.dart';
import 'stats_screen.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  final FocusNode _sourceFocusNode = FocusNode();
  final TranslationService _translationService = TranslationService();
  final SettingsService _settingsService = SettingsService();
  final HistoryService _historyService = HistoryService();
  final StatsService _statsService = StatsService();
  final VoiceInputService _voiceInputService = VoiceInputService();
  final ImagePicker _imagePicker = ImagePicker();
  
  String _sourceLanguage = 'Auto-detect';
  String _targetLanguage = 'English';
  bool _isLoading = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  String _errorMessage = '';
  String _translationResult = '';
  String? _currentRecordingPath;
  double _recordingAmplitude = 0.0;
  Stream<double>? _amplitudeStream;
  bool _isInputFocused = false;
  File? _selectedImage;
  late Stream<List<SharedMediaFile>> _sharedFilesStream;

  final List<String> _sourceLanguages = [
    'Auto-detect',
    'English',
    'Spanish',
    'French',
    'German',
    'Italian',
    'Portuguese',
    'Russian',
    'Japanese',
    'Chinese',
    'Korean',
    'Arabic',
    'Hindi',
  ];

  final List<String> _targetLanguages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Italian',
    'Portuguese',
    'Russian',
    'Japanese',
    'Chinese',
    'Korean',
    'Arabic',
    'Hindi',
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedLanguages();
    _sourceFocusNode.addListener(() {
      setState(() {
        _isInputFocused = _sourceFocusNode.hasFocus;
      });
    });
    
    // Listen for shared files when app is already running
    _sharedFilesStream = ReceiveSharingIntent.instance.getMediaStream();
    _sharedFilesStream.listen((List<SharedMediaFile> files) {
      if (files.isNotEmpty) {
        _handleSharedImage(files.first.path);
      }
    });
    
    // Check for shared files when app is opened from share
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> files) {
      if (files.isNotEmpty) {
        _handleSharedImage(files.first.path);
      }
    });
  }
  
  void _handleSharedImage(String imagePath) {
    setState(() {
      _selectedImage = File(imagePath);
      _errorMessage = '';
    });
  }

  Future<void> _loadSavedLanguages() async {
    final sourceLanguage = await _settingsService.getSourceLanguage();
    final targetLanguage = await _settingsService.getTargetLanguage();
    
    setState(() {
      _sourceLanguage = sourceLanguage;
      _targetLanguage = targetLanguage;
    });
  }
  
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _errorMessage = '';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick image: ${e.toString()}';
      });
    }
  }
  
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _errorMessage = '';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to take photo: ${e.toString()}';
      });
    }
  }
  
  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _translate() async {
    if (_sourceController.text.isEmpty && _selectedImage == null) {
      setState(() {
        _errorMessage = 'Please enter text or select an image to translate';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _targetController.clear();
    });

    try {
      final provider = await _settingsService.getSelectedProvider();
      final apiKey = await _settingsService.getApiKey(provider);
      final regionalPreference = await _settingsService.getRegionalPreference();

      if (apiKey.isEmpty) {
        setState(() {
          _errorMessage = 'Please set your ${provider.name} API key in settings';
          _isLoading = false;
        });
        return;
      }

      final result = await _translationService.translateWithStats(
        text: _sourceController.text,
        sourceLanguage: _sourceLanguage,
        targetLanguage: _targetLanguage,
        provider: provider,
        apiKey: apiKey,
        regionalPreference: regionalPreference,
        image: _selectedImage,
      );

      final translation = result['translation'] as String;
      final stats = result['stats'];

      // Save to history
      final historyItem = TranslationHistoryItem(
        sourceText: _selectedImage != null 
            ? '[Image] ${_sourceController.text.isEmpty ? "Image translation" : _sourceController.text}'
            : _sourceController.text,
        translatedText: translation,
        sourceLanguage: _sourceLanguage,
        targetLanguage: _targetLanguage,
        timestamp: DateTime.now(),
      );
      await _historyService.addToHistory(historyItem);

      // Save stats
      await _statsService.addStats(stats);

      setState(() {
        _targetController.text = translation;
        _translationResult = translation;
        _isLoading = false;
        // Unfocus input to show output in large size
        _sourceFocusNode.unfocus();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Translation failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Start voice recording
  Future<void> _startVoiceInput() async {
    try {
      setState(() {
        _isRecording = true;
        _errorMessage = '';
        _recordingAmplitude = 0.0;
      });

      await _voiceInputService.startRecording();
      
      // Listen to amplitude for volume visualization
      _amplitudeStream = _voiceInputService.getAmplitudeStream();
      _amplitudeStream?.listen((amplitude) {
        setState(() {
          _recordingAmplitude = amplitude;
        });
      });
      
      // Update UI to show recording state
      setState(() {});
    } catch (e) {
      setState(() {
        _isRecording = false;
        _errorMessage = 'Failed to start recording: ${e.toString()}';
      });
    }
  }

  /// Stop voice recording and transcribe
  Future<void> _stopVoiceInput() async {
    if (!_isRecording) return;

    try {
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
      });

      // Stop recording and get file path
      _currentRecordingPath = await _voiceInputService.stopRecording();

      // Check if Whisper model is available
      final isModelAvailable = await _voiceInputService.isWhisperModelAvailable();
      if (!isModelAvailable) {
        setState(() {
          _isTranscribing = false;
          _errorMessage = 'Whisper model not available. Please download a model file and place it in app documents/whisper/ directory. See VOICE_INPUT_SETUP.md for details.';
        });
        return;
      }

      // Transcribe audio
      final transcription = await _voiceInputService.transcribeAudio(_currentRecordingPath!);

      // Update source text with transcription
      setState(() {
        _sourceController.text = transcription;
        _isTranscribing = false;
      });

      // Clean up audio file
      await _voiceInputService.cleanupAudioFile(_currentRecordingPath!);
      _currentRecordingPath = null;

      // Auto-translate if we got text
      if (transcription.isNotEmpty) {
        await _translate();
      }
    } catch (e) {
      setState(() {
        _isTranscribing = false;
        _isRecording = false;
        _errorMessage = 'Transcription failed: ${e.toString()}';
      });

      // Try to clean up on error
      if (_currentRecordingPath != null) {
        await _voiceInputService.cleanupAudioFile(_currentRecordingPath!);
        _currentRecordingPath = null;
      }
    }
  }

  void _swapLanguages() async {
    // Don't swap if source is Auto-detect
    if (_sourceLanguage == 'Auto-detect') {
      return;
    }
    
    setState(() {
      final temp = _sourceLanguage;
      _sourceLanguage = _targetLanguage;
      _targetLanguage = temp;

      final tempText = _sourceController.text;
      _sourceController.text = _targetController.text;
      _targetController.text = tempText;
      _translationResult = tempText;
    });

    // Save the swapped languages
    await _settingsService.setSourceLanguage(_sourceLanguage);
    await _settingsService.setTargetLanguage(_targetLanguage);
  }

  List<TextSpan> _buildFormattedTranslation(String text) {
    final List<TextSpan> spans = [];
    final tnPattern = RegExp(r'\(T/N:[^)]+\)');
    
    int lastIndex = 0;
    for (final match in tnPattern.allMatches(text)) {
      // Add normal text before T/N
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: const TextStyle(fontSize: 18, color: Colors.black87),
        ));
      }
      
      // Add T/N with faded, smaller style
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade600,
          fontStyle: FontStyle.italic,
        ),
      ));
      
      lastIndex = match.end;
    }
    
    // Add remaining text after last T/N
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: const TextStyle(fontSize: 18, color: Colors.black87),
      ));
    }
    
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Translate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StatsScreen()),
              );
            },
            tooltip: 'Statistics',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
            tooltip: 'Translation History',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Language selection row
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String>(
                          value: _sourceLanguage,
                          isExpanded: true,
                          items: _sourceLanguages.map((String language) {
                            return DropdownMenuItem<String>(
                              value: language,
                              child: Text(language),
                            );
                          }).toList(),
                          onChanged: (String? newValue) async {
                            if (newValue != null) {
                              setState(() {
                                _sourceLanguage = newValue;
                              });
                              await _settingsService.setSourceLanguage(newValue);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.swap_horiz),
                        onPressed: _swapLanguages,
                      ),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _targetLanguage,
                          isExpanded: true,
                          items: _targetLanguages.map((String language) {
                            return DropdownMenuItem<String>(
                              value: language,
                              child: Text(language),
                            );
                          }).toList(),
                          onChanged: (String? newValue) async {
                            if (newValue != null) {
                              setState(() {
                                _targetLanguage = newValue;
                              });
                              await _settingsService.setTargetLanguage(newValue);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Image picker buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImageFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Pick from Gallery'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImageFromCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                  ),
                ),
              ],
            ),
                  // Display selected image
                  if (_selectedImage != null) ...[
                    const SizedBox(height: 16),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _selectedImage!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.red,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 20),
                              onPressed: _removeImage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Source text field with voice input
                  Container(
                    height: _translationResult.isEmpty 
                        ? 400
                        : _isInputFocused 
                            ? 250
                            : 150,
                    child: Stack(
                children: [
                  TextField(
                    controller: _sourceController,
                    focusNode: _sourceFocusNode,
                    enabled: !_isRecording && !_isTranscribing,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      hintText: _isRecording 
                          ? 'Recording... Speak now' 
                          : _isTranscribing 
                              ? 'Processing audio...'
                              : _selectedImage != null
                                  ? 'Optional: Add context for the image'
                                  : 'Enter text, pick an image, or use voice input',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: _isRecording || _isTranscribing ? Colors.grey[200] : Colors.grey[100],
                    ),
                  ),
                  // Volume indicator during recording
                  if (_isRecording)
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red, width: 2),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.mic, color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Recording...',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                // Pulsing red dot
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Volume indicator bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _recordingAmplitude.clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _recordingAmplitude > 0.7 
                                      ? Colors.red 
                                      : _recordingAmplitude > 0.4 
                                          ? Colors.orange 
                                          : Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Processing indicator during transcription
                  if (_isTranscribing)
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue, width: 2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Processing audio with Whisper...',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Voice input button
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: _isRecording ? _stopVoiceInput : _startVoiceInput,
                      backgroundColor: _isRecording ? Colors.red : Colors.blue,
                      child: _isTranscribing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _isRecording ? Icons.stop : Icons.mic,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_translationResult.isNotEmpty)
              Container(
                height: _isInputFocused 
                    ? 200
                    : 350,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.blue[50],
                ),
                child: SingleChildScrollView(
                  child: SelectableText.rich(
                    TextSpan(
                      children: _buildFormattedTranslation(_translationResult),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Translate button
          ElevatedButton(
            onPressed: _isLoading ? null : _translate,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Translate', style: TextStyle(fontSize: 16)),
          ),
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              color: Colors.red.shade50,
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  ],
),
    );
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _targetController.dispose();
    _sourceFocusNode.dispose();
    _voiceInputService.dispose();
    super.dispose();
  }
}
