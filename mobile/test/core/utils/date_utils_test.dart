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

    test('fromApiDate parses both a plain date and a timestamp', () {
      expect(AppDateUtils.fromApiDate('2026-09-09'), DateTime(2026, 9, 9));
      expect(
        AppDateUtils.fromApiDate('2026-09-09T00:00:00.000Z').day,
        isIn(const [8, 9, 10]), // the local day depends on the test machine's zone
      );
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
