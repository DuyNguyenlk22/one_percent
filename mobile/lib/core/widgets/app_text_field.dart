import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/theme.dart';

/// Reusable, versatile form input widget adhering to Bloom design system specifications.
///
/// Supports standard input fields (Name, Email, Password) with adaptive padding,
/// built-in password visibility toggling, and specialized OTP digit input mode.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hintText,
    required this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.focusNode,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.maxLength,
    this.width,
    this.height,
    this.isOtp = false,
    this.onKey,
  });

  /// Factory constructor for single-digit OTP input boxes (used on Forgot Password / Verification screens).
  factory AppTextField.otp({
    Key? key,
    required TextEditingController controller,
    required FocusNode focusNode,
    required ValueChanged<String> onChanged,
    void Function(RawKeyEvent)? onKey,
    bool autofocus = false,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onKey: onKey,
      autofocus: autofocus,
      isOtp: true,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 1,
      width: 64,
      height: 64,
    );
  }

  /// Optional label rendered above the input with a 16px indent.
  final String? label;

  /// Placeholder hint text.
  final String? hintText;

  /// Controller managing the text value.
  final TextEditingController controller;

  /// Optional prefix icon displayed at the left of the input field.
  final IconData? prefixIcon;

  /// Optional custom trailing widget.
  final Widget? suffixIcon;

  /// Whether the input obscures text for secure password entry.
  final bool isPassword;

  /// Keyboard type (e.g., text, emailAddress, number).
  final TextInputType keyboardType;

  /// Action key on the software keyboard (e.g., next, done).
  final TextInputAction textInputAction;

  /// Validation logic returning an error message string or null.
  final String? Function(String?)? validator;

  /// Callback triggered on character changes.
  final ValueChanged<String>? onChanged;

  /// Callback triggered on submitting the input field.
  final ValueChanged<String>? onFieldSubmitted;

  /// Formatters restricting or transforming user input.
  final List<TextInputFormatter>? inputFormatters;

  /// Focus node associated with this field.
  final FocusNode? focusNode;

  /// Whether this field automatically receives focus.
  final bool autofocus;

  /// Horizontal alignment of the text.
  final TextAlign textAlign;

  /// Maximum allowed characters.
  final int? maxLength;

  /// Explicit width (commonly used for OTP boxes).
  final double? width;

  /// Explicit height (commonly used for OTP boxes).
  final double? height;

  /// Whether this widget acts as a standalone single-digit OTP box.
  final bool isOtp;

  /// Raw keyboard event handler (used for OTP backspace handling).
  final void Function(RawKeyEvent)? onKey;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscureText;
  late FocusNode _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
    _internalFocusNode = widget.focusNode ?? FocusNode();
    _internalFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _internalFocusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _internalFocusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted && widget.isOtp) {
      setState(() {});
    }
  }

  void _toggleObscureText() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isOtp) {
      return _buildOtpField();
    }
    return _buildStandardField();
  }

  Widget _buildOtpField() {
    final rawListenerFocusNode = FocusNode();

    return Container(
      width: widget.width ?? 64,
      height: widget.height ?? 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppSpacing.ambientShadow,
      ),
      child: RawKeyboardListener(
        focusNode: rawListenerFocusNode,
        onKey: widget.onKey,
        child: TextFormField(
          controller: widget.controller,
          focusNode: _internalFocusNode,
          keyboardType: widget.keyboardType,
          textAlign: widget.textAlign,
          autofocus: widget.autofocus,
          cursorColor: AppColors.primary,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
            ...?widget.inputFormatters,
          ],
          style: AppTypography.display.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: _internalFocusNode.hasFocus
                ? AppColors.surfaceContainerLowest
                : AppColors.surfaceContainer,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStandardField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top label with 16px horizontal indent matching Stitch design
        if (widget.label != null && widget.label!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text(
              widget.label!,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ),

        // Pill-shaped input container
        TextFormField(
          controller: widget.controller,
          focusNode: _internalFocusNode,
          obscureText: _obscureText,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          inputFormatters: widget.inputFormatters,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.outlineVariant,
            ),
            filled: true,
            fillColor: AppColors.surfaceContainer, // #F0EEE9
            contentPadding: EdgeInsets.symmetric(
              horizontal: widget.prefixIcon != null ? 20.0 : 24.0,
              vertical: 18.0,
            ),
            prefixIcon: widget.prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 12.0),
                    child: Icon(
                      widget.prefixIcon,
                      color: AppColors.outlineVariant,
                      size: 20.0,
                    ),
                  )
                : null,
            prefixIconConstraints: widget.prefixIcon != null
                ? const BoxConstraints(
                    minWidth: 48,
                    minHeight: 24,
                  )
                : null,
            suffixIcon: widget.suffixIcon ??
                (widget.isPassword
                    ? Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: IconButton(
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, anim) => ScaleTransition(
                              scale: anim,
                              child: child,
                            ),
                            child: Icon(
                              _obscureText
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              key: ValueKey<bool>(_obscureText),
                              color: AppColors.outlineVariant,
                              size: 20.0,
                            ),
                          ),
                          onPressed: _toggleObscureText,
                          splashRadius: 20.0,
                          tooltip: _obscureText ? 'Show password' : 'Hide password',
                        ),
                      )
                    : null),
            border: OutlineInputBorder(
              borderRadius: AppSpacing.borderRadiusPill,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppSpacing.borderRadiusPill,
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppSpacing.borderRadiusPill,
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppSpacing.borderRadiusPill,
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppSpacing.borderRadiusPill,
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
