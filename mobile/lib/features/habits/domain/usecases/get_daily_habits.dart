import '../../../../core/errors/result.dart';
import '../../../../core/utils/date_utils.dart';
import '../entities/daily_habit.dart';
import '../repositories/habit_repository.dart';

/// Loads the habits for one day, decorated with `doneToday` and
/// `currentStreak`.
class GetDailyHabits {
  const GetDailyHabits(this._repository);

  final HabitRepository _repository;

  /// [date] defaults to today, which is what every current caller wants.
  Future<Result<List<DailyHabit>>> call({DateTime? date}) {
    return _repository.getHabitsForDate(date ?? AppDateUtils.today);
  }
}
