import '../entities/user.dart';
import 'dart:io';

abstract class AuthRepository {
  Future<void> requestOtp(String phone);
  Future<User> verifyOtp(String phone, String otp, {bool? rememberMe});
  Future<void> logout();
  Future<User?> getCurrentUser();
  Future<bool> get isAuthenticated;
  Future<String> uploadProfilePhoto(File photoFile);
  Future<User> register({
    required String name,
    required String phone,
    required String password,
    required String role,
    String? referralCode,
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

  Future<User> registerImpl({
    required String name,
    required String phone,
    required String password,
    required String role,
    String? referralCode,
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
  });
}
