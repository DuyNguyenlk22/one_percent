import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/widgets/app_error.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../domain/entities/daily_habit.dart';
import '../providers/daily_habits_provider.dart';
import '../widgets/habit_color.dart';

/// Every habit the user is tracking, with the edit actions the app otherwise
/// has nowhere to offer.
///
/// Replaces the Stitch "Routines" mockup: routines were three hardcoded cards
/// with no table behind them, while `PATCH` and `DELETE /habits/:id` had no
/// caller at all.
class MyHabitsPage extends ConsumerWidget {
  const MyHabitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(dailyHabitsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
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
                            color:
                                AppColors.primaryContainer.withValues(alpha: 0.15),
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
                      'Habits',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

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
                      'Your Habits',
                      style: AppTypography.headlineLargeMobile.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Everything you are growing right now.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            switch (habitsAsync) {
              AsyncError(:final error) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: AppError(
                      message: error is Failure
                          ? error.message
                          : 'Could not load your habits.',
                      onRetry: () =>
                          ref.read(dailyHabitsProvider.notifier).refresh(),
                    ),
                  ),
                ),
              AsyncData(:final value) => SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.containerMargin,
                    vertical: 8,
                  ),
                  sliver: SliverList.separated(
                    itemCount: value.length + 2,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.stackGap),
                    itemBuilder: (context, index) {
                      if (index < value.length) {
                        return _HabitRow(habit: value[index]);
                      }
                      if (index == value.length) {
                        return value.isEmpty
                            ? const _EmptyHabits()
                            : const _AddHabitCard();
                      }
                      // Trailing spacer clears the floating nav dock.
                      return const SizedBox(height: 110);
                    },
                  ),
                ),
              _ => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: AppLoading(),
                  ),
                ),
            },
          ],
        ),
      ),
    );
  }
}

class _HabitRow extends ConsumerWidget {
  const _HabitRow({required this.habit});

  final DailyHabit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = HabitColors.parse(habit.color);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: AppSpacing.borderRadiusCard,
        boxShadow: AppSpacing.ambientShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.name,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  habit.currentStreak == 0
                      ? 'No streak yet'
                      : '${habit.currentStreak} day streak',
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            key: ValueKey('habit-menu-${habit.id}'),
            icon: const Icon(Icons.more_horiz_rounded,
                color: AppColors.onSurfaceVariant),
            onSelected: (action) => _onAction(context, ref, action),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'color', child: Text('Change colour')),
              PopupMenuItem(value: 'archive', child: Text('Archive')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final notifier = ref.read(dailyHabitsProvider.notifier);

    // A switch statement, not an expression: each arm uses `context` before
    // its own await, which the analyzer can only see when they are separate
    // statements.
    final Failure? failure;
    switch (action) {
      case 'rename':
        failure = await _rename(context, notifier);
      case 'color':
        failure = await _recolor(context, notifier);
      // Archiving is reversible and keeps history, so it needs no dialog.
      case 'archive':
        failure = await notifier.archive(habit.id);
      case 'delete':
        failure = await _confirmDelete(context, notifier);
      default:
        failure = null;
    }

    if (failure == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failure.message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<Failure?> _rename(
    BuildContext context,
    DailyHabitsNotifier notifier,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(initialName: habit.name),
    );

    if (name == null) return null;
    return notifier.rename(habit.id, name);
  }

  Future<Failure?> _recolor(
    BuildContext context,
    DailyHabitsNotifier notifier,
  ) async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change colour'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final hex in HabitColors.palette)
              InkWell(
                key: ValueKey('habit-color-$hex'),
                onTap: () => Navigator.of(context).pop(hex),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: HabitColors.parse(hex),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hex == habit.color
                          ? AppColors.onSurface
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (chosen == null) return null;
    return notifier.recolor(habit.id, chosen);
  }

  Future<Failure?> _confirmDelete(
    BuildContext context,
    DailyHabitsNotifier notifier,
  ) async {
    // Deleting cascades to every entry the habit has. Archiving is the
    // reversible option, so this is the one that asks.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${habit.name}"?'),
        content: const Text(
          'This removes the habit and its whole history. It cannot be undone — '
          'archive it instead to keep the record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete habit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return null;
    return notifier.remove(habit.id);
  }
}

class _AddHabitCard extends StatelessWidget {
  const _AddHabitCard();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.pushNamed(RouteNames.addHabit),
      borderRadius: AppSpacing.borderRadiusCard,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding,
          vertical: 18,
        ),
        decoration: BoxDecoration(
          borderRadius: AppSpacing.borderRadiusCard,
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(
              'Plant a new habit',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHabits extends StatelessWidget {
  const _EmptyHabits();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.spa_outlined, size: 44, color: AppColors.primary),
        const SizedBox(height: 12),
        Text(
          'Nothing planted yet',
          style:
              AppTypography.headlineSmall.copyWith(color: AppColors.onSurface),
        ),
        const SizedBox(height: 6),
        Text(
          'Add your first habit and it will appear here.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium
              .copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        const _AddHabitCard(),
      ],
    );
  }
}


/// Rename prompt.
///
/// Stateful so the controller is disposed with the dialog's own element. A
/// controller disposed as soon as `showDialog` resolves is still being read by
/// the TextField during the dismissal animation.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename habit'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
