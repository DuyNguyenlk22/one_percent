import '../../../../core/errors/result.dart';
import '../repositories/entry_repository.dart';

/// Loads the days a habit was completed within an inclusive window.
class GetEntries {
  const GetEntries(this._repository);

  final EntryRepository _repository;

  Future<Result<List<DateTime>>> call({
    required String habitId,
    required DateTime from,
    required DateTime to,
  }) {
    return _repository.getEntries(habitId: habitId, from: from, to: to);
  }
}
