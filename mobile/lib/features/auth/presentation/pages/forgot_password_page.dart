import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/result.dart';
import '../../../../app/theme/theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection/dependency_injection.dart';

/// Which half of the flow the page is showing.
enum _Step {
  /// Collect an address to send the code to.
  email,

  /// Enter the code that was sent.
  code,
}

/// Forgot Password / OTP verification, wired to `POST /auth/forgot-password`
/// and `POST /auth/verify-reset-code`.
///
/// Two steps on one screen. [email] seeds the first one: a usable address —
/// typically typed on the login screen — skips straight to the code step and
/// sends on entry, while a blank or malformed one asks for the address first.
/// Verifying the code hands off to [ResetPasswordPage] with the short-lived
/// reset token.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({
    super.key,
    this.email = '',
  });

  /// Address to send the verification OTP to, if the caller knows one.
  final String email;

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  /// Six, from one constant — the backend widened the code from four digits.
  static const int _otpLength = AppConstants.resetCodeLength;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  late _Step _step;

  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  bool _isCtaPressed = false;
  bool _isSending = false;
  bool _isLoading = false;

  /// The address every request on this page is made against. The field is the
  /// source of truth, not [widget.email] — the user may have corrected it.
  String get _email => _emailController.text.trim();

  @override
  void initState() {
    super.initState();

    _emailController = TextEditingController(text: widget.email.trim());
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

    // Only an address the backend would accept is worth sending on entry.
    // Anything else — blank, or half-typed on the login screen — starts on the
    // email step so the user fixes it before a request is wasted on it.
    final isSeeded = Validators.email(widget.email) == null;
    _step = isSeeded ? _Step.code : _Step.email;
    if (isSeeded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode());
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animController.dispose();
    _emailController.dispose();
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
    // Matches the backend's 60s resend cooldown, which silently drops a second
    // request inside that window — counting down to it keeps the button honest.
    setState(() => _secondsRemaining = AppConstants.resendCooldown.inSeconds);
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

  /// Validates the typed address before spending a request on it.
  void _handleSendPressed() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _sendCode();
  }

  /// Asks the backend to email a code, then advances to the code step and
  /// starts the resend countdown.
  ///
  /// The response is the same whether or not the address is registered, so
  /// there is nothing here to tell the user beyond "we sent it".
  Future<void> _sendCode({bool isResend = false}) async {
    if (_isSending) return;
    setState(() => _isSending = true);

    final email = _email;
    final result =
        await ref.read(requestPasswordResetUseCaseProvider)(email: email);

    if (!mounted) return;
    setState(() => _isSending = false);

    if (result.isSuccess) {
      setState(() => _step = _Step.code);
      _startResendTimer();
      if (isResend) {
        _showSnackBar('A new code is on its way to $email', AppColors.primary);
      }
      return;
    }

    // A failure leaves the user where they are — on the email step that means
    // the field is still there to correct.
    _showSnackBar(
      result.failureOrNull?.message ?? 'Could not send the code.',
      AppColors.error,
    );
  }

  Future<void> _handleVerifyCode() async {
    if (_isLoading) return;

    final code = _controllers.map((c) => c.text).join();
    if (code.length < _otpLength) {
      _showSnackBar(
        'Please enter all $_otpLength digits of the code.',
        AppColors.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    final email = _email;
    final result = await ref.read(verifyResetCodeUseCaseProvider)(
      email: email,
      code: code,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    switch (result) {
      case Success(:final data):
        context.goNamed(
          RouteNames.resetPassword,
          queryParameters: {'token': data, 'email': email},
        );
      case ResultError(:final failure):
        // The backend returns one message for wrong, expired and
        // attempts-exhausted alike, so show it as-is and clear the boxes for
        // another try.
        _clearCode();
        _showSnackBar(failure.message, AppColors.error);
    }
  }

  void _clearCode() {
    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes.first.requestFocus();
  }

  void _handleResend() {
    if (_secondsRemaining > 0) return;
    _sendCode(isResend: true);
  }

  /// Returns to the email step — the escape hatch when the code went to the
  /// wrong address. The countdown and any half-typed code go with it.
  void _handleEditEmail() {
    _countdownTimer?.cancel();
    for (final controller in _controllers) {
      controller.clear();
    }
    setState(() {
      _secondsRemaining = 0;
      _step = _Step.email;
    });
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

                              // 3. The step itself — ask for the address, or
                              // for the code that was sent to it.
                              if (_step == _Step.email)
                                ..._buildEmailStep()
                              else
                                ..._buildCodeStep(),
                              const SizedBox(height: 40),

                              // 4. Return to Login Footer with Subtle Divider
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

  /// Step one: which address should the code go to?
  List<Widget> _buildEmailStep() {
    return [
      _buildTitle('Forgot Password'),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Text(
          "Enter your email and we'll send you a $_otpLength-digit code to "
          'reset your password.',
          style: AppTypography.bodyMedium.copyWith(
            fontSize: 15,
            color: AppColors.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: 32),
      Form(
        key: _formKey,
        child: AppTextField(
          label: 'Email Address',
          hintText: 'you@example.com',
          controller: _emailController,
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofocus: true,
          validator: Validators.email,
          onFieldSubmitted: (_) => _handleSendPressed(),
        ),
      ),
      const SizedBox(height: 32),
      _buildPrimaryCta(
        label: 'Send Code',
        isBusy: _isSending,
        onTap: _handleSendPressed,
      ),
    ];
  }

  /// Step two: the code that was just emailed.
  List<Widget> _buildCodeStep() {
    return [
      _buildTitle('Verification Code'),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Text.rich(
          TextSpan(
            text: 'We sent a $_otpLength-digit code to \n',
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 15,
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
            children: [
              TextSpan(
                text: _email,
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

      // OTP Input Form — six boxes do not fit at the 64px default, so each is
      // sized from the space actually available.
      LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          final available = constraints.maxWidth - gap * (_otpLength - 1);
          final boxSize = (available / _otpLength).clamp(36.0, 64.0);

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_otpLength, (index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < _otpLength - 1 ? gap : 0.0,
                ),
                child: AppTextField.otp(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  size: boxSize,
                  onKey: (event) => _handleKeyEvent(index, event),
                  onChanged: (val) => _handleDigitChanged(index, val),
                  autofocus: index == 0,
                ),
              );
            }),
          );
        },
      ),
      const SizedBox(height: 32),

      _buildPrimaryCta(
        label: 'Verify Code',
        isBusy: _isLoading,
        onTap: _handleVerifyCode,
      ),
      const SizedBox(height: 24),

      // Resend Code Section with Timer
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
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _handleEditEmail,
            child: Text(
              'Wrong email?',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildTitle(String text) {
    return Text(
      text,
      style: AppTypography.headlineLarge.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.onSurface,
        letterSpacing: -0.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// The pill CTA, shared by both steps — only one is ever on screen, so the
  /// press-scale state can be shared too.
  Widget _buildPrimaryCta({
    required String label,
    required bool isBusy,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isCtaPressed = true),
      onTapUp: (_) => setState(() => _isCtaPressed = false),
      onTapCancel: () => setState(() => _isCtaPressed = false),
      onTap: isBusy ? null : onTap,
      child: AnimatedScale(
        scale: _isCtaPressed ? 0.99 : 1.0,
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
            child: isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.onPrimary,
                      ),
                    ),
                  )
                : Text(
                    label,
                    style: AppTypography.labelMedium.copyWith(
                      fontSize: 16,
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
