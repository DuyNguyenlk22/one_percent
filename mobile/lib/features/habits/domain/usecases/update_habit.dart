import '../../../../core/errors/result.dart';
import '../entities/habit.dart';
import '../repositories/habit_repository.dart';
import 'habit_validators.dart';

/// Renames, recolours or archives a habit. Omitted fields are left alone.
class UpdateHabit {
  const UpdateHabit(this._repository);

  final HabitRepository _repository;

  Future<Result<Habit>> call({
    required String habitId,
    String? name,
    String? color,
    bool? archived,
  }) async {
    // Only validate what was actually supplied: archiving does not carry a
    // name, and validating a null one would reject it.
    if (name != null) {
      final nameFailure = HabitValidators.name(name);
      if (nameFailure != null) return ResultError(nameFailure);
    }

    final colorFailure = HabitValidators.color(color);
    if (colorFailure != null) return ResultError(colorFailure);

    return _repository.updateHabit(
      habitId: habitId,
      name: name?.trim(),
      color: color,
      archived: archived,
    );
  }
}
