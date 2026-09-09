import '../../domain/entities/daily_habit.dart';
import 'habit_model.dart';

/// Wire representation of [DailyHabit].
///
/// The backend returns the decoration flattened onto the habit row rather than
/// nested, so the habit is parsed from the same map.
class DailyHabitModel extends DailyHabit {
  const DailyHabitModel({
    required super.habit,
    required super.doneToday,
    required super.currentStreak,
  });

  /// Parses a row from `GET /habits?date=`.
  ///
  /// `doneToday` and `currentStreak` default rather than throw: the same
  /// endpoint without a `date` omits them, and a habit nobody has checked off
  /// is genuinely "not done, streak zero".
  factory DailyHabitModel.fromJson(Map<String, dynamic> json) {
    return DailyHabitModel(
      habit: HabitModel.fromJson(json),
      doneToday: json['doneToday'] as bool? ?? false,
      currentStreak: json['currentStreak'] as int? ?? 0,
    );
  }
}
