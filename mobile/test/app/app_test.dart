import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/features/auth/presentation/pages/login_page.dart';
import 'package:mobile/features/auth/presentation/pages/register_page.dart';
import 'package:mobile/features/habits/domain/entities/daily_habit.dart';
import 'package:mobile/features/habits/presentation/pages/today_page.dart';
import 'package:mobile/features/onboarding/presentation/pages/welcome_page.dart';
import 'package:mobile/injection/dependency_injection.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';
import '../helpers/pump_app.dart';

/// Boots the real object graph — DI, router, and redirects — with only the
/// repositories and SharedPreferences replaced. Catches wiring mistakes that
/// per-layer unit tests cannot see.
void main() {
  setUpAll(registerFallbacks);

  Future<void> pumpBootedApp(
    WidgetTester tester, {
    required List<Override> overrides,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          ...overrides,
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('App opens on the welcome screen while signed out', (tester) async {
    await pumpBootedApp(tester, overrides: signedOutOverrides());

    expect(find.byType(WelcomePage), findsOneWidget);
  });

  testWidgets('Begin Your Journey opens the register page', (tester) async {
    await pumpBootedApp(tester, overrides: signedOutOverrides());

    await tester.tap(find.text('Begin Your Journey'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsOneWidget);
  });

  testWidgets('Sign In opens the login page', (tester) async {
    await pumpBootedApp(tester, overrides: signedOutOverrides());

    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('a signed-in user sees the welcome screen, then the shell',
      (tester) async {
    final habits = MockHabitRepository();
    when(() => habits.getHabitsForDate(any()))
        .thenAnswer((_) async => const Success(<DailyHabit>[]));

    await pumpBootedApp(
      tester,
      overrides: [
        ...signedInOverrides(buildUserModel()),
        habitRepositoryProvider.overrideWithValue(habits),
      ],
    );

    // The brand holds the screen even for a user who is already signed in.
    expect(find.byType(WelcomePage), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(find.byType(TodayPage), findsOneWidget);
  });
}
