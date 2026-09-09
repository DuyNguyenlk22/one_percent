import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../injection/dependency_injection.dart';
import '../../domain/entities/daily_habit.dart';

/// Today's habits, and every mutation the two habit screens perform.
///
/// Today and My Habits read this one provider because they are two
/// presentations of one list, not two datasets.
///
/// Mutations return a `Failure?` rather than pushing an `AsyncError`: an
/// optimistic toggle that failed must show a message *and* keep the list on
/// screen, which a global error state cannot do.
class DailyHabitsNotifier extends AsyncNotifier<List<DailyHabit>> {
  @override
  Future<List<DailyHabit>> build() => _load();

  Future<List<DailyHabit>> _load() async {
    final result = await ref.read(getDailyHabitsUseCaseProvider)();
    return switch (result) {
      Success(:final data) => data,
      // Throwing hands the failure to AsyncValue.error, which is what the
      // error-with-retry widget renders.
      ResultError(:final failure) => throw failure,
    };
  }

  /// Re-reads the day from the server.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  /// Flips [habitId]'s check-off for today.
  ///
  /// The list updates first and the request follows. A check-off that waits on
  /// a round trip feels broken, and the call is idempotent, so the worst case
  /// is the rollback below.
  Future<Failure?> toggle(String habitId) async {
    final current = state.value;
    if (current == null) return null;

    final habit = current.where((item) => item.id == habitId).firstOrNull;
    if (habit == null) return null;

    final completed = !habit.doneToday;
    state = AsyncValue.data(
      _replace(
        current,
        habitId,
        habit.copyWith(
          doneToday: completed,
          // The backend recomputes the real streak on the next read; this
          // keeps the number honest in the meantime.
          currentStreak: completed
              ? habit.currentStreak + 1
              : (habit.currentStreak - 1).clamp(0, 1 << 30),
        ),
      ),
    );

    final result = await ref.read(setEntryUseCaseProvider)(
      habitId: habitId,
      date: AppDateUtils.today,
      completed: completed,
    );

    if (result case ResultError(:final failure)) {
      state = AsyncValue.data(_replace(current, habitId, habit));
      return failure;
    }
    _markChanged();
    return null;
  }

  /// Creates a habit and reloads, so the new row arrives with its real id.
  Future<Failure?> create({required String name, String? color}) async {
    final result =
        await ref.read(createHabitUseCaseProvider)(name: name, color: color);
    if (result case ResultError(:final failure)) return failure;

    await refresh();
    _markChanged();
    return null;
  }

  Future<Failure?> rename(String habitId, String name) =>
      _patch(habitId, name: name);

  Future<Failure?> recolor(String habitId, String color) =>
      _patch(habitId, color: color);

  /// Archives the habit. It leaves the active list but its history survives.
  Future<Failure?> archive(String habitId) async {
    final current = state.value;
    if (current == null) return null;

    state = AsyncValue.data(_without(current, habitId));

    final result = await ref.read(updateHabitUseCaseProvider)(
      habitId: habitId,
      archived: true,
    );

    if (result case ResultError(:final failure)) {
      state = AsyncValue.data(current);
      return failure;
    }
    _markChanged();
    return null;
  }

  /// Deletes the habit and, by cascade, every entry it has.
  Future<Failure?> remove(String habitId) async {
    final current = state.value;
    if (current == null) return null;

    state = AsyncValue.data(_without(current, habitId));

    final result = await ref.read(deleteHabitUseCaseProvider)(habitId);

    if (result case ResultError(:final failure)) {
      state = AsyncValue.data(current);
      return failure;
    }
    _markChanged();
    return null;
  }

  /// Shared body of [rename] and [recolor]: patch, then reload so the list
  /// shows exactly what the server stored.
  Future<Failure?> _patch(String habitId, {String? name, String? color}) async {
    final result = await ref.read(updateHabitUseCaseProvider)(
      habitId: habitId,
      name: name,
      color: color,
    );
    if (result case ResultError(:final failure)) return failure;

    await refresh();
    _markChanged();
    return null;
  }

  /// Tells Insights its history is stale. Only called after a write actually
  /// landed, so a failed mutation does not trigger a needless refetch.
  void _markChanged() => ref.read(habitsRevisionProvider.notifier).bump();

  List<DailyHabit> _replace(
    List<DailyHabit> list,
    String habitId,
    DailyHabit replacement,
  ) {
    return [
      for (final item in list) item.id == habitId ? replacement : item,
    ];
  }

  List<DailyHabit> _without(List<DailyHabit> list, String habitId) =>
      [for (final item in list) if (item.id != habitId) item];
}

final dailyHabitsProvider =
    AsyncNotifierProvider<DailyHabitsNotifier, List<DailyHabit>>(
  DailyHabitsNotifier.new,
  // Riverpod 3 retries a failed build with backoff by default, leaving the
  // provider in AsyncLoading(retrying) rather than an error the UI can render.
  // These screens offer an explicit Retry, so a silent background retry would
  // both hide the failure and keep hitting the API while the device is offline.
  retry: (_, _) => null,
);

/// How many of today's habits are checked off. Zero while loading or on error.
final todayCompletedCountProvider = Provider<int>((ref) {
  final habits = ref.watch(dailyHabitsProvider).value ?? const [];
  return habits.where((habit) => habit.doneToday).length;
});

/// The longest streak currently running across all habits.
final topStreakProvider = Provider<int>((ref) {
  final habits = ref.watch(dailyHabitsProvider).value ?? const [];
  return habits.fold(
    0,
    (best, habit) => habit.currentStreak > best ? habit.currentStreak : best,
  );
});
