import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/failures.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/features/auth/domain/usecases/login.dart';
import 'package:mobile/features/auth/domain/usecases/register.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockAuthRepository repository;
  final user = buildUserModel();

  setUp(() {
    repository = MockAuthRepository();
    when(() => repository.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => Success(user));
    when(() => repository.register(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => Success(user));
  });

  group('Login', () {
    test('delegates to the repository with a trimmed email', () async {
      final result = await Login(repository)(
        email: '  alex.bloom@example.com  ',
        password: 'secret',
      );

      expect(result.dataOrNull, user);
      verify(() => repository.login(email: 'alex.bloom@example.com', password: 'secret'))
          .called(1);
    });

    test('rejects a malformed email without calling the repository', () async {
      final result = await Login(repository)(email: 'nope', password: 'secret');

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(result.failureOrNull?.message, 'Enter a valid email address');
      verifyNever(
        () => repository.login(email: any(named: 'email'), password: any(named: 'password')),
      );
    });

    test('rejects a short password without calling the repository', () async {
      final result = await Login(repository)(email: 'alex@example.com', password: 'no');

      expect(result.failureOrNull, isA<ValidationFailure>());
      verifyNever(
        () => repository.login(email: any(named: 'email'), password: any(named: 'password')),
      );
    });
  });

  group('Register', () {
    test('passes valid input through to the repository', () async {
      final result = await Register(repository)(
        email: 'alex@example.com',
        password: 'secret',
        confirmPassword: 'secret',
      );

      expect(result.dataOrNull, user);
      verify(() => repository.register(email: 'alex@example.com', password: 'secret'))
          .called(1);
    });

    test('rejects a confirmation that does not match', () async {
      final result = await Register(repository)(
        email: 'alex@example.com',
        password: 'secret',
        confirmPassword: 'different',
      );

      expect(result.failureOrNull?.message, 'Passwords do not match');
      verifyNever(
        () => repository.register(email: any(named: 'email'), password: any(named: 'password')),
      );
    });

    test('skips the confirmation check when none is supplied', () async {
      final result = await Register(repository)(
        email: 'alex@example.com',
        password: 'secret',
      );

      expect(result.dataOrNull, user);
    });
  });
}
