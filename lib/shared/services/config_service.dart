import 'package:dio/dio.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  String? _baseUrl;
  String? _socketUrl;
  String? _googleMapsApiKey;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  // Production URLs - always use these
  static const String _productionBaseUrl = 'https://api.glaya.space/api/v1';
  static const String _productionSocketUrl = 'https://api.glaya.space';

  String get baseUrl => _baseUrl ?? _productionBaseUrl;
  String get socketUrl => _socketUrl ?? _productionSocketUrl;
  String get googleMapsApiKey => _googleMapsApiKey ?? '';

  // Utility method to normalize URLs for production
  String replaceLocalhost(String url) {
    // If URL is already absolute and not localhost, return as-is
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    // If URL is a relative path (e.g., /uploads/...), prepend production socket URL
    if (url.startsWith('/uploads/') || url.startsWith('/uploads\\')) {
      return '$_productionSocketUrl$url';
    }

    // Return as-is for other cases
    return url;
  }

  Future<void> loadConfig({String? overrideBaseUrl}) async {
    // Always use production URLs
    _baseUrl = _productionBaseUrl;
    _socketUrl = _productionSocketUrl;

    // Try to fetch Google Maps API key from backend
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: _productionBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final mapsResponse = await dio.get('/config/google-maps-api-key');
      if (mapsResponse.data['success'] == true) {
        _googleMapsApiKey = mapsResponse.data['data']['apiKey'] as String?;
      }
    } catch (e) {
      // If Google Maps endpoint fails, continue with empty key
      _googleMapsApiKey = '';
    }

    _isLoaded = true;
  }

  void setFallbackConfig({
    String? baseUrl,
    String? socketUrl,
    String? googleMapsApiKey,
  }) {
    _baseUrl = baseUrl ?? _productionBaseUrl;
    _socketUrl = socketUrl ?? _productionSocketUrl;
    _googleMapsApiKey = googleMapsApiKey ?? '';
    _isLoaded = true;
  }

  // Platform-specific configuration - always use production
  void setMobilePlatformConfig(String platform) {
    _baseUrl = _productionBaseUrl;
    _socketUrl = _productionSocketUrl;
    _isLoaded = true;
  }
}
