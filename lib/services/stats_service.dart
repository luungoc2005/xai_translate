import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/translation_stats.dart';
import '../models/llm_provider.dart';

class StatsService {
  static const String _statsKey = 'translation_stats';
  static const int _maxStats = 1000; // Keep last 1000 stats

  Future<void> addStats(TranslationStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    final statsList = await getAllStats();
    
    statsList.add(stats);
    
    // Keep only the most recent stats
    if (statsList.length > _maxStats) {
      statsList.removeRange(0, statsList.length - _maxStats);
    }
    
    final jsonList = statsList.map((s) => s.toJson()).toList();
    await prefs.setString(_statsKey, jsonEncode(jsonList));
  }

  Future<List<TranslationStats>> getAllStats() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_statsKey);
    
    if (jsonString == null) {
      return [];
    }
    
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => TranslationStats.fromJson(json)).toList();
  }

  Future<List<TranslationStats>> getFilteredStats({
    LLMProvider? provider,
    String? sourceLanguage,
    bool? regionalPreferenceEnabled,
  }) async {
    var stats = await getAllStats();
    
    if (provider != null) {
      stats = stats.where((s) => s.provider == provider).toList();
    }
    
    if (sourceLanguage != null && sourceLanguage != 'All') {
      stats = stats.where((s) => s.sourceLanguage == sourceLanguage).toList();
    }
    
    if (regionalPreferenceEnabled != null) {
      stats = stats.where((s) => s.regionalPreferenceEnabled == regionalPreferenceEnabled).toList();
    }
    
    return stats;
  }

  Future<Map<String, dynamic>> getProviderStats({
    LLMProvider? provider,
    String? sourceLanguage,
    bool? regionalPreferenceEnabled,
  }) async {
    final stats = await getFilteredStats(
      provider: provider,
      sourceLanguage: sourceLanguage,
      regionalPreferenceEnabled: regionalPreferenceEnabled,
    );
    
    if (stats.isEmpty) {
      return {
        'count': 0,
        'avgResponseTime': 0.0,
        'avgTimePerWord': 0.0,
        'totalWords': 0,
      };
    }
    
    final totalResponseTime = stats.fold<int>(0, (sum, s) => sum + s.responseTimeMs);
    final totalWords = stats.fold<int>(0, (sum, s) => sum + s.wordCount);
    final avgResponseTime = totalResponseTime / stats.length;
    final avgTimePerWord = totalWords > 0 ? totalResponseTime / totalWords : 0.0;
    
    return {
      'count': stats.length,
      'avgResponseTime': avgResponseTime,
      'avgTimePerWord': avgTimePerWord,
      'totalWords': totalWords,
    };
  }

  Future<void> clearStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_statsKey);
  }
}
