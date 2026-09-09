/// Low-level errors thrown by data sources.
///
/// Exceptions never cross the repository boundary — [AuthRepositoryImpl] and
/// its siblings catch them and translate them into a [Failure] carried by a
/// `Result`. Presentation code therefore never handles an exception directly.
library;

/// Base class for every exception raised inside the data layer.
sealed class AppException implements Exception {
  const AppException(this.message, {this.statusCode});

  /// Human-readable description, safe to surface to the user.
  final String message;

  /// HTTP status code when the exception originated from an API call.
  final int? statusCode;

  @override
  String toString() => '$runtimeType($statusCode): $message';
}

/// The API responded with a 5xx status, or with a body we could not parse.
final class ServerException extends AppException {
  const ServerException(super.message, {super.statusCode});
}

/// The request never reached the API: no connectivity, DNS failure, timeout.
final class NetworkException extends AppException {
  const NetworkException([
    super.message = 'No internet connection. Please check your network.',
  ]);
}

/// The API rejected the credentials or the bearer token (401 / 403).
final class UnauthorizedException extends AppException {
  const UnauthorizedException([
    super.message = 'Your session has expired. Please sign in again.',
  ]) : super(statusCode: 401);
}

/// The API rejected the payload (400 / 422), usually class-validator output.
final class ValidationException extends AppException {
  const ValidationException(super.message, {this.errors, super.statusCode});

  /// Field-level messages returned by the backend, when it sent a list.
  final List<String>? errors;
}

/// The requested resource does not exist (404).
final class NotFoundException extends AppException {
  const NotFoundException([super.message = 'The requested resource was not found.'])
      : super(statusCode: 404);
}

/// Reading from or writing to device storage failed.
final class CacheException extends AppException {
  const CacheException([super.message = 'Could not read local data.']);
}
