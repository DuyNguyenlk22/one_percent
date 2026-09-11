import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

/// Auth calls against the NestJS backend.
///
/// Throws [AppException] on failure — mapping to a `Failure` is the
/// repository's job.
abstract interface class AuthRemoteDataSource {
  /// `POST /auth/login`
  Future<AuthResponseModel> login({required String email, required String password});

  /// `POST /auth/register`
  Future<AuthResponseModel> register({required String email, required String password});

  /// `GET /auth/me`, requires the bearer token.
  Future<UserModel> getCurrentUser();

  /// `POST /auth/forgot-password` — asks the backend to email a reset code.
  ///
  /// Succeeds whether or not the address is registered: the backend answers
  /// identically either way so the response cannot be used to discover who has
  /// an account.
  Future<void> requestPasswordReset({required String email});

  /// `POST /auth/verify-reset-code` — trades the emailed code for a
  /// short-lived reset token.
  Future<String> verifyResetCode({required String email, required String code});

  /// `POST /auth/reset-password` — sets the new password.
  ///
  /// Returns nothing: the backend issues no access token here by design, so the
  /// user signs in again afterwards.
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<AuthResponseModel> login({required String email, required String password}) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiConstants.login,
      data: {'email': email, 'password': password},
    );
    return AuthResponseModel.fromJson(json);
  }

  @override
  Future<AuthResponseModel> register({
    required String email,
    required String password,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiConstants.register,
      data: {'email': email, 'password': password},
    );
    return AuthResponseModel.fromJson(json);
  }

  @override
  Future<UserModel> getCurrentUser() async {
    final json = await _client.get<Map<String, dynamic>>(ApiConstants.me);
    return UserModel.fromJson(json);
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    await _client.post<Map<String, dynamic>>(
      ApiConstants.forgotPassword,
      data: {'email': email},
    );
  }

  @override
  Future<String> verifyResetCode({
    required String email,
    required String code,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiConstants.verifyResetCode,
      data: {'email': email, 'code': code},
    );

    final token = json['resetToken'];
    if (token is! String || token.isEmpty) {
      throw const ServerException('The server did not return a reset token.');
    }
    return token;
  }

  @override
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    await _client.post<Map<String, dynamic>>(
      ApiConstants.resetPassword,
      data: {'resetToken': resetToken, 'newPassword': newPassword},
    );
  }
}
