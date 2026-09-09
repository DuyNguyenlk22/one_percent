import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/exceptions.dart';
import 'package:mobile/core/errors/failures.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/features/entries/data/models/habit_entry_model.dart';
import 'package:mobile/features/entries/data/repositories/entry_repository_impl.dart';
import 'package:mobile/features/entries/domain/usecases/set_entry.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockEntryRemoteDataSource remote;
  late MockNetworkInfo network;
  late EntryRepositoryImpl repository;

  const habitId = 'bbbbbbbb-0000-4000-8000-000000000001';
  final day = DateTime(2026, 3, 10);

  setUpAll(registerFallbacks);

  setUp(() {
    remote = MockEntryRemoteDataSource();
    network = MockNetworkInfo();
    when(() => network.isConnected).thenAnswer((_) async => true);
    repository = EntryRepositoryImpl(
      remoteDataSource: remote,
      networkInfo: network,
    );
  });

  group('HabitEntryModel', () {
    test('parses the row POST returns, reading the day key in UTC', () {
      final entry = HabitEntryModel.fromJson(const {
        'id': 'eeeeeeee-0000-4000-8000-000000000001',
        'habitId': habitId,
        'date': '2026-03-10T00:00:00.000Z',
        'createdAt': '2026-03-10T08:15:00.000Z',
      });

      expect(entry.date, DateTime(2026, 3, 10));
      expect(entry.habitId, habitId);
    });
  });

  group('getEntries', () {
    test('returns the bare date list the endpoint sends', () async {
      when(() => remote.getEntries(
                habitId: any(named: 'habitId'),
                from: any(named: 'from'),
                to: any(named: 'to'),
              ))
          .thenAnswer(
              (_) async => [DateTime(2026, 3, 9), DateTime(2026, 3, 10)]);

      final result = await repository.getEntries(
        habitId: habitId,
        from: DateTime(2026, 3, 1),
        to: day,
      );

      expect(result.dataOrNull, [DateTime(2026, 3, 9), DateTime(2026, 3, 10)]);
    });

    test('short-circuits when offline', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);

      final result = await repository.getEntries(
        habitId: habitId,
        from: DateTime(2026, 3, 1),
        to: day,
      );

      expect(result.failureOrNull, isA<NetworkFailure>());
      verifyNever(() => remote.getEntries(
            habitId: any(named: 'habitId'),
            from: any(named: 'from'),
            to: any(named: 'to'),
          ));
    });
  });

  group('exception translation', () {
    test('a 404 becomes NotFoundFailure', () async {
      when(() => remote.checkOff(
            habitId: any(named: 'habitId'),
            date: any(named: 'date'),
          )).thenThrow(const NotFoundException());

      final result = await repository.checkOff(habitId: habitId, date: day);

      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('a 401 becomes AuthFailure', () async {
      when(() => remote.deleteEntry(
            habitId: any(named: 'habitId'),
            date: any(named: 'date'),
          )).thenThrow(const UnauthorizedException());

      final result = await repository.deleteEntry(habitId: habitId, date: day);

      expect(result.failureOrNull, isA<AuthFailure>());
    });
  });

  group('SetEntry', () {
    late MockEntryRepository entryRepository;

    setUp(() {
      entryRepository = MockEntryRepository();
    });

    test('completed true checks the day off', () async {
      when(() => entryRepository.checkOff(
            habitId: any(named: 'habitId'),
            date: any(named: 'date'),
          )).thenAnswer((_) async => Success(buildHabitEntryModel()));

      await SetEntry(entryRepository)(
        habitId: habitId,
        date: day,
        completed: true,
      );

      verify(() => entryRepository.checkOff(habitId: habitId, date: day))
          .called(1);
      verifyNever(() => entryRepository.deleteEntry(
            habitId: any(named: 'habitId'),
            date: any(named: 'date'),
          ));
    });

    test('completed false un-checks the day', () async {
      when(() => entryRepository.deleteEntry(
            habitId: any(named: 'habitId'),
            date: any(named: 'date'),
          )).thenAnswer((_) async => const Success(null));

      await SetEntry(entryRepository)(
        habitId: habitId,
        date: day,
        completed: false,
      );

      verify(() => entryRepository.deleteEntry(habitId: habitId, date: day))
          .called(1);
    });

    test('un-checking a day that was never checked off is not an error',
        () async {
      when(() => entryRepository.deleteEntry(
            habitId: any(named: 'habitId'),
            date: any(named: 'date'),
          )).thenAnswer((_) async => const ResultError(NotFoundFailure()));

      final result = await SetEntry(entryRepository)(
        habitId: habitId,
        date: day,
        completed: false,
      );

      expect(result.isSuccess, isTrue);
    });
  });
}
