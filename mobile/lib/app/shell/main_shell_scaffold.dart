import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// App shell housing the primary tabs (Today, Habits, Insights, Profile)
/// with a floating frosted-glass bottom navigation bar.
class MainShellScaffold extends StatelessWidget {
  const MainShellScaffold({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Current branch page content
          Positioned.fill(
            child: navigationShell,
          ),

          // Floating Frosted Glass Bottom Navigation Bar
          Positioned(
            left: AppSpacing.containerMargin,
            right: AppSpacing.containerMargin,
            bottom: MediaQuery.paddingOf(context).bottom > 0
                ? MediaQuery.paddingOf(context).bottom + 4
                : 16,
            child: _FloatingBottomNavBar(
              currentIndex: navigationShell.currentIndex,
              onTap: _onTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingBottomNavBar extends StatelessWidget {
  const _FloatingBottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppSpacing.borderRadiusDock,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppSpacing.glassBlur,
          sigmaY: AppSpacing.glassBlur,
        ),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.glassBackground,
            borderRadius: AppSpacing.borderRadiusDock,
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.4),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D1B1C19),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                index: 0,
                currentIndex: currentIndex,
                icon: Icons.calendar_today_rounded,
                activeIcon: Icons.calendar_today_rounded,
                label: 'Today',
                onTap: onTap,
              ),
              _NavItem(
                index: 1,
                currentIndex: currentIndex,
                icon: Icons.spa_outlined,
                activeIcon: Icons.format_list_bulleted_rounded,
                label: 'Habits',
                onTap: onTap,
              ),
              _NavItem(
                index: 2,
                currentIndex: currentIndex,
                icon: Icons.insights_rounded,
                activeIcon: Icons.insights_rounded,
                label: 'Insights',
                onTap: onTap,
              ),
              _NavItem(
                index: 3,
                currentIndex: currentIndex,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ValueChanged<int> onTap;

  bool get _isSelected => index == currentIndex;

  @override
  Widget build(BuildContext context) {
    final color = _isSelected ? AppColors.primary : AppColors.onSurfaceVariant;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(index),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Top indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: _isSelected ? 28 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: _isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(height: 6),
              Icon(
                _isSelected ? activeIcon : icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: color,
                  fontWeight: _isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
