import '../constants/app_constants.dart';

/// Form-field validators shared across features.
///
/// Each returns `null` when the value is acceptable and an error message
/// otherwise, matching the signature `TextFormField.validator` expects. Rules
/// mirror the backend's class-validator DTOs so the client rejects what the
/// server would reject anyway.
abstract final class Validators {
  static final RegExp _emailPattern = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?"
    r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
  );

  /// Requires a non-empty, well-formed email address.
  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }

  /// Requires a password of at least [AppConstants.minPasswordLength].
  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Password is required';
    if (password.length < AppConstants.minPasswordLength) {
      return 'Password must be at least ${AppConstants.minPasswordLength} characters';
    }
    return null;
  }

  /// Requires [value] to match [original].
  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  /// Requires a non-blank value. [fieldName] is interpolated into the message.
  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  /// Requires a non-blank habit name no longer than the backend allows.
  static String? habitName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Habit name is required';
    if (name.length > AppConstants.maxHabitNameLength) {
      return 'Keep it under ${AppConstants.maxHabitNameLength} characters';
    }
    return null;
  }
}
