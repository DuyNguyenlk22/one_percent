import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// How long the brand holds the screen before a signed-in user is moved on.
///
/// Long enough to read the wordmark, short enough not to feel like a delay.
const Duration _brandBeat = Duration(milliseconds: 1200);

/// The first screen of the app, shown on every cold start.
///
/// Signed-out visitors choose their way in; a signed-in one is carried to the
/// shell once [_brandBeat] has passed, so returning users still see the brand
/// but never have to tap through it.
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  Timer? _beatTimer;
  bool _beatElapsed = false;

  @override
  void initState() {
    super.initState();

    // Matches the login page's entrance: 0.8s cubic-bezier(0.16, 1, 0.3, 1).
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    final curved = CurvedAnimation(
      parent: _animController,
      curve: const Cubic(0.16, 1.0, 0.3, 1.0),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.04),
      end: Offset.zero,
    ).animate(curved);

    _animController.forward();

    _beatTimer = Timer(_brandBeat, () {
      _beatElapsed = true;
      _advanceIfSignedIn();
    });
  }

  @override
  void dispose() {
    _beatTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  /// Moves a signed-in user on to the shell.
  ///
  /// Called from both ends of the race — the beat may finish before the stored
  /// session is restored, or after — and does nothing until both have landed.
  void _advanceIfSignedIn() {
    if (!mounted || !_beatElapsed) return;
    if (ref.read(authNotifierProvider).status != AuthStatus.authenticated) {
      return;
    }
    context.goNamed(RouteNames.today);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      authNotifierProvider.select((state) => state.status),
      (_, _) => _advanceIfSignedIn(),
    );

    // The session is still being restored: the ways in are not answerable yet.
    final isRestoring =
        ref.watch(authNotifierProvider.select((state) => state.status)) ==
            AuthStatus.unknown;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.containerMargin,
                    vertical: 16.0,
                  ),
                  child: Column(
                    children: [
                      const _WelcomeHeader(),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(height: AppSpacing.sectionGap),
                              const _BrandMark(),
                              const SizedBox(height: 28),
                              const _PillarsCard(),
                              const SizedBox(height: AppSpacing.sectionGap),
                            ],
                          ),
                        ),
                      ),
                      _WelcomeActions(isRestoring: isRestoring),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "The 1% Rule" pill and the founding year.
class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: AppSpacing.borderRadiusPill,
            border: Border.all(color: AppColors.surfaceContainerHighest),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'THE 1% RULE',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Text(
          'Est. 2024',
          style: AppTypography.labelMedium.copyWith(color: AppColors.outline),
        ),
      ],
    );
  }
}

/// Logo, wordmark, and the promise the app makes.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 112,
          height: 112,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.surfaceContainerHighest),
            boxShadow: AppSpacing.ambientShadow,
          ),
          child: Image.asset(
            AppAssets.bloomLogo,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.spa_rounded, size: 44, color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Bloom',
          style: AppTypography.display.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            text: 'Small habits, remarkable compounding. Grow ',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            children: [
              TextSpan(
                text: '1% better',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(text: ' every single day.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// The three things the app promises to be.
class _PillarsCard extends StatelessWidget {
  const _PillarsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.borderRadiusCard,
        border: Border.all(color: AppColors.surfaceContainerHighest),
        boxShadow: AppSpacing.ambientShadow,
      ),
      child: const Column(
        children: [
          _Pillar(
            icon: Icons.wb_sunny_outlined,
            title: 'Daily Rituals',
            description: 'Gentle morning & evening micro-actions',
          ),
          _PillarDivider(),
          _Pillar(
            icon: Icons.trending_up_rounded,
            title: 'Consistency over Perfection',
            description: 'Track momentum without guilt or streaks pressure',
          ),
          _PillarDivider(),
          _Pillar(
            icon: Icons.auto_awesome_outlined,
            title: 'Calm Clarity',
            description: 'Mindful inspiration tailored for quiet growth',
          ),
        ],
      ),
    );
  }
}

class _Pillar extends StatelessWidget {
  const _Pillar({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primaryFixed.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall + 4),
          ),
          child: Icon(icon, size: 17, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.labelLarge.copyWith(
                  fontSize: 13,
                  height: 18 / 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  height: 15 / 11,
                  color: AppColors.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PillarDivider extends StatelessWidget {
  const _PillarDivider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Divider(
          height: 1,
          thickness: 1,
          color: AppColors.surfaceContainerHigh,
        ),
      );
}

/// The two ways in, plus the progress dots.
class _WelcomeActions extends StatelessWidget {
  const _WelcomeActions({required this.isRestoring});

  /// True while the stored session is still being checked.
  final bool isRestoring;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppButton(
          label: 'Begin Your Journey',
          trailingIcon: Icons.arrow_forward_rounded,
          isLoading: isRestoring,
          onPressed: () => context.goNamed(RouteNames.register),
        ),
        const SizedBox(height: 4),
        // Wraps rather than clips: the line has to survive a long translation
        // and a large text-scale setting.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Already have an account?',
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            TextButton(
              onPressed: isRestoring
                  ? null
                  : () => context.goNamed(RouteNames.login),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.onSurface,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: AppTypography.labelLarge.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text('Sign In'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const _ProgressDots(),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Decorative position markers. Bloom has one welcome screen today; the dots
/// keep the mock's rhythm and leave room for the pages that may follow.
class _ProgressDots extends StatelessWidget {
  const _ProgressDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 24,
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: AppSpacing.borderRadiusPill,
          ),
        ),
        for (var i = 0; i < 2; i++) ...[
          const SizedBox(width: 6),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}
