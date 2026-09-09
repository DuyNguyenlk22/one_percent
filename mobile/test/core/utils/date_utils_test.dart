import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/date_utils.dart';

void main() {
  group('AppDateUtils', () {
    test('dateOnly strips the time component', () {
      final stripped = AppDateUtils.dateOnly(DateTime(2026, 9, 9, 13, 45, 30));
      expect(stripped, DateTime(2026, 9, 9));
    });

    test('toApiDate zero-pads month and day', () {
      expect(AppDateUtils.toApiDate(DateTime(2026, 9, 9)), '2026-09-09');
      expect(AppDateUtils.toApiDate(DateTime(2026, 12, 25)), '2026-12-25');
    });

    test('fromApiDate reads the UTC calendar day in every timezone', () {
      expect(AppDateUtils.fromApiDate('2026-09-09'), DateTime(2026, 9, 9));
      // Entries are stored at UTC midnight. Converting to local time first
      // would move this to the 8th anywhere west of Greenwich.
      expect(
        AppDateUtils.fromApiDate('2026-09-09T00:00:00.000Z'),
        DateTime(2026, 9, 9),
      );
      // Any instant on the 9th UTC still reads as the 9th.
      expect(
        AppDateUtils.fromApiDate('2026-09-09T23:59:59.000Z'),
        DateTime(2026, 9, 9),
      );
    });

    test('addDays and daysBetween survive a DST transition', () {
      // Chile springs forward on the first Sunday of September. Adding 24-hour
      // Durations across it lands on 23:00 the day before.
      final before = DateTime(2026, 9, 1);
      final after = AppDateUtils.addDays(before, 30);

      expect(after, DateTime(2026, 10, 1));
      expect(AppDateUtils.daysBetween(before, after), 30);
      expect(AppDateUtils.subtractDays(after, 30), before);
    });

    test('isSameDay ignores the time of day', () {
      expect(
        AppDateUtils.isSameDay(DateTime(2026, 9, 9, 1), DateTime(2026, 9, 9, 23)),
        isTrue,
      );
      expect(AppDateUtils.isSameDay(DateTime(2026, 9, 9), DateTime(2026, 9, 10)), isFalse);
    });

    test('daysBetween counts whole calendar days', () {
      expect(AppDateUtils.daysBetween(DateTime(2026, 9, 1), DateTime(2026, 9, 9)), 8);
      expect(AppDateUtils.daysBetween(DateTime(2026, 9, 9), DateTime(2026, 9, 9, 23)), 0);
    });

    test('startOfWeek returns the Monday of that week', () {
      // 2026-09-09 is a Wednesday.
      expect(AppDateUtils.startOfWeek(DateTime(2026, 9, 9)), DateTime(2026, 9, 7));
      expect(AppDateUtils.startOfWeek(DateTime(2026, 9, 7)), DateTime(2026, 9, 7));
    });

    test('weekOf returns seven consecutive days, Monday first', () {
      final week = AppDateUtils.weekOf(DateTime(2026, 9, 9));
      expect(week, hasLength(7));
      expect(week.first, DateTime(2026, 9, 7));
      expect(week.last, DateTime(2026, 9, 13));
    });

    test('friendlyLabel names today and yesterday', () {
      expect(AppDateUtils.friendlyLabel(DateTime.now()), 'Today');
      expect(
        AppDateUtils.friendlyLabel(DateTime.now().subtract(const Duration(days: 1))),
        'Yesterday',
      );
    });

    test('friendlyLabel spells out any other day', () {
      expect(AppDateUtils.friendlyLabel(DateTime(2026, 3, 11)), 'Wed, 11 March');
    });
  });
}
