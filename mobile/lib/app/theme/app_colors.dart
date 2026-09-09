import 'package:flutter/material.dart';

/// Semantic color tokens extracted from Google Stitch (docs/DESIGN.md).
/// Represents the "Bloom" natural minimalist palette.
abstract final class AppColors {
  // Base Surfaces
  static const Color surface = Color(0xFFFBF9F4); // Warm Cream Canvas
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF5F3EE); // Recessed inputs
  static const Color surfaceContainer = Color(0xFFF0EEE9); // Habit card surface
  static const Color surfaceContainerHigh = Color(0xFFEAE8E3); // Modal sheets
  static const Color surfaceContainerHighest = Color(0xFFE4E2DD);

  // Primary: Sage Green (Vitality, Completion, CTA)
  static const Color primary = Color(0xFF4D6054);
  static const Color primaryContainer = Color(0xFF66796C);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFF6FFF6);

  // Secondary: Dusty Rose (Highlights, Reflection)
  static const Color secondary = Color(0xFF7C5454);
  static const Color secondaryContainer = Color(0xFFFFCACA);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF7B5353);

  // Tertiary: Sky Slate (Focus Sessions, Metadata)
  static const Color tertiary = Color(0xFF4C5F69);
  static const Color tertiaryContainer = Color(0xFF647782);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFFFBFDFF);

  // Text & Ink
  static const Color onSurface = Color(0xFF1B1C19); // Deep Charcoal Ink
  static const Color onSurfaceVariant = Color(0xFF434844); // Secondary labels

  // Borders & Dividers
  static const Color outline = Color(0xFF737873);
  static const Color outlineVariant = Color(0xFFC3C8C2); // 1px subtle divider

  // Error & Status
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Glassmorphism & Ambient Shadows
  static const Color glassBackground = Color(0xD9FBF9F4); // rgba(251, 249, 244, 0.85)
  static const Color ambientShadow = Color(0x0A4D6054); // rgba(77, 96, 84, 0.04)

  /// Material 3 ColorScheme mapping based on Bloom tokens.
  static const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryContainer,
    tertiary: tertiary,
    onTertiary: onTertiary,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: onTertiaryContainer,
    error: error,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: onErrorContainer,
    surface: surface,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: outlineVariant,
    surfaceContainerLow: surfaceContainerLow,
    surfaceContainer: surfaceContainer,
    surfaceContainerHigh: surfaceContainerHigh,
    surfaceContainerHighest: surfaceContainerHighest,
  );
}
