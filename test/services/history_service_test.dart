import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xai_translate/services/history_service.dart';
import 'package:xai_translate/models/translation_history_item.dart';

void main() {
  group('HistoryService', () {
    late HistoryService historyService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      historyService = HistoryService();
    });

    test('should return empty list when no history exists', () async {
      // Act
      final history = await historyService.getHistory();

      // Assert
      expect(history, isEmpty);
    });

    test('should save translation to history', () async {
      // Arrange
      final timestamp = DateTime.now();
      final item = TranslationHistoryItem(
        sourceText: 'Hello',
        translatedText: 'Hola',
        sourceLanguage: 'English',
        targetLanguage: 'Spanish',
        timestamp: timestamp,
      );

      // Act
      await historyService.addToHistory(item);
      final history = await historyService.getHistory();

      // Assert
      expect(history.length, 1);
      expect(history.first.sourceText, 'Hello');
      expect(history.first.translatedText, 'Hola');
      expect(history.first.sourceLanguage, 'English');
      expect(history.first.targetLanguage, 'Spanish');
    });

    test('should save multiple translations to history', () async {
      // Arrange
      final item1 = TranslationHistoryItem(
        sourceText: 'Hello',
        translatedText: 'Hola',
        sourceLanguage: 'English',
        targetLanguage: 'Spanish',
        timestamp: DateTime.now(),
      );
      final item2 = TranslationHistoryItem(
        sourceText: 'Goodbye',
        translatedText: 'Adiós',
        sourceLanguage: 'English',
        targetLanguage: 'Spanish',
        timestamp: DateTime.now(),
      );

      // Act
      await historyService.addToHistory(item1);
      await historyService.addToHistory(item2);
      final history = await historyService.getHistory();

      // Assert
      expect(history.length, 2);
      expect(history[0].sourceText, 'Goodbye'); // Most recent first
      expect(history[1].sourceText, 'Hello');
    });

    test('should limit history to maximum items', () async {
      // Arrange - Add 101 items (max is 100)
      for (int i = 0; i < 101; i++) {
        final item = TranslationHistoryItem(
          sourceText: 'Text $i',
          translatedText: 'Translation $i',
          sourceLanguage: 'English',
          targetLanguage: 'Spanish',
          timestamp: DateTime.now(),
        );
        await historyService.addToHistory(item);
      }

      // Act
      final history = await historyService.getHistory();

      // Assert
      expect(history.length, 100); // Should be limited to 100
      expect(history.first.sourceText, 'Text 100'); // Most recent
      expect(history.last.sourceText, 'Text 1'); // Oldest kept
    });

    test('should clear all history', () async {
      // Arrange
      final item = TranslationHistoryItem(
        sourceText: 'Hello',
        translatedText: 'Hola',
        sourceLanguage: 'English',
        targetLanguage: 'Spanish',
        timestamp: DateTime.now(),
      );
      await historyService.addToHistory(item);

      // Act
      await historyService.clearHistory();
      final history = await historyService.getHistory();

      // Assert
      expect(history, isEmpty);
    });

    test('should delete specific history item', () async {
      // Arrange
      final item1 = TranslationHistoryItem(
        sourceText: 'Hello',
        translatedText: 'Hola',
        sourceLanguage: 'English',
        targetLanguage: 'Spanish',
        timestamp: DateTime.now(),
      );
      final item2 = TranslationHistoryItem(
        sourceText: 'Goodbye',
        translatedText: 'Adiós',
        sourceLanguage: 'English',
        targetLanguage: 'Spanish',
        timestamp: DateTime.now(),
      );
      await historyService.addToHistory(item1);
      await historyService.addToHistory(item2);

      // Act
      await historyService.deleteHistoryItem(0); // Delete first item
      final history = await historyService.getHistory();

      // Assert
      expect(history.length, 1);
      expect(history.first.sourceText, 'Hello');
    });

    test('should persist history across service instances', () async {
      // Arrange
      final item = TranslationHistoryItem(
        sourceText: 'Hello',
        translatedText: 'Hola',
        sourceLanguage: 'English',
        targetLanguage: 'Spanish',
        timestamp: DateTime.now(),
      );
      await historyService.addToHistory(item);

      // Act - Create new service instance
      final newService = HistoryService();
      final history = await newService.getHistory();

      // Assert
      expect(history.length, 1);
      expect(history.first.sourceText, 'Hello');
    });
  });
}
