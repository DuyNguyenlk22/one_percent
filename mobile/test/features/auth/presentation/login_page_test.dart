import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/pages/login_page.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group('LoginPage', () {
    testWidgets('renders the header, fields and actions', (tester) async {
      await pumpApp(tester, const LoginPage(), overrides: signedOutOverrides());

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Your journey to consistency continues.'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);

      // The footer is a Text.rich, so its spans need findRichText.
      expect(
        find.textContaining("Don't have an account?", findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('shows validation errors when submitted empty', (tester) async {
      await pumpApp(tester, const LoginPage(), overrides: signedOutOverrides());

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });
  });
}
