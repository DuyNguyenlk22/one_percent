import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/theme.dart';

void main() {
  group('AppTheme & Tokens Tests', () {
    test('AppColors matches Bloom tokens in docs/DESIGN.md', () {
      expect(AppColors.surface, const Color(0xFFFBF9F4));
      expect(AppColors.primary, const Color(0xFF4D6054));
      expect(AppColors.secondary, const Color(0xFF7C5454));
      expect(AppColors.tertiary, const Color(0xFF4C5F69));
      expect(AppColors.onSurface, const Color(0xFF1B1C19));
      expect(AppColors.surfaceContainer, const Color(0xFFF0EEE9));
      expect(AppColors.surfaceContainerLow, const Color(0xFFF5F3EE));
    });

    test('AppSpacing matches layout specifications in docs/DESIGN.md', () {
      expect(AppSpacing.containerMargin, 24.0);
      expect(AppSpacing.stackGap, 16.0);
      expect(AppSpacing.sectionGap, 40.0);
      expect(AppSpacing.touchTarget, 56.0);
      expect(AppSpacing.radiusCard, 24.0);
      expect(AppSpacing.radiusDock, 32.0);
      expect(AppSpacing.radiusPill, 9999.0);
    });

    test('AppTheme.lightTheme builds correctly with Material 3', () {
      final theme = AppTheme.lightTheme;
      expect(theme.useMaterial3, isTrue);
      expect(theme.scaffoldBackgroundColor, AppColors.surface);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.surface, AppColors.surface);
      expect(theme.cardTheme.color, AppColors.surfaceContainer);
    });
  });
}
