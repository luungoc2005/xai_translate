import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xai_translate/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupService', () {
    late BackupService backupService;

    setUp(() {
      backupService = BackupService();
    });

    tearDown(() async {
      // Clear shared preferences after each test
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    });

    group('exportAllData', () {
      test('exports empty data when no preferences exist', () async {
        SharedPreferences.setMockInitialValues({});

        final result = await backupService.exportAllData();

        expect(result['version'], equals('1.0'));
        expect(result['exportDate'], isNotNull);
        expect(result['data'], isEmpty);
      });

      test('exports string values correctly', () async {
        SharedPreferences.setMockInitialValues({
          'test_key': 'test_value',
          'another_key': 'another_value',
        });

        final result = await backupService.exportAllData();

        expect(result['data']['test_key'], equals('test_value'));
        expect(result['data']['another_key'], equals('another_value'));
      });

      test('exports int values correctly', () async {
        SharedPreferences.setMockInitialValues({
          'count': 42,
          'age': 25,
        });

        final result = await backupService.exportAllData();

        expect(result['data']['count'], equals(42));
        expect(result['data']['age'], equals(25));
      });

      test('exports double values correctly', () async {
        SharedPreferences.setMockInitialValues({
          'price': 19.99,
          'rating': 4.5,
        });

        final result = await backupService.exportAllData();

        expect(result['data']['price'], equals(19.99));
        expect(result['data']['rating'], equals(4.5));
      });

      test('exports bool values correctly', () async {
        SharedPreferences.setMockInitialValues({
          'isEnabled': true,
          'isActive': false,
        });

        final result = await backupService.exportAllData();

        expect(result['data']['isEnabled'], equals(true));
        expect(result['data']['isActive'], equals(false));
      });

      test('exports list values correctly', () async {
        SharedPreferences.setMockInitialValues({
          'tags': ['tag1', 'tag2', 'tag3'],
        });

        final result = await backupService.exportAllData();

        expect(result['data']['tags'], equals(['tag1', 'tag2', 'tag3']));
      });

      test('exports mixed data types correctly', () async {
        SharedPreferences.setMockInitialValues({
          'string_key': 'value',
          'int_key': 123,
          'double_key': 45.67,
          'bool_key': true,
          'list_key': ['item1', 'item2'],
        });

        final result = await backupService.exportAllData();

        expect(result['data']['string_key'], equals('value'));
        expect(result['data']['int_key'], equals(123));
        expect(result['data']['double_key'], equals(45.67));
        expect(result['data']['bool_key'], equals(true));
        expect(result['data']['list_key'], equals(['item1', 'item2']));
      });

      test('includes version and exportDate in result', () async {
        SharedPreferences.setMockInitialValues({});

        final result = await backupService.exportAllData();

        expect(result.containsKey('version'), isTrue);
        expect(result.containsKey('exportDate'), isTrue);
        expect(result.containsKey('data'), isTrue);
        expect(result['version'], equals('1.0'));
        
        // Verify exportDate is a valid ISO 8601 string
        expect(
          () => DateTime.parse(result['exportDate'] as String),
          returnsNormally,
        );
      });
    });

    group('importData', () {
      test('imports string data correctly', () async {
        SharedPreferences.setMockInitialValues({});

        final backupData = {
          'version': '1.0',
          'exportDate': DateTime.now().toIso8601String(),
          'data': {
            'test_key': 'test_value',
          },
        };

        final success = await backupService.importData(backupData);
        expect(success, isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('test_key'), equals('test_value'));
      });

      test('imports int data correctly', () async {
        SharedPreferences.setMockInitialValues({});

        final backupData = {
          'version': '1.0',
          'exportDate': DateTime.now().toIso8601String(),
          'data': {
            'count': 42,
          },
        };

        final success = await backupService.importData(backupData);
        expect(success, isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('count'), equals(42));
      });

      test('imports double data correctly', () async {
        SharedPreferences.setMockInitialValues({});

        final backupData = {
          'version': '1.0',
          'exportDate': DateTime.now().toIso8601String(),
          'data': {
            'price': 19.99,
          },
        };

        final success = await backupService.importData(backupData);
        expect(success, isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getDouble('price'), equals(19.99));
      });

      test('imports bool data correctly', () async {
        SharedPreferences.setMockInitialValues({});

        final backupData = {
          'version': '1.0',
          'exportDate': DateTime.now().toIso8601String(),
          'data': {
            'isEnabled': true,
          },
        };

        final success = await backupService.importData(backupData);
        expect(success, isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('isEnabled'), equals(true));
      });

      test('imports list data correctly', () async {
        SharedPreferences.setMockInitialValues({});

        final backupData = {
          'version': '1.0',
          'exportDate': DateTime.now().toIso8601String(),
          'data': {
            'tags': ['tag1', 'tag2', 'tag3'],
          },
        };

        final success = await backupService.importData(backupData);
        expect(success, isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getStringList('tags'), equals(['tag1', 'tag2', 'tag3']));
      });

      test('clears existing data before import', () async {
        SharedPreferences.setMockInitialValues({
          'old_key': 'old_value',
        });

        final backupData = {
          'version': '1.0',
          'exportDate': DateTime.now().toIso8601String(),
          'data': {
            'new_key': 'new_value',
          },
        };

        final success = await backupService.importData(backupData);
        expect(success, isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('old_key'), isNull);
        expect(prefs.getString('new_key'), equals('new_value'));
      });

      test('imports mixed data types correctly', () async {
        SharedPreferences.setMockInitialValues({});

        final backupData = {
          'version': '1.0',
          'exportDate': DateTime.now().toIso8601String(),
          'data': {
            'string_key': 'value',
            'int_key': 123,
            'double_key': 45.67,
            'bool_key': true,
            'list_key': ['item1', 'item2'],
          },
        };

        final success = await backupService.importData(backupData);
        expect(success, isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('string_key'), equals('value'));
        expect(prefs.getInt('int_key'), equals(123));
        expect(prefs.getDouble('double_key'), equals(45.67));
        expect(prefs.getBool('bool_key'), equals(true));
        expect(prefs.getStringList('list_key'), equals(['item1', 'item2']));
      });

      test('returns false for invalid backup format (missing version)', () async {
        SharedPreferences.setMockInitialValues({});

        final backupData = {
          'exportDate': DateTime.now().toIso8601String(),
          'data': {},
        };

        final success = await backupService.importData(backupData);
        expect(success, isFalse);
      });

      test('returns false for invalid backup format (missing data)', () async {
        SharedPreferences.setMockInitialValues({});

        final backupData = {
          'version': '1.0',
          'exportDate': DateTime.now().toIso8601String(),
        };

        final success = await backupService.importData(backupData);
        expect(success, isFalse);
      });

      test('handles empty data map', () async {
        // Set some initial data first
        SharedPreferences.setMockInitialValues({
          'old_key': 'old_value',
        });

        final backupData = {
          'version': '1.0',
          'exportDate': DateTime.now().toIso8601String(),
          'data': <String, dynamic>{},
        };

        final success = await backupService.importData(backupData);
        expect(success, isTrue);

        // After import with empty data, the old key should be cleared
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('old_key'), isNull);
      });
    });

    group('getExportSummary', () {
      test('returns zero counts for empty data', () async {
        SharedPreferences.setMockInitialValues({});

        final summary = await backupService.getExportSummary();

        expect(summary.settingsCount, equals(0));
        expect(summary.apiKeysCount, equals(0));
        expect(summary.conversationMessagesCount, equals(0));
        expect(summary.historyCount, equals(0));
        expect(summary.statsCount, equals(0));
        expect(summary.totalItems, equals(0));
      });

      test('counts API keys correctly', () async {
        SharedPreferences.setMockInitialValues({
          'api_key_grok': 'key1',
          'api_key_openai': 'key2',
          'api_key_gemini': 'key3',
        });

        final summary = await backupService.getExportSummary();

        expect(summary.apiKeysCount, equals(3));
        expect(summary.settingsCount, equals(0));
      });

      test('counts settings correctly', () async {
        SharedPreferences.setMockInitialValues({
          'selected_provider': 'grok',
          'regional_preference': 'us',
          'tts_voice': 'alloy',
        });

        final summary = await backupService.getExportSummary();

        expect(summary.settingsCount, equals(3));
        expect(summary.apiKeysCount, equals(0));
      });

      test('counts conversation messages correctly', () async {
        final messagesJson = '[{"text":"hello","language":"en","timestamp":"2025-11-15T10:00:00.000","isUserInput":true}]';
        
        SharedPreferences.setMockInitialValues({
          'conversation_messages': messagesJson,
        });

        final summary = await backupService.getExportSummary();

        expect(summary.conversationMessagesCount, equals(1));
        expect(summary.settingsCount, equals(0));
      });

      test('counts translation history correctly', () async {
        final historyJson = '[{"text":"test","translation":"prueba","timestamp":"2025-11-15T10:00:00.000"}]';
        
        SharedPreferences.setMockInitialValues({
          'translation_history': historyJson,
        });

        final summary = await backupService.getExportSummary();

        expect(summary.historyCount, equals(1));
        expect(summary.settingsCount, equals(0));
      });

      test('counts translation stats correctly', () async {
        final statsJson = '[{"provider":"grok","responseTimeMs":1000,"wordCount":10}]';
        
        SharedPreferences.setMockInitialValues({
          'translation_stats': statsJson,
        });

        final summary = await backupService.getExportSummary();

        expect(summary.statsCount, equals(1));
        expect(summary.settingsCount, equals(0));
      });

      test('calculates total items correctly', () async {
        final messagesJson = '[{"text":"hello"}]';
        final historyJson = '[{"text":"test"}]';
        
        SharedPreferences.setMockInitialValues({
          'api_key_grok': 'key1',
          'api_key_openai': 'key2',
          'selected_provider': 'grok',
          'conversation_messages': messagesJson,
          'translation_history': historyJson,
        });

        final summary = await backupService.getExportSummary();

        expect(summary.apiKeysCount, equals(2));
        expect(summary.settingsCount, equals(1));
        expect(summary.conversationMessagesCount, equals(1));
        expect(summary.historyCount, equals(1));
        expect(summary.totalItems, equals(5));
      });

      test('handles invalid JSON gracefully', () async {
        SharedPreferences.setMockInitialValues({
          'conversation_messages': 'invalid json',
          'translation_history': '{not valid}',
        });

        final summary = await backupService.getExportSummary();

        // Invalid JSON should return 0 for those counts
        expect(summary.conversationMessagesCount, equals(0));
        expect(summary.historyCount, equals(0));
        // These keys are still in the data but parsing failed,
        // so they don't get counted as settings either (they just fail parsing)
        expect(summary.settingsCount, equals(0));
        expect(summary.totalItems, equals(0));
      });
    });

    group('Export and Import Integration', () {
      test('full export and import cycle preserves all data', () async {
        // Setup initial data
        SharedPreferences.setMockInitialValues({
          'string_key': 'test_value',
          'int_key': 42,
          'double_key': 3.14,
          'bool_key': true,
          'list_key': ['a', 'b', 'c'],
          'api_key_grok': 'secret_key',
        });

        // Export data
        final exportedData = await backupService.exportAllData();

        // Clear data
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        // Verify data is cleared
        expect(prefs.getKeys(), isEmpty);

        // Import data
        final success = await backupService.importData(exportedData);
        expect(success, isTrue);

        // Verify all data is restored
        expect(prefs.getString('string_key'), equals('test_value'));
        expect(prefs.getInt('int_key'), equals(42));
        expect(prefs.getDouble('double_key'), equals(3.14));
        expect(prefs.getBool('bool_key'), equals(true));
        expect(prefs.getStringList('list_key'), equals(['a', 'b', 'c']));
        expect(prefs.getString('api_key_grok'), equals('secret_key'));
      });
    });
  });

  group('ImportResult', () {
    test('creates ImportResult with all properties', () {
      final result = ImportResult(
        success: true,
        message: 'Success',
        importDate: '2025-11-15T10:00:00.000',
      );

      expect(result.success, isTrue);
      expect(result.message, equals('Success'));
      expect(result.importDate, equals('2025-11-15T10:00:00.000'));
    });

    test('creates ImportResult without importDate', () {
      final result = ImportResult(
        success: false,
        message: 'Failed',
      );

      expect(result.success, isFalse);
      expect(result.message, equals('Failed'));
      expect(result.importDate, isNull);
    });
  });

  group('ExportSummary', () {
    test('creates ExportSummary with all properties', () {
      final summary = ExportSummary(
        settingsCount: 5,
        apiKeysCount: 3,
        conversationMessagesCount: 10,
        historyCount: 20,
        statsCount: 15,
      );

      expect(summary.settingsCount, equals(5));
      expect(summary.apiKeysCount, equals(3));
      expect(summary.conversationMessagesCount, equals(10));
      expect(summary.historyCount, equals(20));
      expect(summary.statsCount, equals(15));
      expect(summary.totalItems, equals(53));
    });

    test('calculates totalItems correctly with zeros', () {
      final summary = ExportSummary(
        settingsCount: 0,
        apiKeysCount: 0,
        conversationMessagesCount: 0,
        historyCount: 0,
        statsCount: 0,
      );

      expect(summary.totalItems, equals(0));
    });
  });
}
