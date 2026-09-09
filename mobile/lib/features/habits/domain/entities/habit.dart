/// A habit the user is tracking.
///
/// Mirrors the Prisma `Habit` model in `backend/prisma/schema.prisma`. Archived
/// habits are soft-deleted: the backend sets [archivedAt] rather than removing
/// the row, so history survives.
class Habit {
  const Habit({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
    this.color,
    this.archivedAt,
  });

  /// UUID assigned by the backend.
  final String id;

  /// Owner's UUID.
  final String userId;

  final String name;

  /// Hex colour chosen for the habit card, e.g. `#4D6054`. Optional.
  final String? color;

  final DateTime createdAt;

  /// When the habit was archived, `null` while it is active.
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  Habit copyWith({String? name, String? color, DateTime? archivedAt}) {
    return Habit(
      id: id,
      userId: userId,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Habit &&
          id == other.id &&
          userId == other.userId &&
          name == other.name &&
          color == other.color &&
          createdAt == other.createdAt &&
          archivedAt == other.archivedAt;

  @override
  int get hashCode => Object.hash(id, userId, name, color, createdAt, archivedAt);

  @override
  String toString() => 'Habit(id: $id, name: $name)';
}
