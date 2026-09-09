import '../../../../core/errors/result.dart';
import '../entities/habit.dart';
import '../repositories/habit_repository.dart';
import 'habit_validators.dart';

/// Creates a habit for the signed-in user.
class CreateHabit {
  const CreateHabit(this._repository);

  final HabitRepository _repository;

  Future<Result<Habit>> call({required String name, String? color}) async {
    final nameFailure = HabitValidators.name(name);
    if (nameFailure != null) return ResultError(nameFailure);

    final colorFailure = HabitValidators.color(color);
    if (colorFailure != null) return ResultError(colorFailure);

    return _repository.createHabit(name: name.trim(), color: color);
  }
}
