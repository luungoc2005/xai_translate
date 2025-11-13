import 'package:flutter/material.dart';
import '../models/llm_provider.dart';
import '../services/translation_service.dart';
import '../services/settings_service.dart';
import 'settings_screen.dart';

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
  
  String _sourceLanguage = 'English';
  String _targetLanguage = 'Spanish';
  bool _isLoading = false;
  String _errorMessage = '';

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

      if (apiKey.isEmpty) {
        setState(() {
          _errorMessage = 'Please set your ${provider.name} API key in settings';
          _isLoading = false;
        });
        return;
      }

      final translation = await _translationService.translate(
        text: _sourceController.text,
        targetLanguage: _targetLanguage,
        provider: provider,
        apiKey: apiKey,
      );

      setState(() {
        _targetController.text = translation;
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
    setState(() {
      final temp = _sourceLanguage;
      _sourceLanguage = _targetLanguage;
      _targetLanguage = temp;

      final tempText = _sourceController.text;
      _sourceController.text = _targetController.text;
      _targetController.text = tempText;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Translate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
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
                    items: _languages.map((String language) {
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
                    items: _languages.map((String language) {
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
              child: TextField(
                controller: _targetController,
                maxLines: null,
                expands: true,
                readOnly: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Translation will appear here',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.blue[50],
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
