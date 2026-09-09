import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/entries/domain/repositories/entry_repository.dart';
import 'package:mobile/features/habits/domain/repositories/habit_repository.dart';
import 'package:mobile/features/habits/domain/usecases/create_habit.dart';
import 'package:mobile/features/habits/domain/usecases/get_daily_habits.dart';
import 'package:mobile/injection/dependency_injection.dart';

void main() {
  test('the habit and entry graph resolves without a network call', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(habitRepositoryProvider), isA<HabitRepository>());
    expect(container.read(entryRepositoryProvider), isA<EntryRepository>());
    expect(container.read(getDailyHabitsUseCaseProvider), isA<GetDailyHabits>());
    expect(container.read(createHabitUseCaseProvider), isA<CreateHabit>());
  });

  test('sessionExpiredProvider starts at zero', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(sessionExpiredProvider), 0);
  });
}
