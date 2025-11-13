import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/translation_history_item.dart';

class HistoryService {
  static const String _historyKey = 'translation_history';
  static const int _maxHistoryItems = 100;

  Future<List<TranslationHistoryItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    
    if (historyJson == null) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(historyJson);
      return decoded
          .map((item) => TranslationHistoryItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addToHistory(TranslationHistoryItem item) async {
    final history = await getHistory();
    
    // Add new item at the beginning (most recent first)
    history.insert(0, item);
    
    // Limit to maximum items
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }
    
    await _saveHistory(history);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  Future<void> deleteHistoryItem(int index) async {
    final history = await getHistory();
    
    if (index >= 0 && index < history.length) {
      history.removeAt(index);
      await _saveHistory(history);
    }
  }

  Future<void> _saveHistory(List<TranslationHistoryItem> history) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = jsonEncode(history.map((item) => item.toJson()).toList());
    await prefs.setString(_historyKey, historyJson);
  }
}
