import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/daily_habit.dart';
import '../../domain/entities/habit.dart';
import '../../domain/repositories/habit_repository.dart';
import '../datasources/habit_remote_datasource.dart';

/// The only place where habit exceptions become failures.
class HabitRepositoryImpl implements HabitRepository {
  const HabitRepositoryImpl({
    required HabitRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
  })  : _remote = remoteDataSource,
        _networkInfo = networkInfo;

  final HabitRemoteDataSource _remote;
  final NetworkInfo _networkInfo;

  @override
  Future<Result<List<Habit>>> getHabits() => _guard(_remote.getHabits);

  @override
  Future<Result<List<DailyHabit>>> getHabitsForDate(DateTime date) =>
      _guard(() => _remote.getHabitsForDate(date));

  @override
  Future<Result<Habit>> createHabit({required String name, String? color}) =>
      _guard(() => _remote.createHabit(name: name, color: color));

  @override
  Future<Result<Habit>> updateHabit({
    required String habitId,
    String? name,
    String? color,
    bool? archived,
  }) {
    return _guard(() => _remote.updateHabit(
          habitId: habitId,
          name: name,
          color: color,
          archived: archived,
        ));
  }

  @override
  Future<Result<void>> deleteHabit(String habitId) =>
      _guard(() => _remote.deleteHabit(habitId));

  /// Checks connectivity, runs [call], and converts anything thrown into a
  /// [Failure]. Every method is this shape, so it lives in one place.
  Future<Result<T>> _guard<T>(Future<T> Function() call) async {
    if (!await _networkInfo.isConnected) {
      return const ResultError(NetworkFailure());
    }
    try {
      return Success(await call());
    } on AppException catch (exception) {
      return ResultError(_toFailure(exception));
    } on Object catch (error, stackTrace) {
      Logger.error('Habit request failed', error: error, stackTrace: stackTrace);
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
