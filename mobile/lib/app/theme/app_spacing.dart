import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Spacing, radii, and elevation tokens extracted from Google Stitch (docs/DESIGN.md).
abstract final class AppSpacing {
  // Spacing Metrics
  static const double containerMargin = 24.0; // Outer horizontal safe-area padding
  static const double stackGap = 16.0; // Vertical gap between habit cards
  static const double sectionGap = 40.0; // Gap between distinct habit categories
  static const double touchTarget = 56.0; // Minimum touch area for one-handed mobile use
  static const double cardPadding = 20.0;
  static const double cardPaddingLarge = 24.0;
  static const double buttonHeight = 56.0;

  // Corner Radii
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusCard = 24.0; // rounded-2xl for Habit Cards
  static const double radiusDock = 32.0; // rounded-3xl for Floating Navigation Bar
  static const double radiusPill = 9999.0; // rounded-full for Buttons & Inputs

  static const BorderRadius borderRadiusCard = BorderRadius.all(Radius.circular(radiusCard));
  static const BorderRadius borderRadiusDock = BorderRadius.all(Radius.circular(radiusDock));
  static const BorderRadius borderRadiusPill = BorderRadius.all(Radius.circular(radiusPill));

  // Ambient Soft-Tactile Shadows
  static const List<BoxShadow> ambientShadow = [
    BoxShadow(
      color: AppColors.ambientShadow, // Primary-tinted diffused shadow
      blurRadius: 30.0,
      offset: Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  // Glassmorphism Blur
  static const double glassBlur = 20.0;
}
