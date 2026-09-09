import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/failures.dart';
import 'package:mobile/core/errors/result.dart';

void main() {
  const failure = ServerFailure('boom', statusCode: 500);

  group('Success', () {
    const result = Success(42);

    test('reports success and exposes its data', () {
      expect(result.isSuccess, isTrue);
      expect(result.isError, isFalse);
      expect(result.dataOrNull, 42);
      expect(result.failureOrNull, isNull);
    });

    test('fold runs the success branch', () {
      expect(result.fold((_) => 'error', (data) => 'got $data'), 'got 42');
    });

    test('map transforms the data', () {
      expect(result.map((data) => data * 2), const Success(84));
    });
  });

  group('ResultError', () {
    const result = ResultError<int>(failure);

    test('reports failure and exposes it', () {
      expect(result.isSuccess, isFalse);
      expect(result.isError, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.failureOrNull, failure);
    });

    test('fold runs the error branch', () {
      expect(result.fold((f) => f.message, (data) => 'got $data'), 'boom');
    });

    test('map leaves the failure untouched and re-types the result', () {
      expect(result.map((data) => data.toString()), const ResultError<String>(failure));
    });
  });

  test('switch over a Result is exhaustive', () {
    String describe(Result<int> result) => switch (result) {
          Success(:final data) => 'ok:$data',
          ResultError(:final failure) => 'err:${failure.message}',
        };

    expect(describe(const Success(1)), 'ok:1');
    expect(describe(const ResultError(failure)), 'err:boom');
  });

  test('failures of the same type and message are equal', () {
    expect(const NetworkFailure('offline'), const NetworkFailure('offline'));
    expect(const NetworkFailure('offline'), isNot(const CacheFailure('offline')));
  });
}
