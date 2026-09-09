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
}
