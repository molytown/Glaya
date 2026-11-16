import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../domain/entities/user.dart';
import '../../data/repositories/auth_repository_impl.dart';

final authRepositoryProvider = Provider<AuthRepositoryImpl>((ref) => AuthRepositoryImpl());

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthRepositoryImpl _repository;

  AuthNotifier(this._repository) : super(const AsyncValue.loading()) {
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      print('[AUTH] Loading user from storage...');
      final user = await _repository.getCurrentUser();
      print('[AUTH] User loaded: ${user?.name}, role: ${user?.role}');
      state = AsyncValue.data(user);
    } catch (e) {
      print('[AUTH] Error loading user: $e');
      // If user is not authenticated (401), set state to null instead of error
      // This allows the router to redirect to login without showing error
      state = const AsyncValue.data(null);
    }
  }

  Future<void> requestOtp(String phone) async {
    await _repository.requestOtp(phone);
  }

  Future<void> verifyOtp(String phone, String otp, {bool? rememberMe}) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.verifyOtp(phone, otp, rememberMe: rememberMe);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> register({
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
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.registerImpl(
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
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> login({
    required String phone,
    required String password,
    bool? rememberMe,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.loginWithPassword(
        phone: phone,
        password: password,
        rememberMe: rememberMe,
      );
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> refreshUser() async {
    try {
      final user = await _repository.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (_) {}
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncValue.data(null);
  }

  Future<String> uploadProfilePhoto(File photoFile) async {
    return await _repository.uploadProfilePhoto(photoFile);
  }

  User? get currentUser => state.valueOrNull;
  bool get isAuthenticated => currentUser != null;
  String? get userRole => currentUser?.role;
}
