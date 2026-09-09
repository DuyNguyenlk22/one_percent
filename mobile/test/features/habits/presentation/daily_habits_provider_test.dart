import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/failures.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/features/habits/domain/entities/daily_habit.dart';
import 'package:mobile/features/habits/presentation/providers/daily_habits_provider.dart';
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
    // Riverpod 3 providers auto-dispose when nothing listens, and a provider
    // disposed mid-load never emits its error. A widget supplies this
    // subscription in the app; a test has to supply its own.
    container.listen(dailyHabitsProvider, (_, _) {});
    return container;
  }

  setUp(() {
    habits = MockHabitRepository();
    entries = MockEntryRepository();

    when(() => habits.getHabitsForDate(any())).thenAnswer(
      (_) async => Success([
        buildDailyHabit(
          habit: buildHabitModel(id: 'habit-1', name: 'Read'),
          doneToday: false,
          currentStreak: 2,
        ),
        buildDailyHabit(
          habit: buildHabitModel(id: 'habit-2', name: 'Stretch'),
          doneToday: true,
          currentStreak: 7,
        ),
      ]),
    );
  });

  test('loads the day on build', () async {
    final container = buildContainer();

    final list = await container.read(dailyHabitsProvider.future);

    expect(list, hasLength(2));
    expect(list.first.name, 'Read');
  });

  test('a load failure surfaces as an AsyncError', () async {
    when(() => habits.getHabitsForDate(any()))
        .thenAnswer((_) async => const ResultError(ServerFailure('boom')));
    final container = buildContainer();

    await expectLater(
      container.read(dailyHabitsProvider.future),
      throwsA(isA<ServerFailure>()),
    );
  });

  group('toggle', () {
    test('flips the habit and bumps the streak', () async {
      when(() => entries.checkOff(
            habitId: any(named: 'habitId'),
            date: any(named: 'date'),
          )).thenAnswer((_) async => Success(buildHabitEntryModel()));
      final container = buildContainer();
      await container.read(dailyHabitsProvider.future);

      final failure =
          await container.read(dailyHabitsProvider.notifier).toggle('habit-1');

      expect(failure, isNull);
      final updated = container.read(dailyHabitsProvider).requireValue;
      expect(updated.first.doneToday, isTrue);
      expect(updated.first.currentStreak, 3);
    });

    test('un-checking decrements the streak', () async {
      when(() => entries.deleteEntry(
            habitId: any(named: 'habitId'),
            date: any(named: 'date'),
          )).thenAnswer((_) async => const Success(null));
      final container = buildContainer();
      await container.read(dailyHabitsProvider.future);

      await container.read(dailyHabitsProvider.notifier).toggle('habit-2');

      final updated = container.read(dailyHabitsProvider).requireValue;
      expect(updated[1].doneToday, isFalse);
      expect(updated[1].currentStreak, 6);
    });

    test('rolls back and reports the failure when the request fails', () async {
      when(() => entries.checkOff(
            habitId: any(named: 'habitId'),
            date: any(named: 'date'),
          )).thenAnswer((_) async => const ResultError(ServerFailure('nope')));
      final container = buildContainer();
      await container.read(dailyHabitsProvider.future);

      final failure =
          await container.read(dailyHabitsProvider.notifier).toggle('habit-1');

      expect(failure, isA<ServerFailure>());
      final restored = container.read(dailyHabitsProvider).requireValue;
      expect(restored.first.doneToday, isFalse);
      expect(restored.first.currentStreak, 2);
    });
  });

  group('mutations', () {
    test('create reloads the list', () async {
      when(() => habits.createHabit(
            name: any(named: 'name'),
            color: any(named: 'color'),
          )).thenAnswer((_) async => Success(buildHabitModel()));
      final container = buildContainer();
      await container.read(dailyHabitsProvider.future);

      final failure = await container
          .read(dailyHabitsProvider.notifier)
          .create(name: 'Walk', color: '#4D6054');

      expect(failure, isNull);
      verify(() => habits.getHabitsForDate(any())).called(2);
    });

    test('create reports a validation failure and does not reload', () async {
      final container = buildContainer();
      await container.read(dailyHabitsProvider.future);

      final failure =
          await container.read(dailyHabitsProvider.notifier).create(name: '  ');

      expect(failure, isA<ValidationFailure>());
      verify(() => habits.getHabitsForDate(any())).called(1);
    });

    test('remove drops the habit from the list immediately', () async {
      when(() => habits.deleteHabit(any()))
          .thenAnswer((_) async => const Success(null));
      final container = buildContainer();
      await container.read(dailyHabitsProvider.future);

      await container.read(dailyHabitsProvider.notifier).remove('habit-1');

      final remaining = container.read(dailyHabitsProvider).requireValue;
      expect(remaining.map((habit) => habit.id), ['habit-2']);
    });

    test('archive drops the habit from the active list', () async {
      when(() => habits.updateHabit(
            habitId: any(named: 'habitId'),
            name: any(named: 'name'),
            color: any(named: 'color'),
            archived: any(named: 'archived'),
          )).thenAnswer((_) async => Success(buildHabitModel()));
      final container = buildContainer();
      await container.read(dailyHabitsProvider.future);

      await container.read(dailyHabitsProvider.notifier).archive('habit-2');

      final remaining = container.read(dailyHabitsProvider).requireValue;
      expect(remaining.map((habit) => habit.id), ['habit-1']);
    });

    test('a failed remove puts the habit back', () async {
      when(() => habits.deleteHabit(any()))
          .thenAnswer((_) async => const ResultError(NetworkFailure()));
      final container = buildContainer();
      await container.read(dailyHabitsProvider.future);

      final failure =
          await container.read(dailyHabitsProvider.notifier).remove('habit-1');

      expect(failure, isA<NetworkFailure>());
      expect(container.read(dailyHabitsProvider).requireValue, hasLength(2));
    });
  });

  group('derived counts', () {
    test('counts completions and the top streak', () async {
      final container = buildContainer();
      await container.read(dailyHabitsProvider.future);

      expect(container.read(todayCompletedCountProvider), 1);
      expect(container.read(topStreakProvider), 7);
    });

    test('an empty list reads as zero, not an error', () async {
      when(() => habits.getHabitsForDate(any()))
          .thenAnswer((_) async => const Success(<DailyHabit>[]));
      final container = buildContainer();
      await container.read(dailyHabitsProvider.future);

      expect(container.read(todayCompletedCountProvider), 0);
      expect(container.read(topStreakProvider), 0);
    });
  });
}
