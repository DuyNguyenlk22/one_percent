import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/habit_entry.dart';

/// Wire representation of [HabitEntry], as `POST /habits/:id/entries` returns
/// it.
///
/// `GET /habits/:id/entries` sends bare dates instead, so those are parsed with
/// [AppDateUtils.fromApiDate] directly rather than through this model.
class HabitEntryModel extends HabitEntry {
  const HabitEntryModel({
    required super.id,
    required super.habitId,
    required super.date,
    required super.createdAt,
  });

  factory HabitEntryModel.fromJson(Map<String, dynamic> json) {
    return HabitEntryModel(
      id: json['id'] as String,
      habitId: json['habitId'] as String,
      // A day key, not an instant: read it in UTC.
      date: AppDateUtils.fromApiDate(json['date'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }
}
