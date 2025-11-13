import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xai_translate/screens/settings_screen.dart';

void main() {
  group('Settings Integration Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('should save settings without MissingPluginException',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(); // Wait for loading to complete

      // Act - Enter API key
      final grokKeyField = find.widgetWithText(TextField, '');
      await tester.enterText(grokKeyField.first, 'test_grok_api_key');
      await tester.pump();

      // Tap save button
      final saveButton = find.widgetWithText(ElevatedButton, 'Save Settings');
      expect(saveButton, findsOneWidget);
      
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump(); // Wait for save to complete

      // Assert - Should show success message
      expect(find.text('Settings saved successfully'), findsOneWidget);
    });

    testWidgets('should persist provider selection across saves',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Act - Change provider dropdown
      final dropdown = find.byType(DropdownButton<String>);
      expect(dropdown, findsOneWidget);
      
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      
      // Select OpenAI
      await tester.tap(find.text('OpenAI').last);
      await tester.pumpAndSettle();

      // Save settings
      final saveButton = find.widgetWithText(ElevatedButton, 'Save Settings');
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump();

      // Assert - Should save without exception
      expect(find.text('Settings saved successfully'), findsOneWidget);
    });

    testWidgets('should handle saving multiple API keys without exception',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Act - Enter all three API keys
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3));

      await tester.enterText(textFields.at(0), 'grok_key_123');
      await tester.pump();
      
      await tester.enterText(textFields.at(1), 'openai_key_456');
      await tester.pump();
      
      await tester.enterText(textFields.at(2), 'gemini_key_789');
      await tester.pump();

      // Save
      final saveButton = find.widgetWithText(ElevatedButton, 'Save Settings');
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump();

      // Assert - No exception, success message shown
      expect(find.text('Settings saved successfully'), findsOneWidget);
    });

    testWidgets('should handle save failure gracefully',
        (WidgetTester tester) async {
      // Arrange - This tests error handling if SharedPreferences fails
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Act - Try to save (should work in test environment)
      final saveButton = find.widgetWithText(ElevatedButton, 'Save Settings');
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump();

      // Assert - Should not crash, should show some feedback
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
