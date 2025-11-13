import 'package:flutter/material.dart';
import '../models/llm_provider.dart';
import '../services/stats_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final StatsService _statsService = StatsService();
  
  LLMProvider? _selectedProvider;
  String _selectedLanguage = 'All';
  bool? _regionalPreferenceFilter;
  
  Map<String, dynamic>? _currentStats;
  bool _isLoading = true;

  final List<String> _languages = [
    'All',
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

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
    });

    final stats = await _statsService.getProviderStats(
      provider: _selectedProvider,
      sourceLanguage: _selectedLanguage,
      regionalPreferenceEnabled: _regionalPreferenceFilter,
    );

    setState(() {
      _currentStats = stats;
      _isLoading = false;
    });
  }

  Future<void> _clearStats() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Statistics'),
        content: const Text('Are you sure you want to clear all translation statistics? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _statsService.clearStats();
      await _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Statistics cleared')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Translation Statistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearStats,
            tooltip: 'Clear all statistics',
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
                  // Filters Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.filter_list, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Filters',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Provider Filter
                          const Text('Provider:', style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          DropdownButton<LLMProvider?>(
                            value: _selectedProvider,
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<LLMProvider?>(
                                value: null,
                                child: Text('All Providers'),
                              ),
                              ...LLMProvider.values.map((provider) {
                                return DropdownMenuItem<LLMProvider?>(
                                  value: provider,
                                  child: Text(provider.name),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedProvider = value;
                              });
                              _loadStats();
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Language Filter
                          const Text('Source Language:', style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          DropdownButton<String>(
                            value: _selectedLanguage,
                            isExpanded: true,
                            items: _languages.map((lang) {
                              return DropdownMenuItem<String>(
                                value: lang,
                                child: Text(lang),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedLanguage = value;
                                });
                                _loadStats();
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Regional Preference Filter
                          const Text('Regional Preferences:', style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          DropdownButton<bool?>(
                            value: _regionalPreferenceFilter,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem<bool?>(
                                value: null,
                                child: Text('All'),
                              ),
                              DropdownMenuItem<bool?>(
                                value: true,
                                child: Text('Enabled'),
                              ),
                              DropdownMenuItem<bool?>(
                                value: false,
                                child: Text('Disabled'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _regionalPreferenceFilter = value;
                              });
                              _loadStats();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Statistics Display
                  if (_currentStats != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.analytics, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Statistics',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            if (_currentStats!['count'] == 0) ...[
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Text(
                                    'No statistics available for the selected filters',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ),
                            ] else ...[
                              _buildStatRow(
                                'Total Translations',
                                _currentStats!['count'].toString(),
                                Icons.translate,
                              ),
                              const Divider(height: 24),
                              _buildStatRow(
                                'Total Words Translated',
                                _currentStats!['totalWords'].toString(),
                                Icons.text_fields,
                              ),
                              const Divider(height: 24),
                              _buildStatRow(
                                'Avg Response Time',
                                '${_currentStats!['avgResponseTime'].toStringAsFixed(0)} ms',
                                Icons.timer,
                              ),
                              const Divider(height: 24),
                              _buildStatRow(
                                'Avg Time per Word',
                                '${_currentStats!['avgTimePerWord'].toStringAsFixed(1)} ms/word',
                                Icons.speed,
                                isHighlight: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Provider Comparison Card (when no provider filter)
                    if (_selectedProvider == null) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.compare_arrows, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Provider Comparison',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ...LLMProvider.values.map((provider) {
                                return FutureBuilder<Map<String, dynamic>>(
                                  future: _statsService.getProviderStats(
                                    provider: provider,
                                    sourceLanguage: _selectedLanguage,
                                    regionalPreferenceEnabled: _regionalPreferenceFilter,
                                  ),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const SizedBox.shrink();
                                    }
                                    
                                    final stats = snapshot.data!;
                                    if (stats['count'] == 0) {
                                      return const SizedBox.shrink();
                                    }
                                    
                                    return Column(
                                      children: [
                                        ListTile(
                                          leading: Icon(Icons.dns, color: _getProviderColor(provider)),
                                          title: Text(provider.name),
                                          subtitle: Text(
                                            '${stats['count']} translations • '
                                            '${stats['avgTimePerWord'].toStringAsFixed(1)} ms/word',
                                          ),
                                          trailing: Text(
                                            '${stats['avgResponseTime'].toStringAsFixed(0)} ms',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        if (provider != LLMProvider.values.last)
                                          const Divider(height: 8),
                                      ],
                                    );
                                  },
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, {bool isHighlight = false}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: isHighlight ? Colors.blue : Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isHighlight ? Colors.blue : Colors.black,
          ),
        ),
      ],
    );
  }

  Color _getProviderColor(LLMProvider provider) {
    switch (provider) {
      case LLMProvider.grok:
        return Colors.purple;
      case LLMProvider.openai:
        return Colors.green;
      case LLMProvider.gemini:
        return Colors.blue;
    }
  }
}
