import '../../../../core/errors/failures.dart';

/// Input rules shared by `CreateHabit` and `UpdateHabit`.
///
/// They mirror the backend DTOs — `@IsNotEmpty()` on the name and
/// `@IsHexColor()` on the colour — so an obviously bad value fails before it
/// costs a round trip. The backend still validates; this is not the guard.
abstract final class HabitValidators {
  static const int maxNameLength = 60;

  static final RegExp _hex = RegExp(r'^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$');

  /// Returns a failure when [name] is unusable, otherwise null.
  static ValidationFailure? name(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const ValidationFailure('Give your habit a name.');
    }
    if (trimmed.length > maxNameLength) {
      return const ValidationFailure(
        'Habit names are limited to 60 characters.',
      );
    }
    return null;
  }

  /// Returns a failure when [color] is present and not a hex colour.
  static ValidationFailure? color(String? color) {
    if (color == null) return null;
    if (!_hex.hasMatch(color)) {
      return const ValidationFailure('Pick a colour from the palette.');
    }
    return null;
  }
}
