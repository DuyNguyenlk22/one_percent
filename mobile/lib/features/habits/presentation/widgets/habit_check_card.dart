import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/daily_habit.dart';
import 'habit_color.dart';

/// One habit on Today, with its check-off control.
///
/// The whole card is the tap target — the circle is a visual affordance, not a
/// separate one, which makes a check-off much easier to hit.
class HabitCheckCard extends StatelessWidget {
  const HabitCheckCard({
    super.key,
    required this.habit,
    required this.onToggle,
  });

  final DailyHabit habit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final done = habit.doneToday;
    final accent = HabitColors.parse(habit.color);

    return Semantics(
      button: true,
      checked: done,
      label: habit.name,
      child: InkWell(
        key: ValueKey('habit-toggle-${habit.id}'),
        onTap: onToggle,
        borderRadius: AppSpacing.borderRadiusCard,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPadding,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color:
                done ? AppColors.primaryContainer : AppColors.surfaceContainer,
            borderRadius: AppSpacing.borderRadiusCard,
            boxShadow: AppSpacing.ambientShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? AppColors.onPrimaryContainer.withValues(alpha: 0.2)
                      : accent.withValues(alpha: 0.18),
                ),
                child: Icon(
                  Icons.eco_rounded,
                  color: done ? AppColors.onPrimaryContainer : accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: AppTypography.bodyLarge.copyWith(
                        color: done
                            ? AppColors.onPrimaryContainer
                            : AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _streakLabel(habit.currentStreak),
                      style: AppTypography.labelSmall.copyWith(
                        color: done
                            ? AppColors.onPrimaryContainer
                                .withValues(alpha: 0.75)
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      done ? AppColors.onPrimaryContainer : Colors.transparent,
                  border: Border.all(
                    color: done ? Colors.transparent : AppColors.outlineVariant,
                    width: 2,
                  ),
                ),
                child: done
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.primary, size: 20)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _streakLabel(int streak) => switch (streak) {
        0 => 'Not started',
        1 => '1 day streak',
        _ => '$streak day streak',
      };
}
