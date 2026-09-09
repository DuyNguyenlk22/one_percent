import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../insights/domain/entities/insights_summary.dart';
import '../../../insights/presentation/providers/insights_provider.dart';

/// Stitch Screen: Profile
/// Screen ID: 4c5eb381a47e47e99186f7dc53ec7a71
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusCard,
          ),
          title: Text(
            'Log out',
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          content: Text(
            'Are you sure you want to log out of your account?',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.onError,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref.read(authNotifierProvider.notifier).logout();
              },
              child: Text(
                'Log out',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.onError,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    // Zeroes while loading rather than a spinner: the stat row is a summary on
    // a page whose real purpose is settings and sign-out, and swapping it for
    // a spinner makes the whole page feel like it is loading.
    final summary =
        ref.watch(insightsProvider).value ?? InsightsSummary.empty;
    final displayName = user?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.containerMargin,
          ),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Avatar with Edit Badge
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryContainer.withValues(alpha: 0.15),
                        border: Border.all(
                          color: AppColors.surface,
                          width: 4,
                        ),
                        boxShadow: AppSpacing.ambientShadow,
                      ),
                      child: Center(
                        child: Text(
                          displayName.isEmpty ? '\u{1F331}' : displayName[0],
                          style: AppTypography.display.copyWith(
                            color: AppColors.primary,
                            fontSize: 42,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryContainer,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: AppColors.onPrimaryContainer,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // User Name & Tagline
              Text(
                displayName.isEmpty ? 'Your profile' : displayName,
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _growingSince(user?.createdAt),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Stats Row (3 Columns)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppSpacing.borderRadiusCard,
                  boxShadow: AppSpacing.ambientShadow,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatColumn(
                        value: '${summary.consistencyPercent}%',
                        label: 'CONSISTENCY',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: AppColors.outlineVariant.withValues(alpha: 0.4),
                    ),
                    Expanded(
                      child: _StatColumn(
                        value: '${summary.habitCount}',
                        label: 'HABITS',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: AppColors.outlineVariant.withValues(alpha: 0.4),
                    ),
                    Expanded(
                      child: _StatColumn(
                        value: '${summary.currentStreak}',
                        label: 'STREAK',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Settings Options Card
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppSpacing.ambientShadow,
                ),
                child: Column(
                  children: [
                    _SettingsItem(
                      icon: Icons.notifications_rounded,
                      iconBg: AppColors.primaryFixed,
                      iconColor: AppColors.onPrimaryFixed,
                      title: 'Notifications',
                      subtitle: 'Daily reminders',
                      onTap: () {},
                    ),
                    Divider(
                      height: 1,
                      indent: 68,
                      endIndent: 20,
                      color: AppColors.outlineVariant.withValues(alpha: 0.25),
                    ),
                    _SettingsItem(
                      icon: Icons.palette_rounded,
                      iconBg: AppColors.secondaryFixed,
                      iconColor: AppColors.onSecondaryFixed,
                      title: 'Appearance',
                      subtitle: 'Light mode',
                      onTap: () {},
                    ),
                    Divider(
                      height: 1,
                      indent: 68,
                      endIndent: 20,
                      color: AppColors.outlineVariant.withValues(alpha: 0.25),
                    ),
                    _SettingsItem(
                      icon: Icons.shield_rounded,
                      iconBg: AppColors.tertiaryFixed,
                      iconColor: AppColors.onTertiaryFixed,
                      title: 'Privacy & Security',
                      onTap: () {},
                    ),
                    Divider(
                      height: 1,
                      indent: 68,
                      endIndent: 20,
                      color: AppColors.outlineVariant.withValues(alpha: 0.25),
                    ),
                    _SettingsItem(
                      icon: Icons.help_outline_rounded,
                      iconBg: AppColors.primaryFixed.withValues(alpha: 0.5),
                      iconColor: AppColors.primary,
                      title: 'Help & Support',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Log Out Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorContainer,
                    foregroundColor: AppColors.error,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => _confirmLogout(context, ref),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: Text(
                    'Log Out',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Space for floating dock
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}

/// The month the account was created. Falls back to a neutral line rather than
/// inventing a date when the profile has not loaded.
String _growingSince(DateTime? createdAt) {
  if (createdAt == null) return 'Welcome to Bloom';
  return 'Growing since ${AppDateUtils.monthLabel(createdAt)} ${createdAt.year}';
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.headlineMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconBg,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
