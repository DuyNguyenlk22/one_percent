/// A single day on which a habit was completed.
///
/// Mirrors the Prisma `HabitEntry` model. The backend stores [date] as a
/// Postgres `DATE` and enforces `@@unique([habitId, date])`, so a habit has at
/// most one entry per day — checking off twice is idempotent, not additive.
class HabitEntry {
  const HabitEntry({
    required this.id,
    required this.habitId,
    required this.date,
    required this.createdAt,
  });

  /// UUID assigned by the backend.
  final String id;

  /// The habit this entry completes.
  final String habitId;

  /// The calendar day, with no time component.
  final DateTime date;

  /// When the entry was recorded.
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitEntry &&
          id == other.id &&
          habitId == other.habitId &&
          date == other.date &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, habitId, date, createdAt);

  @override
  String toString() => 'HabitEntry(habitId: $habitId, date: $date)';
}
