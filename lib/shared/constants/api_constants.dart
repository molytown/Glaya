import '../services/config_service.dart';

class ApiConstants {
  ApiConstants._();

  static String get baseUrl => ConfigService().baseUrl;
  static String get socketUrl => ConfigService().socketUrl;
  static String get googleMapsApiKey => ConfigService().googleMapsApiKey;

  static const Duration connectTimeout = Duration(seconds: 12);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
