import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';

/// Stitch Screen: Routines
/// Screen ID: bc94ba62e1d347a8a6e8967e6bf78aa7
class RoutinesPage extends StatelessWidget {
  const RoutinesPage({super.key});

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
                      'Routines',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Hero / Intro
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.containerMargin,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Routines',
                      style: AppTypography.headlineLargeMobile.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Structured growth, one step at a time.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Routines List
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.containerMargin,
                vertical: 8,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    // Routine 1: Sunrise Ritual (Active / In Progress)
                    _RoutineCard(
                      title: 'Sunrise Ritual',
                      subtitle: 'Morning · 4 habits',
                      icon: Icons.wb_twilight_rounded,
                      iconColor: AppColors.primary,
                      progressPercent: 75,
                      habitTags: const ['Hydrate', 'Meditate', 'Journal', 'Stretch'],
                      actionLabel: 'Continue',
                      isPrimaryAction: true,
                      onActionTap: () => context.goNamed(RouteNames.today),
                    ),
                    const SizedBox(height: AppSpacing.stackGap),

                    // Routine 2: Focus Block
                    _RoutineCard(
                      title: 'Focus Block',
                      subtitle: 'Afternoon · 2 habits',
                      icon: Icons.light_mode_rounded,
                      iconColor: AppColors.tertiary,
                      isLocked: true,
                      habitTags: const ['Deep Work', 'Walk'],
                      actionLabel: 'Start',
                      isPrimaryAction: false,
                      onActionTap: () {},
                    ),
                    const SizedBox(height: AppSpacing.stackGap),

                    // Routine 3: Wind Down
                    _RoutineCard(
                      title: 'Wind Down',
                      subtitle: 'Evening · 3 habits',
                      icon: Icons.dark_mode_rounded,
                      iconColor: AppColors.secondary,
                      habitTags: const ['Read', 'Plan Tomorrow', 'Digital Detox'],
                      actionLabel: 'Start',
                      isPrimaryAction: false,
                      onActionTap: () {},
                    ),
                    const SizedBox(height: AppSpacing.stackGap),

                    // Routine 4: Custom Weekend Growth
                    _CustomRoutineCard(
                      title: 'Weekend Growth',
                      subtitle: 'Custom · 5 habits',
                      actionLabel: 'Start Routine',
                      onActionTap: () {},
                    ),
                    const SizedBox(height: 24),

                    // Create Routine Action
                    Center(
                      child: InkWell(
                        onTap: () => context.pushNamed(RouteNames.addHabit),
                        borderRadius: BorderRadius.circular(32),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.surfaceContainerHigh,
                                  boxShadow: AppSpacing.ambientShadow,
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  color: AppColors.onSurface,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create Routine',
                                style: AppTypography.labelMedium.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.habitTags,
    required this.actionLabel,
    required this.isPrimaryAction,
    required this.onActionTap,
    this.progressPercent,
    this.isLocked = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final List<String> habitTags;
  final String actionLabel;
  final bool isPrimaryAction;
  final VoidCallback onActionTap;
  final int? progressPercent;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: AppSpacing.borderRadiusCard,
        boxShadow: AppSpacing.ambientShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top progress bar indicator if active
          if (progressPercent != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressPercent! / 100,
                minHeight: 4,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 24),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.headlineSmall.copyWith(
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
                ],
              ),
              if (progressPercent != null)
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progressPercent! / 100,
                        strokeWidth: 4,
                        backgroundColor: AppColors.surfaceVariant,
                        color: AppColors.primary,
                      ),
                      Text(
                        '$progressPercent%',
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                )
              else if (isLocked)
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceVariant,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Habit Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: habitTags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppSpacing.borderRadiusPill,
                  border: Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  tag,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Action Button
          Align(
            alignment: Alignment.centerRight,
            child: isPrimaryAction
                ? ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      elevation: 0,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onPressed: onActionTap,
                    label: Text(actionLabel, style: AppTypography.labelMedium),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  )
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.outlineVariant),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                    ),
                    onPressed: onActionTap,
                    child: Text(actionLabel, style: AppTypography.labelMedium),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CustomRoutineCard extends StatelessWidget {
  const _CustomRoutineCard({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onActionTap,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.tertiaryFixed.withValues(alpha: 0.35),
        borderRadius: AppSpacing.borderRadiusCard,
        boxShadow: AppSpacing.ambientShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.tertiary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.headlineSmall.copyWith(
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
                ],
              ),
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppColors.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tertiaryContainer,
                foregroundColor: AppColors.onTertiaryContainer,
                elevation: 0,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              onPressed: onActionTap,
              child: Text(actionLabel, style: AppTypography.labelMedium),
            ),
          ),
        ],
      ),
    );
  }
}
