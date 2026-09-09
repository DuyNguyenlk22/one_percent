import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/date_utils.dart';
import '../models/daily_habit_model.dart';
import '../models/habit_model.dart';

/// Habit CRUD against the NestJS backend.
///
/// Throws [AppException] on failure — mapping to a `Failure` is the
/// repository's job.
abstract interface class HabitRemoteDataSource {
  /// `GET /habits` — active habits, undecorated.
  Future<List<HabitModel>> getHabits();

  /// `GET /habits?date=yyyy-MM-dd` — each row plus `doneToday` and
  /// `currentStreak` for that day.
  Future<List<DailyHabitModel>> getHabitsForDate(DateTime date);

  /// `POST /habits`
  Future<HabitModel> createHabit({required String name, String? color});

  /// `PATCH /habits/:id` — only non-null fields are sent.
  Future<HabitModel> updateHabit({
    required String habitId,
    String? name,
    String? color,
    bool? archived,
  });

  /// `DELETE /habits/:id`
  Future<void> deleteHabit(String habitId);
}

class HabitRemoteDataSourceImpl implements HabitRemoteDataSource {
  const HabitRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<HabitModel>> getHabits() async {
    final json = await _client.get<List<dynamic>>(ApiConstants.habits);
    return json
        .map((row) => HabitModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<DailyHabitModel>> getHabitsForDate(DateTime date) async {
    final json = await _client.get<List<dynamic>>(
      ApiConstants.habits,
      queryParameters: {'date': AppDateUtils.toApiDate(date)},
    );
    return json
        .map((row) => DailyHabitModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<HabitModel> createHabit({required String name, String? color}) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiConstants.habits,
      data: {'name': name, 'color': ?color},
    );
    return HabitModel.fromJson(json);
  }

  @override
  Future<HabitModel> updateHabit({
    required String habitId,
    String? name,
    String? color,
    bool? archived,
  }) async {
    // Omitting a field is how the caller says "leave it alone"; sending null
    // would clear the colour and, before the backend fix, un-archive the row.
    final json = await _client.patch<Map<String, dynamic>>(
      ApiConstants.habit(habitId),
      data: {'name': ?name, 'color': ?color, 'archived': ?archived},
    );
    return HabitModel.fromJson(json);
  }

  @override
  Future<void> deleteHabit(String habitId) async {
    await _client.delete<Map<String, dynamic>>(ApiConstants.habit(habitId));
  }
}
