import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../app/theme/theme.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../app/router/route_names.dart';
import '../providers/auth_provider.dart';

/// Pixel-accurate Register / Sign-up Screen extracted from Stitch project specifications.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _isButtonPressed = false;

  @override
  void initState() {
    super.initState();

    // Stitch 'animate-fade-in-up' (0.8s cubic-bezier(0.16, 1, 0.3, 1))
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
      begin: const Offset(0.0, 0.05),
      end: Offset.zero,
    ).animate(curved);

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final success = await ref.read(authNotifierProvider.notifier).register(
          email: _emailController.text,
          password: _passwordController.text,
        );

    if (!mounted) return;

    if (success) {
      // The router redirects to the main shell on its own once the auth state
      // flips, so this only has to confirm what happened.
      _showSnackBar(
        'Account created successfully! Welcome to Bloom.',
        AppColors.primary,
      );
      return;
    }

    final error = ref.read(authNotifierProvider).errorMessage;
    if (error != null) _showSnackBar(error, AppColors.error);
  }

  void _showSnackBar(String message, Color background) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _navigateToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(RouteNames.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(authNotifierProvider).isSubmitting;

    return Scaffold(
      backgroundColor: AppColors.surface, // #FBF9F4
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.containerMargin, // 24px
              vertical: 24.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384), // max-w-sm
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: AppSpacing.sectionGap), // 40px

                      // 1. Header with Bloom Logo
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest, // #FFFFFF
                          borderRadius: AppSpacing.borderRadiusCard, // 24px
                          boxShadow: AppSpacing.ambientShadow,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          AppAssets.bloomLogo,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                            child: Icon(
                              Icons.spa_rounded,
                              size: 40,
                              color: AppColors.primary, // Sage Green fallback
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.stackGap), // 16px

                      // 2. Headlines
                      Text(
                        'Start your journey',
                        style: AppTypography.headlineLargeMobile.copyWith(
                          color: AppColors.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Text(
                          'Join Bloom and cultivate healthy, mindful habits at your own pace.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sectionGap), // 40px

                      // 3. Registration Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Name Input (Optional)
                            AppTextField(
                              label: 'Name',
                              hintText: 'Optional',
                              controller: _nameController,
                              keyboardType: TextInputType.name,
                            ),
                            const SizedBox(height: AppSpacing.stackGap), // 16px

                            // Email Address Input
                            AppTextField(
                              label: 'Email Address',
                              hintText: 'you@example.com',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.stackGap), // 16px

                            // Password Input
                            AppTextField(
                              label: 'Password',
                              hintText: 'Create a password',
                              controller: _passwordController,
                              isPassword: true,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _handleRegister(),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Password is required';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 4. Submit Button (Create Account)
                      GestureDetector(
                        onTapDown: (_) =>
                            setState(() => _isButtonPressed = true),
                        onTapUp: (_) =>
                            setState(() => _isButtonPressed = false),
                        onTapCancel: () =>
                            setState(() => _isButtonPressed = false),
                        onTap: isSubmitting ? null : _handleRegister,
                        child: AnimatedScale(
                          scale: _isButtonPressed ? 0.98 : 1.0,
                          duration: const Duration(milliseconds: 100),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: double.infinity,
                            height: AppSpacing.touchTarget, // 56px
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: AppSpacing.borderRadiusPill,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          AppColors.onPrimary,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      'Create Account',
                                      style: AppTypography.labelMedium.copyWith(
                                        color: AppColors.onPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sectionGap), // 40px

                      // 5. Footer (Already have an account? Sign In)
                      GestureDetector(
                        onTap: _navigateToLogin,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text.rich(
                            TextSpan(
                              text: 'Already have an account? ',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Sign In',
                                  style: AppTypography.labelMedium.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
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
