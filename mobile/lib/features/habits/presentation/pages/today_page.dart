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
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/daily_habits_provider.dart';
import '../widgets/habit_check_card.dart';

/// Stitch Screen: Today (Interactive Quotes)
/// Screen ID: 7657660f0ff14fe0a33d3578d71f8d4f
class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  static const List<String> _quotes = [
    '"Focus on the step you\'re taking, not the whole staircase."',
    '"The secret of your future is hidden in your daily routine."',
    '"Small steps every day lead to big results."',
    '"Consistency is the playground of excellence."',
    '"Be gentle with yourself. You are blooming."',
    '"Root yourself in the present moment."',
  ];

  int _quoteIndex = 0;
  bool _showMotivation = true;

  void _cycleQuote() {
    setState(() {
      _quoteIndex = (_quoteIndex + 1) % _quotes.length;
    });
  }

  /// Flips a habit's check-off, surfacing the message if the write is rejected.
  /// The provider has already rolled the list back by the time this returns.
  Future<void> _toggle(String habitId) async {
    final failure =
        await ref.read(dailyHabitsProvider.notifier).toggle(habitId);
    if (failure == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failure.message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(dailyHabitsProvider);
    final total = habitsAsync.value?.length ?? 0;
    final completed = ref.watch(todayCompletedCountProvider);
    final topStreak = ref.watch(topStreakProvider);

    final user = ref.watch(authNotifierProvider).user;
    final userName = user?.email.split('@').first ?? 'Sarah';
    final capitalizedName = userName.isNotEmpty
        ? '${userName[0].toUpperCase()}${userName.substring(1)}'
        : 'Sarah';

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
                    InkWell(
                      onTap: () => context.goNamed(RouteNames.profile),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryFixed,
                          border: Border.all(
                            color: AppColors.outlineVariant.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            capitalizedName[0],
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.onPrimaryFixed,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Header Greetings
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
                      'Good morning, $capitalizedName.',
                      style: AppTypography.headlineLargeMobile.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formattedDate(),
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Progress Ring & Streak Widget
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.containerMargin,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Progress Ring Card
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 156,
                        padding: const EdgeInsets.all(AppSpacing.cardPadding),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: AppSpacing.borderRadiusCard,
                          boxShadow: AppSpacing.ambientShadow,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 72,
                              height: 72,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: total == 0 ? 0 : completed / total,
                                    strokeWidth: 7,
                                    backgroundColor: AppColors.surfaceVariant,
                                    color: AppColors.primary,
                                    strokeCap: StrokeCap.round,
                                  ),
                                  Text(
                                    '$completed/$total',
                                    style: AppTypography.headlineSmall.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Today's Progress",
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Streak Badge Card
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 156,
                        padding: const EdgeInsets.all(AppSpacing.cardPadding),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: AppSpacing.borderRadiusCard,
                          boxShadow: AppSpacing.ambientShadow,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.eco_rounded,
                              color: AppColors.onPrimaryContainer,
                              size: 36,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$topStreak',
                              style: AppTypography.headlineLarge.copyWith(
                                color: AppColors.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Day Streak',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.onPrimaryContainer.withValues(alpha: 0.85),
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

            // Interactive Daily Motivation Card
            if (_showMotivation)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.containerMargin,
                    vertical: 8,
                  ),
                  child: InkWell(
                    onTap: _cycleQuote,
                    borderRadius: AppSpacing.borderRadiusCard,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.cardPadding),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: AppSpacing.borderRadiusCard,
                        border: Border.all(
                          color: AppColors.outlineVariant.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: AppSpacing.ambientShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'DAILY MOTIVATION',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: AppColors.primary,
                                        letterSpacing: 1.0,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      child: Text(
                                        _quotes[_quoteIndex],
                                        key: ValueKey<int>(_quoteIndex),
                                        style: AppTypography.bodyMedium.copyWith(
                                          color: AppColors.onSurface,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: AppColors.onSurfaceVariant,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _showMotivation = false;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Daily Habits Section Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.containerMargin,
                  right: AppSpacing.containerMargin,
                  top: 20,
                  bottom: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DAILY HABITS',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, color: AppColors.primary),
                      onPressed: () => context.pushNamed(RouteNames.addHabit),
                      tooltip: 'Add Habit',
                    ),
                  ],
                ),
              ),
            ),

            // Daily habits, from GET /habits?date=today
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
              AsyncData(:final value) when value.isEmpty =>
                const SliverToBoxAdapter(child: _EmptyHabits()),
              AsyncData(:final value) => SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.containerMargin,
                  ),
                  sliver: SliverList.separated(
                    itemCount: value.length + 1,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.stackGap),
                    itemBuilder: (context, index) {
                      // Trailing spacer clears the floating nav dock.
                      if (index == value.length) {
                        return const SizedBox(height: 110);
                      }
                      final habit = value[index];
                      return HabitCheckCard(
                        habit: habit,
                        onToggle: () => _toggle(habit.id),
                      );
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

  static String _formattedDate() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }
}

class _EmptyHabits extends StatelessWidget {
  const _EmptyHabits();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.containerMargin,
        vertical: 40,
      ),
      child: Column(
        children: [
          const Icon(Icons.spa_outlined, size: 44, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            'No habits yet',
            style:
                AppTypography.headlineSmall.copyWith(color: AppColors.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            'Plant your first one and it will show up here every day.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
