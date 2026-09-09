import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/features/auth/presentation/pages/login_page.dart';
import 'package:mobile/injection/dependency_injection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/pump_app.dart';

/// Boots the real object graph — DI, router, and redirects — with only the
/// repository and SharedPreferences replaced. Catches wiring mistakes that
/// per-layer unit tests cannot see.
void main() {
  testWidgets('App starts signed out and lands on the login page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          ...signedOutOverrides(),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
  });
}
