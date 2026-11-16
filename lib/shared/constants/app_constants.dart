import 'api_constants.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'Glaya';
  static const String appTagline = 'Book beauty, trust the process';

  static const List<String> categories = ['Hair', 'Nails', 'Barber', 'Spa', 'Makeup', 'Lashes', 'Hair Coloring', 'Bridal'];
  static const Map<String, String> categoryIcons = {
    'Hair': 'hair',
    'Nails': 'nails',
    'Barber': 'barber',
    'Spa': 'spa',
    'Makeup': 'makeup',
    'Lashes': 'lashes',
    'Hair Coloring': 'hair_coloring',
    'Bridal': 'bridal',
  };

  // API Configuration - now uses dynamic config from backend
  static String get baseUrl => ApiConstants.baseUrl;
  static String get googleMapsApiKey => ApiConstants.googleMapsApiKey;
}
