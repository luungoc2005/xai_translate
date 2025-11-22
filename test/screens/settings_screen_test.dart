import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xai_translate/screens/settings_screen.dart';

void main() {
  group('SettingsScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('should display app title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('should display Native Language selection', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Native Language'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsAtLeastNWidgets(1));
    });

    testWidgets('should display API key input fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Grok API Key'), findsOneWidget);
      expect(find.text('OpenAI API Key'), findsOneWidget);
      expect(find.text('Gemini API Key'), findsOneWidget);
    });

    testWidgets('should display save button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);
    });
  });
}
