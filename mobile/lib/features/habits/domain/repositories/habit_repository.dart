import '../../../../core/errors/result.dart';
import '../entities/daily_habit.dart';
import '../entities/habit.dart';

/// Habit CRUD, as the domain layer needs it.
///
/// Backed by `backend/src/habit/habit.controller.ts`.
abstract interface class HabitRepository {
  /// `GET /habits` — active habits, undecorated.
  Future<Result<List<Habit>>> getHabits();

  /// `GET /habits?date=` — active habits decorated with `doneToday` and
  /// `currentStreak` for [date]. A separate method because the response is a
  /// different shape, not a richer one.
  Future<Result<List<DailyHabit>>> getHabitsForDate(DateTime date);

  /// `POST /habits`.
  Future<Result<Habit>> createHabit({required String name, String? color});

  /// `PATCH /habits/:id`. Only the supplied fields are changed.
  Future<Result<Habit>> updateHabit({
    required String habitId,
    String? name,
    String? color,
    bool? archived,
  });

  /// `DELETE /habits/:id`.
  Future<Result<void>> deleteHabit(String habitId);
}
