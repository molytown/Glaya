import 'package:dio/dio.dart';
import 'api_service.dart';

class NotchPayService {
  static final Dio _dio = Dio();

  /// Initiate a NotchPay payment
  static Future<Map<String, dynamic>?> initiatePayment({
    required double amount,
    required String currency,
    required String email,
    required String phone,
    required String name,
    required String reference,
    String? description,
  }) async {
    try {
      final response = await ApiService.dio.post('/payments/notchpay/initiate', data: {
        'amount': amount,
        'currency': currency,
        'email': email,
        'phone': phone,
        'name': name,
        'reference': reference,
        'description': description ?? 'Payment for booking',
      });

      if (response.statusCode == 200 && response.data['success']) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      print('Error initiating NotchPay payment: $e');
      return null;
    }
  }

  /// Verify payment status
  static Future<Map<String, dynamic>?> verifyPayment(String reference) async {
    try {
      final response = await ApiService.dio.get('/payments/notchpay/verify/$reference');

      if (response.statusCode == 200 && response.data['success']) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      print('Error verifying NotchPay payment: $e');
      return null;
    }
  }

  /// Check if NotchPay is available and configured
  static Future<bool> isAvailable() async {
    try {
      final response = await ApiService.dio.get('/config/addons/payment_config');
      final gateways = response.data['data'] as List;
      final notchpay = gateways.firstWhere(
        (g) => g['key_name'] == 'notchpay',
        orElse: () => null,
      );

      if (notchpay != null && notchpay['is_active'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      print('Error checking NotchPay availability: $e');
      return false;
    }
  }
}
