import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xai_translate/screens/settings_screen.dart';
import 'package:xai_translate/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsScreen - Backup/Import UI', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'selected_provider': 'grok',
        'regional_preference': 'none',
        'tts_voice': 'alloy',
      });
    });

    tearDown() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    }

    testWidgets('settings screen loads successfully', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );

      // Wait for the screen to load
      await tester.pumpAndSettle();

      // Check that the screen loads
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('settings screen has scrollable content', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify SingleChildScrollView exists
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('settings screen shows core sections', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Check for core section titles that should be visible
      expect(find.text('Regional Preferences'), findsOneWidget);
      expect(find.text('API Keys'), findsOneWidget);
    });
  });

  group('BackupService Integration', () {
    test('BackupService can be instantiated', () {
      expect(() => BackupService(), returnsNormally);
    });

    test('BackupService exports and imports data correctly', () async {
      SharedPreferences.setMockInitialValues({
        'test_setting': 'test_value',
        'api_key_grok': 'secret_key',
      });

      final service = BackupService();
      
      // Export data
      final exported = await service.exportAllData();
      
      // Verify exported data structure
      expect(exported['version'], equals('1.0'));
      expect(exported['exportDate'], isNotNull);
      expect(exported['data'], isNotNull);
      expect(exported['data']['test_setting'], equals('test_value'));
      expect(exported['data']['api_key_grok'], equals('secret_key'));

      // Clear data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Import data back
      final success = await service.importData(exported);
      expect(success, isTrue);

      // Verify data is restored
      final restoredPrefs = await SharedPreferences.getInstance();
      expect(restoredPrefs.getString('test_setting'), equals('test_value'));
      expect(restoredPrefs.getString('api_key_grok'), equals('secret_key'));
    });

    test('BackupService provides accurate export summary', () async {
      SharedPreferences.setMockInitialValues({
        'api_key_grok': 'key1',
        'api_key_openai': 'key2',
        'selected_provider': 'grok',
        'regional_preference': 'us',
      });

      final service = BackupService();
      final summary = await service.getExportSummary();

      expect(summary.apiKeysCount, equals(2));
      expect(summary.settingsCount, equals(2));
      expect(summary.totalItems, greaterThan(0));
    });
  });
}
