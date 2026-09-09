import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Backend base URL and endpoint paths.
///
/// Paths mirror the NestJS controllers in `backend/src`. Keep them here rather
/// than inline in data sources so a route rename is a one-line change.
abstract final class ApiConstants {
  /// Overridable at build time:
  /// `flutter run --dart-define=API_BASE_URL=https://api.example.com`
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static const int _port = 3000;

  /// Resolved base URL.
  ///
  /// The Android emulator reaches the host machine on `10.0.2.2`, not
  /// `localhost`, so debug builds pick the host per platform.
  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:$_port';
    return 'http://localhost:$_port';
  }

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);

  // Auth — backend/src/auth/auth.controller.ts
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';

  // Habits — backend/src/habit/habit.controller.ts
  static const String habits = '/habits';
  static String habit(String id) => '/habits/$id';

  // Habit entries — backend/src/entries/entries.controller.ts
  static String entries(String habitId) => '/habits/$habitId/entries';
  static String entry(String habitId, String date) => '/habits/$habitId/entries/$date';

  // Headers
  static const String authorizationHeader = 'Authorization';
  static const String bearerPrefix = 'Bearer';
}
