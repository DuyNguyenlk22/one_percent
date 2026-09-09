import '../../domain/entities/habit.dart';

/// Wire representation of [Habit].
///
/// Extends the entity so a model is usable anywhere a [Habit] is, while every
/// mention of JSON stays inside the data layer.
class HabitModel extends Habit {
  const HabitModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.createdAt,
    super.color,
    super.archivedAt,
  });

  /// Parses a row from `GET /habits`, `POST /habits` or `PATCH /habits/:id`.
  factory HabitModel.fromJson(Map<String, dynamic> json) {
    final archivedAt = json['archivedAt'] as String?;
    return HabitModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      color: json['color'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      archivedAt:
          archivedAt == null ? null : DateTime.parse(archivedAt).toLocal(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'name': name,
        'color': color,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'archivedAt': archivedAt?.toUtc().toIso8601String(),
      };
}
