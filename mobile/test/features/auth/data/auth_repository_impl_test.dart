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
