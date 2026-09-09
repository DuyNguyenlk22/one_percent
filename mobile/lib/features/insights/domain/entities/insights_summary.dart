import '../../../habits/domain/entities/habit.dart';

/// How reliably one habit was kept over the window.
class HabitConsistency {
  const HabitConsistency({required this.habit, required this.rate});

  final Habit habit;

  /// Completed days divided by the days the habit existed, 0.0–1.0.
  final double rate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitConsistency && habit == other.habit && rate == other.rate;

  @override
  int get hashCode => Object.hash(habit, rate);
}

/// Everything the Insights screen and the Profile stat row display.
///
/// Computed on the client from entry history, because the API has no aggregate
/// endpoint.
class InsightsSummary {
  const InsightsSummary({
    required this.currentStreak,
    required this.bestStreak,
    required this.consistency,
    required this.dailyCompletion,
    required this.habitConsistency,
    required this.habitCount,
  });

  /// Nothing tracked yet — what the screens render before the first habit.
  static const InsightsSummary empty = InsightsSummary(
    currentStreak: 0,
    bestStreak: 0,
    consistency: 0,
    dailyCompletion: [],
    habitConsistency: [],
    habitCount: 0,
  );

  /// The longest run of consecutive completed days ending at the window's last
  /// day, across all habits.
  final int currentStreak;

  /// The longest run anywhere in the window, across all habits.
  final int bestStreak;

  /// Mean daily completion over the days something was due, 0.0–1.0.
  final double consistency;

  /// Completion rate per day, oldest first, one entry per day in the window.
  final List<double> dailyCompletion;

  /// Per-habit rates, strongest first.
  final List<HabitConsistency> habitConsistency;

  final int habitCount;

  /// [consistency] as a whole percentage, for display.
  int get consistencyPercent => (consistency * 100).round();
}
