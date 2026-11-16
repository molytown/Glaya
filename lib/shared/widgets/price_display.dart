import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/location_provider.dart';
import '../services/api_service.dart';

// Currency code to symbol mapping
const _currencySymbols = <String, String>{
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
  'XAF': 'XAF',
  'XOF': 'CFA',
  'NGN': '₦',
  'GHS': '₵',
  'KES': 'KSh',
  'ZAR': 'R',
  'EGP': 'E£',
  'MAD': 'DH',
  'ETB': 'Br',
  'TZS': 'TSh',
  'UGX': 'USh',
  'CDF': 'FC',
  'AED': 'د.إ',
  'SAR': '﷼',
  'INR': '₹',
  'CNY': '¥',
  'JPY': '¥',
  'CAD': 'C\$',
};

String _getCurrencySymbol(String currencyCode) {
  return _currencySymbols[currencyCode] ?? currencyCode;
}

class PriceDisplay extends ConsumerWidget {
  final double amount;
  final String? fromCurrency;
  final TextStyle? style;
  final String fallbackCurrency;

  const PriceDisplay({
    super.key,
    required this.amount,
    this.fromCurrency,
    this.style,
    this.fallbackCurrency = 'XAF',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userCurrency = ref.watch(userCurrencyProvider);
    final sourceCurrency = fromCurrency ?? fallbackCurrency;
    final targetCurrency = userCurrency ?? fallbackCurrency;

    // If currencies are the same, display directly
    if (sourceCurrency == targetCurrency) {
      return Text(
        _formatPrice(amount, targetCurrency),
        style: style,
      );
    }

    // Otherwise, fetch converted price
    return FutureBuilder<double>(
      future: _convertPrice(amount, sourceCurrency, targetCurrency),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Text(
            _formatPrice(snapshot.data!, targetCurrency),
            style: style,
          );
        }
        // Show original price while loading
        return Text(
          _formatPrice(amount, sourceCurrency),
          style: style,
        );
      },
    );
  }

  String _formatPrice(double price, String? currency) {
    final symbol = _getCurrencySymbol(currency ?? 'USD');
    return '$symbol${price.toStringAsFixed(0)}';
  }

  Future<double> _convertPrice(double amount, String from, String to) async {
    if (from == to) return amount;
    try {
      final response = await ApiService.dio.get('/currencies/exchange-rate', queryParameters: {
        'from': from,
        'to': to,
      });
      final rate = (response.data['data']?['rate'] ?? response.data['rate']) as num?;
      if (rate == null) return amount;
      return amount * rate.toDouble();
    } catch (_) {
      return amount;
    }
  }
}

// Helper function to convert price synchronously (for use in non-widget contexts)
Future<double> convertPrice(double amount, String fromCurrency, String toCurrency) async {
  if (fromCurrency == toCurrency) return amount;
  
  try {
    final dio = ApiService.dio;
    final response = await dio.get('/currencies/exchange-rate', queryParameters: {
      'from': fromCurrency,
      'to': toCurrency,
    });
    final rate = (response.data['data']?['rate'] ?? response.data['rate']) as num?;
    if (rate == null) return amount;
    return amount * rate.toDouble();
  } catch (_) {
    return amount;
  }
}

// Format price with currency symbol
String formatPriceWithCurrency(double amount, String currency) {
  final symbol = _getCurrencySymbol(currency);
  return '$symbol${amount.toStringAsFixed(0)}';
}
