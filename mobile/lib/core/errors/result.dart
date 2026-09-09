import 'failures.dart';

/// The value a repository returns: either a [Success] carrying data, or a
/// [ResultError] carrying a [Failure].
///
/// This is the project's alternative to `Either` from dartz/fpdart. Because it
/// is a Dart 3 sealed class, `switch` over a `Result` is exhaustive — the
/// compiler rejects a call site that forgets to handle one of the two cases.
///
/// ```dart
/// final result = await repository.login(email: email, password: password);
/// switch (result) {
///   case Success(:final data):
///     state = state.copyWith(user: data);
///   case ResultError(:final failure):
///     state = state.copyWith(errorMessage: failure.message);
/// }
/// ```
sealed class Result<T> {
  const Result();

  /// Wraps a successful value.
  const factory Result.success(T data) = Success<T>;

  /// Wraps a [Failure].
  const factory Result.error(Failure failure) = ResultError<T>;

  /// Whether this result carries data.
  bool get isSuccess => this is Success<T>;

  /// Whether this result carries a [Failure].
  bool get isError => this is ResultError<T>;

  /// The data when successful, otherwise `null`.
  T? get dataOrNull => switch (this) {
        Success<T>(:final data) => data,
        ResultError<T>() => null,
      };

  /// The failure when unsuccessful, otherwise `null`.
  Failure? get failureOrNull => switch (this) {
        Success<T>() => null,
        ResultError<T>(:final failure) => failure,
      };

  /// Collapses both cases into a single value.
  R fold<R>(R Function(Failure failure) onError, R Function(T data) onSuccess) {
    return switch (this) {
      Success<T>(:final data) => onSuccess(data),
      ResultError<T>(:final failure) => onError(failure),
    };
  }

  /// Transforms the data of a [Success], leaving a [ResultError] untouched.
  Result<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      Success<T>(:final data) => Success<R>(transform(data)),
      ResultError<T>(:final failure) => ResultError<R>(failure),
    };
  }
}

/// A [Result] holding a value.
final class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Success<T> && data == other.data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Success($data)';
}

/// A [Result] holding a [Failure].
final class ResultError<T> extends Result<T> {
  const ResultError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ResultError<T> && failure == other.failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'ResultError($failure)';
}
