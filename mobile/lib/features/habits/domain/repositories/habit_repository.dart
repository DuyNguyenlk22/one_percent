import '../../../../core/errors/result.dart';
import '../entities/habit.dart';

/// Habit CRUD, as the domain layer needs it.
///
/// Declared ahead of its implementation so the contract is settled and the
/// presentation layer can be built against it. Backed by
/// `backend/src/habit/habit.controller.ts`.
///
/// Not yet implemented — see `data/repositories/`.
abstract interface class HabitRepository {
  /// `GET /habits`, optionally filtered to habits active on [date].
  Future<Result<List<Habit>>> getHabits({DateTime? date});

  /// `POST /habits`.
  Future<Result<Habit>> createHabit({required String name, String? color});

  /// `PATCH /habits/:id`. Only the supplied fields are changed.
  Future<Result<Habit>> updateHabit({
    required String habitId,
    String? name,
    String? color,
    bool? archived,
  });

  /// `DELETE /habits/:id`.
  Future<Result<void>> deleteHabit(String habitId);
}
