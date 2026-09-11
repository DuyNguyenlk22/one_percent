import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/exceptions.dart';
import 'package:mobile/core/errors/failures.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/features/auth/data/models/auth_response_model.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockAuthRemoteDataSource remote;
  late MockAuthLocalDataSource local;
  late MockNetworkInfo network;
  late AuthRepositoryImpl repository;

  final user = buildUserModel();
  final authResponse = AuthResponseModel(accessToken: 'jwt-token', user: user);

  setUpAll(registerFallbacks);

  setUp(() {
    remote = MockAuthRemoteDataSource();
    local = MockAuthLocalDataSource();
    network = MockNetworkInfo();
    repository = AuthRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: local,
      networkInfo: network,
    );
    when(() => network.isConnected).thenAnswer((_) async => true);
    when(() => local.cacheSession(accessToken: any(named: 'accessToken'), user: any(named: 'user')))
        .thenAnswer((_) async {});
    when(() => local.cacheUser(any())).thenAnswer((_) async {});
    when(local.clearSession).thenAnswer((_) async {});
  });

  tearDown(() => repository.dispose());

  group('login', () {
    test('returns the user and caches the session on success', () async {
      when(() => remote.login(email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async => authResponse);

      final result = await repository.login(email: user.email, password: 'secret');

      expect(result, isA<Success<dynamic>>());
      expect(result.dataOrNull, user);
      verify(() => local.cacheSession(accessToken: 'jwt-token', user: user)).called(1);
    });

    test('announces the new user on authStateChanges', () async {
      when(() => remote.login(email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async => authResponse);

      expectLater(repository.authStateChanges, emits(user));

      await repository.login(email: user.email, password: 'secret');
    });

    test('fails with NetworkFailure and never calls the API when offline', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);

      final result = await repository.login(email: user.email, password: 'secret');

      expect(result.failureOrNull, isA<NetworkFailure>());
      verifyNever(
        () => remote.login(email: any(named: 'email'), password: any(named: 'password')),
      );
    });

    test('maps a rejected credential to AuthFailure', () async {
      when(() => remote.login(email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(const UnauthorizedException('Invalid credentials'));

      final result = await repository.login(email: user.email, password: 'wrong');

      expect(result.failureOrNull, const AuthFailure('Invalid credentials'));
      verifyNever(
        () => local.cacheSession(accessToken: any(named: 'accessToken'), user: any(named: 'user')),
      );
    });

    test('maps a validation error, keeping the field messages', () async {
      when(() => remote.login(email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(const ValidationException(
        'Please provide a valid email',
        errors: ['Please provide a valid email'],
        statusCode: 400,
      ));

      final failure = (await repository.login(email: 'nope', password: 'secret')).failureOrNull;

      expect(failure, isA<ValidationFailure>());
      expect((failure! as ValidationFailure).errors, ['Please provide a valid email']);
    });

    test('maps a server error to ServerFailure with its status code', () async {
      when(() => remote.login(email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(const ServerException('Internal error', statusCode: 500));

      final failure = (await repository.login(email: user.email, password: 'secret')).failureOrNull;

      expect(failure, isA<ServerFailure>());
      expect((failure! as ServerFailure).statusCode, 500);
    });
  });

  group('register', () {
    test('caches the session on success', () async {
      when(() => remote.register(email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async => authResponse);

      final result = await repository.register(email: user.email, password: 'secret');

      expect(result.dataOrNull, user);
      verify(() => local.cacheSession(accessToken: 'jwt-token', user: user)).called(1);
    });
  });

  group('logout', () {
    test('clears the session and emits null', () async {
      expectLater(repository.authStateChanges, emits(null));

      final result = await repository.logout();

      expect(result.isSuccess, isTrue);
      verify(local.clearSession).called(1);
    });
  });

  group('requestPasswordReset', () {
    test('succeeds when the backend accepts the address', () async {
      when(() => remote.requestPasswordReset(email: any(named: 'email')))
          .thenAnswer((_) async {});

      final result = await repository.requestPasswordReset(email: user.email);

      expect(result.isSuccess, isTrue);
      verify(() => remote.requestPasswordReset(email: user.email)).called(1);
    });

    test('fails with NetworkFailure and never calls the API when offline', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);

      final result = await repository.requestPasswordReset(email: user.email);

      expect(result.failureOrNull, isA<NetworkFailure>());
      verifyNever(() => remote.requestPasswordReset(email: any(named: 'email')));
    });

    test('surfaces the throttle message the backend sends', () async {
      when(() => remote.requestPasswordReset(email: any(named: 'email'))).thenThrow(
        const ServerException(
          'Too many requests. Please try again in a minute.',
          statusCode: 429,
        ),
      );

      final failure = (await repository.requestPasswordReset(email: user.email)).failureOrNull;

      expect(failure, isA<ServerFailure>());
      expect(failure?.message, 'Too many requests. Please try again in a minute.');
    });
  });

  group('verifyResetCode', () {
    test('returns the reset token on success', () async {
      when(() => remote.verifyResetCode(
            email: any(named: 'email'),
            code: any(named: 'code'),
          )).thenAnswer((_) async => 'reset-token');

      final result = await repository.verifyResetCode(email: user.email, code: '481920');

      expect(result.dataOrNull, 'reset-token');
    });

    test('maps a rejected code to ValidationFailure, message intact', () async {
      when(() => remote.verifyResetCode(
            email: any(named: 'email'),
            code: any(named: 'code'),
          )).thenThrow(const ValidationException('Invalid or expired code', statusCode: 400));

      final failure =
          (await repository.verifyResetCode(email: user.email, code: '000000')).failureOrNull;

      expect(failure, isA<ValidationFailure>());
      expect(failure?.message, 'Invalid or expired code');
    });

    test('fails with NetworkFailure when offline', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);

      final result = await repository.verifyResetCode(email: user.email, code: '481920');

      expect(result.failureOrNull, isA<NetworkFailure>());
      verifyNever(
        () => remote.verifyResetCode(email: any(named: 'email'), code: any(named: 'code')),
      );
    });
  });

  group('resetPassword', () {
    test('succeeds without touching the cached session', () async {
      when(() => remote.resetPassword(
            resetToken: any(named: 'resetToken'),
            newPassword: any(named: 'newPassword'),
          )).thenAnswer((_) async {});

      final result = await repository.resetPassword(
        resetToken: 'reset-token',
        newPassword: 'newsecret',
      );

      expect(result.isSuccess, isTrue);
      // The backend deliberately issues no access token here — the user signs
      // in again — so nothing may be cached.
      verifyNever(
        () => local.cacheSession(accessToken: any(named: 'accessToken'), user: any(named: 'user')),
      );
    });

    test('maps a spent or forged token to AuthFailure', () async {
      when(() => remote.resetPassword(
            resetToken: any(named: 'resetToken'),
            newPassword: any(named: 'newPassword'),
          )).thenThrow(const UnauthorizedException('Invalid or expired reset token'));

      final failure = (await repository.resetPassword(
        resetToken: 'spent',
        newPassword: 'newsecret',
      ))
          .failureOrNull;

      expect(failure, const AuthFailure('Invalid or expired reset token'));
    });
  });

  group('getCurrentUser', () {
    test('refreshes the cached profile on success', () async {
      when(remote.getCurrentUser).thenAnswer((_) async => user);

      final result = await repository.getCurrentUser();

      expect(result.dataOrNull, user);
      verify(() => local.cacheUser(user)).called(1);
    });

    test('clears the session when the token is rejected', () async {
      when(remote.getCurrentUser).thenThrow(const UnauthorizedException());

      final result = await repository.getCurrentUser();

      expect(result.failureOrNull, isA<AuthFailure>());
      verify(local.clearSession).called(1);
    });

    test('falls back to the cached profile when offline', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);
      when(local.getCachedUser).thenAnswer((_) async => user);

      final result = await repository.getCurrentUser();

      expect(result.dataOrNull, user);
      verifyNever(remote.getCurrentUser);
    });

    test('fails when offline with nothing cached', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);
      when(local.getCachedUser).thenAnswer((_) async => null);

      final result = await repository.getCurrentUser();

      expect(result.failureOrNull, isA<NetworkFailure>());
    });
  });
}
