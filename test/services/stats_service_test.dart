import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xai_translate/services/stats_service.dart';
import 'package:xai_translate/models/translation_stats.dart';
import 'package:xai_translate/models/llm_provider.dart';

void main() {
  group('StatsService', () {
    late StatsService statsService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      statsService = StatsService();
    });

    test('should add and retrieve stats', () async {
      // Arrange
      final stats = TranslationStats(
        provider: LLMProvider.grok,
        sourceLanguage: 'English',
        wordCount: 10,
        responseTimeMs: 1500,
        regionalPreferenceEnabled: false,
        timestamp: DateTime.now(),
      );

      // Act
      await statsService.addStats(stats);
      final retrieved = await statsService.getAllStats();

      // Assert
      expect(retrieved.length, 1);
      expect(retrieved[0].provider, LLMProvider.grok);
      expect(retrieved[0].wordCount, 10);
      expect(retrieved[0].responseTimeMs, 1500);
    });

    test('should retrieve multiple stats', () async {
      // Arrange
      final stats1 = TranslationStats(
        provider: LLMProvider.grok,
        sourceLanguage: 'English',
        wordCount: 10,
        responseTimeMs: 1500,
        regionalPreferenceEnabled: false,
        timestamp: DateTime.now(),
      );
      
      final stats2 = TranslationStats(
        provider: LLMProvider.openai,
        sourceLanguage: 'Spanish',
        wordCount: 20,
        responseTimeMs: 2000,
        regionalPreferenceEnabled: true,
        timestamp: DateTime.now(),
      );

      // Act
      await statsService.addStats(stats1);
      await statsService.addStats(stats2);
      final retrieved = await statsService.getAllStats();

      // Assert
      expect(retrieved.length, 2);
    });

    test('should filter stats by provider', () async {
      // Arrange
      final grokStats = TranslationStats(
        provider: LLMProvider.grok,
        sourceLanguage: 'English',
        wordCount: 10,
        responseTimeMs: 1500,
        regionalPreferenceEnabled: false,
        timestamp: DateTime.now(),
      );
      
      final openaiStats = TranslationStats(
        provider: LLMProvider.openai,
        sourceLanguage: 'Spanish',
        wordCount: 20,
        responseTimeMs: 2000,
        regionalPreferenceEnabled: true,
        timestamp: DateTime.now(),
      );

      await statsService.addStats(grokStats);
      await statsService.addStats(openaiStats);

      // Act
      final filtered = await statsService.getFilteredStats(provider: LLMProvider.grok);

      // Assert
      expect(filtered.length, 1);
      expect(filtered[0].provider, LLMProvider.grok);
    });

    test('should filter stats by source language', () async {
      // Arrange
      final englishStats = TranslationStats(
        provider: LLMProvider.grok,
        sourceLanguage: 'English',
        wordCount: 10,
        responseTimeMs: 1500,
        regionalPreferenceEnabled: false,
        timestamp: DateTime.now(),
      );
      
      final spanishStats = TranslationStats(
        provider: LLMProvider.grok,
        sourceLanguage: 'Spanish',
        wordCount: 20,
        responseTimeMs: 2000,
        regionalPreferenceEnabled: false,
        timestamp: DateTime.now(),
      );

      await statsService.addStats(englishStats);
      await statsService.addStats(spanishStats);

      // Act
      final filtered = await statsService.getFilteredStats(sourceLanguage: 'English');

      // Assert
      expect(filtered.length, 1);
      expect(filtered[0].sourceLanguage, 'English');
    });

    test('should filter stats by regional preference', () async {
      // Arrange
      final withPref = TranslationStats(
        provider: LLMProvider.grok,
        sourceLanguage: 'English',
        wordCount: 10,
        responseTimeMs: 1500,
        regionalPreferenceEnabled: true,
        timestamp: DateTime.now(),
      );
      
      final withoutPref = TranslationStats(
        provider: LLMProvider.grok,
        sourceLanguage: 'English',
        wordCount: 20,
        responseTimeMs: 2000,
        regionalPreferenceEnabled: false,
        timestamp: DateTime.now(),
      );

      await statsService.addStats(withPref);
      await statsService.addStats(withoutPref);

      // Act
      final filtered = await statsService.getFilteredStats(regionalPreferenceEnabled: true);

      // Assert
      expect(filtered.length, 1);
      expect(filtered[0].regionalPreferenceEnabled, true);
    });

    test('should calculate provider stats correctly', () async {
      // Arrange
      final stats1 = TranslationStats(
        provider: LLMProvider.grok,
        sourceLanguage: 'English',
        wordCount: 10,
        responseTimeMs: 1000,
        regionalPreferenceEnabled: false,
        timestamp: DateTime.now(),
      );
      
      final stats2 = TranslationStats(
        provider: LLMProvider.grok,
        sourceLanguage: 'English',
        wordCount: 20,
        responseTimeMs: 2000,
        regionalPreferenceEnabled: false,
        timestamp: DateTime.now(),
      );

      await statsService.addStats(stats1);
      await statsService.addStats(stats2);

      // Act
      final providerStats = await statsService.getProviderStats(provider: LLMProvider.grok);

      // Assert
      expect(providerStats['count'], 2);
      expect(providerStats['totalWords'], 30);
      expect(providerStats['avgResponseTime'], 1500.0);
      expect(providerStats['avgTimePerWord'], 100.0); // 3000 ms / 30 words
    });

    test('should return zero stats when no data', () async {
      // Act
      final providerStats = await statsService.getProviderStats(provider: LLMProvider.grok);

      // Assert
      expect(providerStats['count'], 0);
      expect(providerStats['avgResponseTime'], 0.0);
      expect(providerStats['avgTimePerWord'], 0.0);
      expect(providerStats['totalWords'], 0);
    });

    test('should clear all stats', () async {
      // Arrange
      final stats = TranslationStats(
        provider: LLMProvider.grok,
        sourceLanguage: 'English',
        wordCount: 10,
        responseTimeMs: 1500,
        regionalPreferenceEnabled: false,
        timestamp: DateTime.now(),
      );
      
      await statsService.addStats(stats);
      expect((await statsService.getAllStats()).length, 1);

      // Act
      await statsService.clearStats();
      final retrieved = await statsService.getAllStats();

      // Assert
      expect(retrieved.length, 0);
    });

    test('should limit stats to max count', () async {
      // Arrange - Add more than max stats
      for (int i = 0; i < 1100; i++) {
        final stats = TranslationStats(
          provider: LLMProvider.grok,
          sourceLanguage: 'English',
          wordCount: 10,
          responseTimeMs: 1500,
          regionalPreferenceEnabled: false,
          timestamp: DateTime.now(),
        );
        await statsService.addStats(stats);
      }

      // Act
      final retrieved = await statsService.getAllStats();

      // Assert
      expect(retrieved.length, 1000); // Should be limited to max
    });
  });
}
