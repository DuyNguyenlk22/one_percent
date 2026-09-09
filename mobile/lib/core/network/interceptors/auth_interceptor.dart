import 'package:dio/dio.dart';

import '../../constants/api_constants.dart';
import '../../storage/secure_storage.dart';

/// Attaches the bearer token to outgoing requests and clears the session when
/// the backend rejects it.
///
/// The backend guards `/auth/me`, `/habits`, and `/habits/:id/entries` with
/// `JwtAuthGuard`, so every request except login and register needs the header.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required SecureStorage secureStorage, this.onUnauthorized})
      : _secureStorage = secureStorage;

  final SecureStorage _secureStorage;

  /// Invoked after the token is cleared on a 401, so the app can route back to
  /// the login page. Kept as a callback to avoid a dependency on the router.
  final void Function()? onUnauthorized;

  /// Paths that must not carry a token: sending a stale one to `/auth/login`
  /// would have the guard reject a request that should have succeeded.
  static const Set<String> _publicPaths = {
    ApiConstants.login,
    ApiConstants.register,
  };

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_publicPaths.contains(options.path)) {
      final token = await _secureStorage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers[ApiConstants.authorizationHeader] =
            '${ApiConstants.bearerPrefix} $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final isPublic = _publicPaths.contains(err.requestOptions.path);

    // A 401 on login means "wrong password", not "expired session" — leave the
    // stored token alone and let the repository surface the message.
    if ((status == 401 || status == 403) && !isPublic) {
      await _secureStorage.deleteAccessToken();
      onUnauthorized?.call();
    }
    handler.next(err);
  }
}
