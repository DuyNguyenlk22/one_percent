import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

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

  // Interactive local states for demo habits
  double _waterDrankLiters = 1.5;
  final double _waterGoalLiters = 2.0;

  bool _exerciseCompleted = false;
  bool _meditateCompleted = true;
  bool _readCompleted = false;

  int get _totalHabits => 4;
  int get _completedCount {
    int count = 0;
    if (_waterDrankLiters >= _waterGoalLiters) count++;
    if (_exerciseCompleted) count++;
    if (_meditateCompleted) count++;
    if (_readCompleted) count++;
    return count;
  }

  void _cycleQuote() {
    setState(() {
      _quoteIndex = (_quoteIndex + 1) % _quotes.length;
    });
  }

  void _addWater() {
    setState(() {
      _waterDrankLiters = (_waterDrankLiters + 0.25).clamp(0.0, 3.0);
    });
  }

  @override
  Widget build(BuildContext context) {
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
                                    value: _completedCount / _totalHabits,
                                    strokeWidth: 7,
                                    backgroundColor: AppColors.surfaceVariant,
                                    color: AppColors.primary,
                                    strokeCap: StrokeCap.round,
                                  ),
                                  Text(
                                    '$_completedCount/$_totalHabits',
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
                              '12',
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

            // Daily Habits Items
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.containerMargin,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    // Habit 1: Drink water (Quantity Counter)
                    _WaterHabitCard(
                      drankLiters: _waterDrankLiters,
                      goalLiters: _waterGoalLiters,
                      onAdd: _addWater,
                    ),
                    const SizedBox(height: AppSpacing.stackGap),

                    // Habit 2: Morning exercise
                    _ToggleHabitCard(
                      title: 'Morning exercise',
                      subtitle: '20 mins',
                      icon: Icons.directions_run_rounded,
                      iconBg: AppColors.primaryFixed,
                      iconColor: AppColors.onPrimaryFixed,
                      isCompleted: _exerciseCompleted,
                      onToggle: () {
                        setState(() {
                          _exerciseCompleted = !_exerciseCompleted;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.stackGap),

                    // Habit 3: Meditate (Completed state with sage banner)
                    _ToggleHabitCard(
                      title: 'Meditate',
                      subtitle: '10 mins',
                      icon: Icons.self_improvement_rounded,
                      iconBg: AppColors.secondaryContainer,
                      iconColor: AppColors.onSecondaryContainer,
                      isCompleted: _meditateCompleted,
                      onToggle: () {
                        setState(() {
                          _meditateCompleted = !_meditateCompleted;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.stackGap),

                    // Habit 4: Read a book
                    _ToggleHabitCard(
                      title: 'Read a book',
                      subtitle: '15 mins',
                      icon: Icons.menu_book_rounded,
                      iconBg: AppColors.tertiaryFixed,
                      iconColor: AppColors.onTertiaryFixed,
                      isCompleted: _readCompleted,
                      onToggle: () {
                        setState(() {
                          _readCompleted = !_readCompleted;
                        });
                      },
                    ),

                    // Space for floating bottom navigation dock
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

class _WaterHabitCard extends StatelessWidget {
  const _WaterHabitCard({
    required this.drankLiters,
    required this.goalLiters,
    required this.onAdd,
  });

  final double drankLiters;
  final double goalLiters;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final progress = (drankLiters / goalLiters).clamp(0.0, 1.0);

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Drink enough water',
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${drankLiters.toStringAsFixed(1)}L / ${goalLiters.toStringAsFixed(1)}L Goal',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondaryContainer,
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: AppColors.onSecondaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: const AlwaysStoppedAnimation(AppColors.secondary),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryContainer,
                foregroundColor: AppColors.onSecondaryContainer,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Add 250ml',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleHabitCard extends StatelessWidget {
  const _ToggleHabitCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.isCompleted,
    required this.onToggle,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final bool isCompleted;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: isCompleted ? AppColors.primaryContainer : AppColors.surfaceContainer,
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
              color: isCompleted
                  ? AppColors.onPrimaryContainer.withValues(alpha: 0.2)
                  : iconBg,
            ),
            child: Icon(
              icon,
              color: isCompleted ? AppColors.onPrimaryContainer : iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyLarge.copyWith(
                    color: isCompleted
                        ? AppColors.onPrimaryContainer
                        : AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.labelSmall.copyWith(
                    color: isCompleted
                        ? AppColors.onPrimaryContainer.withValues(alpha: 0.75)
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? AppColors.onPrimaryContainer : Colors.transparent,
                border: Border.all(
                  color: isCompleted
                      ? Colors.transparent
                      : AppColors.outlineVariant,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      color: AppColors.primary,
                      size: 20,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
