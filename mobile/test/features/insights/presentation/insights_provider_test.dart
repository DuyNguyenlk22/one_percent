import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/failures.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/core/utils/date_utils.dart';
import 'package:mobile/features/habits/domain/entities/habit.dart';
import 'package:mobile/features/insights/presentation/providers/insights_provider.dart';
import 'package:mobile/injection/dependency_injection.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockHabitRepository habits;
  late MockEntryRepository entries;

  setUpAll(registerFallbacks);

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        habitRepositoryProvider.overrideWithValue(habits),
        entryRepositoryProvider.overrideWithValue(entries),
      ],
    );
    addTearDown(container.dispose);
    container.listen(insightsProvider, (_, _) {});
    return container;
  }

  setUp(() {
    habits = MockHabitRepository();
    entries = MockEntryRepository();

    when(() => habits.getHabits()).thenAnswer(
      (_) async => Success<List<Habit>>([
        buildHabitModel(
            id: 'habit-1', name: 'Read', createdAt: DateTime(2026, 1, 1)),
        buildHabitModel(
            id: 'habit-2', name: 'Stretch', createdAt: DateTime(2026, 1, 1)),
      ]),
    );
    when(() => habits.getHabitsForDate(any()))
        .thenAnswer((_) async => const Success([]));
    when(() => entries.getEntries(
          habitId: any(named: 'habitId'),
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer((_) async => Success([AppDateUtils.today]));
  });

  test("fetches every habit's entries and summarises them", () async {
    final container = buildContainer();

    final summary = await container.read(insightsProvider.future);

    expect(summary.habitCount, 2);
    expect(summary.currentStreak, 1);
    verify(() => entries.getEntries(
          habitId: 'habit-1',
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).called(1);
    verify(() => entries.getEntries(
          habitId: 'habit-2',
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).called(1);
  });

  test('requests exactly the configured window', () async {
    final container = buildContainer();
    await container.read(insightsProvider.future);

    final captured = verify(() => entries.getEntries(
          habitId: 'habit-1',
          from: captureAny(named: 'from'),
          to: captureAny(named: 'to'),
        )).captured;

    expect(
      AppDateUtils.daysBetween(captured[0] as DateTime, captured[1] as DateTime),
      insightsWindowDays - 1,
    );
  });

  test('no habits yields the empty summary without fetching entries', () async {
    when(() => habits.getHabits())
        .thenAnswer((_) async => const Success(<Habit>[]));
    final container = buildContainer();

    final summary = await container.read(insightsProvider.future);

    expect(summary.habitCount, 0);
    verifyNever(() => entries.getEntries(
          habitId: any(named: 'habitId'),
          from: any(named: 'from'),
          to: any(named: 'to'),
        ));
  });

  test('a failed habit load surfaces as an AsyncError', () async {
    when(() => habits.getHabits())
        .thenAnswer((_) async => const ResultError(NetworkFailure()));
    final container = buildContainer();

    await expectLater(
      container.read(insightsProvider.future),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('one habit failing to load entries does not sink the whole summary',
      () async {
    when(() => entries.getEntries(
          habitId: 'habit-2',
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer((_) async => const ResultError(ServerFailure('boom')));
    final container = buildContainer();

    final summary = await container.read(insightsProvider.future);

    expect(summary.habitCount, 2);
    final stretch = summary.habitConsistency
        .firstWhere((item) => item.habit.name == 'Stretch');
    expect(stretch.rate, 0.0);
  });
}
