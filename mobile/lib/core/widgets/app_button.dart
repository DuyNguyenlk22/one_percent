import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Visual weight of an [AppButton].
enum AppButtonVariant {
  /// Filled sage-green pill. One per screen — the screen's main action.
  primary,

  /// Tonal surface pill for supporting actions.
  secondary,

  /// Outlined pill for low-emphasis actions.
  outlined,

  /// Text-only, for tertiary actions such as "Skip".
  text,
}

/// The app's standard button.
///
/// Sizes to [AppSpacing.buttonHeight] so every call to action lands on the
/// same touch target, and swaps its label for a spinner while [isLoading] is
/// true — taps are ignored in that state, which stops a double submit.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.isFullWidth = true,
  });

  /// Convenience constructor for [AppButtonVariant.secondary].
  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isFullWidth = true,
  }) : variant = AppButtonVariant.secondary;

  /// Convenience constructor for [AppButtonVariant.outlined].
  const AppButton.outlined({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isFullWidth = true,
  }) : variant = AppButtonVariant.outlined;

  /// Convenience constructor for [AppButtonVariant.text].
  const AppButton.text({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isFullWidth = false,
  }) : variant = AppButtonVariant.text;

  final String label;

  /// Tap handler. A `null` value renders the button disabled.
  final VoidCallback? onPressed;

  final AppButtonVariant variant;

  /// Replaces the label with a spinner and suppresses taps.
  final bool isLoading;

  /// Optional leading icon, hidden while loading.
  final IconData? icon;

  /// Whether the button stretches to fill its parent's width.
  final bool isFullWidth;

  bool get _isEnabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, border) = switch (variant) {
      AppButtonVariant.primary => (AppColors.primary, AppColors.onPrimary, null),
      AppButtonVariant.secondary => (
          AppColors.surfaceContainer,
          AppColors.onSurface,
          null,
        ),
      AppButtonVariant.outlined => (
          Colors.transparent,
          AppColors.primary,
          const BorderSide(color: AppColors.outlineVariant),
        ),
      AppButtonVariant.text => (Colors.transparent, AppColors.primary, null),
    };

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: AppSpacing.buttonHeight,
      child: FilledButton(
        onPressed: _isEnabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.4),
          disabledForegroundColor: foreground.withValues(alpha: 0.6),
          elevation: 0,
          side: border,
          shape: const RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusPill),
          textStyle: AppTypography.labelLarge,
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: foreground),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}
