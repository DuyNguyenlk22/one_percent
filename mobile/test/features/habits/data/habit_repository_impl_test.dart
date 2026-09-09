import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/exceptions.dart';
import 'package:mobile/core/errors/failures.dart';
import 'package:mobile/features/habits/data/models/daily_habit_model.dart';
import 'package:mobile/features/habits/data/repositories/habit_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockHabitRemoteDataSource remote;
  late MockNetworkInfo network;
  late HabitRepositoryImpl repository;

  final habit = buildHabitModel();

  setUpAll(registerFallbacks);

  setUp(() {
    remote = MockHabitRemoteDataSource();
    network = MockNetworkInfo();
    when(() => network.isConnected).thenAnswer((_) async => true);
    repository = HabitRepositoryImpl(
      remoteDataSource: remote,
      networkInfo: network,
    );
  });

  group('getHabitsForDate', () {
    test('returns the decorated list on success', () async {
      final daily = DailyHabitModel(
        habit: habit,
        doneToday: true,
        currentStreak: 4,
      );
      when(() => remote.getHabitsForDate(any()))
          .thenAnswer((_) async => [daily]);

      final result = await repository.getHabitsForDate(DateTime(2026, 3, 10));

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull!.single.currentStreak, 4);
    });

    test('short-circuits when offline without touching the network', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);

      final result = await repository.getHabitsForDate(DateTime(2026, 3, 10));

      expect(result.failureOrNull, isA<NetworkFailure>());
      verifyNever(() => remote.getHabitsForDate(any()));
    });
  });

  group('exception translation', () {
    test('maps every AppException onto its Failure', () async {
      final cases = <AppException, Type>{
        const NetworkException(): NetworkFailure,
        const UnauthorizedException(): AuthFailure,
        const ValidationException('bad', errors: ['name should not be empty']):
            ValidationFailure,
        const NotFoundException(): NotFoundFailure,
        const ServerException('boom', statusCode: 500): ServerFailure,
      };

      for (final entry in cases.entries) {
        when(() => remote.getHabits()).thenThrow(entry.key);

        final result = await repository.getHabits();

        expect(
          result.failureOrNull.runtimeType,
          entry.value,
          reason: '${entry.key.runtimeType} should become ${entry.value}',
        );
      }
    });

    test('keeps the field messages from a validation failure', () async {
      when(() => remote.createHabit(
            name: any(named: 'name'),
            color: any(named: 'color'),
          )).thenThrow(const ValidationException(
        'name should not be empty',
        errors: ['name should not be empty'],
      ));

      final result = await repository.createHabit(name: '');

      final failure = result.failureOrNull! as ValidationFailure;
      expect(failure.errors, ['name should not be empty']);
    });

    test('an unrecognised error becomes UnexpectedFailure', () async {
      when(() => remote.getHabits()).thenThrow(StateError('nope'));

      final result = await repository.getHabits();

      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });

  group('mutations', () {
    test('createHabit forwards the name and colour', () async {
      when(() => remote.createHabit(name: 'Read', color: '#4D6054'))
          .thenAnswer((_) async => habit);

      final result =
          await repository.createHabit(name: 'Read', color: '#4D6054');

      expect(result.dataOrNull, habit);
    });

    test('updateHabit forwards only the fields it is given', () async {
      when(() => remote.updateHabit(
            habitId: habit.id,
            name: 'Read daily',
            color: null,
            archived: null,
          )).thenAnswer((_) async => habit);

      final result = await repository.updateHabit(
        habitId: habit.id,
        name: 'Read daily',
      );

      expect(result.isSuccess, isTrue);
    });

    test('deleteHabit succeeds with no payload', () async {
      when(() => remote.deleteHabit(habit.id)).thenAnswer((_) async {});

      final result = await repository.deleteHabit(habit.id);

      expect(result.isSuccess, isTrue);
    });
  });
}
