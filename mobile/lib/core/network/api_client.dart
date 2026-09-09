import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../errors/exceptions.dart';
import '../utils/logger.dart';

/// The app's single HTTP entry point.
///
/// Wraps Dio so that no feature imports `dio` directly, and translates every
/// [DioException] into an [AppException] using the error envelope produced by
/// the backend's `HttpExceptionFilter`:
///
/// ```json
/// { "statusCode": 401, "isSuccess": false, "timestamp": "...",
///   "path": "/auth/login", "error": "Invalid credentials" }
/// ```
///
/// `error` is a string for most failures and a list of strings when
/// class-validator rejects a DTO.
class ApiClient {
  ApiClient({Dio? dio, List<Interceptor> interceptors = const []})
      : _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      sendTimeout: ApiConstants.sendTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    );
    _dio.interceptors.addAll(interceptors);
  }

  final Dio _dio;

  /// The underlying client, exposed so interceptors can be added at bootstrap.
  Dio get dio => _dio;

  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters}) =>
      _send<T>(() => _dio.get<T>(path, queryParameters: queryParameters), 'GET', path);

  Future<T> post<T>(String path, {Object? data, Map<String, dynamic>? queryParameters}) =>
      _send<T>(
        () => _dio.post<T>(path, data: data, queryParameters: queryParameters),
        'POST',
        path,
      );

  Future<T> patch<T>(String path, {Object? data}) =>
      _send<T>(() => _dio.patch<T>(path, data: data), 'PATCH', path);

  Future<T> put<T>(String path, {Object? data}) =>
      _send<T>(() => _dio.put<T>(path, data: data), 'PUT', path);

  Future<T> delete<T>(String path, {Object? data}) =>
      _send<T>(() => _dio.delete<T>(path, data: data), 'DELETE', path);

  Future<T> _send<T>(
    Future<Response<T>> Function() request,
    String method,
    String path,
  ) async {
    try {
      final response = await request();
      final data = response.data;
      if (data == null) {
        throw ServerException(
          'The server returned an empty response.',
          statusCode: response.statusCode,
        );
      }
      return data;
    } on DioException catch (error) {
      final exception = _toAppException(error);
      Logger.error('$method $path failed', tag: 'ApiClient', error: exception);
      throw exception;
    }
  }

  /// Maps a Dio failure onto the matching [AppException].
  AppException _toAppException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const NetworkException('The request timed out. Please try again.');
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return const NetworkException();
      case DioExceptionType.cancel:
        return const ServerException('The request was cancelled.');
      case DioExceptionType.badCertificate:
        return const ServerException('The server certificate could not be verified.');
      case DioExceptionType.badResponse:
        return _fromResponse(error.response);
    }
  }

  AppException _fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode ?? 0;
    final (message, errors) = _parseErrorBody(response?.data);

    return switch (status) {
      400 || 422 => ValidationException(
          message ?? 'Please check the information you entered.',
          errors: errors,
          statusCode: status,
        ),
      401 || 403 => UnauthorizedException(message ?? 'Your session has expired.'),
      404 => NotFoundException(message ?? 'The requested resource was not found.'),
      _ => ServerException(
          message ?? 'Something went wrong on our end. Please try again.',
          statusCode: status,
        ),
    };
  }

  /// Pulls the message out of the backend's error envelope.
  ///
  /// Returns the display message and, when class-validator returned a list,
  /// the individual field messages.
  (String?, List<String>?) _parseErrorBody(dynamic body) {
    if (body is! Map) return (null, null);
    final error = body['error'] ?? body['message'];

    if (error is String) return (error, null);
    if (error is List) {
      final messages = error.map((item) => '$item').toList();
      return (messages.isEmpty ? null : messages.first, messages);
    }
    return (null, null);
  }
}
