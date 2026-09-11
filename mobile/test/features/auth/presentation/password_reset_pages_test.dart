import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/router/route_names.dart';
import 'package:mobile/app/theme/theme.dart';
import 'package:mobile/core/errors/failures.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:mobile/features/auth/presentation/pages/reset_password_page.dart';
import 'package:mobile/injection/dependency_injection.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

const _email = 'alex.bloom@example.com';

/// Mounts the reset flow on a router carrying the three routes it moves
/// between, so the hand-off from verify to reset is the real one.
///
/// Pumps explicitly rather than settling: the resend countdown is a periodic
/// timer, and `pumpAndSettle` would run the whole 60 seconds of it.
Future<GoRouter> pumpResetFlow(
  WidgetTester tester,
  MockAuthRepository repository, {
  String initialLocation = '${RouteNames.forgotPasswordPath}?email=$_email',
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: RouteNames.forgotPasswordPath,
        name: RouteNames.forgotPassword,
        builder: (context, state) =>
            ForgotPasswordPage(email: state.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(
        path: RouteNames.resetPasswordPath,
        name: RouteNames.resetPassword,
        builder: (context, state) => ResetPasswordPage(
          resetToken: state.uri.queryParameters['token'] ?? '',
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: RouteNames.loginPath,
        name: RouteNames.login,
        builder: (context, state) => const Scaffold(body: Text('Login screen')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  // Build, run the post-frame send, then let the repository future complete.
  await tester.pump();
  await tester.pump();
  await tester.pump();

  return router;
}

/// Fills the email step's single field and taps its CTA, then lets the
/// request settle.
Future<void> submitEmail(WidgetTester tester, String email) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.tap(find.text('Send Code'));
  await tester.pump();
  await tester.pump();
}

/// Types a full code into the OTP boxes. The last digit auto-submits.
Future<void> enterCode(WidgetTester tester, String code) async {
  final boxes = find.byType(TextFormField);
  for (var i = 0; i < code.length; i++) {
    await tester.enterText(boxes.at(i), code[i]);
    await tester.pump();
  }
  await tester.pump();
  await tester.pump();
}

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
    when(() => repository.requestPasswordReset(email: any(named: 'email')))
        .thenAnswer((_) async => const Success(null));
    when(() => repository.verifyResetCode(
          email: any(named: 'email'),
          code: any(named: 'code'),
        )).thenAnswer((_) async => const Success('reset-token'));
    when(() => repository.resetPassword(
          resetToken: any(named: 'resetToken'),
          newPassword: any(named: 'newPassword'),
        )).thenAnswer((_) async => const Success(null));
  });

  group('ForgotPasswordPage', () {
    testWidgets('asks the backend for a code as soon as it opens', (tester) async {
      await pumpResetFlow(tester, repository);

      verify(() => repository.requestPasswordReset(email: _email)).called(1);
    });

    testWidgets('renders six code boxes, matching the backend', (tester) async {
      await pumpResetFlow(tester, repository);

      expect(find.byType(TextFormField), findsNWidgets(6));
      expect(
        find.textContaining('6-digit code', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('carries the reset token to the reset-password screen',
        (tester) async {
      final router = await pumpResetFlow(tester, repository);

      await enterCode(tester, '481920');

      verify(() => repository.verifyResetCode(email: _email, code: '481920'))
          .called(1);
      final location = router.routerDelegate.currentConfiguration.uri;
      expect(location.path, RouteNames.resetPasswordPath);
      expect(location.queryParameters['token'], 'reset-token');
    });

    testWidgets('shows the backend message and clears the boxes on a bad code',
        (tester) async {
      when(() => repository.verifyResetCode(
            email: any(named: 'email'),
            code: any(named: 'code'),
          )).thenAnswer(
        (_) async => const ResultError(ValidationFailure('Invalid or expired code')),
      );

      final router = await pumpResetFlow(tester, repository);

      await enterCode(tester, '000000');

      expect(find.text('Invalid or expired code'), findsOneWidget);
      // Still on the code screen, with the boxes emptied for another try.
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        RouteNames.forgotPasswordPath,
      );
      final firstBox = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(firstBox.controller?.text, isEmpty);
    });
  });

  group('ForgotPasswordPage email step', () {
    testWidgets('opens on the email step when login sent no address',
        (tester) async {
      await pumpResetFlow(
        tester,
        repository,
        initialLocation: RouteNames.forgotPasswordPath,
      );

      expect(find.text('Send Code'), findsOneWidget);
      // One field — the email input. The six code boxes come later.
      expect(find.byType(TextFormField), findsOneWidget);
      verifyNever(() => repository.requestPasswordReset(
            email: any(named: 'email'),
          ));
    });

    testWidgets('starts on the email step when login passed a malformed address',
        (tester) async {
      await pumpResetFlow(
        tester,
        repository,
        initialLocation: '${RouteNames.forgotPasswordPath}?email=not-an-email',
      );

      expect(find.text('Send Code'), findsOneWidget);
      verifyNever(() => repository.requestPasswordReset(
            email: any(named: 'email'),
          ));
      // Prefilled, so the user corrects rather than retypes.
      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller?.text, 'not-an-email');
    });

    testWidgets('refuses an invalid address without calling the backend',
        (tester) async {
      await pumpResetFlow(
        tester,
        repository,
        initialLocation: RouteNames.forgotPasswordPath,
      );

      await submitEmail(tester, 'not-an-email');

      expect(find.text('Enter a valid email address'), findsOneWidget);
      verifyNever(() => repository.requestPasswordReset(
            email: any(named: 'email'),
          ));
    });

    testWidgets('sends the code to the address typed on the email step',
        (tester) async {
      await pumpResetFlow(
        tester,
        repository,
        initialLocation: RouteNames.forgotPasswordPath,
      );

      await submitEmail(tester, _email);

      verify(() => repository.requestPasswordReset(email: _email)).called(1);
    });

    testWidgets('reveals the code boxes once the email step succeeds',
        (tester) async {
      await pumpResetFlow(
        tester,
        repository,
        initialLocation: RouteNames.forgotPasswordPath,
      );

      await submitEmail(tester, _email);

      expect(find.byType(TextFormField), findsNWidgets(6));
      expect(
        find.textContaining(_email, findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('verifies the code against the address typed on the email step',
        (tester) async {
      await pumpResetFlow(
        tester,
        repository,
        initialLocation: RouteNames.forgotPasswordPath,
      );
      await submitEmail(tester, _email);

      await enterCode(tester, '481920');

      verify(() => repository.verifyResetCode(email: _email, code: '481920'))
          .called(1);
    });

    testWidgets('lets the user go back to correct the address', (tester) async {
      await pumpResetFlow(tester, repository);

      // Below the fold on the test viewport, so scroll it in before tapping.
      await tester.ensureVisible(find.text('Wrong email?'));
      await tester.pump();
      await tester.tap(find.text('Wrong email?'));
      await tester.pump();

      expect(find.text('Send Code'), findsOneWidget);
      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller?.text, _email);
    });
  });

  group('ResetPasswordPage', () {
    testWidgets('sends the new password with the token it was given',
        (tester) async {
      await pumpResetFlow(
        tester,
        repository,
        initialLocation:
            '${RouteNames.resetPasswordPath}?token=reset-token&email=$_email',
      );

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'newsecret');
      await tester.enterText(fields.at(1), 'newsecret');
      await tester.tap(find.text('Update Password'));
      await tester.pump();
      await tester.pump();

      verify(() => repository.resetPassword(
            resetToken: 'reset-token',
            newPassword: 'newsecret',
          )).called(1);
    });

    testWidgets('returns the user to login once the password is set',
        (tester) async {
      final router = await pumpResetFlow(
        tester,
        repository,
        initialLocation:
            '${RouteNames.resetPasswordPath}?token=reset-token&email=$_email',
      );

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'newsecret');
      await tester.enterText(fields.at(1), 'newsecret');
      await tester.tap(find.text('Update Password'));
      await tester.pump();
      await tester.pump();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        RouteNames.loginPath,
      );
    });

    testWidgets('refuses a mismatched confirmation without calling the API',
        (tester) async {
      await pumpResetFlow(
        tester,
        repository,
        initialLocation:
            '${RouteNames.resetPasswordPath}?token=reset-token&email=$_email',
      );

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'newsecret');
      await tester.enterText(fields.at(1), 'different');
      await tester.tap(find.text('Update Password'));
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
      verifyNever(() => repository.resetPassword(
            resetToken: any(named: 'resetToken'),
            newPassword: any(named: 'newPassword'),
          ));
    });
  });
}
