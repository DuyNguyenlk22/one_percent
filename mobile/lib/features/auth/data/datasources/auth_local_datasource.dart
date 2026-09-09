import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/storage/secure_storage.dart';
import '../models/user_model.dart';

/// The session as it is held on the device.
///
/// The token goes to encrypted storage; the cached user profile — which is not
/// a secret — goes to plain preferences, so the app can render a name before
/// `/auth/me` returns.
abstract interface class AuthLocalDataSource {
  Future<void> cacheSession({required String accessToken, required UserModel user});

  Future<String?> getAccessToken();

  /// The cached profile, or `null` on a cache miss.
  Future<UserModel?> getCachedUser();

  Future<void> cacheUser(UserModel user);

  /// Removes the token and the cached profile.
  Future<void> clearSession();

  Future<bool> hasSession();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  const AuthLocalDataSourceImpl({
    required SecureStorage secureStorage,
    required LocalStorage localStorage,
  })  : _secureStorage = secureStorage,
        _localStorage = localStorage;

  final SecureStorage _secureStorage;
  final LocalStorage _localStorage;

  @override
  Future<void> cacheSession({
    required String accessToken,
    required UserModel user,
  }) async {
    await _secureStorage.saveAccessToken(accessToken);
    await cacheUser(user);
  }

  @override
  Future<String?> getAccessToken() => _secureStorage.readAccessToken();

  @override
  Future<void> cacheUser(UserModel user) =>
      _localStorage.setJson(AppConstants.cachedUserKey, user.toJson());

  @override
  Future<UserModel?> getCachedUser() async {
    final json = _localStorage.getJson(AppConstants.cachedUserKey);
    if (json == null) return null;
    try {
      return UserModel.fromJson(json);
    } on Exception {
      // The cached shape no longer parses — drop it and treat it as a miss.
      await _localStorage.remove(AppConstants.cachedUserKey);
      return null;
    }
  }

  @override
  Future<void> clearSession() async {
    await _secureStorage.deleteAccessToken();
    await _localStorage.remove(AppConstants.cachedUserKey);
  }

  @override
  Future<bool> hasSession() async {
    try {
      return await _secureStorage.hasAccessToken();
    } on CacheException {
      return false;
    }
  }
}
