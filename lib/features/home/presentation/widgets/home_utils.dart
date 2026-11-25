import 'package:flutter/material.dart';
import '../../../discovery/data/professional_model.dart';
import '../../../discovery/domain/professional.dart';

Color colorFromHex(String hex) {
  final buffer = StringBuffer();
  if (hex.length == 6 || hex.length == 7) buffer.write('ff');
  buffer.write(hex.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

double professionalRating(int trustScore) =>
    (trustScore / 20.0).clamp(3.0, 5.0);

double professionalDisplayRating(Professional professional) {
  final avg = professional.avgRating;
  if (avg != null && avg > 0) return avg;
  if (professional.trustScore > 0) {
    return (professional.trustScore / 20.0).clamp(0.0, 5.0);
  }
  return 0.0;
}

String professionalPriceLabel(ProfessionalModel professional) {
  // Get currency symbol from professional's currency
  final currency = professional.currency ?? 'XAF';
  final symbol = _getCurrencySymbol(currency);

  if (professional.services?.isNotEmpty == true) {
    return '$symbol${professional.services!.first.price.toStringAsFixed(0)}+';
  }
  return '${symbol}30+';
}

String _getCurrencySymbol(String currencyCode) {
  const symbols = <String, String>{
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
  return symbols[currencyCode] ?? currencyCode;
}
