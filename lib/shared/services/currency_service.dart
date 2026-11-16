import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';

class PriceConversion {
  final double converted;
  final String currency;

  PriceConversion({required this.converted, required this.currency});
}

class CurrencyService {
  static Dio get _dio => ApiService.dio;

  CurrencyService._();
  static final CurrencyService instance = CurrencyService._();

  factory CurrencyService() => instance;

  /// Get user's currency based on geolocation and zone lookup
  static Future<String> getUserCurrency() async {
    try {
      // Check location permission
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _getCurrencyFromLocale();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _getCurrencyFromLocale();
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Lookup zone from coordinates
      final response = await _dio.get(
        '/config/zones/by-coordinates',
        queryParameters: {
          'lat': position.latitude,
          'lng': position.longitude,
        },
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        final zone = response.data['data'] as Map<String, dynamic>;
        return zone['zone_currency'] as String? ?? _getCurrencyFromLocale();
      }
    } catch (e) {
      print('Failed to get currency from location: $e');
    }

    return _getCurrencyFromLocale();
  }

  /// Fallback: get currency from device locale
  static String _getCurrencyFromLocale() {
    try {
      final locale = Platform.localeName ?? 'en_US';
      final countryCode = locale.split('_').last.toUpperCase();

      final countryToCurrency = {
        'NG': 'NGN',
        'GH': 'GHS',
        'KE': 'KES',
        'ZA': 'ZAR',
        'US': 'USD',
        'GB': 'GBP',
        'EU': 'EUR',
        'CA': 'CAD',
        'FR': 'EUR',
        'DE': 'EUR',
        'IT': 'EUR',
        'ES': 'EUR',
        'NL': 'EUR',
        'BE': 'EUR',
        'AE': 'AED',
        'SA': 'SAR',
        'IN': 'INR',
        'CN': 'CNY',
        'JPY': 'JPY',
        'MA': 'MAD',
        'ET': 'ETB',
        'TZ': 'TZS',
        'UG': 'UGX',
        'SN': 'XOF',
        'CI': 'XOF',
        'CM': 'XAF',
        'GA': 'XAF',
        'CG': 'XAF',
        'CD': 'CDF',
        'EG': 'EGP',
        'RW': 'RWF',
        'BF': 'XOF',
        'ML': 'XOF',
        'NE': 'XOF',
        'BJ': 'XOF',
        'TG': 'XOF',
      };

      return countryToCurrency[countryCode] ?? 'XAF';
    } catch (e) {
      print('Failed to get currency from locale: $e');
      return 'XAF';
    }
  }

  /// Get currency symbol
  static String getCurrencySymbol(String currencyCode) {
    final symbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'NGN': '₦',
      'GHS': '₵',
      'KES': 'KSh',
      'ZAR': 'R',
      'XAF': 'FCFA',
      'XOF': 'CFA',
      'CDF': 'FC',
      'RWF': 'RF',
      'ETB': 'Br',
      'TZS': 'TSh',
      'UGX': 'USh',
      'EGP': 'E£',
      'AED': 'د.إ',
      'SAR': '﷼',
      'INR': '₹',
      'CNY': '¥',
      'JPY': '¥',
      'MAD': 'DH',
    };
    return symbols[currencyCode] ?? currencyCode;
  }

  /// Convert price from one currency to another
  Future<PriceConversion> convertPrice(
      double amount, String fromCurrency) async {
    try {
      final userCurrency = await getUserCurrency();
      if (fromCurrency == userCurrency) {
        return PriceConversion(converted: amount, currency: userCurrency);
      }

      final response = await _dio.get(
        '/config/exchange-rates/$fromCurrency/$userCurrency',
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        final raw = response.data['data']['rate'];
        final rate =
            raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 1.0;
        return PriceConversion(
            converted: amount * rate, currency: userCurrency);
      }
    } catch (e) {
      print('Failed to convert price: $e');
    }

    return PriceConversion(converted: amount, currency: fromCurrency);
  }

  /// Convert price from one currency to another (explicit target currency)
  Future<PriceConversion> convertPriceTo(
      double amount, String fromCurrency, String toCurrency) async {
    try {
      if (fromCurrency == toCurrency) {
        return PriceConversion(converted: amount, currency: toCurrency);
      }

      final response = await _dio.get(
        '/config/exchange-rates/$fromCurrency/$toCurrency',
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        final raw = response.data['data']['rate'];
        final rate =
            raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 1.0;
        return PriceConversion(converted: amount * rate, currency: toCurrency);
      }
    } catch (e) {
      print('Failed to convert price: $e');
    }

    return PriceConversion(converted: amount, currency: fromCurrency);
  }

  /// Format price with currency symbol
  String formatPrice(double amount, String currencyCode) {
    final symbol = getCurrencySymbol(currencyCode);
    return '$symbol ${amount.toStringAsFixed(0)}';
  }

  /// Get list of supported currencies
  static List<Map<String, dynamic>> getCurrencies() {
    return [
      {
        'currency_code': 'XAF',
        'currency_symbol': 'FCFA',
        'name': 'Central African CFA Franc'
      },
      {
        'currency_code': 'XOF',
        'currency_symbol': 'CFA',
        'name': 'West African CFA Franc'
      },
      {
        'currency_code': 'NGN',
        'currency_symbol': '₦',
        'name': 'Nigerian Naira'
      },
      {'currency_code': 'GHS', 'currency_symbol': '₵', 'name': 'Ghanaian Cedi'},
      {
        'currency_code': 'KES',
        'currency_symbol': 'KSh',
        'name': 'Kenyan Shilling'
      },
      {
        'currency_code': 'ZAR',
        'currency_symbol': 'R',
        'name': 'South African Rand'
      },
      {'currency_code': 'USD', 'currency_symbol': '\$', 'name': 'US Dollar'},
      {'currency_code': 'EUR', 'currency_symbol': '€', 'name': 'Euro'},
      {'currency_code': 'GBP', 'currency_symbol': '£', 'name': 'British Pound'},
      {
        'currency_code': 'ETB',
        'currency_symbol': 'Br',
        'name': 'Ethiopian Birr'
      },
      {
        'currency_code': 'TZS',
        'currency_symbol': 'TSh',
        'name': 'Tanzanian Shilling'
      },
      {
        'currency_code': 'UGX',
        'currency_symbol': 'USh',
        'name': 'Ugandan Shilling'
      },
      {
        'currency_code': 'EGP',
        'currency_symbol': 'E£',
        'name': 'Egyptian Pound'
      },
      {'currency_code': 'AED', 'currency_symbol': 'د.إ', 'name': 'UAE Dirham'},
      {'currency_code': 'SAR', 'currency_symbol': '﷼', 'name': 'Saudi Riyal'},
      {'currency_code': 'INR', 'currency_symbol': '₹', 'name': 'Indian Rupee'},
      {'currency_code': 'CNY', 'currency_symbol': '¥', 'name': 'Chinese Yuan'},
      {'currency_code': 'JPY', 'currency_symbol': '¥', 'name': 'Japanese Yen'},
      {
        'currency_code': 'MAD',
        'currency_symbol': 'DH',
        'name': 'Moroccan Dirham'
      },
    ];
  }
}
