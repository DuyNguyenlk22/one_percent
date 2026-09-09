import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/insights/presentation/pages/insights_page.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group('InsightsPage', () {
    testWidgets('renders streak counters, weekly flow, and focus areas', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(tester, const InsightsPage(), overrides: signedOutOverrides());

      expect(find.text('CURRENT STREAK'), findsOneWidget);
      expect(find.text('BEST STREAK'), findsOneWidget);
      expect(find.text('Weekly Flow'), findsOneWidget);
      expect(find.text('+15%'), findsOneWidget);
      expect(find.text('Focus Areas'), findsOneWidget);
      expect(find.text('Meditation'), findsOneWidget);
      expect(find.text('Early Sleep'), findsOneWidget);
    });
  });
}
