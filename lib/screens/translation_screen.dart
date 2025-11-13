import 'package:flutter/material.dart';
import '../models/llm_provider.dart';
import '../models/regional_preference.dart';
import '../models/translation_history_item.dart';
import '../services/translation_service.dart';
import '../services/settings_service.dart';
import '../services/history_service.dart';
import '../services/stats_service.dart';
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
  final TranslationService _translationService = TranslationService();
  final SettingsService _settingsService = SettingsService();
  final HistoryService _historyService = HistoryService();
  final StatsService _statsService = StatsService();
  
  String _sourceLanguage = 'Auto-detect';
  String _targetLanguage = 'Spanish';
  bool _isLoading = false;
  String _errorMessage = '';
  String _translationResult = '';

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

  Future<void> _translate() async {
    if (_sourceController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter text to translate';
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
      );

      final translation = result['translation'] as String;
      final stats = result['stats'];

      // Save to history
      final historyItem = TranslationHistoryItem(
        sourceText: _sourceController.text,
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
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Translation failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _swapLanguages() {
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
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ));
      }
      
      // Add T/N with faded, smaller style
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          fontSize: 13,
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
        style: const TextStyle(fontSize: 16, color: Colors.black87),
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
      body: Padding(
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
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _sourceLanguage = newValue;
                        });
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
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _targetLanguage = newValue;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Source text field
            Expanded(
              child: TextField(
                controller: _sourceController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Enter text to translate',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
            ),
            const SizedBox(height: 16),
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
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            // Target text field
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.blue[50],
                ),
                child: SingleChildScrollView(
                  child: _translationResult.isEmpty
                      ? Text(
                          'Translation will appear here',
                          style: TextStyle(color: Colors.grey.shade600),
                        )
                      : RichText(
                          text: TextSpan(
                            children: _buildFormattedTranslation(_translationResult),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _targetController.dispose();
    super.dispose();
  }
}
