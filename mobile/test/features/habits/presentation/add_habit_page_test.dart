import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/failures.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/features/habits/presentation/pages/add_habit_page.dart';
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
    when(() => habits.getHabitsForDate(any()))
        .thenAnswer((_) async => const Success([]));
    when(() => habits.createHabit(
          name: any(named: 'name'),
          color: any(named: 'color'),
        )).thenAnswer((_) async => Success(buildHabitModel()));
  });

  List<Override> overrides() => [
        ...signedOutOverrides(),
        habitRepositoryProvider.overrideWithValue(habits),
        entryRepositoryProvider.overrideWithValue(entries),
      ];

  testWidgets('drops the fields the schema cannot store', (tester) async {
    await pumpRoutedApp(tester, const AddHabitPage(), overrides: overrides());

    expect(find.text('DAILY GOAL'), findsNothing);
    expect(find.text('Every day'), findsNothing);
    expect(find.textContaining('Reminder'), findsNothing);
    // The colour picker replaces them.
    expect(find.text('COLOUR'), findsOneWidget);
  });

  testWidgets('creates the selected seed habit', (tester) async {
    await pumpRoutedApp(tester, const AddHabitPage(), overrides: overrides());

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    verify(() => habits.createHabit(
          name: 'Drink water',
          color: any(named: 'color'),
        )).called(1);
  });

  testWidgets('creates a custom habit from the text field', (tester) async {
    await pumpRoutedApp(tester, const AddHabitPage(), overrides: overrides());

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Walk the dog');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    verify(() => habits.createHabit(
          name: 'Walk the dog',
          color: any(named: 'color'),
        )).called(1);
  });

  testWidgets('a blank custom name never reaches the API', (tester) async {
    await pumpRoutedApp(tester, const AddHabitPage(), overrides: overrides());

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    verifyNever(() => habits.createHabit(
          name: any(named: 'name'),
          color: any(named: 'color'),
        ));
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('a chosen colour is sent with the habit', (tester) async {
    await pumpRoutedApp(tester, const AddHabitPage(), overrides: overrides());

    await tester.tap(find.byKey(const ValueKey('habit-color-#C77D52')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    verify(() => habits.createHabit(name: 'Drink water', color: '#C77D52'))
        .called(1);
  });

  testWidgets('a server failure keeps the form open with a message',
      (tester) async {
    when(() => habits.createHabit(
          name: any(named: 'name'),
          color: any(named: 'color'),
        )).thenAnswer((_) async => const ResultError(ServerFailure('boom')));

    await pumpRoutedApp(tester, const AddHabitPage(), overrides: overrides());
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('boom'), findsOneWidget);
    expect(find.byType(AddHabitPage), findsOneWidget);
  });
}
