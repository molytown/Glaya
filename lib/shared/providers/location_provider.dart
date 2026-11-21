import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/services/api_service.dart';

class LocationState {
  final double? lat;
  final double? lng;
  final bool loading;
  final String? error;
  final String? currency;
  final List<String>? availableCategories;
  final bool inServiceZone;
  final String? locationName;
  final String? countryCode;
  final String? zoneId;
  final String? zoneName;

  const LocationState({
    this.lat,
    this.lng,
    this.loading = false,
    this.error,
    this.currency,
    this.availableCategories,
    this.inServiceZone = false,
    this.locationName,
    this.countryCode,
    this.zoneId,
    this.zoneName,
  });

  bool get hasLocation => lat != null && lng != null;

  LocationState copyWith({
    double? lat,
    double? lng,
    bool? loading,
    String? error,
    String? currency,
    List<String>? availableCategories,
    bool? inServiceZone,
    String? locationName,
    String? countryCode,
    String? zoneId,
    String? zoneName,
  }) {
    return LocationState(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      loading: loading ?? this.loading,
      error: error ?? this.error,
      currency: currency ?? this.currency,
      availableCategories: availableCategories ?? this.availableCategories,
      inServiceZone: inServiceZone ?? this.inServiceZone,
      locationName: locationName ?? this.locationName,
      countryCode: countryCode ?? this.countryCode,
      zoneId: zoneId ?? this.zoneId,
      zoneName: zoneName ?? this.zoneName,
    );
  }
}

class _ZoneContext {
  final String? zoneId;
  final String? zoneName;
  final String? currency;
  final List<String>? categories;
  final String? country;
  const _ZoneContext(
      {this.zoneId,
      this.zoneName,
      this.currency,
      this.categories,
      this.country});
}

const _locationCacheKey = 'glaya_cached_location';

/// Reads the persisted location WITHOUT touching any provider state.
/// Called from main() before runApp so the very first provider builds are
/// already zone-scoped — avoids a full second data-fetch cycle on launch.
Future<LocationState?> readCachedLocation() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_locationCacheKey);
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final lat = (j['lat'] as num?)?.toDouble();
    final lng = (j['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    // Align the API cache zone key so cached content hits immediately.
    final zoneId = j['zoneId'] as String?;
    if (zoneId != null) ApiService.zoneKey = zoneId;
    return LocationState(
      lat: lat,
      lng: lng,
      locationName: j['locationName'] as String?,
      countryCode: j['countryCode'] as String?,
      currency: j['currency'] as String?,
      zoneId: zoneId,
      zoneName: j['zoneName'] as String?,
      availableCategories: (j['categories'] as List?)?.cast<String>(),
      inServiceZone: j['inServiceZone'] == true,
    );
  } catch (_) {
    return null;
  }
}

class LocationNotifier extends StateNotifier<LocationState> {
  final geocoding.Geocoding? _geocoding = kIsWeb ? null : geocoding.Geocoding();

  /// Seeded by main() before runApp — when set, the notifier starts with the
  /// cached location already applied (no async restore gap).
  static LocationState? seedState;

  LocationNotifier() : super(seedState ?? const LocationState(loading: true)) {
    if (seedState != null) {
      _fetchLocation();
    } else {
      // Restore the last known location FIRST so the initial provider fetches
      // are already zone-scoped — avoids a full second data cycle after GPS.
      _restoreCachedLocation().then((_) => _fetchLocation());
    }
  }

  Future<void> _restoreCachedLocation() async {
    final cached = await readCachedLocation();
    if (cached != null) state = cached;
  }

  Future<void> _saveCachedLocation(LocationState s) async {
    try {
      if (s.lat == null || s.lng == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _locationCacheKey,
          jsonEncode({
            'lat': s.lat,
            'lng': s.lng,
            'locationName': s.locationName,
            'countryCode': s.countryCode,
            'currency': s.currency,
            'zoneId': s.zoneId,
            'zoneName': s.zoneName,
            'categories': s.availableCategories,
            'inServiceZone': s.inServiceZone,
          }));
    } catch (_) {}
  }

