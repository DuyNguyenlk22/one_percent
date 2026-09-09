import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';

/// Stitch Screen: Insights
/// Screen ID: e35e325694c845d9b7a3aacbdef35ca9
class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                              '12',
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
                              '28',
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
                          painter: _WeeklyFlowPainter(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Weekday labels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
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
                    // Meditation
                    _FocusAreaCard(
                      title: 'Meditation',
                      subtitle: 'Most Consistent',
                      percentage: '100%',
                      icon: Icons.self_improvement_rounded,
                      iconBg: AppColors.primaryContainer.withValues(alpha: 0.25),
                      iconColor: AppColors.primary,
                      percentColor: AppColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.stackGap),

                    // Early Sleep
                    _FocusAreaCard(
                      title: 'Early Sleep',
                      subtitle: 'Needs Attention',
                      percentage: '40%',
                      icon: Icons.bedtime_rounded,
                      iconBg: AppColors.secondaryContainer.withValues(alpha: 0.35),
                      iconColor: AppColors.secondary,
                      percentColor: AppColors.secondary,
                    ),

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

class _WeeklyFlowPainter extends CustomPainter {
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
    final points = [0.2, 0.35, 0.4, 0.6, 0.65, 0.85, 0.95];

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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
