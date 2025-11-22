import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/conversation_message.dart';
import '../models/llm_provider.dart';
import '../services/translation_service.dart';
import '../services/settings_service.dart';
import '../services/voice_input_service.dart';
import '../services/tts_service.dart';
import '../services/volume_service.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TranslationService _translationService = TranslationService();
  final SettingsService _settingsService = SettingsService();
  final VoiceInputService _voiceInputService = VoiceInputService();
  final TTSService _ttsService = TTSService();
  final VolumeService _volumeService = VolumeService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String _language1 = 'English';
  String _language2 = 'English';
  LLMProvider _selectedProvider = LLMProvider.grok;
  List<LLMProvider> _availableProviders = [];
  List<ConversationMessage> _messages = [];
  bool _isLoading = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isGeneratingTTS = false;
  bool _isPlayingTTS = false;
  String _errorMessage = '';
  String? _currentRecordingPath;
  double _recordingAmplitude = 0.0;
  Stream<double>? _amplitudeStream;
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
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final selectedProvider = await _settingsService.getSelectedProvider();

    // Load languages from translate tab settings
    final sourceLanguage = await _settingsService.getSourceLanguage();
    final targetLanguage = await _settingsService.getTargetLanguage();
    
    // For conversation mode, we need two specific languages (not Auto-detect)
    // If source is Auto-detect, use English as first language
    final lang1 = (sourceLanguage == 'Auto-detect') ? 'English' : sourceLanguage;
    final lang2 = targetLanguage;

    // Load persisted conversation messages
    final savedMessages = await _settingsService.getConversationMessages();

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

    setState(() {
      _language1 = lang1;
      _language2 = lang2;
      _messages = savedMessages;
      _selectedProvider = providerToUse;
      _availableProviders = availableProviders;
    });
    
    // Scroll to bottom after loading messages
    if (_messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  /// Send a text message and translate it (auto-detect which language)
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message to conversation (without language yet)
    setState(() {
      _inputController.clear();
      _isLoading = true;
      _errorMessage = '';
    });

    _scrollToBottom();

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

      // Build context from previous messages (last 10 messages for context)
      final recentMessages = _messages.length > 10
          ? _messages.sublist(_messages.length - 10)
          : _messages;

      // Auto-detect and translate with context
      final result = await _translationService.translateInConversationModeWithAutoDetect(
        text: text,
        language1: _language1,
        language2: _language2,
        provider: provider,
        apiKey: apiKey,
        regionalPreference: regionalPreference,
        conversationHistory: recentMessages,
      );

      final detectedLanguage = result['detectedLanguage'] as String;
      final translation = result['translation'] as String;

      // Determine target language
      final targetLanguage = detectedLanguage == _language1 ? _language2 : _language1;

      // Create a single message with both original and translation
      final userMessage = ConversationMessage(
        text: text,
        language: detectedLanguage,
        timestamp: DateTime.now(),
        isUserInput: true,
        translatedText: translation,
        targetLanguage: targetLanguage,
      );

      setState(() {
        _messages.add(userMessage);
        _isLoading = false;
      });

      // Save messages to persistent storage
      await _settingsService.saveConversationMessages(_messages);

      _scrollToBottom();
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
        if (mounted) {
          setState(() {
            _recordingAmplitude = amplitude;
          });
        }
      });
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
          _errorMessage =
              'Whisper model not available. Please download a model file and place it in app documents/whisper/ directory.';
        });
        return;
      }

      // Transcribe audio
      final transcription = await _voiceInputService.transcribeAudio(
        _currentRecordingPath!,
      );

      setState(() {
        _isTranscribing = false;
      });

      // Clean up audio file
      await _voiceInputService.cleanupAudioFile(_currentRecordingPath!);
      _currentRecordingPath = null;

      // Send the transcribed message
      if (transcription.isNotEmpty) {
        await _sendMessage(transcription);
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

  /// Play TTS for a message
  Future<void> _playTTS(String text, String language) async {
    if (text.isEmpty) return;

    try {
      setState(() {
        _isGeneratingTTS = true;
        _errorMessage = '';
      });

      // Get OpenAI API key
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

      // Truncate to OpenAI's 4096 character limit
      final truncatedText = text.length > 4096
          ? text.substring(0, 4096)
          : text;

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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _clearConversation() async {
    await _settingsService.clearConversationMessages();
    setState(() {
      _messages.clear();
      _errorMessage = '';
    });
  }

  Widget _buildMessageBubble(ConversationMessage message) {
    // Blue bubble for language1, grey for language2
    final isLanguage1 = message.language == _language1;
    // Blue bubbles (language1) are right-aligned, grey bubbles (language2) are left-aligned
    final alignment = isLanguage1 ? Alignment.centerRight : Alignment.centerLeft;
    final color = isLanguage1 ? Colors.blue.shade100 : Colors.grey.shade200;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.language,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (message.translatedText != null)
                  IconButton(
                    icon: Icon(
                      _isPlayingTTS ? Icons.stop : Icons.volume_up,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _isGeneratingTTS
                        ? null
                        : (_isPlayingTTS
                            ? _stopTTS
                            : () => _playTTS(message.translatedText!, message.targetLanguage!)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SelectableText(
              message.text,
              style: const TextStyle(fontSize: 16),
            ),
            // Show translation if available
            if (message.translatedText != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isLanguage1 ? Colors.blue.shade300 : Colors.grey.shade400,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.targetLanguage ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      message.translatedText!,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(message.timestamp),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversation Mode'),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Conversation'),
                    content: const Text(
                      'Are you sure you want to clear this conversation?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          _clearConversation();
                          Navigator.pop(context);
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
              },
              tooltip: 'Clear conversation',
            ),
        ],
      ),
      body: Column(
        children: [
          // Language selection bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _language1,
                    isExpanded: true,
                    items: _languages.map((String language) {
                      return DropdownMenuItem<String>(
                        value: language,
                        child: Text(language),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null && newValue != _language2) {
                        setState(() {
                          _language1 = newValue;
                        });
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(
                    Icons.arrow_forward,
                    color: Colors.grey.shade600,
                  ),
                ),
                Expanded(
                  child: DropdownButton<String>(
                    value: _language2,
                    isExpanded: true,
                    items: _languages.map((String language) {
                      return DropdownMenuItem<String>(
                        value: language,
                        child: Text(language),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null && newValue != _language1) {
                        setState(() {
                          _language2 = newValue;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          // Provider selection
          if (_availableProviders.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Provider:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<LLMProvider>(
                    value: _selectedProvider,
                    isDense: true,
                    items: _availableProviders.map((provider) {
                      return DropdownMenuItem<LLMProvider>(
                        value: provider,
                        child: Text(provider.name),
                      );
                    }).toList(),
                    onChanged: (LLMProvider? newValue) async {
                      if (newValue != null) {
                        setState(() {
                          _selectedProvider = newValue;
                        });
                        await _settingsService.setSelectedProvider(newValue);
                      }
                    },
                  ),
                ],
              ),
            ),
          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose a language and send a message',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),
          // Loading indicator
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Translating...',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          // Recording indicator
          if (_isRecording)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                    ],
                  ),
                  const SizedBox(height: 8),
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
          // Transcribing indicator
          if (_isTranscribing)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
          // Error message
          if (_errorMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                ],
              ),
            ),
          // Input area
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                children: [
                  // Voice input button
                  IconButton(
                    icon: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: _isRecording ? Colors.red : Colors.blue,
                    ),
                    onPressed: _isTranscribing
                        ? null
                        : (_isRecording ? _stopVoiceInput : _startVoiceInput),
                    tooltip: _isRecording ? 'Stop recording' : 'Voice input',
                  ),
                  const SizedBox(width: 8),
                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      enabled: !_isRecording && !_isTranscribing,
                      decoration: InputDecoration(
                        hintText: _isRecording
                            ? 'Recording...'
                            : _isTranscribing
                                ? 'Processing...'
                                : 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          _sendMessage(value);
                        }
                      },
                      onChanged: (value) {
                        // Trigger rebuild to show/hide send button
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  if (_inputController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.send),
                      color: Colors.blue,
                      onPressed: () {
                        final text = _inputController.text;
                        if (text.isNotEmpty) {
                          _sendMessage(text);
                        }
                      },
                    ),
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
    _inputController.dispose();
    _scrollController.dispose();
    _voiceInputService.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
