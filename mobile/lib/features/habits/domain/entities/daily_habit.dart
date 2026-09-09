import 'habit.dart';

/// A habit as `GET /habits?date=` returns it: the row plus the two fields the
/// backend computes for that day.
///
/// Kept separate from [Habit] because it is a different shape, not a richer
/// one — the undecorated `GET /habits` never carries these, and [Habit] stays a
/// faithful mirror of the database row.
class DailyHabit {
  const DailyHabit({
    required this.habit,
    required this.doneToday,
    required this.currentStreak,
  });

  final Habit habit;

  /// Whether the habit was checked off on the requested day.
  final bool doneToday;

  /// Consecutive days ending at the requested day, computed by the backend's
  /// `computeCurrentStreak`. Never stored.
  final int currentStreak;

  String get id => habit.id;
  String get name => habit.name;
  String? get color => habit.color;

  DailyHabit copyWith({bool? doneToday, int? currentStreak}) {
    return DailyHabit(
      habit: habit,
      doneToday: doneToday ?? this.doneToday,
      currentStreak: currentStreak ?? this.currentStreak,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyHabit &&
          habit == other.habit &&
          doneToday == other.doneToday &&
          currentStreak == other.currentStreak;

  @override
  int get hashCode => Object.hash(habit, doneToday, currentStreak);

  @override
  String toString() =>
      'DailyHabit(${habit.name}, done: $doneToday, streak: $currentStreak)';
}
