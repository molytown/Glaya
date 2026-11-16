import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/api_service.dart';

// Business Settings Providers
final businessSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final response = await ApiService.dio.get('/config/business');
    final settings = response.data['data'] as List;
    return {for (var s in settings) s['key'] as String: s['value'] as String};
  } catch (e) {
    return {};
  }
});

final businessSettingsNotifierProvider =
    StateNotifierProvider<BusinessSettingsNotifier, AsyncValue<void>>((ref) {
  return BusinessSettingsNotifier(ref);
});

class BusinessSettingsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  BusinessSettingsNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> updateSetting(String key, String value) async {
    state = const AsyncValue.loading();
    try {
      await ApiService.dio.put('/config/business/$key', data: {'value': value});
      ref.invalidate(businessSettingsProvider);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

// Payment Gateway Providers
final paymentGatewaysProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final response = await ApiService.dio.get('/config/addons/payment_config');
    return List<Map<String, dynamic>>.from(response.data['data'] ?? []);
  } catch (e) {
    return [];
  }
});

final paymentGatewayNotifierProvider =
    StateNotifierProvider<PaymentGatewayNotifier, AsyncValue<void>>((ref) {
  return PaymentGatewayNotifier(ref);
});

class PaymentGatewayNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  PaymentGatewayNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> updateGateway(String keyName, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      await ApiService.dio.put('/config/addons/$keyName/payment_config', data: data);
      ref.invalidate(paymentGatewaysProvider);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

// Currency Providers
final currenciesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final response = await ApiService.dio.get('/config/currencies?active=true');
    return List<Map<String, dynamic>>.from(response.data['data'] ?? []);
  } catch (e) {
    return [];
  }
});

final currencyNotifierProvider =
    StateNotifierProvider<CurrencyNotifier, AsyncValue<void>>((ref) {
  return CurrencyNotifier(ref);
});

class CurrencyNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  CurrencyNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> addCurrency(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      await ApiService.dio.post('/config/currencies', data: data);
      ref.invalidate(currenciesProvider);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> updateCurrency(String id, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      await ApiService.dio.put('/config/currencies/$id', data: data);
      ref.invalidate(currenciesProvider);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> deleteCurrency(String id) async {
    state = const AsyncValue.loading();
    try {
      await ApiService.dio.delete('/config/currencies/$id');
      ref.invalidate(currenciesProvider);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> refreshExchangeRates() async {
    state = const AsyncValue.loading();
    try {
      await ApiService.dio.post('/config/exchange-rates/refresh');
      ref.invalidate(currenciesProvider);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

// Location Settings Providers
final locationSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final response = await ApiService.dio.get('/config/business');
    final settings = response.data['data'] as List;
    final locationSetting = settings.firstWhere(
      (s) => s['key'] == 'default_location',
      orElse: () => {'value': '{"lat": 3.8480, "lng": 11.5021}'},
    );
    return Map<String, dynamic>.from(
      locationSetting['value'] is String
          ? (locationSetting['value'] as String).startsWith('{')
              ? (locationSetting['value'] as String).startsWith('[')
                  ? {}
                  : (locationSetting['value'] as String).isEmpty
                      ? {}
                      : {}
              : {}
          : locationSetting['value'] ?? {},
    );
  } catch (e) {
    return {'lat': 3.8480, 'lng': 11.5021};
  }
});

final locationSettingsNotifierProvider =
    StateNotifierProvider<LocationSettingsNotifier, AsyncValue<void>>((ref) {
  return LocationSettingsNotifier(ref);
});

class LocationSettingsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  LocationSettingsNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> updateLocation(double lat, double lng) async {
    state = const AsyncValue.loading();
    try {
      await ApiService.dio.put('/config/business/default_location', data: {
        'value': '{"lat": $lat, "lng": $lng}',
        'valueType': 'json',
      });
      ref.invalidate(locationSettingsProvider);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}
