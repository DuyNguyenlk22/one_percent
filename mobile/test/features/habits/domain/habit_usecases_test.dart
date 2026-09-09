import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/failures.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/core/utils/date_utils.dart';
import 'package:mobile/features/habits/domain/usecases/create_habit.dart';
import 'package:mobile/features/habits/domain/usecases/delete_habit.dart';
import 'package:mobile/features/habits/domain/usecases/get_daily_habits.dart';
import 'package:mobile/features/habits/domain/usecases/update_habit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockHabitRepository repository;

  setUpAll(registerFallbacks);

  setUp(() {
    repository = MockHabitRepository();
  });

  group('GetDailyHabits', () {
    test('defaults to today', () async {
      when(() => repository.getHabitsForDate(any()))
          .thenAnswer((_) async => const Success([]));

      await GetDailyHabits(repository)();

      final captured = verify(() => repository.getHabitsForDate(captureAny()))
          .captured
          .single as DateTime;
      expect(AppDateUtils.isToday(captured), isTrue);
    });

    test('passes an explicit date through', () async {
      when(() => repository.getHabitsForDate(any()))
          .thenAnswer((_) async => const Success([]));

      await GetDailyHabits(repository)(date: DateTime(2026, 3, 10));

      verify(() => repository.getHabitsForDate(DateTime(2026, 3, 10)))
          .called(1);
    });
  });

  group('CreateHabit', () {
    test('rejects a blank name without a round trip', () async {
      final result = await CreateHabit(repository)(name: '   ');

      expect(result.failureOrNull, isA<ValidationFailure>());
      verifyNever(() => repository.createHabit(
            name: any(named: 'name'),
            color: any(named: 'color'),
          ));
    });

    test('rejects a name longer than 60 characters', () async {
      final result = await CreateHabit(repository)(name: 'a' * 61);

      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('rejects a colour that is not hex', () async {
      final result =
          await CreateHabit(repository)(name: 'Read', color: 'forest green');

      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('trims the name before sending it', () async {
      when(() => repository.createHabit(
            name: any(named: 'name'),
            color: any(named: 'color'),
          )).thenAnswer((_) async => Success(buildHabitModel()));

      await CreateHabit(repository)(name: '  Read  ', color: '#4D6054');

      verify(() => repository.createHabit(name: 'Read', color: '#4D6054'))
          .called(1);
    });
  });

  group('UpdateHabit', () {
    test('rejects a blank rename', () async {
      final result =
          await UpdateHabit(repository)(habitId: 'habit-1', name: '  ');

      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('an archive with no name skips name validation', () async {
      when(() => repository.updateHabit(
            habitId: any(named: 'habitId'),
            name: any(named: 'name'),
            color: any(named: 'color'),
            archived: any(named: 'archived'),
          )).thenAnswer((_) async => Success(buildHabitModel()));

      final result =
          await UpdateHabit(repository)(habitId: 'habit-1', archived: true);

      expect(result.isSuccess, isTrue);
    });
  });

  group('DeleteHabit', () {
    test('forwards the id', () async {
      when(() => repository.deleteHabit('habit-1'))
          .thenAnswer((_) async => const Success(null));

      final result = await DeleteHabit(repository)('habit-1');

      expect(result.isSuccess, isTrue);
    });
  });
}
