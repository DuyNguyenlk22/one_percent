import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/failures.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/features/auth/domain/usecases/request_password_reset.dart';
import 'package:mobile/features/auth/domain/usecases/reset_password.dart';
import 'package:mobile/features/auth/domain/usecases/verify_reset_code.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

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

  group('RequestPasswordReset', () {
    test('delegates to the repository with a trimmed email', () async {
      final result = await RequestPasswordReset(repository)(
        email: '  alex.bloom@example.com  ',
      );

      expect(result.isSuccess, isTrue);
      verify(() => repository.requestPasswordReset(email: 'alex.bloom@example.com'))
          .called(1);
    });

    test('rejects a malformed email without spending a round trip', () async {
      final result = await RequestPasswordReset(repository)(email: 'nope');

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(result.failureOrNull?.message, 'Enter a valid email address');
      verifyNever(() => repository.requestPasswordReset(email: any(named: 'email')));
    });
  });

  group('VerifyResetCode', () {
    test('returns the reset token the repository produced', () async {
      final result = await VerifyResetCode(repository)(
        email: 'alex.bloom@example.com',
        code: '481920',
      );

      expect(result.dataOrNull, 'reset-token');
      verify(() => repository.verifyResetCode(
            email: 'alex.bloom@example.com',
            code: '481920',
          )).called(1);
    });

    test('rejects a code that is not six digits', () async {
      final result = await VerifyResetCode(repository)(
        email: 'alex.bloom@example.com',
        code: '4819',
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      verifyNever(() => repository.verifyResetCode(
            email: any(named: 'email'),
            code: any(named: 'code'),
          ));
    });

    test('rejects a non-numeric code', () async {
      final result = await VerifyResetCode(repository)(
        email: 'alex.bloom@example.com',
        code: '48a920',
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      verifyNever(() => repository.verifyResetCode(
            email: any(named: 'email'),
            code: any(named: 'code'),
          ));
    });

    test('rejects a malformed email before sending the code', () async {
      final result = await VerifyResetCode(repository)(
        email: 'nope',
        code: '481920',
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      verifyNever(() => repository.verifyResetCode(
            email: any(named: 'email'),
            code: any(named: 'code'),
          ));
    });
  });

  group('ResetPassword', () {
    test('passes a valid new password through to the repository', () async {
      final result = await ResetPassword(repository)(
        resetToken: 'reset-token',
        newPassword: 'newsecret',
        confirmPassword: 'newsecret',
      );

      expect(result.isSuccess, isTrue);
      verify(() => repository.resetPassword(
            resetToken: 'reset-token',
            newPassword: 'newsecret',
          )).called(1);
    });

    test('rejects a confirmation that does not match', () async {
      final result = await ResetPassword(repository)(
        resetToken: 'reset-token',
        newPassword: 'newsecret',
        confirmPassword: 'different',
      );

      expect(result.failureOrNull?.message, 'Passwords do not match');
      verifyNever(() => repository.resetPassword(
            resetToken: any(named: 'resetToken'),
            newPassword: any(named: 'newPassword'),
          ));
    });

    test('rejects a password shorter than the backend allows', () async {
      final result = await ResetPassword(repository)(
        resetToken: 'reset-token',
        newPassword: 'no',
        confirmPassword: 'no',
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      verifyNever(() => repository.resetPassword(
            resetToken: any(named: 'resetToken'),
            newPassword: any(named: 'newPassword'),
          ));
    });

    test('rejects a missing reset token rather than calling the API', () async {
      final result = await ResetPassword(repository)(
        resetToken: '',
        newPassword: 'newsecret',
        confirmPassword: 'newsecret',
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      verifyNever(() => repository.resetPassword(
            resetToken: any(named: 'resetToken'),
            newPassword: any(named: 'newPassword'),
          ));
    });
  });
}
