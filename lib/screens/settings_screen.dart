import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/llm_provider.dart';
import '../models/regional_preference.dart';
import '../models/tts_voice.dart';
import '../services/settings_service.dart';
import '../services/backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final BackupService _backupService = BackupService();
  final TextEditingController _grokKeyController = TextEditingController();
  final TextEditingController _openaiKeyController = TextEditingController();
  final TextEditingController _geminiKeyController = TextEditingController();

  RegionalPreference _selectedRegionalPreference = RegionalPreference.none;
  TTSVoice _selectedTTSVoice = TTSVoice.alloy;
  String _nativeLanguage = 'English';
  bool _isLoading = true;
  bool _isSaving = false;

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
    setState(() {
      _isLoading = true;
    });

    try {
      final regionalPreference = await _settingsService.getRegionalPreference();
      final ttsVoice = await _settingsService.getTTSVoice();
      final nativeLanguage = await _settingsService.getNativeLanguage();
      final grokKey = await _settingsService.getApiKey(LLMProvider.grok);
      final openaiKey = await _settingsService.getApiKey(LLMProvider.openai);
      final geminiKey = await _settingsService.getApiKey(LLMProvider.gemini);

      setState(() {
        _selectedRegionalPreference = regionalPreference;
        _selectedTTSVoice = ttsVoice;
        _nativeLanguage = nativeLanguage;
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
      await _settingsService.setNativeLanguage(_nativeLanguage);
      await _settingsService.setApiKey(
        LLMProvider.grok,
        _grokKeyController.text,
      );
      await _settingsService.setApiKey(
        LLMProvider.openai,
        _openaiKeyController.text,
      );
      await _settingsService.setApiKey(
        LLMProvider.gemini,
        _geminiKeyController.text,
      );

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

  Future<void> _pasteFromClipboard(TextEditingController controller) async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        controller.text = clipboardData.text!;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pasted from clipboard'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _exportData() async {
    // Show summary dialog first
    try {
      final summary = await _backupService.getExportSummary();
      
      if (!mounted) return;
      
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export App Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The following data will be exported:'),
              const SizedBox(height: 16),
              _buildSummaryItem('Settings', summary.settingsCount),
              _buildSummaryItem('API Keys', summary.apiKeysCount),
              _buildSummaryItem('Conversation Messages', summary.conversationMessagesCount),
              _buildSummaryItem('Translation History', summary.historyCount),
              _buildSummaryItem('Statistics', summary.statsCount),
              const Divider(height: 24),
              Text(
                'Total: ${summary.totalItems} items',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Export'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final success = await _backupService.exportToFile();
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to export data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close any open dialogs
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importData() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import App Data'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⚠️ Warning: This will replace all current data with the imported data.'),
            SizedBox(height: 16),
            Text('This includes:'),
            Text('• All settings'),
            Text('• API keys'),
            Text('• Conversation history'),
            Text('• Translation history'),
            Text('• Statistics'),
            SizedBox(height: 16),
            Text(
              'Make sure to export your current data first if you want to keep it!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final result = await _backupService.importFromFile();
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result.success) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import Successful'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Data imported successfully!'),
                if (result.importDate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Backup date: ${result.importDate}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'The app will reload to apply the changes.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Reload settings
                  _loadSettings();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close any open dialogs
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSummaryItem(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            count.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 8.0,
              ),
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
                    'General Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _nativeLanguage,
                    decoration: const InputDecoration(
                      labelText: 'Native Language',
                      border: OutlineInputBorder(),
                      helperText: 'Your primary language for translations',
                    ),
                    items: _languages.map((String language) {
                      return DropdownMenuItem<String>(
                        value: language,
                        child: Text(language),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _nativeLanguage = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Regional Preferences',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: _selectedRegionalPreference
                        .toString()
                        .split('.')
                        .last,
                    isExpanded: true,
                    items: RegionalPreference.values.map((
                      RegionalPreference preference,
                    ) {
                      return DropdownMenuItem<String>(
                        value: preference.toString().split('.').last,
                        child: Text(preference.name),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedRegionalPreference =
                              RegionalPreferenceExtension.fromString(newValue);
                        });
                      }
                    },
                  ),
                  if (_selectedRegionalPreference !=
                      RegionalPreference.none) ...[
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
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: Colors.blue.shade700,
                              ),
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
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• Currency → ${_selectedRegionalPreference.currency}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            '• Units → ${_selectedRegionalPreference.unitSystem}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            '• Cultural context hints',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'API Keys',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _grokKeyController,
                    decoration: InputDecoration(
                      labelText: 'Grok API Key',
                      hintText: 'Enter your Grok API key',
                      border: const OutlineInputBorder(),
                      helperText: 'Get your API key from x.ai',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste),
                        onPressed: () => _pasteFromClipboard(_grokKeyController),
                        tooltip: 'Paste from clipboard',
                      ),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _openaiKeyController,
                    decoration: InputDecoration(
                      labelText: 'OpenAI API Key',
                      hintText: 'Enter your OpenAI API key',
                      border: const OutlineInputBorder(),
                      helperText: 'Get your API key from platform.openai.com',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste),
                        onPressed: () => _pasteFromClipboard(_openaiKeyController),
                        tooltip: 'Paste from clipboard',
                      ),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _geminiKeyController,
                    decoration: InputDecoration(
                      labelText: 'Gemini API Key',
                      hintText: 'Enter your Gemini API key',
                      border: const OutlineInputBorder(),
                      helperText: 'Get your API key from aistudio.google.com',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste),
                        onPressed: () => _pasteFromClipboard(_geminiKeyController),
                        tooltip: 'Paste from clipboard',
                      ),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Text-to-Speech Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Requires OpenAI API key',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                  const Text(
                    'Data Management',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _exportData,
                          icon: const Icon(Icons.upload),
                          label: const Text('Export Data'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _importData,
                          icon: const Icon(Icons.download),
                          label: const Text('Import Data'),
                        ),
                      ),
                    ],
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
