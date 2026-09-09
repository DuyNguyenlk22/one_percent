import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../providers/daily_habits_provider.dart';
import '../widgets/habit_color.dart';

/// Stitch Screen: Add Habit
/// Screen ID: c5d28de911dd4f468537b18705902a8f
class AddHabitPage extends ConsumerStatefulWidget {
  const AddHabitPage({super.key});

  @override
  ConsumerState<AddHabitPage> createState() => _AddHabitPageState();
}

class _AddHabitPageState extends ConsumerState<AddHabitPage> {
  String _selectedSeed = 'Drink water';
  final TextEditingController _customHabitController = TextEditingController();

  String _selectedColor = HabitColors.palette.first;
  bool _isSubmitting = false;

  final List<({String label, IconData icon})> _seedOptions = [
    (label: 'Drink water', icon: Icons.water_drop_rounded),
    (label: 'Exercise', icon: Icons.directions_run_rounded),
    (label: 'Meditation', icon: Icons.self_improvement_rounded),
    (label: 'Read', icon: Icons.menu_book_rounded),
    (label: 'Custom', icon: Icons.edit_rounded),
  ];

  @override
  void dispose() {
    _customHabitController.dispose();
    super.dispose();
  }

  Future<void> _onConfirm() async {
    final habitName = _selectedSeed == 'Custom'
        ? _customHabitController.text.trim()
        : _selectedSeed;

    if (habitName.isEmpty) {
      _showMessage('Please enter a habit name', AppColors.error);
      return;
    }

    setState(() => _isSubmitting = true);

    final failure = await ref
        .read(dailyHabitsProvider.notifier)
        .create(name: habitName, color: _selectedColor);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (failure != null) {
      // Keep the form open so the user does not lose what they typed.
      _showMessage(failure.message, AppColors.error);
      return;
    }

    _showMessage('Planted habit "$habitName"!', AppColors.primary);
    context.pop();
  }

  void _showMessage(String message, Color background) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.onSurface,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Add Habit',
                    style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Form Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.containerMargin,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Headline
                    Text(
                      'Plant a new habit',
                      style: AppTypography.headlineLargeMobile.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'What would you like to nurture today?',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),

                    // 1. Select a Seed
                    Text(
                      'SELECT A SEED',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _seedOptions.map((seed) {
                        final isSelected = _selectedSeed == seed.label;
                        return ChoiceChip(
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedSeed = seed.label;
                              });
                            }
                          },
                          avatar: Icon(
                            seed.icon,
                            size: 18,
                            color: isSelected
                                ? AppColors.onPrimary
                                : AppColors.onSurface,
                          ),
                          label: Text(
                            seed.label,
                            style: AppTypography.labelMedium.copyWith(
                              color: isSelected
                                  ? AppColors.onPrimary
                                  : AppColors.onSurface,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                          backgroundColor: AppColors.surfaceContainer,
                          selectedColor: AppColors.primary,
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),

                    // Custom habit input field if 'Custom' is selected
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      crossFadeState: _selectedSeed == 'Custom'
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      firstChild: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: TextField(
                          controller: _customHabitController,
                          decoration: InputDecoration(
                            hintText: 'Name your habit...',
                            hintStyle: AppTypography.bodyLarge.copyWith(
                              color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceContainerLow,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: AppSpacing.borderRadiusPill,
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      secondChild: const SizedBox.shrink(),
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),

                    // 2. Colour — the only other field the schema stores
                    Text(
                      'COLOUR',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final hex in HabitColors.palette)
                          InkWell(
                            key: ValueKey('habit-color-$hex'),
                            onTap: () => setState(() => _selectedColor = hex),
                            customBorder: const CircleBorder(),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: HabitColors.parse(hex),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: hex == _selectedColor
                                      ? AppColors.onSurface
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Fixed Bottom CTA
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.containerMargin,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x081B1C19),
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonHeight,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: _isSubmitting ? null : _onConfirm,
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: Text(
                    'Confirm',
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.onPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
