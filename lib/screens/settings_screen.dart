import 'package:flutter/material.dart';
import '../models/llm_provider.dart';
import '../models/regional_preference.dart';
import '../models/tts_voice.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final TextEditingController _grokKeyController = TextEditingController();
  final TextEditingController _openaiKeyController = TextEditingController();
  final TextEditingController _geminiKeyController = TextEditingController();
  
  RegionalPreference _selectedRegionalPreference = RegionalPreference.none;
  TTSVoice _selectedTTSVoice = TTSVoice.alloy;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final regionalPreference = await _settingsService.getRegionalPreference();
      final ttsVoice = await _settingsService.getTTSVoice();
      final grokKey = await _settingsService.getApiKey(LLMProvider.grok);
      final openaiKey = await _settingsService.getApiKey(LLMProvider.openai);
      final geminiKey = await _settingsService.getApiKey(LLMProvider.gemini);

      setState(() {
        _selectedRegionalPreference = regionalPreference;
        _selectedTTSVoice = ttsVoice;
        _grokKeyController.text = grokKey;
        _openaiKeyController.text = openaiKey;
        _geminiKeyController.text = geminiKey;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _settingsService.setRegionalPreference(_selectedRegionalPreference);
      await _settingsService.setTTSVoice(_selectedTTSVoice);
      await _settingsService.setApiKey(LLMProvider.grok, _grokKeyController.text);
      await _settingsService.setApiKey(LLMProvider.openai, _openaiKeyController.text);
      await _settingsService.setApiKey(LLMProvider.gemini, _geminiKeyController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
        
        // Navigate back to the main screen after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: _isSaving
                  ? const Center(
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : TextButton.icon(
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Save'),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Regional Preferences',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: _selectedRegionalPreference.toString().split('.').last,
                    isExpanded: true,
                    items: RegionalPreference.values.map((RegionalPreference preference) {
                      return DropdownMenuItem<String>(
                        value: preference.toString().split('.').last,
                        child: Text(preference.name),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedRegionalPreference = RegionalPreferenceExtension.fromString(newValue);
                        });
                      }
                    },
                  ),
                  if (_selectedRegionalPreference != RegionalPreference.none) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Translator Notes Enabled',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Translations will include T/N annotations for:',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• Currency → ${_selectedRegionalPreference.currency}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          Text(
                            '• Units → ${_selectedRegionalPreference.unitSystem}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          Text(
                            '• Cultural context hints',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'API Keys',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _grokKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Grok API Key',
                      hintText: 'Enter your Grok API key',
                      border: OutlineInputBorder(),
                      helperText: 'Get your API key from x.ai',
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _openaiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'OpenAI API Key',
                      hintText: 'Enter your OpenAI API key',
                      border: OutlineInputBorder(),
                      helperText: 'Get your API key from platform.openai.com',
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _geminiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Gemini API Key',
                      hintText: 'Enter your Gemini API key',
                      border: OutlineInputBorder(),
                      helperText: 'Get your API key from aistudio.google.com',
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Text-to-Speech Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Requires OpenAI API key',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TTSVoice>(
                    value: _selectedTTSVoice,
                    decoration: const InputDecoration(
                      labelText: 'Default Voice',
                      border: OutlineInputBorder(),
                      helperText: 'Select the voice for text-to-speech',
                    ),
                    items: TTSVoice.values.map((voice) {
                      return DropdownMenuItem<TTSVoice>(
                        value: voice,
                        child: Text('${voice.name} - ${voice.description}'),
                      );
                    }).toList(),
                    onChanged: (TTSVoice? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedTTSVoice = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _grokKeyController.dispose();
    _openaiKeyController.dispose();
    _geminiKeyController.dispose();
    super.dispose();
  }
}
