import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/services/config_service.dart';
import '../models/zone_response_model.dart';
import '../models/address_model.dart';

class LocationRepository {
  final String baseUrl;
  final String _googleMapApiKey;

  LocationRepository({
    required this.baseUrl,
    required String googleMapApiKey,
  }) : _googleMapApiKey = googleMapApiKey;

  // Read live so the key fetched during background bootstrap is picked up
  // even though the repository is constructed before config finishes loading.
  String get googleMapApiKey {
    final live = ConfigService().googleMapsApiKey;
    return live.isNotEmpty ? live : _googleMapApiKey;
  }

  static LocationRepository? _instance;
  static LocationRepository get instance {
    _instance ??= LocationRepository(
      baseUrl: AppConstants.baseUrl,
      googleMapApiKey: AppConstants.googleMapsApiKey,
    );
    return _instance!;
  }

  Future<http.Response> getZone(String lat, String long) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/config/zone?lat=$lat&long=$long'),
      );
      return response;
    } catch (e) {
      return http.Response('Error: $e', 500);
    }
  }

  Future<ZoneResponseModel?> getCachedZone(String lat, String long) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'zone_cache_${lat}_${long}';
      final cachedData = prefs.getString(cacheKey);
      
      if (cachedData != null) {
        final Map<String, dynamic> jsonData = jsonDecode(cachedData);
        return ZoneResponseModel(
          jsonData['isSuccess'] ?? false,
          jsonData['message'] ?? '',
          List<int>.from(jsonData['zoneIds'] ?? []),
          (jsonData['zoneData'] as List<dynamic>?)
              ?.map((x) => ZoneData.fromJson(x as Map<String, dynamic>))
              .toList() ?? [],
        );
      }
    } catch (e) {
      // Return null on cache error
    }
    return null;
  }

  Future<void> saveZoneToCache(String lat, String long, ZoneResponseModel zoneData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'zone_cache_${lat}_${long}';
      final cacheData = {
        'isSuccess': zoneData.isSuccess,
        'message': zoneData.message,
        'zoneIds': zoneData.zoneIds,
        'zoneData': zoneData.zoneData.map<ZoneData>((x) => x).map((x) => x.toJson()).toList(),
      };
      await prefs.setString(cacheKey, jsonEncode(cacheData));
    } catch (e) {
      // Ignore cache save errors
    }
  }

  Future<String?> getUserAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_address');
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveUserAddress(String address, List<int>? zoneIds, String? lat, String? long) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_address', address);
      if (zoneIds != null) {
        await prefs.setStringList('zone_ids', zoneIds.map((e) => e.toString()).toList());
      }
      if (lat != null) {
        await prefs.setString('user_latitude', lat);
      }
      if (long != null) {
        await prefs.setString('user_longitude', long);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<http.Response> getAddressFromGeocode(LatLng latLng) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${latLng.latitude},${latLng.longitude}&key=$googleMapApiKey'
        ),
      );
      return response;
    } catch (e) {
      return http.Response('Error: $e', 500);
    }
  }

  Future<http.Response> searchLocation(String text) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?searchtext=$text&key=$googleMapApiKey'
        ),
      );
      return response;
    } catch (e) {
      return http.Response('Error: $e', 500);
    }
  }

  Future<http.Response> getPlaceDetails(String? placeID) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json?placeid=$placeID&key=$googleMapApiKey'
        ),
      );
      return response;
    } catch (e) {
      return http.Response('Error: $e', 500);
    }
  }

  Future<http.Response> getAllAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      final response = await http.get(
        Uri.parse('$baseUrl/address'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      return response;
    } catch (e) {
      return http.Response('Error: $e', 500);
    }
  }

  Future<http.Response> addAddress(AddressModel addressModel) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      final response = await http.post(
        Uri.parse('$baseUrl/address'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(addressModel.toJson()),
      );
      return response;
    } catch (e) {
      return http.Response('Error: $e', 500);
    }
  }

  Future<http.Response> updateAddress(AddressModel addressModel, int addressId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      final response = await http.put(
        Uri.parse('$baseUrl/address/$addressId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(addressModel.toJson()),
      );
      return response;
    } catch (e) {
      return http.Response('Error: $e', 500);
    }
  }

  Future<http.Response> removeAddressByID(int? id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/address/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      return response;
    } catch (e) {
      return http.Response('Error: $e', 500);
    }
  }
}
