import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xai_translate/screens/translation_screen.dart';

void main() {
  group('TranslationScreen Widget Tests', () {
    testWidgets('should display app title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TranslationScreen(),
        ),
      );

      expect(find.text('AI Translate'), findsOneWidget);
    });

    testWidgets('should display input text field', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TranslationScreen(),
        ),
      );

      expect(find.byType(TextField), findsAtLeastNWidgets(1));
    });

    testWidgets('should display translate button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TranslationScreen(),
        ),
      );

      expect(find.widgetWithText(ElevatedButton, 'Translate'), findsOneWidget);
    });

    testWidgets('should display settings button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TranslationScreen(),
        ),
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('should display language selector', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TranslationScreen(),
        ),
      );

      expect(find.byType(DropdownButton<String>), findsAtLeastNWidgets(2));
    });

    testWidgets('should display swap languages button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TranslationScreen(),
        ),
      );

      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    });
  });
}
