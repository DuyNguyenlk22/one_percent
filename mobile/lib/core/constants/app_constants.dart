/// App-wide values that are neither theme tokens nor API routes.
abstract final class AppConstants {
  static const String appName = 'One Percent';

  /// Keys used by `SecureStorage` and `LocalStorage`. Centralised so a key is
  /// never misspelled at one of its two call sites.
  static const String accessTokenKey = 'access_token';
  static const String cachedUserKey = 'cached_user';
  static const String onboardingCompleteKey = 'onboarding_complete';
  static const String themeModeKey = 'theme_mode';

  /// Validation rules, matching the backend's class-validator DTOs.
  static const int minPasswordLength = 6;
  static const int maxHabitNameLength = 60;

  /// Digits in an emailed password reset code.
  ///
  /// The OTP boxes are generated from this one value, so it is the only place
  /// to change if the backend ever widens the code again.
  static const int resetCodeLength = 6;

  /// How long the backend makes a user wait before resending a reset code.
  /// Mirrors `RESEND_COOLDOWN_MS` in `backend/src/auth/auth.service.ts`.
  static const Duration resendCooldown = Duration(seconds: 60);

  /// Standard animation durations.
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 700);
}
