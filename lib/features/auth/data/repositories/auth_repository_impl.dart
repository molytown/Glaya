import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../../../../../shared/services/api_service.dart';
import '../../../../../shared/services/storage_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  Dio get _dio => ApiService.dio;

  Future<String?> _getFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  String _deviceType() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'android'; // Default fallback
  }

  @override
  Future<void> requestOtp(String phone) async {
    await _dio.post('/auth/request-otp', data: {'phone': phone});
  }

  @override
  Future<User> verifyOtp(String phone, String otp,
      {bool? rememberMe, String? ambassadorCode, String? referralCode}) async {
    final fcmToken = await _getFcmToken();
    final response = await _dio.post('/auth/verify-otp', data: {
      'phone': phone,
      'otp': otp,
      if (ambassadorCode != null) 'ambassadorCode': ambassadorCode,
      if (referralCode != null) 'referralCode': referralCode,
      if (fcmToken != null) 'fcmToken': fcmToken,
      if (fcmToken != null) 'deviceType': _deviceType(),
      if (rememberMe != null) 'rememberMe': rememberMe,
    });

    final data = response.data['data'] as Map<String, dynamic>;
    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String;
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

    await _storeSession(accessToken, refreshToken, user, rememberMe);

    return user;
  }

  @override
  Future<User> register({
    required String name,
    required String phone,
    required String password,
    required String role,
    String? referralCode,
    String? ambassadorCode,
    double? latitude,
    double? longitude,
    String? fullAddress,
    // Professional fields
    String? email,
    String? businessName,
    List<String>? categoryIds,
    String? country,
    String? regionState,
    String? city,
    String? neighborhood,
    String? photoUrl,
    bool? rememberMe,
  }) {
    return registerImpl(
      name: name,
      phone: phone,
      password: password,
      role: role,
      referralCode: referralCode,
      ambassadorCode: ambassadorCode,
      latitude: latitude,
      longitude: longitude,
      fullAddress: fullAddress,
      email: email,
      businessName: businessName,
      categoryIds: categoryIds,
      country: country,
      state: regionState,
      city: city,
      neighborhood: neighborhood,
      photoUrl: photoUrl,
      rememberMe: rememberMe,
    );
  }

  @override
  Future<User> registerImpl({
    required String name,
    required String phone,
    required String password,
    required String role,
    String? referralCode,
    String? ambassadorCode,
    double? latitude,
    double? longitude,
    String? fullAddress,
    // Professional fields
    String? email,
    String? businessName,
    List<String>? categoryIds,
    String? country,
    String? state,
    String? city,
    String? neighborhood,
    String? photoUrl,
    bool? rememberMe,
  }) async {
    final fcmToken = await _getFcmToken();
    final data = {
      'name': name,
      'phone': phone,
      'password': password,
      'role': role,
      if (referralCode != null) 'referralCode': referralCode,
      if (ambassadorCode != null) 'ambassadorCode': ambassadorCode,
      if (fcmToken != null) 'fcmToken': fcmToken,
      if (fcmToken != null) 'deviceType': _deviceType(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (fullAddress != null) 'fullAddress': fullAddress,
      // Professional fields
      if (email != null) 'email': email,
      if (businessName != null) 'businessName': businessName,
      if (categoryIds != null && categoryIds.isNotEmpty)
        'categoryIds': categoryIds,
      if (country != null) 'country': country,
      if (state != null && state.isNotEmpty) 'state': state,
      if (city != null) 'city': city,
      if (neighborhood != null) 'neighborhood': neighborhood,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (rememberMe != null) 'rememberMe': rememberMe,
    };

    final response = await _dio.post('/auth/register', data: data);

    final responseData = response.data['data'] as Map<String, dynamic>;
    final accessToken = responseData['accessToken'] as String;
    final refreshToken = responseData['refreshToken'] as String;
    final user =
        UserModel.fromJson(responseData['user'] as Map<String, dynamic>);

    await _storeSession(accessToken, refreshToken, user, rememberMe);

    return user;
  }

  Future<User> loginWithPassword({
    required String phone,
    required String password,
    bool? rememberMe,
  }) async {
    final fcmToken = await _getFcmToken();
    final response = await _dio.post('/auth/login', data: {
      'phone': phone,
      'password': password,
      if (fcmToken != null) 'fcmToken': fcmToken,
      if (fcmToken != null) 'deviceType': _deviceType(),
      if (rememberMe != null) 'rememberMe': rememberMe,
    });

    final data = response.data['data'] as Map<String, dynamic>;
    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String;
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

    await _storeSession(accessToken, refreshToken, user, rememberMe);

    return user;
  }

  /// Persists the session. When [rememberMe] is explicitly false the refresh
  /// token is dropped so the session ends with the (short-lived) access token.
  Future<void> _storeSession(
    String accessToken,
    String refreshToken,
    UserModel user,
    bool? rememberMe,
  ) async {
    await StorageService.setToken(accessToken);
    if (rememberMe == false) {
      await StorageService.deleteRefreshToken();
    } else {
      await StorageService.setRefreshToken(refreshToken);
    }
    await StorageService.setUserId(user.id);
    await StorageService.setUserData(jsonEncode(user.toJson()));
  }

  @override
  Future<void> logout() async {
    try {
      final refreshToken = await StorageService.getRefreshToken();
      if (refreshToken != null) {
        await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
      }
    } catch (_) {}
    await StorageService.clearAll();
  }

  @override
  Future<String> uploadProfilePhoto(File photoFile) async {
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(photoFile.path),
    });
    final response = await _dio.post('/auth/upload', data: formData);
    final url = response.data['data']['url'] as String;

    // Update cached user so the header avatar refreshes without re-login
    final cached = await StorageService.getUserData();
    if (cached != null) {
      try {
        final map = jsonDecode(cached) as Map<String, dynamic>;
        map['photoUrl'] = url;
        await StorageService.setUserData(jsonEncode(map));
      } catch (_) {}
    }
    return url;
  }

  @override
  Future<User?> getCurrentUser() async {
    final token = await StorageService.getToken();
    print(
        '[AUTH_REPO] Token from storage: ${token != null ? "exists" : "null"}');
    if (token == null) {
      await StorageService.clearAll();
      return null;
    }

    // Use cached user data (like web app) - no API call on app start
    print('[AUTH_REPO] Using cached user data');
    final cached = await StorageService.getUserData();
    if (cached != null) {
      try {
        return UserModel.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      } catch (e) {
        print('[AUTH_REPO] Failed to parse cached user: $e');
        await StorageService.clearAll();
        return null;
      }
    }

    // No cached data but token exists - clear storage
    print('[AUTH_REPO] No cached user data, clearing storage');
    await StorageService.clearAll();
    return null;
  }

  /// Fetches the latest profile from the API and updates the cached user
  /// so auth state (header avatar, etc.) reflects server-side changes like
  /// a newly uploaded photo. Returns null on failure — callers should fall
  /// back to the cached user.
  Future<User?> fetchCurrentUser() async {
    final token = await StorageService.getToken();
    if (token == null) return null;
    try {
      final response = await _dio.get('/users/me');
      final data = response.data['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      final json = Map<String, dynamic>.from(data);
      // /users/me nests the professional under a relation, not a flat id
      final professional = json['professional'] as Map<String, dynamic>?;
      json['professionalId'] ??= professional?['id']?.toString();
      final user = UserModel.fromJson(json);
      await StorageService.setUserId(user.id);
      await StorageService.setUserData(jsonEncode(user.toJson()));
      return user;
    } catch (e) {
      print('[AUTH_REPO] fetchCurrentUser failed: $e');
      return null;
    }
  }

  @override
  Future<bool> get isAuthenticated async {
    final token = await StorageService.getToken();
    return token != null;
  }
}
