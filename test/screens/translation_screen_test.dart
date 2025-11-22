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

      // Should have 1 dropdown for Foreign language
      expect(find.byType(DropdownButton<String>), findsOneWidget);
      
      // Should NOT display Foreign Language label (removed for simplicity)
      expect(find.text('Foreign Language'), findsNothing);
      
      // Should NOT display Native label or swap icon
      expect(find.text('Native'), findsNothing);
      expect(find.byIcon(Icons.swap_horiz), findsNothing);
    });

    testWidgets('should display history button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TranslationScreen(),
        ),
      );

      expect(find.byIcon(Icons.history), findsOneWidget);
    });

    testWidgets('should display stats button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TranslationScreen(),
        ),
      );

      expect(find.byIcon(Icons.bar_chart), findsOneWidget);
    });
  });
}
