import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';

class LocationService {
  static final Dio _dio = Dio();

  /// Check if location permissions are granted
  static Future<bool> hasLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are permanently denied');
      return false;
    }

    return true;
  }

  /// Get current position
  static Future<Position?> getCurrentPosition() async {
    try {
      if (!await hasLocationPermission()) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return position;
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }

  /// Get continuous position updates
  static Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }

  /// Calculate distance between two coordinates in meters
  static double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Calculate distance between two positions in meters
  static double calculateDistanceBetweenPositions(
    Position start,
    Position end,
  ) {
    return calculateDistance(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  /// Geocode address to coordinates using Google Maps API
  static Future<LatLng?> geocodeAddress(String address) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'address': address,
          'key': await _getGoogleMapsApiKey(),
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'] as List;
        if (results.isNotEmpty) {
          final location = results[0]['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error geocoding address: $e');
      return null;
    }
  }

  /// Reverse geocode coordinates to address using Google Maps API
  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '$lat,$lng',
          'key': await _getGoogleMapsApiKey(),
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'] as List;
        if (results.isNotEmpty) {
          return results[0]['formatted_address'] as String;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
      return null;
    }
  }

  /// Get Google Maps API key from backend config
  static Future<String> _getGoogleMapsApiKey() async {
    try {
      final response = await ApiService.dio.get('/config/location/default');
      final location = response.data['data'];
      // For now, return empty string - the API key should be configured in backend
      return '';
    } catch (e) {
      debugPrint('Error getting Google Maps API key: $e');
      return '';
    }
  }

  /// Get default location from backend
  static Future<LatLng?> getDefaultLocation() async {
    try {
      final response = await ApiService.dio.get('/config/location/default');
      final location = response.data['data'];
      if (location != null &&
          location['lat'] != null &&
          location['lng'] != null) {
        return LatLng(location['lat'], location['lng']);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting default location: $e');
      return const LatLng(3.8480, 11.5021); // Default to Douala, Cameroon
    }
  }

  /// Check if a location is within a given radius (in meters)
  static bool isWithinRadius(
    double centerLat,
    double centerLng,
    double targetLat,
    double targetLng,
    double radiusMeters,
  ) {
    final distance = calculateDistance(
      centerLat,
      centerLng,
      targetLat,
      targetLng,
    );
    return distance <= radiusMeters;
  }

  /// Open location in Google Maps app
  static Future<void> openInGoogleMaps(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    // TODO: Use url_launcher to open the URL
    debugPrint('Opening Google Maps: $url');
  }

  /// Get directions between two points
  static Future<void> getDirections(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&origin=$startLat,$startLng&destination=$endLat,$endLng';
    // TODO: Use url_launcher to open the URL
    debugPrint('Getting directions: $url');
  }
}
