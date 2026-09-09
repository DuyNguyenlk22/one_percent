import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../app/theme/theme.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Pixel-accurate Forgot Password / OTP Verification Screen extracted from Stitch specifications.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    this.email = 'alex.bloom@example.com',
  });

  /// Target email to which the verification OTP was dispatched.
  final String email;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  static const int _otpLength = 4;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  Timer? _countdownTimer;
  int _secondsRemaining = 45;
  bool _isVerifyPressed = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());

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
    _startResendTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animController.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _countdownTimer?.cancel();
    setState(() => _secondsRemaining = 45);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTimer(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return 'in $mins:$secs';
  }

  void _handleDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste scenario
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < _otpLength; i++) {
        if (i < digits.length) {
          _controllers[i].text = digits[i];
        }
      }
      final nextIndex = digits.length < _otpLength ? digits.length : _otpLength - 1;
      _focusNodes[nextIndex].requestFocus();
      return;
    }

    if (value.isNotEmpty) {
      if (index < _otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _handleVerifyCode();
      }
    }
  }

  void _handleKeyEvent(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _handleVerifyCode() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length < _otpLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter all 4 digits of the code.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Code verified successfully!'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );

    context.pop();
  }

  void _handleResend() {
    if (_secondsRemaining > 0) return;
    _startResendTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('A new verification code has been sent to ${widget.email}'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface, // #FBF9F4
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    children: [
                      // 1. Top Back Navigation (subtle & minimalist circle button)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceContainer, // #F0EEE9
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                                color: AppColors.primary, // #4A5D52
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 2. Brand Logo Emblem (96x96, rounded 28px, white fill, subtle border)
                              Container(
                                width: 96,
                                height: 96,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLowest, // #FFFFFF
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: AppColors.surfaceContainer,
                                    width: 1,
                                  ),
                                  boxShadow: AppSpacing.ambientShadow,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.asset(
                                    AppAssets.bloomLogo,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(
                                        Icons.spa_rounded,
                                        size: 44,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // 3. Screen Title & Context Copy
                              Text(
                                'Verification Code',
                                style: AppTypography.headlineLarge.copyWith(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onSurface,
                                  letterSpacing: -0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                child: Text.rich(
                                  TextSpan(
                                    text: 'We sent a 4-digit code to \n',
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontSize: 15,
                                      color: AppColors.onSurfaceVariant,
                                      height: 1.5,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: widget.email,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // 4. 4-Digit OTP Input Form
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(_otpLength, (index) {
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      right: index < _otpLength - 1 ? 12.0 : 0.0,
                                    ),
                                    child: AppTextField.otp(
                                      controller: _controllers[index],
                                      focusNode: _focusNodes[index],
                                      onKey: (event) => _handleKeyEvent(index, event),
                                      onChanged: (val) => _handleDigitChanged(index, val),
                                      autofocus: index == 0,
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 32),

                              // 5. Verify CTA Button
                              GestureDetector(
                                onTapDown: (_) =>
                                    setState(() => _isVerifyPressed = true),
                                onTapUp: (_) =>
                                    setState(() => _isVerifyPressed = false),
                                onTapCancel: () =>
                                    setState(() => _isVerifyPressed = false),
                                onTap: _isLoading ? null : _handleVerifyCode,
                                child: AnimatedScale(
                                  scale: _isVerifyPressed ? 0.99 : 1.0,
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
                                          color: AppColors.primary.withValues(alpha: 0.2),
                                          blurRadius: 16,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: _isLoading
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
                                              'Verify Code',
                                              style: AppTypography.labelMedium.copyWith(
                                                fontSize: 16,
                                                color: AppColors.onPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // 6. Resend Code Section with Timer
                              Column(
                                children: [
                                  Text(
                                    "Didn't receive the email?",
                                    style: AppTypography.bodySmall.copyWith(
                                      fontSize: 14,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      GestureDetector(
                                        onTap: _secondsRemaining == 0 ? _handleResend : null,
                                        child: Text(
                                          'Resend Code',
                                          style: AppTypography.labelMedium.copyWith(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: _secondsRemaining == 0
                                                ? AppColors.primary
                                                : AppColors.outline,
                                            decoration: _secondsRemaining == 0
                                                ? TextDecoration.underline
                                                : TextDecoration.none,
                                          ),
                                        ),
                                      ),
                                      if (_secondsRemaining > 0) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          '(${_formatTimer(_secondsRemaining)})',
                                          style: AppTypography.bodySmall.copyWith(
                                            fontSize: 12,
                                            color: AppColors.outline,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 40),

                              // 7. Return to Login Footer with Subtle Divider
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.only(top: 16.0),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: AppColors.surfaceContainer.withValues(alpha: 0.6),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: GestureDetector(
                                    onTap: () => Navigator.of(context).pop(),
                                    child: Text.rich(
                                      TextSpan(
                                        text: 'Remember your password? ',
                                        style: AppTypography.bodySmall.copyWith(
                                          fontSize: 14,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                        children: const [
                                          TextSpan(
                                            text: 'Sign In',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
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
