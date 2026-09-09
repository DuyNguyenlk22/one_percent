/// Domain-level error values returned by repositories.
///
/// A [Failure] is a plain value, not something thrown. Repositories map an
/// [AppException] onto one of these and hand it back inside a `Result`, so the
/// domain and presentation layers stay free of `try`/`catch`.
library;

/// Base class for every error the domain layer can observe.
sealed class Failure {
  const Failure(this.message);

  /// Message suitable for display in the UI.
  final String message;

  @override
  String toString() => '$runtimeType: $message';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure && runtimeType == other.runtimeType && message == other.message;

  @override
  int get hashCode => Object.hash(runtimeType, message);
}

/// The backend was reached but could not fulfil the request.
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});

  final int? statusCode;
}

/// The device is offline or the request timed out.
final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'No internet connection. Please check your network.',
  ]);
}

/// Credentials were rejected, or the session is no longer valid.
final class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Your session has expired. Please sign in again.']);
}

/// Input was rejected, either locally or by the backend.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {this.errors});

  /// Field-level messages, when the backend returned more than one.
  final List<String>? errors;
}

/// The requested resource does not exist.
final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'The requested resource was not found.']);
}

/// Local storage could not be read or written.
final class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Could not read local data.']);
}

/// Nothing else fit. Carries the original error description for logging.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Something went wrong. Please try again.']);
}
