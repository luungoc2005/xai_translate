import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xai_translate/screens/stats_screen.dart';

void main() {
  group('StatsScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('should display app title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StatsScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Translation Statistics'), findsOneWidget);
    });

    testWidgets('should display filters section', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StatsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Provider:'), findsOneWidget);
      expect(find.text('Source Language:'), findsOneWidget);
      expect(find.text('Regional Preferences:'), findsOneWidget);
    });

    testWidgets('should display statistics section', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StatsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Statistics'), findsOneWidget);
    });

    testWidgets('should display clear stats button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StatsScreen(),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.delete_sweep), findsOneWidget);
    });

    testWidgets('should display empty state when no stats', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StatsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('No statistics available for the selected filters'), findsOneWidget);
    });

    testWidgets('should have provider dropdown', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StatsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('All Providers'), findsOneWidget);
    });
  });
}
