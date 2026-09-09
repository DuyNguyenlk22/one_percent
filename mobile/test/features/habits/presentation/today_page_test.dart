import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/failures.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/core/widgets/app_error.dart';
import 'package:mobile/features/habits/domain/entities/daily_habit.dart';
import 'package:mobile/features/habits/presentation/pages/today_page.dart';
import 'package:mobile/injection/dependency_injection.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';
import '../../../helpers/pump_app.dart';

void main() {
  late MockHabitRepository habits;
  late MockEntryRepository entries;

  setUpAll(registerFallbacks);

  setUp(() {
    habits = MockHabitRepository();
    entries = MockEntryRepository();
    when(() => entries.checkOff(
          habitId: any(named: 'habitId'),
          date: any(named: 'date'),
        )).thenAnswer((_) async => Success(buildHabitEntryModel()));
  });

  List<Override> overrides() => [
        ...signedOutOverrides(),
        habitRepositoryProvider.overrideWithValue(habits),
        entryRepositoryProvider.overrideWithValue(entries),
      ];

  testWidgets('renders the habits the API returned', (tester) async {
    when(() => habits.getHabitsForDate(any())).thenAnswer(
      (_) async => Success([
        buildDailyHabit(
          habit: buildHabitModel(id: 'habit-1', name: 'Read'),
          currentStreak: 3,
        ),
        buildDailyHabit(
          habit: buildHabitModel(id: 'habit-2', name: 'Stretch'),
          doneToday: true,
          currentStreak: 9,
        ),
      ]),
    );

    await pumpApp(tester, const TodayPage(), overrides: overrides());

    expect(find.text('Read'), findsOneWidget);
    // The second card sits below the fold in the test viewport, and a sliver
    // does not build what it cannot show.
    await tester.dragUntilVisible(
      find.text('Stretch'),
      find.byType(CustomScrollView),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    expect(find.text('Stretch'), findsOneWidget);
    // The old hardcoded demo habits are gone.
    expect(find.text('Drink enough water'), findsNothing);
    expect(find.text('Morning exercise'), findsNothing);
  });

  testWidgets('the ring counts completions and the badge shows the top streak',
      (tester) async {
    when(() => habits.getHabitsForDate(any())).thenAnswer(
      (_) async => Success([
        buildDailyHabit(habit: buildHabitModel(id: 'habit-1', name: 'Read')),
        buildDailyHabit(
          habit: buildHabitModel(id: 'habit-2', name: 'Stretch'),
          doneToday: true,
          currentStreak: 9,
        ),
      ]),
    );

    await pumpApp(tester, const TodayPage(), overrides: overrides());

    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    // The hardcoded 12-day streak is gone.
    expect(find.text('12'), findsNothing);
  });

  testWidgets('tapping a habit checks it off optimistically', (tester) async {
    when(() => habits.getHabitsForDate(any())).thenAnswer(
      (_) async => Success([
        buildDailyHabit(habit: buildHabitModel(id: 'habit-1', name: 'Read')),
      ]),
    );

    await pumpApp(tester, const TodayPage(), overrides: overrides());
    expect(find.text('0/1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('habit-toggle-habit-1')));
    await tester.pumpAndSettle();

    expect(find.text('1/1'), findsOneWidget);
    verify(() => entries.checkOff(habitId: 'habit-1', date: any(named: 'date')))
        .called(1);
  });

  testWidgets('a failed toggle reverts and shows a message', (tester) async {
    when(() => habits.getHabitsForDate(any())).thenAnswer(
      (_) async => Success([
        buildDailyHabit(habit: buildHabitModel(id: 'habit-1', name: 'Read')),
      ]),
    );
    when(() => entries.checkOff(
          habitId: any(named: 'habitId'),
          date: any(named: 'date'),
        )).thenAnswer((_) async => const ResultError(NetworkFailure()));

    await pumpApp(tester, const TodayPage(), overrides: overrides());
    await tester.tap(find.byKey(const ValueKey('habit-toggle-habit-1')));
    await tester.pumpAndSettle();

    expect(find.text('0/1'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no habits yet',
      (tester) async {
    when(() => habits.getHabitsForDate(any()))
        .thenAnswer((_) async => const Success(<DailyHabit>[]));

    await pumpApp(tester, const TodayPage(), overrides: overrides());

    expect(find.text('No habits yet'), findsOneWidget);
  });

  testWidgets('shows a retryable error when the load fails', (tester) async {
    when(() => habits.getHabitsForDate(any()))
        .thenAnswer((_) async => const ResultError(NetworkFailure()));

    await pumpApp(tester, const TodayPage(), overrides: overrides());

    expect(find.byType(AppError), findsOneWidget);
  });
}
