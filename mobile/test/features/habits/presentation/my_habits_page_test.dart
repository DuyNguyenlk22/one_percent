import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/features/habits/domain/entities/daily_habit.dart';
import 'package:mobile/features/habits/presentation/pages/my_habits_page.dart';
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
    when(() => habits.getHabitsForDate(any())).thenAnswer(
      (_) async => Success([
        buildDailyHabit(
          habit: buildHabitModel(id: 'habit-1', name: 'Read'),
          currentStreak: 4,
        ),
      ]),
    );
  });

  List<Override> overrides() => [
        ...signedOutOverrides(),
        habitRepositoryProvider.overrideWithValue(habits),
        entryRepositoryProvider.overrideWithValue(entries),
      ];

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('habit-menu-habit-1')));
    await tester.pumpAndSettle();
  }

  testWidgets('lists the real habits, not the Stitch routines', (tester) async {
    await pumpApp(tester, const MyHabitsPage(), overrides: overrides());

    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Sunrise Ritual'), findsNothing);
    expect(find.text('Focus Block'), findsNothing);
  });

  testWidgets('renames a habit through the overflow menu', (tester) async {
    when(() => habits.updateHabit(
              habitId: any(named: 'habitId'),
              name: any(named: 'name'),
              color: any(named: 'color'),
              archived: any(named: 'archived'),
            ))
        .thenAnswer((_) async => Success(buildHabitModel(name: 'Read daily')));

    await pumpApp(tester, const MyHabitsPage(), overrides: overrides());
    await openMenu(tester);
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Read daily');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(() => habits.updateHabit(
          habitId: 'habit-1',
          name: 'Read daily',
          color: null,
          archived: null,
        )).called(1);
  });

  testWidgets('archiving does not ask for confirmation', (tester) async {
    when(() => habits.updateHabit(
          habitId: any(named: 'habitId'),
          name: any(named: 'name'),
          color: any(named: 'color'),
          archived: any(named: 'archived'),
        )).thenAnswer((_) async => Success(buildHabitModel()));

    await pumpApp(tester, const MyHabitsPage(), overrides: overrides());
    await openMenu(tester);
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    verify(() => habits.updateHabit(
          habitId: 'habit-1',
          name: null,
          color: null,
          archived: true,
        )).called(1);
  });

  testWidgets('deleting asks first and does nothing when cancelled',
      (tester) async {
    await pumpApp(tester, const MyHabitsPage(), overrides: overrides());
    await openMenu(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.textContaining('cannot be undone'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => habits.deleteHabit(any()));
  });

  testWidgets('confirming the dialog deletes the habit', (tester) async {
    when(() => habits.deleteHabit(any()))
        .thenAnswer((_) async => const Success(null));

    await pumpApp(tester, const MyHabitsPage(), overrides: overrides());
    await openMenu(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete habit'));
    await tester.pumpAndSettle();

    verify(() => habits.deleteHabit('habit-1')).called(1);
  });

  testWidgets('shows an empty state when nothing is tracked', (tester) async {
    when(() => habits.getHabitsForDate(any()))
        .thenAnswer((_) async => const Success(<DailyHabit>[]));

    await pumpApp(tester, const MyHabitsPage(), overrides: overrides());

    expect(find.textContaining('Nothing planted'), findsOneWidget);
  });
}
