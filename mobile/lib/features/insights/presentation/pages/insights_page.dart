import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_error.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../habits/presentation/widgets/habit_color.dart';
import '../../domain/entities/insights_summary.dart';
import '../providers/insights_provider.dart';

/// Stitch Screen: Insights
/// Screen ID: e35e325694c845d9b7a3aacbdef35ca9
class InsightsPage extends ConsumerWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(insightsProvider);

    return switch (summaryAsync) {
      AsyncError(:final error) => _Frame(
          child: AppError(
            message: error is Failure
                ? error.message
                : 'Could not load your insights.',
            onRetry: () => ref.read(insightsProvider.notifier).refresh(),
          ),
        ),
      AsyncData(:final value) when value.habitCount == 0 =>
        const _Frame(child: _EmptyInsights()),
      AsyncData(:final value) => _build(context, ref, value),
      _ => const _Frame(child: AppLoading()),
    };
  }

  Widget _build(BuildContext context, WidgetRef ref, InsightsSummary summary) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top App Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.containerMargin,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.eco_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Bloom',
                          style: AppTypography.headlineMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Insights',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Overview Streak Cards
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.containerMargin,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Current Streak Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.cardPadding,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: AppSpacing.borderRadiusCard,
                          boxShadow: AppSpacing.ambientShadow,
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${summary.currentStreak}',
                              style: AppTypography.display.copyWith(
                                color: AppColors.primary,
                                fontSize: 32,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'CURRENT STREAK',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.onSurfaceVariant,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Best Streak Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.cardPadding,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: AppSpacing.borderRadiusCard,
                          boxShadow: AppSpacing.ambientShadow,
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${summary.bestStreak}',
                              style: AppTypography.display.copyWith(
                                color: AppColors.tertiary,
                                fontSize: 32,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'BEST STREAK',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.onSurfaceVariant,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Weekly Flow Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.containerMargin,
                  vertical: 12,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Weekly Flow',
                            style: AppTypography.headlineMedium.copyWith(
                              color: AppColors.onSurface,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '+15%',
                              style: AppTypography.labelMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Chart Painter
                      SizedBox(
                        height: 160,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _WeeklyFlowPainter(_lastSevenDays(summary.dailyCompletion)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Weekday labels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: _weekdayInitials().map((day) {
                          return Text(
                            day,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Focus Areas Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.containerMargin,
                  right: AppSpacing.containerMargin,
                  top: 20,
                  bottom: 12,
                ),
                child: Text(
                  'Focus Areas',
                  style: AppTypography.headlineMedium.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ),

            // Focus Areas Cards
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.containerMargin,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    for (final entry in _focusAreas(summary)) ...[
                      _FocusAreaCard(
                        title: entry.habit.name,
                        subtitle: entry == summary.habitConsistency.first
                            ? 'Most Consistent'
                            : 'Needs Attention',
                        percentage: '${(entry.rate * 100).round()}%',
                        icon: Icons.eco_rounded,
                        iconBg: HabitColors.parse(entry.habit.color)
                            .withValues(alpha: 0.25),
                        iconColor: HabitColors.parse(entry.habit.color),
                        percentColor: HabitColors.parse(entry.habit.color),
                      ),
                      const SizedBox(height: AppSpacing.stackGap),
                    ],

                    // Space for floating dock
                    const SizedBox(height: 110),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The last seven completion rates, oldest first.
///
/// A shorter history is left-padded with zeroes so the chart always has seven
/// columns and the weekday labels stay aligned.
List<double> _lastSevenDays(List<double> daily) {
  if (daily.length >= 7) return daily.sublist(daily.length - 7);
  return [...List<double>.filled(7 - daily.length, 0), ...daily];
}

/// Weekday initials for the seven days ending today, so the last column is
/// always today rather than a fixed Monday-to-Sunday.
List<String> _weekdayInitials() {
  final today = AppDateUtils.today;
  return [
    for (var back = 6; back >= 0; back--)
      AppDateUtils.weekdayLabel(today.subtract(Duration(days: back)))
          .substring(0, 1),
  ];
}

/// The strongest and the weakest habit. With one habit there is only one card —
/// showing the same habit twice would be noise.
List<HabitConsistency> _focusAreas(InsightsSummary summary) {
  final ranked = summary.habitConsistency;
  if (ranked.length < 2) return ranked;
  return [ranked.first, ranked.last];
}

/// Page chrome for the states that have nothing to chart.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(child: Center(child: child)),
    );
  }
}

class _EmptyInsights extends StatelessWidget {
  const _EmptyInsights();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.containerMargin),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insights_rounded, size: 44, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            'Nothing to chart yet',
            style:
                AppTypography.headlineSmall.copyWith(color: AppColors.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            'Check a habit off and your history starts here.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _WeeklyFlowPainter extends CustomPainter {
  const _WeeklyFlowPainter(this.points);

  /// Completion rate per day, 0.0–1.0, oldest first.
  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.outlineVariant.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    // Draw 4 horizontal grid lines
    const int lines = 4;
    for (int i = 0; i < lines; i++) {
      final y = size.height * (i / (lines - 1));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Normalized points for M, T, W, T, F, S, S
    // 0 = bottom, 1 = top

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = size.width * (i / (points.length - 1));
      final y = size.height * (1.0 - points[i]);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = size.width * ((i - 1) / (points.length - 1));
        final prevY = size.height * (1.0 - points[i - 1]);
        final controlX1 = prevX + (x - prevX) / 2;
        final controlY1 = prevY;
        final controlX2 = prevX + (x - prevX) / 2;
        final controlY2 = y;
        path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
      }
    }

    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.primary, AppColors.primaryContainer],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _WeeklyFlowPainter oldDelegate) =>
      !listEquals(oldDelegate.points, points);
}

class _FocusAreaCard extends StatelessWidget {
  const _FocusAreaCard({
    required this.title,
    required this.subtitle,
    required this.percentage,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.percentColor,
  });

  final String title;
  final String subtitle;
  final String percentage;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color percentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppSpacing.ambientShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconBg,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            percentage,
            style: AppTypography.headlineSmall.copyWith(
              color: percentColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