  Future<void> _fetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = const LocationState(error: 'Location services disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = const LocationState(error: 'Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = const LocationState(
            error: 'Location permission permanently denied');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      // Resolve zone context, location name and country code in parallel,
      // then emit state ONCE — every emission rebuilds all providers that
      // watch locationProvider, so intermediate states cause full reloads.
      final zoneFuture =
          _loadZoneContext(position.latitude, position.longitude);
      final nameFuture =
          _getLocationName(position.latitude, position.longitude);
      final countryFuture =
          _getCountryCode(position.latitude, position.longitude);
      final zone = await zoneFuture;
      final locationName = await nameFuture;
      final countryCode = await countryFuture;
      final currency =
          countryCode != null ? _countryToCurrency[countryCode] : null;

      final next = state.copyWith(
        lat: position.latitude,
        lng: position.longitude,
        loading: false,
        locationName: locationName ?? 'Current location',
        countryCode: countryCode,
        currency: currency ?? zone?.currency ?? state.currency ?? 'XAF',
        zoneId: zone?.zoneId,
        zoneName: zone?.zoneName,
        availableCategories: zone?.categories ?? state.availableCategories,
        inServiceZone: zone != null,
      );

      // Only emit if something meaningful changed — GPS jitter of a few
      // meters shouldn't trigger a full provider reload cycle.
      final prev = state;
      final moved = prev.lat == null ||
          prev.lng == null ||
          Geolocator.distanceBetween(
                  prev.lat!, prev.lng!, position.latitude, position.longitude) >
              500;
      final zoneChanged =
          prev.zoneId != next.zoneId || prev.currency != next.currency;
      if (moved ||
          zoneChanged ||
          prev.locationName != next.locationName ||
          prev.hasLocation == false) {
        state = next;
      }
      await _saveCachedLocation(next);
      print(
          'Location state updated: lat=${position.latitude}, lng=${position.longitude}, name=$locationName, country=$countryCode, currency=$currency');
    } catch (e) {
      print('Failed to fetch location: $e');
      state = LocationState(error: e.toString());
    }
  }

  Future<String?> _getLocationName(double lat, double lng) async {
    // Try native geocoding first (works better on mobile)
    if (!kIsWeb && _geocoding != null) {
      try {
        final placemarks = await _geocoding!.placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final parts = <String>[];

          // Prioritize neighborhood/suburb over street address
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            parts.add(place.subLocality!);
          } else if (place.locality != null && place.locality!.isNotEmpty) {
            parts.add(place.locality!);
          } else if (place.administrativeArea != null &&
              place.administrativeArea!.isNotEmpty) {
            parts.add(place.administrativeArea!);
          }

          // Add city if available and different from neighborhood
          if (place.locality != null &&
              place.locality!.isNotEmpty &&
              !parts.contains(place.locality)) {
            parts.add(place.locality!);
          }

          // Add country
          if (place.country != null && place.country!.isNotEmpty) {
            parts.add(place.country!);
          }

          final locationName = parts.join(', ');
          print('Location name resolved via native geocoding: $locationName');
          return locationName;
        }
      } catch (e) {
        print('Native geocoding failed: $e');
      }
    }

    // Fallback to web-based geocoding (OpenStreetMap Nominatim - free, no API key needed)
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'format': 'json',
        },
      );

      if (response.data != null && response.data['address'] != null) {
        final address = response.data['address'] as Map<String, dynamic>;
        final parts = <String>[];

        // Prioritize neighborhood/suburb over street address
        if (address['suburb'] != null &&
            address['suburb'].toString().isNotEmpty) {
          parts.add(address['suburb']);
        } else if (address['neighbourhood'] != null &&
            address['neighbourhood'].toString().isNotEmpty) {
          parts.add(address['neighbourhood']);
        } else if (address['quarter'] != null &&
            address['quarter'].toString().isNotEmpty) {
          parts.add(address['quarter']);
        }

        // Add city/town/village if available and different from neighborhood
        if (address['city'] != null &&
            address['city'].toString().isNotEmpty &&
            !parts.contains(address['city'])) {
          parts.add(address['city']);
        } else if (address['town'] != null &&
            address['town'].toString().isNotEmpty &&
            !parts.contains(address['town'])) {
          parts.add(address['town']);
        } else if (address['village'] != null &&
            address['village'].toString().isNotEmpty &&
            !parts.contains(address['village'])) {
          parts.add(address['village']);
        } else if (address['locality'] != null &&
            address['locality'].toString().isNotEmpty &&
            !parts.contains(address['locality'])) {
          parts.add(address['locality']);
        }

        // Add state/province if available
        if (address['state'] != null) {
          parts.add(address['state']);
        } else if (address['province'] != null) {
          parts.add(address['province']);
        }

        // Add country
        if (address['country'] != null) {
          parts.add(address['country']);
        }

        final locationName = parts.join(', ');
        print('Location name resolved via Nominatim: $locationName');
        return locationName.isNotEmpty ? locationName : null;
      }
    } catch (e) {
      print('Nominatim geocoding failed: $e');
    }

    // Final fallback to coordinates
    return null;
  }

  Future<String?> _getCountryCode(double lat, double lng) async {
    // Try native geocoding first
    if (!kIsWeb && _geocoding != null) {
      try {
        final placemarks = await _geocoding!.placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          if (place.isoCountryCode != null &&
              place.isoCountryCode!.isNotEmpty) {
            print(
                'Country code resolved via native geocoding: ${place.isoCountryCode}');
            return place.isoCountryCode;
          }
        }
      } catch (e) {
        print('Native country code detection failed: $e');
      }
    }

    // Fallback to Nominatim
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'format': 'json',
        },
      );

      if (response.data != null && response.data['address'] != null) {
        final address = response.data['address'] as Map<String, dynamic>;
        final countryCode = address['country_code'] as String?;
        if (countryCode != null && countryCode.isNotEmpty) {
          print(
              'Country code resolved via Nominatim: ${countryCode.toUpperCase()}');
          return countryCode.toUpperCase();
        }
      }
    } catch (e) {
      print('Nominatim country code detection failed: $e');
    }

    return null;
  }

  /// Fetch zone context without touching state. Returns null on failure.
  Future<_ZoneContext?> _loadZoneContext(double lat, double lng) async {
    try {
      final response =
          await ApiService.dio.get('/config/context', queryParameters: {
        'lat': lat,
        'lng': lng,
      });

      if (response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>?;
        if (data == null) return null;
        final zone = data['zone'] as Map<String, dynamic>?;
        final zones = data['zones'] as List?;
        final firstZone = zone ??
            (zones != null && zones.isNotEmpty
                ? zones.first as Map<String, dynamic>
                : null);
        final serviceAvailability = firstZone?['service_availability'] as Map?;
        final categories = serviceAvailability?['categories'] as List<String>?;

        final zoneId =
            data['zoneId'] as String? ?? firstZone?['id']?.toString();

        // Zone changed → drop cached zone content so fresh items load
        if (zoneId != null && zoneId != ApiService.zoneKey) {
          ApiService.zoneKey = zoneId;
          ApiService.clearContentCache();
        } else if (zoneId != null) {
          ApiService.zoneKey = zoneId;
        }

        return _ZoneContext(
          zoneId: zoneId,
          zoneName: firstZone?['name'] as String?,
          currency: data['currency'] as String?,
          categories: categories,
          country: data['country'] as String?,
        );
      }
    } catch (e) {
      print('Failed to resolve zone context: $e');
    }
    return null;
  }

  /// Resolve zone context (zone + country + currency) in a single call.
  /// Updates currency/categories/zone fields on state. Returns the zone id if matched.
  Future<String?> resolveZoneContext() async {
    final lat = state.lat;
    final lng = state.lng;
    if (lat == null || lng == null) return null;
    final zone = await _loadZoneContext(lat, lng);
    if (zone == null) return null;
    state = state.copyWith(
      currency: zone.currency ?? state.currency,
      availableCategories: zone.categories ?? state.availableCategories,
      inServiceZone: true,
      zoneId: zone.zoneId,
      zoneName: zone.zoneName,
      countryCode: zone.country ?? state.countryCode,
    );
    return state.zoneId;
  }

  Future<void> _fetchZoneInfo(double lat, double lng) async {
    // Use the unified /config/context endpoint: zone + country + currency in one call
    state = state.copyWith(lat: lat, lng: lng);
    await resolveZoneContext();
  }

  Future<void> setLocation(double lat, double lng) async {
    state = state.copyWith(lat: lat, lng: lng, loading: true);

    // Get country code and derive currency FIRST (this is the authoritative source)
    String? countryCode = await _getCountryCode(lat, lng);
    String? currency =
        countryCode != null ? _countryToCurrency[countryCode] : null;

    print('Location: lat=$lat, lng=$lng');
    print('Country code: $countryCode');
    print('Derived currency: $currency');

    // Get location name using reverse geocoding
    String? locationName = await _getLocationName(lat, lng);

    // Fetch zone info but don't let it override the country-derived currency
    await _fetchZoneInfo(lat, lng);

    print('Zone currency: ${state.currency}');

    // Use country-derived currency, fall back to zone currency, then XAF
    final finalCurrency = currency ?? state.currency ?? 'XAF';

    print('Final currency: $finalCurrency');

    state = state.copyWith(
      loading: false,
      locationName: locationName ?? 'Selected location',
      countryCode: countryCode,
      currency: finalCurrency,
    );
    await _saveCachedLocation(state);
  }

  Future<void> refresh() async {
    state = const LocationState(loading: true);
    await _fetchLocation();
  }
}

