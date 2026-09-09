import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Turns the backend's optional hex string into a [Color].
///
/// `Habit.color` is nullable and only loosely validated server-side, so an
/// unparseable value falls back to the theme rather than throwing in a build.
abstract final class HabitColors {
  /// The colours Add Habit and My Habits offer. All six-digit hex, which is
  /// what the backend's `@IsHexColor()` accepts.
  static const List<String> palette = [
    '#4D6054',
    '#8A9A5B',
    '#B5C4A1',
    '#C77D52',
    '#7D8CA3',
    '#A8756B',
  ];

  static Color parse(String? hex) {
    if (hex == null) return AppColors.primary;

    final digits = hex.replaceFirst('#', '');
    final normalised = switch (digits.length) {
      3 => digits.split('').map((char) => '$char$char').join(),
      6 => digits,
      _ => null,
    };
    if (normalised == null) return AppColors.primary;

    final value = int.tryParse(normalised, radix: 16);
    return value == null ? AppColors.primary : Color(0xFF000000 | value);
  }
}
