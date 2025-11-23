import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/llm_provider.dart';
import '../models/translation_history_item.dart';
import '../models/translation_stats.dart';
import '../models/regional_preference.dart';
import '../services/translation_service.dart';
import '../services/settings_service.dart';
import '../services/history_service.dart';
import '../services/stats_service.dart';
import '../services/voice_input_service.dart';
import '../services/tts_service.dart';
import '../services/volume_service.dart';
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
  final TTSService _ttsService = TTSService();
  final VolumeService _volumeService = VolumeService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ImagePicker _imagePicker = ImagePicker();

  String _nativeLanguage = 'English';
  String _selectedLanguage = 'Spanish';
  LLMProvider _selectedProvider = LLMProvider.grok;
  List<LLMProvider> _availableProviders = [];
  bool _isLoading = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  String _errorMessage = '';
  String _translationResult = '';
  double _recordingAmplitude = 0.0;
  Stream<double>? _amplitudeStream;
  bool _isInputFocused = false;
  bool _isFromWhisper = false;
  File? _selectedImage;
  late Stream<List<SharedMediaFile>> _sharedFilesStream;
  bool _isGeneratingTTS = false;
  bool _isPlayingTTS = false;
  String _selectedText = '';
  StreamSubscription? _playerCompleteSubscription;

  final List<String> _languages = [
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
    'Vietnamese',
    'Malay',
    'Indonesian',
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
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> files,
    ) {
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
    final nativeLanguage = await _settingsService.getNativeLanguage();
    final targetLanguage = await _settingsService.getTargetLanguage();
    final selectedProvider = await _settingsService.getSelectedProvider();

    // Check which providers have API keys configured
    final availableProviders = <LLMProvider>[];
    for (final provider in LLMProvider.values) {
      final apiKey = await _settingsService.getApiKey(provider);
      if (apiKey.isNotEmpty) {
        availableProviders.add(provider);
      }
    }

    // Ensure selected provider is available, otherwise use first available
    var providerToUse = selectedProvider;
    if (availableProviders.isNotEmpty &&
        !availableProviders.contains(selectedProvider)) {
      providerToUse = availableProviders.first;
      await _settingsService.setSelectedProvider(providerToUse);
    }

    // Ensure selected language is not the same as native language if possible
    var selectedLanguage = targetLanguage;
    if (selectedLanguage == nativeLanguage) {
      selectedLanguage = (nativeLanguage == 'Spanish') ? 'English' : 'Spanish';
    }

    setState(() {
      _nativeLanguage = nativeLanguage;
      _selectedLanguage = selectedLanguage;
      _selectedProvider = providerToUse;
      _availableProviders = availableProviders;
    });
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
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
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );
      if (image != null) {
        // Save to gallery so it can be synced
        try {
          // Check for access permission
          final hasAccess = await Gal.hasAccess();
          if (!hasAccess) {
            await Gal.requestAccess();
          }
          await Gal.putImage(image.path);
        } catch (e) {
          debugPrint('Failed to save image to gallery: $e');
        }

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

  void _showImagePreview() {
    if (_selectedImage == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () {}, // Prevents closing when tapping the image
              child: Center(
                child: Stack(
                  children: [
                    InteractiveViewer(child: Image.file(_selectedImage!)),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        backgroundColor: Colors.black87,
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
      final provider = _selectedProvider;
      final apiKey = await _settingsService.getApiKey(provider);
      final regionalPreference = await _settingsService.getRegionalPreference();

      if (apiKey.isEmpty) {
        setState(() {
          _errorMessage =
              'Please set your ${provider.name} API key in settings';
          _isLoading = false;
        });
        return;
      }

      final startTime = DateTime.now();
      final wordCount = _translationService.countWords(_sourceController.text);

      final result = await _translationService.translateInConversationModeWithAutoDetect(
        text: _sourceController.text,
        language1: _nativeLanguage,
        language2: _selectedLanguage,
        provider: provider,
        apiKey: apiKey,
        regionalPreference: regionalPreference,
        userNativeLanguage: _nativeLanguage,
        image: _selectedImage,
      );

      final translation = result['translation'] as String;
      final detectedLanguage = result['detectedLanguage'] as String;
      
      final endTime = DateTime.now();
      final responseTimeMs = endTime.difference(startTime).inMilliseconds;

      final stats = TranslationStats(
        provider: provider,
        sourceLanguage: detectedLanguage,
        wordCount: wordCount,
        imageCount: _selectedImage != null ? 1 : 0,
        responseTimeMs: responseTimeMs,
        regionalPreferenceEnabled: regionalPreference != RegionalPreference.none,
        timestamp: endTime,
      );

      // Determine target language based on detected language
      final targetLanguage = detectedLanguage == _nativeLanguage ? _selectedLanguage : _nativeLanguage;

      // Save to history
      final historyItem = TranslationHistoryItem(
        sourceText: _selectedImage != null
            ? '[Image] ${_sourceController.text.isEmpty ? "Image translation" : _sourceController.text}'
            : _sourceController.text,
        translatedText: translation,
        sourceLanguage: detectedLanguage,
        targetLanguage: targetLanguage,
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

  /// Translate and then immediately play TTS
  Future<void> _translateAndSpeak() async {
    // Check if OpenAI API key exists before proceeding
    final openaiKey = await _settingsService.getApiKey(LLMProvider.openai);

    if (openaiKey.isEmpty) {
      setState(() {
        _errorMessage =
            'Please set your OpenAI API key in settings to use translate & speak';
      });
      return;
    }

    // First translate
    await _translate();

    // If translation was successful and we have a result, play TTS
    if (_translationResult.isNotEmpty && _errorMessage.isEmpty) {
      await _playTTS();
    }
  }

  /// Start voice recording
  Future<void> _startVoiceInput() async {
    try {
      setState(() {
        _isRecording = true;
        _errorMessage = '';
        _recordingAmplitude = 0.0;
        // Optional: Clear text when starting new recording
        // _sourceController.clear(); 
      });

      await _voiceInputService.startListening(
        onResult: (text) {
          setState(() {
            _sourceController.text = text;
          });
        },
        language: _nativeLanguage,
      );

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

  /// Stop voice recording
  Future<void> _stopVoiceInput() async {
    if (!_isRecording) return;

    try {
      await _voiceInputService.stopListening();

      setState(() {
        _isRecording = false;
        _isTranscribing = false;
      });

      // Auto-translate if we got text
      if (_sourceController.text.isNotEmpty) {
        await _translate();
      }
    } catch (e) {
      setState(() {
        _isTranscribing = false;
        _isRecording = false;
        _errorMessage = 'Error stopping recording: ${e.toString()}';
      });
    }
  }


  /// Convert translation text to markdown format
  /// T/N notes are converted to italic text for markdown rendering
  String _convertToMarkdown(String text) {
    // Convert (T/N: ...) to italic text
    final tnPattern = RegExp(r'\(T/N:([^)]+)\)');

    String markdownText = text.replaceAllMapped(tnPattern, (match) {
      final note = match.group(1)?.trim() ?? '';
      return '*T/N:$note*';
    });

    return markdownText;
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
              ).then((_) => _loadSavedLanguages());
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate available height
                final availableHeight = constraints.maxHeight;

                // Fixed heights
                const languageRowHeight = 60.0;
                const imageButtonsHeight = 48.0;
                const spacing = 16.0;

                // Image chip height when present
                final imageHeight = _selectedImage != null
                    ? 48.0 + spacing
                    : 0.0;

                // Calculate remaining height for text fields
                var remainingHeight =
                    availableHeight -
                    languageRowHeight -
                    imageButtonsHeight -
                    (spacing * 5); // spacing between elements

                if (_selectedImage != null) {
                  remainingHeight -= imageHeight;
                }

                // Dynamic heights based on focus and content state
                double inputHeight;
                double outputHeight;

                if (_translationResult.isEmpty) {
                  // No translation yet - give all space to input
                  inputHeight = remainingHeight;
                  outputHeight = 0;
                } else if (_isInputFocused) {
                  // Input focused - give more space to input
                  inputHeight = remainingHeight * 0.55;
                  outputHeight = remainingHeight * 0.45;
                } else if (_selectedImage != null) {
                  // Image selected - smaller input, normal output
                  inputHeight = remainingHeight * 0.35;
                  outputHeight = remainingHeight * 0.65;
                } else {
                  // Default balanced split
                  inputHeight = remainingHeight * 0.5;
                  outputHeight = remainingHeight * 0.5;
                }

                // Minimum heights
                inputHeight = inputHeight.clamp(100.0, double.infinity);
                if (_translationResult.isNotEmpty) {
                  outputHeight = outputHeight.clamp(100.0, double.infinity);
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Language selection row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedLanguage,
                            isExpanded: true,
                            items: _languages
                                .where((lang) => lang != _nativeLanguage)
                                .map((String language) {
                              return DropdownMenuItem<String>(
                                value: language,
                                child: Text(language),
                              );
                            }).toList(),
                            onChanged: (String? newValue) async {
                              if (newValue != null && newValue != _nativeLanguage) {
                                setState(() {
                                  _selectedLanguage = newValue;
                                });
                                await _settingsService.setTargetLanguage(
                                  newValue,
                                );
                              }
                            },
                          ),
                        ),
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
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: _showImagePreview,
                            child: Chip(
                              avatar: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  _selectedImage!,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              label: const Text('Image attached'),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: _removeImage,
                              backgroundColor: Colors.blue.shade50,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Source text field with voice input
                      SizedBox(
                        height: inputHeight,
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
                              onChanged: (value) {
                                // Reset Whisper flag when user manually edits text
                                if (_isFromWhisper) {
                                  setState(() {
                                    _isFromWhisper = false;
                                  });
                                }
                              },
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
                                fillColor: _isRecording || _isTranscribing
                                    ? Colors.grey[200]
                                    : Colors.grey[100],
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
                                    border: Border.all(
                                      color: Colors.red,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.mic,
                                            color: Colors.red,
                                            size: 20,
                                          ),
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
                                                  color: Colors.red.withOpacity(
                                                    0.5,
                                                  ),
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
                                          value: _recordingAmplitude.clamp(
                                            0.0,
                                            1.0,
                                          ),
                                          minHeight: 6,
                                          backgroundColor: Colors.grey[300],
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
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
                                    border: Border.all(
                                      color: Colors.blue,
                                      width: 2,
                                    ),
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
                            // Provider dropdown at bottom left
                            if (_availableProviders.isNotEmpty)
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.grey.shade400,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: DropdownButton<LLMProvider>(
                                    value: _selectedProvider,
                                    isDense: true,
                                    underline: const SizedBox(),
                                    icon: const Icon(
                                      Icons.arrow_drop_down,
                                      size: 20,
                                    ),
                                    items: _availableProviders.map((provider) {
                                      return DropdownMenuItem<LLMProvider>(
                                        value: provider,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.cloud,
                                              size: 16,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              provider.name,
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (LLMProvider? newValue) async {
                                      if (newValue != null) {
                                        setState(() {
                                          _selectedProvider = newValue;
                                        });
                                        await _settingsService
                                            .setSelectedProvider(newValue);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            // Clear input button
                            if (_sourceController.text.isNotEmpty ||
                                _selectedImage != null)
                              Positioned(
                                bottom: 8,
                                right: 64,
                                child: FloatingActionButton(
                                  mini: true,
                                  onPressed: () {
                                    setState(() {
                                      _sourceController.clear();
                                      _selectedImage = null;
                                      _isFromWhisper = false;
                                      _errorMessage = '';
                                    });
                                  },
                                  backgroundColor: Colors.grey.shade600,
                                  child: const Icon(
                                    Icons.clear,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            // Voice input button
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: FloatingActionButton(
                                mini: true,
                                onPressed: _isRecording
                                    ? _stopVoiceInput
                                    : _startVoiceInput,
                                backgroundColor: _isRecording
                                    ? Colors.red
                                    : Colors.blue,
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
                      if (_translationResult.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        // Output text field with TTS button
                        SizedBox(
                          height: outputHeight,
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade400,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.blue[50],
                                ),
                                child: SelectionArea(
                                  onSelectionChanged: (selection) {
                                    if (selection != null) {
                                      setState(() {
                                        _selectedText = selection.plainText;
                                      });
                                    } else {
                                      setState(() {
                                        _selectedText = '';
                                      });
                                    }
                                  },
                                  child: Markdown(
                                    data: _convertToMarkdown(
                                      _translationResult,
                                    ),
                                    selectable:
                                        false, // SelectionArea handles this
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      12,
                                      12,
                                      48,
                                    ),
                                    styleSheet: MarkdownStyleSheet(
                                      p: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.black87,
                                      ),
                                      em: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // TTS button (only show if OpenAI key is configured)
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: FloatingActionButton(
                                  mini: true,
                                  onPressed: _isGeneratingTTS
                                      ? null
                                      : (_isPlayingTTS ? _stopTTS : _playTTS),
                                  backgroundColor: _isPlayingTTS
                                      ? Colors.orange
                                      : Colors.blue,
                                  child: _isGeneratingTTS
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Icon(
                                          _isPlayingTTS
                                              ? Icons.stop
                                              : Icons.volume_up,
                                          color: Colors.white,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Split button: Translate with dropdown menu
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _translate,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(4),
                                bottomLeft: Radius.circular(4),
                              ),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Translate',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        enabled: !_isLoading,
                        onSelected: (value) {
                          if (value == 'speak') {
                            _translateAndSpeak();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'speak',
                            child: Row(
                              children: [
                                Icon(Icons.record_voice_over),
                                SizedBox(width: 8),
                                Text('Translate & Speak'),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: _isLoading
                                ? Theme.of(context).disabledColor
                                : Theme.of(context).colorScheme.primary,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(4),
                              bottomRight: Radius.circular(4),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.arrow_drop_down,
                            color: _isLoading
                                ? Colors.grey
                                : Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
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
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                            ),
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
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _playerCompleteSubscription?.cancel();
    _sourceController.dispose();
    _targetController.dispose();
    _sourceFocusNode.dispose();
    _voiceInputService.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Generate and play TTS for the translation output
  Future<void> _playTTS() async {
    if (_translationResult.isEmpty) {
      return;
    }

    try {
      setState(() {
        _isGeneratingTTS = true;
        _errorMessage = '';
      });

      // Get OpenAI API key and TTS voice setting
      final apiKey = await _settingsService.getApiKey(LLMProvider.openai);

      if (apiKey.isEmpty) {
        setState(() {
          _errorMessage =
              'Please set your OpenAI API key in settings to use text-to-speech';
          _isGeneratingTTS = false;
        });
        return;
      }

      final voice = await _settingsService.getTTSVoice();

      // Use selected text if available, otherwise use full translation
      String textToSpeak = _selectedText.isNotEmpty
          ? _selectedText
          : _translationResult;

      // Remove T/N notes from speech output
      final tnPattern = RegExp(r'\(T/N:[^)]+\)');
      textToSpeak = textToSpeak.replaceAll(tnPattern, '');

      // Generate speech (truncate to OpenAI's 4096 character limit)
      final truncatedText = textToSpeak.length > 4096
          ? textToSpeak.substring(0, 4096)
          : textToSpeak;

      final audioPath = await _ttsService.generateSpeech(
        text: truncatedText,
        apiKey: apiKey,
        voice: voice,
      );

      // Handle volume control
      await _volumeService.ensureVolumeIsAudible();

      setState(() {
        _isGeneratingTTS = false;
        _isPlayingTTS = true;
      });

      // Cancel any existing subscription
      await _playerCompleteSubscription?.cancel();

      // Play audio
      await _audioPlayer.play(DeviceFileSource(audioPath));

      // Listen for completion
      _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) async {
        if (mounted) {
          setState(() {
            _isPlayingTTS = false;
          });
        }
        
        // Restore volume if needed
        await _volumeService.restoreVolume();
      });
    } catch (e) {
      setState(() {
        _isGeneratingTTS = false;
        _isPlayingTTS = false;
        _errorMessage = 'Text-to-speech failed: ${e.toString()}';
      });
      
      // Restore volume on error if needed
      await _volumeService.restoreVolume();
    }
  }

  /// Stop TTS playback
  Future<void> _stopTTS() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlayingTTS = false;
    });
    
    // Restore volume if needed
    await _volumeService.restoreVolume();
  }
}
