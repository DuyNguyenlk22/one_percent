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

  /// Standard animation durations.
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 700);
}
