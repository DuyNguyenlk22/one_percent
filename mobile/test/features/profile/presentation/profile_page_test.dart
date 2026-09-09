import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/core/utils/date_utils.dart';
import 'package:mobile/features/habits/domain/entities/habit.dart';
import 'package:mobile/features/profile/presentation/pages/profile_page.dart';
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
    when(() => habits.getHabits()).thenAnswer(
      (_) async => Success<List<Habit>>([
        buildHabitModel(
            id: 'habit-1', name: 'Read', createdAt: DateTime(2026, 1, 1)),
        buildHabitModel(
            id: 'habit-2', name: 'Stretch', createdAt: DateTime(2026, 1, 1)),
      ]),
    );
    when(() => entries.getEntries(
          habitId: any(named: 'habitId'),
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer((_) async => Success([AppDateUtils.today]));
  });

  List<Override> overrides({List<Override> auth = const []}) => [
        ...(auth.isEmpty ? signedOutOverrides() : auth),
        habitRepositoryProvider.overrideWithValue(habits),
        entryRepositoryProvider.overrideWithValue(entries),
      ];

  testWidgets('shows the real habit count, not the hardcoded stats',
      (tester) async {
    await pumpApp(tester, const ProfilePage(), overrides: overrides());

    expect(find.text('2'), findsOneWidget);
    expect(find.text('14'), findsNothing);
    expect(find.text('88%'), findsNothing);
    expect(find.text('28'), findsNothing);
  });

  testWidgets('the stat row falls back to zeroes when nothing is tracked',
      (tester) async {
    when(() => habits.getHabits())
        .thenAnswer((_) async => const Success(<Habit>[]));

    await pumpApp(tester, const ProfilePage(), overrides: overrides());

    expect(find.text('0'), findsWidgets);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('shows when the account was created, not a fixed date',
      (tester) async {
    await pumpApp(
      tester,
      const ProfilePage(),
      overrides: overrides(
        auth: signedInOverrides(
          buildUserModel(createdAt: DateTime.utc(2026, 1, 15)),
        ),
      ),
    );

    expect(find.textContaining('Growing since January 2026'), findsOneWidget);
    expect(find.textContaining('Oct 2022'), findsNothing);
  });

  testWidgets('a signed-out profile shows a neutral tagline', (tester) async {
    await pumpApp(tester, const ProfilePage(), overrides: overrides());

    expect(find.text('Welcome to Bloom'), findsOneWidget);
  });
}
