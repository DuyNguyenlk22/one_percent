import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/date_utils.dart';
import 'package:mobile/features/insights/domain/insights_calculator.dart';

import '../../../helpers/mocks.dart';

void main() {
  final from = DateTime(2026, 3, 4);
  final to = DateTime(2026, 3, 10);

  final read = buildHabitModel(
    id: 'habit-1',
    name: 'Read',
    createdAt: DateTime(2026, 1, 1),
  );
  final stretch = buildHabitModel(
    id: 'habit-2',
    name: 'Stretch',
    createdAt: DateTime(2026, 1, 1),
  );

  test('no habits reads as empty rather than dividing by zero', () {
    final summary = InsightsCalculator.compute(
      habits: const [],
      entriesByHabit: const {},
      from: from,
      to: to,
    );

    expect(summary.consistency, 0.0);
    expect(summary.currentStreak, 0);
    expect(summary.bestStreak, 0);
    expect(summary.habitCount, 0);
    expect(summary.dailyCompletion, hasLength(7));
    expect(summary.dailyCompletion.every((value) => value == 0.0), isTrue);
  });

  test('a perfect week is 100% consistent with a full streak', () {
    final everyDay = [
      for (var day = 0; day < 7; day++) AppDateUtils.addDays(from, day),
    ];

    final summary = InsightsCalculator.compute(
      habits: [read],
      entriesByHabit: {'habit-1': everyDay},
      from: from,
      to: to,
    );

    expect(summary.consistency, 1.0);
    expect(summary.currentStreak, 7);
    expect(summary.bestStreak, 7);
    expect(summary.dailyCompletion, everyElement(1.0));
  });

  test('a gap ends the current streak but not the best one', () {
    final summary = InsightsCalculator.compute(
      habits: [read],
      entriesByHabit: {
        'habit-1': [
          DateTime(2026, 3, 4),
          DateTime(2026, 3, 5),
          DateTime(2026, 3, 6),
          DateTime(2026, 3, 7),
          // 8 March missed
          DateTime(2026, 3, 9),
        ],
      },
      from: from,
      to: to,
    );

    expect(summary.currentStreak, 0, reason: '10 March is not completed');
    expect(summary.bestStreak, 4);
  });

  test('a streak running up to the last day is the current streak', () {
    final summary = InsightsCalculator.compute(
      habits: [read],
      entriesByHabit: {
        'habit-1': [DateTime(2026, 3, 9), DateTime(2026, 3, 10)],
      },
      from: from,
      to: to,
    );

    expect(summary.currentStreak, 2);
    expect(summary.bestStreak, 2);
  });

  test('two habits average into the daily completion rate', () {
    final summary = InsightsCalculator.compute(
      habits: [read, stretch],
      entriesByHabit: {
        'habit-1': [DateTime(2026, 3, 10)],
        'habit-2': const [],
      },
      from: from,
      to: to,
    );

    expect(summary.dailyCompletion.last, 0.5);
    expect(summary.habitCount, 2);
  });

  test('a habit is not counted on days before it existed', () {
    final newHabit = buildHabitModel(
      id: 'habit-3',
      name: 'Walk',
      createdAt: DateTime(2026, 3, 10),
    );

    final summary = InsightsCalculator.compute(
      habits: [read, newHabit],
      entriesByHabit: {
        'habit-1': [
          for (var day = 0; day < 7; day++) AppDateUtils.addDays(from, day),
        ],
        'habit-3': [DateTime(2026, 3, 10)],
      },
      from: from,
      to: to,
    );

    // Every day is 100%: Read was due and done throughout, and Walk was only
    // due on the 10th, when it was done.
    expect(summary.dailyCompletion, everyElement(1.0));
    expect(summary.consistency, 1.0);
  });

  test('per-habit consistency is measured over the days each was due', () {
    final newHabit = buildHabitModel(
      id: 'habit-3',
      name: 'Walk',
      createdAt: DateTime(2026, 3, 9),
    );

    final summary = InsightsCalculator.compute(
      habits: [read, newHabit],
      entriesByHabit: {
        'habit-1': [DateTime(2026, 3, 10)],
        'habit-3': [DateTime(2026, 3, 9)],
      },
      from: from,
      to: to,
    );

    final byName = {
      for (final item in summary.habitConsistency) item.habit.name: item.rate,
    };

    expect(byName['Read'], closeTo(1 / 7, 0.001));
    // Walk existed for the 9th and 10th and was done on one of them.
    expect(byName['Walk'], closeTo(0.5, 0.001));
  });

  test('habit consistency is sorted strongest first', () {
    final summary = InsightsCalculator.compute(
      habits: [read, stretch],
      entriesByHabit: {
        'habit-1': const [],
        'habit-2': [
          for (var day = 0; day < 7; day++) AppDateUtils.addDays(from, day),
        ],
      },
      from: from,
      to: to,
    );

    expect(summary.habitConsistency.first.habit.name, 'Stretch');
    expect(summary.habitConsistency.last.habit.name, 'Read');
  });

  test('entries outside the window are ignored', () {
    final summary = InsightsCalculator.compute(
      habits: [read],
      entriesByHabit: {
        'habit-1': [DateTime(2026, 2, 1), DateTime(2026, 12, 25)],
      },
      from: from,
      to: to,
    );

    expect(summary.consistency, 0.0);
    expect(summary.bestStreak, 0);
  });
}
