import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/presentation/pages/welcome_page.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group('WelcomePage', () {
    testWidgets('renders the brand and its promise', (tester) async {
      await pumpApp(tester, const WelcomePage(), overrides: signedOutOverrides());

      expect(find.text('THE 1% RULE'), findsOneWidget);
      expect(find.text('Est. 2024'), findsOneWidget);
      expect(find.text('Bloom'), findsOneWidget);
      expect(
        find.textContaining('Small habits, remarkable compounding.',
            findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('renders the three pillars', (tester) async {
      await pumpApp(tester, const WelcomePage(), overrides: signedOutOverrides());

      expect(find.text('Daily Rituals'), findsOneWidget);
      expect(find.text('Gentle morning & evening micro-actions'), findsOneWidget);
      expect(find.text('Consistency over Perfection'), findsOneWidget);
      expect(
        find.text('Track momentum without guilt or streaks pressure'),
        findsOneWidget,
      );
      expect(find.text('Calm Clarity'), findsOneWidget);
      expect(
        find.text('Mindful inspiration tailored for quiet growth'),
        findsOneWidget,
      );
    });

    testWidgets('offers both ways in', (tester) async {
      await pumpApp(tester, const WelcomePage(), overrides: signedOutOverrides());

      expect(find.text('Begin Your Journey'), findsOneWidget);
      expect(
        find.textContaining('Already have an account?', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Sign In'), findsOneWidget);
    });
  });
}
