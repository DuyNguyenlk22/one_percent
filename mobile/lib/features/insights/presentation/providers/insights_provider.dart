import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../injection/dependency_injection.dart';
import '../../../habits/domain/entities/habit.dart';
import '../../domain/entities/insights_summary.dart';
import '../../domain/insights_calculator.dart';

/// How far back the Insights screen looks.
const int insightsWindowDays = 30;

/// The history summary behind Insights and the Profile stat row.
///
/// The API has no aggregate endpoint, so this fetches the habits once and then
/// each habit's entries in parallel. N+1 requests, which is acceptable at
/// personal-habit scale and cached here for the lifetime of the screen.
class InsightsNotifier extends AsyncNotifier<InsightsSummary> {
  @override
  Future<InsightsSummary> build() {
    // Any check-off changes the history, so recompute when the list mutates.
    // A plain counter, not `dailyHabitsProvider` itself: watching an AsyncValue
    // would rebuild on its loading/data transition too and run the whole N+1
    // fetch twice per load.
    ref.watch(habitsRevisionProvider);
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  Future<InsightsSummary> _load() async {
    final habitsResult = await ref.read(habitRepositoryProvider).getHabits();

    final List<Habit> habits = switch (habitsResult) {
      Success(:final data) => data,
      ResultError(:final failure) => throw failure,
    };

    if (habits.isEmpty) return InsightsSummary.empty;

    final to = AppDateUtils.today;
    final from = AppDateUtils.subtractDays(to, insightsWindowDays - 1);

    final getEntries = ref.read(getEntriesUseCaseProvider);
    final results = await Future.wait([
      for (final habit in habits)
        getEntries(habitId: habit.id, from: from, to: to),
    ]);

    final entriesByHabit = <String, List<DateTime>>{
      for (var index = 0; index < habits.length; index++)
        // One habit failing is not worth losing the whole screen over; it
        // simply reads as no completions.
        habits[index].id: results[index].dataOrNull ?? const <DateTime>[],
    };

    return InsightsCalculator.compute(
      habits: habits,
      entriesByHabit: entriesByHabit,
      from: from,
      to: to,
    );
  }
}

final insightsProvider =
    AsyncNotifierProvider<InsightsNotifier, InsightsSummary>(
  InsightsNotifier.new,
  // Same reasoning as dailyHabitsProvider: an explicit Retry beats a silent
  // background retry that hides the failure and keeps hitting the API.
  retry: (_, _) => null,
);
