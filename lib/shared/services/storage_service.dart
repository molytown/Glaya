import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // In-memory cache — secure storage reads are platform-channel calls and
  // were being awaited on every API request via the Dio interceptor.
  static String? _cachedToken;
  static String? _cachedRefreshToken;
  static String? _cachedUserId;

  static Future<void> setToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: 'access_token', value: token);
  }

  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    _cachedToken = await _storage.read(key: 'access_token');
    return _cachedToken;
  }

  static Future<void> deleteToken() async {
    _cachedToken = null;
    await _storage.delete(key: 'access_token');
  }

  static Future<void> setRefreshToken(String token) async {
    _cachedRefreshToken = token;
    await _storage.write(key: 'refresh_token', value: token);
  }

  static Future<String?> getRefreshToken() async {
    if (_cachedRefreshToken != null) return _cachedRefreshToken;
    _cachedRefreshToken = await _storage.read(key: 'refresh_token');
    return _cachedRefreshToken;
  }

  static Future<void> deleteRefreshToken() async {
    _cachedRefreshToken = null;
    await _storage.delete(key: 'refresh_token');
  }

  static Future<void> setUserId(String userId) async {
    _cachedUserId = userId;
    await _storage.write(key: 'user_id', value: userId);
  }

  static Future<String?> getUserId() async {
    if (_cachedUserId != null) return _cachedUserId;
    _cachedUserId = await _storage.read(key: 'user_id');
    return _cachedUserId;
  }

  static Future<void> setUserData(String json) async {
    await _storage.write(key: 'user_data', value: json);
  }

  static Future<String?> getUserData() async {
    return _storage.read(key: 'user_data');
  }

  static Future<void> clearAll() async {
    _cachedToken = null;
    _cachedRefreshToken = null;
    _cachedUserId = null;
    await _storage.deleteAll();
  }
}
