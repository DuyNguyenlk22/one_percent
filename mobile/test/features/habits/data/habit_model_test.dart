import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/habits/data/models/daily_habit_model.dart';
import 'package:mobile/features/habits/data/models/habit_model.dart';

void main() {
  const habitJson = {
    'id': 'bbbbbbbb-0000-4000-8000-000000000001',
    'userId': 'aaaaaaaa-0000-4000-8000-000000000001',
    'name': 'Read',
    'color': '#4D6054',
    'createdAt': '2026-01-01T09:30:00.000Z',
    'archivedAt': null,
  };

  group('HabitModel', () {
    test('parses the row the API returns', () {
      final habit = HabitModel.fromJson(habitJson);

      expect(habit.id, 'bbbbbbbb-0000-4000-8000-000000000001');
      expect(habit.name, 'Read');
      expect(habit.color, '#4D6054');
      expect(habit.archivedAt, isNull);
      expect(habit.isArchived, isFalse);
    });

    test('treats a missing colour as null rather than throwing', () {
      final habit = HabitModel.fromJson({...habitJson}..remove('color'));

      expect(habit.color, isNull);
    });

    test('parses an archived habit', () {
      final habit = HabitModel.fromJson({
        ...habitJson,
        'archivedAt': '2026-02-01T00:00:00.000Z',
      });

      expect(habit.isArchived, isTrue);
    });

    test('round-trips through toJson', () {
      final habit = HabitModel.fromJson(habitJson);
      final restored = HabitModel.fromJson(habit.toJson());

      expect(restored, habit);
    });
  });

  group('DailyHabitModel', () {
    test('lifts doneToday and currentStreak off the decorated row', () {
      final daily = DailyHabitModel.fromJson({
        ...habitJson,
        'doneToday': true,
        'currentStreak': 5,
      });

      expect(daily.doneToday, isTrue);
      expect(daily.currentStreak, 5);
      expect(daily.name, 'Read');
      expect(daily.id, habitJson['id']);
      expect(daily.color, '#4D6054');
    });

    test('defaults the decoration when the API omits it', () {
      final daily = DailyHabitModel.fromJson(habitJson);

      expect(daily.doneToday, isFalse);
      expect(daily.currentStreak, 0);
    });

    test('copyWith replaces only what it is given', () {
      final daily = DailyHabitModel.fromJson({
        ...habitJson,
        'doneToday': false,
        'currentStreak': 2,
      });

      final toggled = daily.copyWith(doneToday: true, currentStreak: 3);

      expect(toggled.doneToday, isTrue);
      expect(toggled.currentStreak, 3);
      expect(toggled.habit, daily.habit);
    });
  });
}
