import 'dart:async';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_response_model.dart';

/// The only place where auth exceptions become failures.
///
/// It also owns the ordering the domain layer must not know about: check
/// connectivity, call the API, persist the session, then announce the change
/// on [authStateChanges].
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
    required NetworkInfo networkInfo,
  })  : _remote = remoteDataSource,
        _local = localDataSource,
        _networkInfo = networkInfo;

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final NetworkInfo _networkInfo;

  final StreamController<User?> _authStateController = StreamController<User?>.broadcast();

  @override
  Stream<User?> get authStateChanges => _authStateController.stream;

  @override
  Future<Result<User>> login({required String email, required String password}) {
    return _authenticate(() => _remote.login(email: email, password: password));
  }

  @override
  Future<Result<User>> register({required String email, required String password}) {
    return _authenticate(() => _remote.register(email: email, password: password));
  }

  /// Shared body of [login] and [register]: both return an `AuthResponse` and
  /// both must persist the session before reporting success.
  Future<Result<User>> _authenticate(Future<AuthResponseModel> Function() call) async {
    if (!await _networkInfo.isConnected) {
      return const ResultError(NetworkFailure());
    }
    try {
      final response = await call();
      await _local.cacheSession(
        accessToken: response.accessToken,
        user: response.user,
      );
      _authStateController.add(response.user);
      return Success(response.user);
    } on AppException catch (exception) {
      return ResultError(_toFailure(exception));
    } on Object catch (error, stackTrace) {
      Logger.error('Authentication failed', error: error, stackTrace: stackTrace);
      return const ResultError(UnexpectedFailure());
    }
  }

  @override
  Future<Result<void>> logout() async {
    try {
      await _local.clearSession();
      _authStateController.add(null);
      return const Success(null);
    } on AppException catch (exception) {
      return ResultError(_toFailure(exception));
    }
  }

  @override
  Future<Result<User>> getCurrentUser() async {
    // Offline with a cached profile is a usable state, not an error.
    if (!await _networkInfo.isConnected) {
      final cached = await _local.getCachedUser();
      return cached != null ? Success(cached) : const ResultError(NetworkFailure());
    }

    try {
      final user = await _remote.getCurrentUser();
      await _local.cacheUser(user);
      _authStateController.add(user);
      return Success(user);
    } on UnauthorizedException catch (exception) {
      // The token was rejected: drop it so the router sends the user to login.
      await _local.clearSession();
      _authStateController.add(null);
      return ResultError(AuthFailure(exception.message));
    } on AppException catch (exception) {
      return ResultError(_toFailure(exception));
    } on Object catch (error, stackTrace) {
      Logger.error('Could not load the current user', error: error, stackTrace: stackTrace);
      return const ResultError(UnexpectedFailure());
    }
  }

  @override
  Future<bool> hasSession() => _local.hasSession();

  /// Releases the broadcast controller. Called by the DI layer on dispose.
  void dispose() => _authStateController.close();

  Failure _toFailure(AppException exception) => switch (exception) {
        NetworkException() => NetworkFailure(exception.message),
        UnauthorizedException() => AuthFailure(exception.message),
        ValidationException(:final errors) =>
          ValidationFailure(exception.message, errors: errors),
        NotFoundException() => NotFoundFailure(exception.message),
        CacheException() => CacheFailure(exception.message),
        ServerException(:final statusCode) =>
          ServerFailure(exception.message, statusCode: statusCode),
      };
}
