import '../../../core/utils/date_utils.dart';
import '../../habits/domain/entities/habit.dart';
import 'entities/insights_summary.dart';

/// Turns raw entry history into the numbers the Insights and Profile screens
/// show.
///
/// Deliberately pure — no Riverpod, no Dio, no `DateTime.now()`. Every rule
/// below is testable by calling one function with plain lists.
abstract final class InsightsCalculator {
  static InsightsSummary compute({
    required List<Habit> habits,
    required Map<String, List<DateTime>> entriesByHabit,
    required DateTime from,
    required DateTime to,
  }) {
    final days = _daysBetween(from, to);
    if (habits.isEmpty) {
      return InsightsSummary(
        currentStreak: 0,
        bestStreak: 0,
        consistency: 0,
        dailyCompletion: List<double>.filled(days.length, 0),
        habitConsistency: const [],
        habitCount: 0,
      );
    }

    // Day keys as a set, so an entry is a lookup rather than a list scan per
    // habit per day.
    final completedByHabit = <String, Set<DateTime>>{
      for (final habit in habits)
        habit.id: {
          for (final date in entriesByHabit[habit.id] ?? const <DateTime>[])
            AppDateUtils.dateOnly(date),
        },
    };

    final dailyCompletion = <double>[];
    final dueDayCounts = <String, int>{for (final habit in habits) habit.id: 0};
    final doneDayCounts = <String, int>{for (final habit in habits) habit.id: 0};
    // A day counts toward a streak only if everything due that day was done.
    final perfectDays = <bool>[];
    final scoredDays = <double>[];

    for (final day in days) {
      var due = 0;
      var done = 0;

      for (final habit in habits) {
        // A habit created yesterday must not be marked absent for last month.
        if (AppDateUtils.dateOnly(habit.createdAt).isAfter(day)) continue;

        due++;
        dueDayCounts[habit.id] = dueDayCounts[habit.id]! + 1;

        if (completedByHabit[habit.id]!.contains(day)) {
          done++;
          doneDayCounts[habit.id] = doneDayCounts[habit.id]! + 1;
        }
      }

      final rate = due == 0 ? 0.0 : done / due;
      dailyCompletion.add(rate);
      perfectDays.add(due > 0 && done == due);
      // Days when nothing existed yet are not evidence either way.
      if (due > 0) scoredDays.add(rate);
    }

    final habitConsistency = <HabitConsistency>[
      for (final habit in habits)
        HabitConsistency(
          habit: habit,
          rate: dueDayCounts[habit.id]! == 0
              ? 0
              : doneDayCounts[habit.id]! / dueDayCounts[habit.id]!,
        ),
    ]..sort((a, b) => b.rate.compareTo(a.rate));

    return InsightsSummary(
      currentStreak: _trailingRun(perfectDays),
      bestStreak: _longestRun(perfectDays),
      consistency: scoredDays.isEmpty
          ? 0
          : scoredDays.reduce((a, b) => a + b) / scoredDays.length,
      dailyCompletion: dailyCompletion,
      habitConsistency: habitConsistency,
      habitCount: habits.length,
    );
  }

  /// Every calendar day from [from] to [to] inclusive.
  ///
  /// Built by incrementing the day field rather than adding a `Duration`, which
  /// would drift by an hour across a DST boundary and could repeat or skip a
  /// day.
  static List<DateTime> _daysBetween(DateTime from, DateTime to) {
    final start = AppDateUtils.dateOnly(from);
    final count = AppDateUtils.daysBetween(from, to) + 1;
    return [
      for (var index = 0; index < count; index++)
        DateTime(start.year, start.month, start.day + index),
    ];
  }

  /// Length of the run of `true` ending at the last element.
  static int _trailingRun(List<bool> flags) {
    var run = 0;
    for (var index = flags.length - 1; index >= 0; index--) {
      if (!flags[index]) break;
      run++;
    }
    return run;
  }

  /// Length of the longest run of `true` anywhere.
  static int _longestRun(List<bool> flags) {
    var best = 0;
    var run = 0;
    for (final flag in flags) {
      run = flag ? run + 1 : 0;
      if (run > best) best = run;
    }
    return best;
  }
}
