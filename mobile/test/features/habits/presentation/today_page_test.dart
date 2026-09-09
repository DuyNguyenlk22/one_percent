import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/habits/presentation/pages/today_page.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group('TodayPage', () {
    testWidgets('renders greeting, progress ring, motivation quote, and habits', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(tester, const TodayPage(), overrides: signedOutOverrides());

      expect(find.text('Bloom'), findsOneWidget);
      expect(find.text("Today's Progress"), findsOneWidget);
      expect(find.text('Day Streak'), findsOneWidget);
      expect(find.text('DAILY MOTIVATION'), findsOneWidget);
      expect(find.text('DAILY HABITS'), findsOneWidget);
      expect(find.text('Drink enough water'), findsOneWidget);
      expect(find.text('Morning exercise'), findsOneWidget);
      expect(find.text('Meditate'), findsOneWidget);
      expect(find.text('Read a book'), findsOneWidget);
    });

    testWidgets('interactive water counter increments on Add 250ml', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(tester, const TodayPage(), overrides: signedOutOverrides());

      expect(find.text('1.5L / 2.0L Goal'), findsOneWidget);

      await tester.tap(find.text('Add 250ml'));
      await tester.pumpAndSettle();

      expect(find.text('1.8L / 2.0L Goal'), findsOneWidget);
    });

    testWidgets('tapping motivation card cycles quote', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(tester, const TodayPage(), overrides: signedOutOverrides());

      final firstQuoteFinder = find.text('"Focus on the step you\'re taking, not the whole staircase."');
      expect(firstQuoteFinder, findsOneWidget);

      await tester.tap(find.text('DAILY MOTIVATION'));
      await tester.pumpAndSettle();

      expect(firstQuoteFinder, findsNothing);
      expect(find.text('"The secret of your future is hidden in your daily routine."'), findsOneWidget);
    });
  });
}
