import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../repositories/entry_repository.dart';

/// Puts a habit's day into the requested state.
///
/// [completed] is the state the caller *wants*, not the current one, which
/// keeps the check-off toggle a single call with no branching in the widget.
class SetEntry {
  const SetEntry(this._repository);

  final EntryRepository _repository;

  Future<Result<void>> call({
    required String habitId,
    required DateTime date,
    required bool completed,
  }) async {
    if (completed) {
      final result = await _repository.checkOff(habitId: habitId, date: date);
      return result.map((_) {});
    }

    final result = await _repository.deleteEntry(habitId: habitId, date: date);

    // Un-checking a day that was never checked off already has the outcome the
    // caller asked for. Surfacing a 404 here would make a double tap look like
    // a failure.
    if (result.failureOrNull is NotFoundFailure) return const Success(null);
    return result;
  }
}
