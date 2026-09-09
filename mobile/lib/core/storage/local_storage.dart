import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../errors/exceptions.dart';

/// Plain, unencrypted key-value storage for preferences and cached payloads.
///
/// Never store a token or a password here — that is [SecureStorage]'s job.
/// The instance is created once during bootstrap and injected, so no call site
/// pays for `SharedPreferences.getInstance()` twice.
class LocalStorage {
  LocalStorage(this._preferences);

  final SharedPreferences _preferences;

  /// Resolves the platform preference store. Called once from `main()`.
  static Future<LocalStorage> create() async =>
      LocalStorage(await SharedPreferences.getInstance());

  String? getString(String key) => _preferences.getString(key);

  Future<void> setString(String key, String value) => _guard(
        () => _preferences.setString(key, value),
        key,
      );

  bool getBool(String key, {bool defaultValue = false}) =>
      _preferences.getBool(key) ?? defaultValue;

  Future<void> setBool(String key, {required bool value}) => _guard(
        () => _preferences.setBool(key, value),
        key,
      );

  int? getInt(String key) => _preferences.getInt(key);

  Future<void> setInt(String key, int value) => _guard(
        () => _preferences.setInt(key, value),
        key,
      );

  /// Reads a JSON object previously written with [setJson].
  ///
  /// Returns `null` when the key is absent or the stored text is no longer
  /// valid JSON — a cache miss, not an error worth crashing over.
  Map<String, dynamic>? getJson(String key) {
    final raw = _preferences.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Stores a JSON-encodable object.
  Future<void> setJson(String key, Map<String, dynamic> value) =>
      setString(key, jsonEncode(value));

  Future<void> remove(String key) => _guard(() => _preferences.remove(key), key);

  Future<void> clear() => _guard(_preferences.clear, 'all');

  Future<void> _guard(Future<bool> Function() write, String key) async {
    try {
      await write();
    } on Exception catch (error) {
      throw CacheException('Could not write "$key": $error');
    }
  }
}
