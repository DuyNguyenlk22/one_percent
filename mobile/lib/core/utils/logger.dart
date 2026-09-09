import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Severity levels, ordered from least to most severe.
enum LogLevel { debug, info, warning, error }

/// Thin wrapper over `dart:developer` logging.
///
/// Output is suppressed in release builds, so a stray log statement cannot leak
/// a token or an email address into a production console. Swap the body of
/// [_write] to forward to Crashlytics or Sentry when that is wired up.
abstract final class Logger {
  static const String _defaultTag = 'OnePercent';

  static void debug(Object? message, {String tag = _defaultTag}) =>
      _write(LogLevel.debug, message, tag: tag);

  static void info(Object? message, {String tag = _defaultTag}) =>
      _write(LogLevel.info, message, tag: tag);

  static void warning(Object? message, {String tag = _defaultTag}) =>
      _write(LogLevel.warning, message, tag: tag);

  static void error(
    Object? message, {
    String tag = _defaultTag,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _write(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);

  static void _write(
    LogLevel level,
    Object? message, {
    required String tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kReleaseMode) return;
    developer.log(
      '$message',
      name: '$tag/${level.name}',
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      },
      error: error,
      stackTrace: stackTrace,
    );
  }
}
