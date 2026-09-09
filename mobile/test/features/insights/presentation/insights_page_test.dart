import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/failures.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/core/utils/date_utils.dart';
import 'package:mobile/core/widgets/app_error.dart';
import 'package:mobile/features/habits/domain/entities/habit.dart';
import 'package:mobile/features/insights/presentation/pages/insights_page.dart';
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
  });

  List<Override> overrides() => [
        ...signedOutOverrides(),
        habitRepositoryProvider.overrideWithValue(habits),
        entryRepositoryProvider.overrideWithValue(entries),
      ];

  testWidgets('shows the computed streaks, not the hardcoded ones',
      (tester) async {
    when(() => habits.getHabits()).thenAnswer(
      (_) async => Success<List<Habit>>([
        buildHabitModel(
            id: 'habit-1', name: 'Read', createdAt: DateTime(2026, 1, 1)),
      ]),
    );
    when(() => entries.getEntries(
          habitId: any(named: 'habitId'),
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer((_) async => Success([
          AppDateUtils.today,
          AppDateUtils.today.subtract(const Duration(days: 1)),
          AppDateUtils.today.subtract(const Duration(days: 2)),
        ]));

    await pumpApp(tester, const InsightsPage(), overrides: overrides());

    expect(find.text('3'), findsWidgets);
    expect(find.text('12'), findsNothing);
    expect(find.text('28'), findsNothing);
  });

  testWidgets('names the real habits in Focus Areas', (tester) async {
    when(() => habits.getHabits()).thenAnswer(
      (_) async => Success<List<Habit>>([
        buildHabitModel(
            id: 'habit-1', name: 'Read', createdAt: DateTime(2026, 1, 1)),
        buildHabitModel(
            id: 'habit-2', name: 'Stretch', createdAt: DateTime(2026, 1, 1)),
      ]),
    );
    when(() => entries.getEntries(
          habitId: 'habit-1',
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer((_) async => Success([AppDateUtils.today]));
    when(() => entries.getEntries(
          habitId: 'habit-2',
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer((_) async => const Success(<DateTime>[]));

    await pumpApp(tester, const InsightsPage(), overrides: overrides());
    await tester.scrollUntilVisible(find.text('Read'), -100);
    await tester.pumpAndSettle();

    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Meditation'), findsNothing);
    expect(find.text('Early Sleep'), findsNothing);
  });

  testWidgets('shows an empty state before anything is tracked',
      (tester) async {
    when(() => habits.getHabits())
        .thenAnswer((_) async => const Success(<Habit>[]));

    await pumpApp(tester, const InsightsPage(), overrides: overrides());

    expect(find.textContaining('Nothing to chart yet'), findsOneWidget);
  });

  testWidgets('offers a retry when the load fails', (tester) async {
    when(() => habits.getHabits())
        .thenAnswer((_) async => const ResultError(NetworkFailure()));

    await pumpApp(tester, const InsightsPage(), overrides: overrides());

    expect(find.byType(AppError), findsOneWidget);
  });
}
