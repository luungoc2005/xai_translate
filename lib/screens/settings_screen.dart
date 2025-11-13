import 'package:flutter/material.dart';
import '../models/llm_provider.dart';
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
  
  LLMProvider _selectedProvider = LLMProvider.grok;
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
      final provider = await _settingsService.getSelectedProvider();
      final grokKey = await _settingsService.getApiKey(LLMProvider.grok);
      final openaiKey = await _settingsService.getApiKey(LLMProvider.openai);
      final geminiKey = await _settingsService.getApiKey(LLMProvider.gemini);

      setState(() {
        _selectedProvider = provider;
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
      await _settingsService.setSelectedProvider(_selectedProvider);
      await _settingsService.setApiKey(LLMProvider.grok, _grokKeyController.text);
      await _settingsService.setApiKey(LLMProvider.openai, _openaiKeyController.text);
      await _settingsService.setApiKey(LLMProvider.gemini, _geminiKeyController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'LLM Provider',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: _selectedProvider.toString().split('.').last,
                    isExpanded: true,
                    items: LLMProvider.values.map((LLMProvider provider) {
                      return DropdownMenuItem<String>(
                        value: provider.toString().split('.').last,
                        child: Text(provider.name),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedProvider = LLMProviderExtension.fromString(newValue);
                        });
                      }
                    },
                  ),
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
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveSettings,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Settings', style: TextStyle(fontSize: 16)),
                  ),
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
