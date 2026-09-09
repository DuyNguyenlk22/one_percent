import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Centred progress indicator for a whole page or a section of one.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.message, this.size = 32});

  /// Optional caption shown beneath the spinner.
  final String? message;

  /// Diameter of the spinner.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(
              strokeWidth: 2.6,
              color: AppColors.primary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.stackGap),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dimmed full-screen overlay, for blocking interaction during a submit.
class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface.withValues(alpha: 0.72),
      child: AppLoading(message: message),
    );
  }
}
