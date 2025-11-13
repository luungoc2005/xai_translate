import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xai_translate/screens/history_screen.dart';

void main() {
  group('HistoryScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('should display app title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Translation History'), findsOneWidget);
    });

    testWidgets('should display empty state when no history', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('No translation history yet'), findsOneWidget);
      // Clear button should NOT be visible when history is empty
      expect(find.byIcon(Icons.delete_sweep), findsNothing);
    });

    testWidgets('should display history icon in app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );

      expect(find.byIcon(Icons.history), findsOneWidget);
    });
  });
}
