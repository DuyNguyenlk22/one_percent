import 'user_model.dart';

/// The body of `POST /auth/login` and `POST /auth/register`.
///
/// Matches `AuthResponse` in `backend/src/auth/types/auth.types.ts`:
/// `{ accessToken, user }`.
class AuthResponseModel {
  const AuthResponseModel({required this.accessToken, required this.user});

  /// JWT to send as `Authorization: Bearer <token>`.
  final String accessToken;

  final UserModel user;

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      accessToken: json['accessToken'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
