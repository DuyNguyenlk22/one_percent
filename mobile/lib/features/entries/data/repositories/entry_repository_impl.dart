import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/habit_entry.dart';
import '../../domain/repositories/entry_repository.dart';
import '../datasources/entry_remote_datasource.dart';

/// The only place where entry exceptions become failures.
class EntryRepositoryImpl implements EntryRepository {
  const EntryRepositoryImpl({
    required EntryRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
  })  : _remote = remoteDataSource,
        _networkInfo = networkInfo;

  final EntryRemoteDataSource _remote;
  final NetworkInfo _networkInfo;

  @override
  Future<Result<HabitEntry>> checkOff({
    required String habitId,
    required DateTime date,
  }) {
    return _guard(() => _remote.checkOff(habitId: habitId, date: date));
  }

  @override
  Future<Result<List<DateTime>>> getEntries({
    required String habitId,
    required DateTime from,
    required DateTime to,
  }) {
    return _guard(
      () => _remote.getEntries(habitId: habitId, from: from, to: to),
    );
  }

  @override
  Future<Result<void>> deleteEntry({
    required String habitId,
    required DateTime date,
  }) {
    return _guard(() => _remote.deleteEntry(habitId: habitId, date: date));
  }

  Future<Result<T>> _guard<T>(Future<T> Function() call) async {
    if (!await _networkInfo.isConnected) {
      return const ResultError(NetworkFailure());
    }
    try {
      return Success(await call());
    } on AppException catch (exception) {
      return ResultError(_toFailure(exception));
    } on Object catch (error, stackTrace) {
      Logger.error('Entry request failed', error: error, stackTrace: stackTrace);
      return const ResultError(UnexpectedFailure());
    }
  }

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
