import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';
import '../errors/exceptions.dart';

/// Encrypted key-value storage for credentials.
///
/// Backed by the iOS Keychain and Android EncryptedSharedPreferences. Only
/// secrets belong here — the access token and anything derived from it.
/// Preferences go to [LocalStorage] instead.
class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  /// Persists the bearer token issued by `POST /auth/login`.
  Future<void> saveAccessToken(String token) => _write(AppConstants.accessTokenKey, token);

  /// The stored bearer token, or `null` when signed out.
  Future<String?> readAccessToken() => _read(AppConstants.accessTokenKey);

  /// Removes the bearer token. Called on sign-out and on a 401.
  Future<void> deleteAccessToken() => _delete(AppConstants.accessTokenKey);

  /// Whether a token is currently stored.
  Future<bool> hasAccessToken() async {
    final token = await readAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Wipes every secret. Used when signing out.
  Future<void> clear() async {
    try {
      await _storage.deleteAll();
    } on Exception catch (error) {
      throw CacheException('Could not clear secure storage: $error');
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } on Exception catch (error) {
      throw CacheException('Could not write "$key": $error');
    }
  }

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } on Exception catch (error) {
      throw CacheException('Could not read "$key": $error');
    }
  }

  Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key);
    } on Exception catch (error) {
      throw CacheException('Could not delete "$key": $error');
    }
  }
}