/// Query params that scope public content calls to the user's current zone.
/// Returns lat/lng, zoneId, country and the zone currency for price conversion.
Map<String, dynamic> zoneQueryParams(LocationState loc) {
  return {
    if (loc.lat != null) 'lat': loc.lat,
    if (loc.lng != null) 'lng': loc.lng,
    if (loc.zoneId != null) 'zoneId': loc.zoneId,
    if (loc.countryCode != null) 'country': loc.countryCode,
    'zoneFilter': 'true',
    if (loc.currency != null) 'userCurrency': loc.currency,
  };
}

final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>(
  (_) => LocationNotifier(),
);

// ISO 3166-1 country code -> ISO 4217 currency code
const _countryToCurrency = <String, String>{
  'NG': 'NGN',
  'GH': 'GHS',
  'KE': 'KES',
  'ZA': 'ZAR',
  'EG': 'EGP',
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
  'JP': 'JPY',
};

String _defaultCurrencyForLocale(String locale) {
  final country = locale.length >= 2
      ? locale.substring(locale.length - 2).toUpperCase()
      : '';
  return _countryToCurrency[country] ?? 'XAF';
}

final userCurrencyProvider = Provider<String?>((ref) {
  final locationState = ref.watch(locationProvider);
  return locationState.currency;
});

final convertedPriceProvider =
    FutureProvider.family<double, ({double amount, String fromCurrency})>(
        (ref, params) async {
  final currency = ref.watch(userCurrencyProvider);
  if (currency == params.fromCurrency) return params.amount;
  try {
    final response =
        await ApiService.dio.get('/currencies/exchange-rate', queryParameters: {
      'from': params.fromCurrency,
      'to': currency,
    });
    final rate =
        (response.data['data']?['rate'] ?? response.data['rate']) as num?;
    if (rate == null) return params.amount;
    return params.amount * rate.toDouble();
  } catch (_) {
    return params.amount;
  }
});
