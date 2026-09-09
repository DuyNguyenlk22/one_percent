import '../../../../core/errors/result.dart';
import '../entities/habit_entry.dart';

/// Check-offs for a habit, as the domain layer needs them.
///
/// Backed by `backend/src/entries/entries.controller.ts`.
///
/// Not yet implemented — see `data/repositories/`.
abstract interface class EntryRepository {
  /// `POST /habits/:id/entries` — marks [habitId] complete on [date].
  Future<Result<HabitEntry>> checkOff({required String habitId, required DateTime date});

  /// `GET /habits/:id/entries?from&to`, both bounds inclusive.
  Future<Result<List<HabitEntry>>> getEntries({
    required String habitId,
    required DateTime from,
    required DateTime to,
  });

  /// `DELETE /habits/:id/entries/:date` — undoes a check-off.
  Future<Result<void>> deleteEntry({required String habitId, required DateTime date});
}
