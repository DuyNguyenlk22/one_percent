import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/habits/presentation/pages/routines_page.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group('RoutinesPage', () {
    testWidgets('renders routines list and create routine action', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(tester, const RoutinesPage(), overrides: signedOutOverrides());

      expect(find.text('Your Routines'), findsOneWidget);
      expect(find.text('Structured growth, one step at a time.'), findsOneWidget);
      expect(find.text('Sunrise Ritual'), findsOneWidget);
      expect(find.text('Focus Block'), findsOneWidget);
      expect(find.text('Wind Down'), findsOneWidget);
      expect(find.text('Weekend Growth'), findsOneWidget);
      expect(find.text('Create Routine'), findsOneWidget);
    });
  });
}
