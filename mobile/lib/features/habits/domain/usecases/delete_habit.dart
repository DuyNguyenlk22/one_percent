import '../../../../core/errors/result.dart';
import '../repositories/habit_repository.dart';

/// Permanently removes a habit and, by cascade, all of its entries.
class DeleteHabit {
  const DeleteHabit(this._repository);

  final HabitRepository _repository;

  Future<Result<void>> call(String habitId) => _repository.deleteHabit(habitId);
}
