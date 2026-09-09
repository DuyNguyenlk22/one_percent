/// Date helpers for habit tracking.
///
/// The backend stores `HabitEntry.date` as a Postgres `DATE`, so every date
/// that crosses the API boundary is a calendar day with no time component.
/// [toApiDate] and [dateOnly] keep the client honest about that.
abstract final class AppDateUtils {
  static const List<String> _weekdayNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// Today with its time component removed.
  static DateTime get today => dateOnly(DateTime.now());

  /// Strips the time component, keeping the local calendar day.
  static DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  /// Formats as `yyyy-MM-dd`, the shape the API expects.
  static String toApiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// Parses an API date into the local calendar day it denotes.
  ///
  /// The backend writes `HabitEntry.date` at UTC midnight, so a timestamp is
  /// read in UTC — converting to local time first would shift the day back for
  /// anyone west of Greenwich. A bare `yyyy-MM-dd` is already a day with no
  /// zone, so it is taken as-is.
  static DateTime fromApiDate(String value) {
    if (value.length == 10) return DateTime.parse(value);
    final utc = DateTime.parse(value).toUtc();
    return DateTime(utc.year, utc.month, utc.day);
  }

  /// [date] moved by [days] calendar days.
  ///
  /// Calendar arithmetic, not `Duration`: adding 24 hours across a daylight
  /// saving transition lands on 23:00 or 01:00 rather than midnight, which
  /// silently shifts the day and can make a window one day short or long.
  static DateTime addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  /// [date] moved back by [days] calendar days. See [addDays].
  static DateTime subtractDays(DateTime date, int days) => addDays(date, -days);

  /// Whether both instants fall on the same calendar day.
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Whether [date] is today.
  static bool isToday(DateTime date) => isSameDay(date, DateTime.now());

  /// Whether [date] is yesterday.
  static bool isYesterday(DateTime date) =>
      isSameDay(date, DateTime.now().subtract(const Duration(days: 1)));

  /// Whole calendar days between two days.
  ///
  /// Measured in UTC, which has no daylight saving: a local `difference` counts
  /// a spring-forward day as 23 hours and quietly loses it, so a 30-day window
  /// would come back 29 days long.
  static int daysBetween(DateTime from, DateTime to) {
    final start = dateOnly(from);
    final end = dateOnly(to);
    return DateTime.utc(end.year, end.month, end.day)
        .difference(DateTime.utc(start.year, start.month, start.day))
        .inDays;
  }

  /// The Monday of [date]'s week.
  static DateTime startOfWeek(DateTime date) =>
      subtractDays(dateOnly(date), date.weekday - DateTime.monday);

  /// The seven days of [date]'s week, Monday first.
  static List<DateTime> weekOf(DateTime date) {
    final start = startOfWeek(date);
    return List.generate(7, (index) => addDays(start, index));
  }

  /// Short weekday label, e.g. `Mon`.
  static String weekdayLabel(DateTime date) => _weekdayNames[date.weekday - 1];

  /// Full month name, e.g. `September`.
  static String monthLabel(DateTime date) => _monthNames[date.month - 1];

  /// Header-style label: `Today`, `Yesterday`, or `Mon, 9 September`.
  static String friendlyLabel(DateTime date) {
    if (isToday(date)) return 'Today';
    if (isYesterday(date)) return 'Yesterday';
    return '${weekdayLabel(date)}, ${date.day} ${monthLabel(date)}';
  }
}
