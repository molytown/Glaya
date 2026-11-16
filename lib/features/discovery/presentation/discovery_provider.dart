import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/professional_model.dart';
import '../data/promotion_model.dart';
import '../data/trending_service_model.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/currency_service.dart';
import '../../../../shared/providers/location_provider.dart';
import '../../auth/presentation/providers/auth_notifier.dart';

final professionalsProvider = FutureProvider.family<List<ProfessionalModel>, String?>((ref, category) async {
  final loc = ref.watch(locationProvider);
  final dio = ApiService.dio;
  final response = await dio.get('/professionals', queryParameters: {
    if (category != null) 'category': category.toLowerCase(),
    ...zoneQueryParams(loc),
  });
  final data = response.data['data'] as List<dynamic>;
  return data.map((e) => ProfessionalModel.fromJson(e as Map<String, dynamic>)).toList();
});

final homeCategoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ApiService.dio.get('/categories/public');
  final data = (response.data['data'] as List<dynamic>? ?? [])
      .where((c) => c is Map && c['isActive'] != false)
      .cast<Map<String, dynamic>>()
      .toList();
  data.sort((a, b) =>
      ((a['displayOrder'] as num?) ?? 0).compareTo((b['displayOrder'] as num?) ?? 0));
  return data;
});

final activePromotionsProvider = FutureProvider<List<PromotionModel>>((ref) async {
  final loc = ref.watch(locationProvider);
  final dio = ApiService.dio;
  final response = await dio.get('/promotions/active', queryParameters: zoneQueryParams(loc));
  final data = response.data['data'] as List<dynamic>;
  return data.map((e) => PromotionModel.fromJson(e as Map<String, dynamic>)).toList();
});

// New providers for enhanced discovery sections
class NearbyProfessionalsNotifier extends StateNotifier<AsyncValue<List<ProfessionalModel>>> {
  NearbyProfessionalsNotifier(this._ref) : super(const AsyncValue.loading());

  final Ref _ref;

  String? _lastLat;
  String? _lastLng;

  Future<void> fetchNearby(double lat, double lng) async {
    // Only fetch if location changed significantly
    final latStr = lat.toStringAsFixed(6);
    final lngStr = lng.toStringAsFixed(6);
    
    if (_lastLat == latStr && _lastLng == lngStr && !state.isLoading) {
      return; // Skip duplicate requests
    }
    
    _lastLat = latStr;
    _lastLng = lngStr;
    
    state = const AsyncValue.loading();
    print('NearbyProfessionalsProvider: Fetching with location: lat=$lat, lng=$lng');
    
    try {
      final dio = ApiService.dio;
      final loc = _ref.read(locationProvider);
      final response = await dio.get('/professionals', queryParameters: {
        'lat': lat,
        'lng': lng,
        'radiusKm': 10,
        'sortBy': 'distance',
        ...zoneQueryParams(loc),
      });
      print('NearbyProfessionalsProvider: API response status: ${response.statusCode}');
      final data = response.data['data'] as List<dynamic>;
      print('NearbyProfessionalsProvider: Parsed ${data.length} nearby professionals');
      state = AsyncValue.data(data.map((e) => ProfessionalModel.fromJson(e as Map<String, dynamic>)).toList());
    } catch (e, stack) {
      print('NearbyProfessionalsProvider: Error fetching nearby professionals: $e');
      state = AsyncValue.error(e, stack);
    }
  }
}

final nearbyProfessionalsProvider = StateNotifierProvider<NearbyProfessionalsNotifier, AsyncValue<List<ProfessionalModel>>>(
  (ref) => NearbyProfessionalsNotifier(ref),
);

final topRatedProfessionalsProvider = FutureProvider<List<ProfessionalModel>>((ref) async {
  final loc = ref.watch(locationProvider);
  final dio = ApiService.dio;
  final response = await dio.get('/professionals', queryParameters: {
    'sortBy': 'trust_score',
    'limit': 10,
    ...zoneQueryParams(loc),
  });
  final data = response.data['data'] as List<dynamic>;
  return data.map((e) => ProfessionalModel.fromJson(e as Map<String, dynamic>)).toList();
});

final recommendedProfessionalsProvider = FutureProvider<List<ProfessionalModel>>((ref) async {
  final loc = ref.watch(locationProvider);
  final dio = ApiService.dio;
  final response = await dio.get('/professionals', queryParameters: {
    'sortBy': 'trust_score',
    'featured': true,
    'limit': 8,
    ...zoneQueryParams(loc),
  });
  final data = response.data['data'] as List<dynamic>;
  return data.map((e) => ProfessionalModel.fromJson(e as Map<String, dynamic>)).toList();
});

final trendingStylesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final loc = ref.watch(locationProvider);
  final dio = ApiService.dio;
  final response = await dio.get('/engagement/trending', queryParameters: zoneQueryParams(loc));
  final data = response.data['data'] as List<dynamic>;
  return data.map((e) => e as Map<String, dynamic>).toList();
});

// Popular Services: reads actual service-card data from the services endpoint
final popularServicesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final loc = ref.watch(locationProvider);
  final dio = ApiService.dio;
  final userCurrency = loc.currency ?? await CurrencyService.getUserCurrency();
  final response = await dio.get('/services/public', queryParameters: {
    'sortBy': 'popular',
    'limit': 10,
    'userCurrency': userCurrency,
    ...zoneQueryParams(loc),
  });
  final data = response.data['data'] as List<dynamic>;
  return data
      .take(10)
      .map((e) => e as Map<String, dynamic>)
      .toList();
});

// All Popular Services: full list ranked by booking popularity for the See-All page
final allPopularServicesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final loc = ref.watch(locationProvider);
  final dio = ApiService.dio;
  final userCurrency = loc.currency ?? await CurrencyService.getUserCurrency();
  final response = await dio.get('/services/public', queryParameters: {
    'sortBy': 'popular',
    'limit': 50,
    'userCurrency': userCurrency,
    ...zoneQueryParams(loc),
  });
  final data = response.data['data'] as List<dynamic>;
  return data
      .map((e) => e as Map<String, dynamic>)
      .toList();
});

// Home Service Professionals: professionals who offer home service
final homeServiceProfessionalsProvider = FutureProvider.family<List<ProfessionalModel>, ({double lat, double lng})>((ref, location) async {
  final loc = ref.watch(locationProvider);
  final dio = ApiService.dio;
  print('Fetching home service professionals with location: lat=${location.lat}, lng=${location.lng}');
  try {
    final response = await dio.get('/professionals', queryParameters: {
      'lat': location.lat,
      'lng': location.lng,
      'radiusKm': 50,
      'homeService': true,
      'limit': 6,
      'include': 'services',
      ...zoneQueryParams(loc),
    });
    print('Home service API response status: ${response.statusCode}');
    final data = response.data['data'] as List<dynamic>;
    print('Parsed ${data.length} home service professionals');
    return data.map((e) => ProfessionalModel.fromJson(e as Map<String, dynamic>)).toList();
  } catch (e, stack) {
    print('Error fetching home service professionals: $e');
    print('Stack trace: $stack');
    rethrow;
  }
});

// Trending Now: reads the dedicated trending-now endpoint (title, priceFrom, imageUrl, category, serviceId)
final trendingNowProvider = FutureProvider<List<TrendingServiceModel>>((ref) async {
  final loc = ref.watch(locationProvider);
  final dio = ApiService.dio;
  final response = await dio.get('/engagement/trending-now', queryParameters: {
    ...zoneQueryParams(loc),
    'dynamic': '1',
  });
  final data = response.data['data'] as List<dynamic>;
  return data.map((e) => TrendingServiceModel.fromJson(e as Map<String, dynamic>)).toList();
});

final heroSlidesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final loc = ref.watch(locationProvider);
  print('[Hero Provider] Fetching hero slides from /hero');
  final response = await ApiService.dio.get('/hero', queryParameters: zoneQueryParams(loc));
  print('[Hero Provider] Response status: ${response.statusCode}');
  final data = response.data['data'] as List<dynamic>;
  print('[Hero Provider] Parsed ${data.length} slides');
  return data.map((e) => e as Map<String, dynamic>).toList();
});

final customerReviewsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final loc = ref.watch(locationProvider);
  try {
    final response = await ApiService.dio.get('/engagement/reviews', queryParameters: zoneQueryParams(loc));
    final data = response.data['data'] as List<dynamic>;
    return data.map((e) => e as Map<String, dynamic>).toList();
  } catch (_) {
    return [];
  }
});

final howItWorksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final loc = ref.watch(locationProvider);
  final dio = ApiService.dio;
  final response = await dio.get('/engagement/how-it-works', queryParameters: zoneQueryParams(loc));
  final data = response.data['data'] as List<dynamic>;
  return data.map((e) => e as Map<String, dynamic>).toList();
});

final whyChooseGlayaProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final loc = ref.watch(locationProvider);
  final dio = ApiService.dio;
  final response = await dio.get('/engagement/why-choose-glaya', queryParameters: zoneQueryParams(loc));
  final data = response.data['data'] as List<dynamic>;
  return data.map((e) => e as Map<String, dynamic>).toList();
});

final exclusiveOffersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final loc = ref.watch(locationProvider);
  final dio = ApiService.dio;
  final response = await dio.get('/engagement/exclusive-offers', queryParameters: zoneQueryParams(loc));
  final data = response.data['data'] as List<dynamic>;
  return data.map((e) => e as Map<String, dynamic>).toList();
});

final premiumPlansProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final loc = ref.watch(locationProvider);
  final dio = ApiService.dio;
  final response = await dio.get('/premium/plans', queryParameters: zoneQueryParams(loc));
  final data = response.data['data'] as List<dynamic>;
  return data.map((e) => e as Map<String, dynamic>).toList();
});

final upcomingBookingProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authNotifierProvider).valueOrNull;
  if (user == null) return null;
  
  try {
    final response = await ApiService.dio.get('/bookings', queryParameters: {
      'status': 'confirmed,in_progress',
      'limit': 1,
    });
    final data = response.data['data'] as List<dynamic>;
    if (data.isEmpty) return null;
    return data.first as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
});

final recentlyViewedProvider = FutureProvider<List<ProfessionalModel>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final ids = prefs.getStringList('recently_viewed') ?? [];
  if (ids.isEmpty) return [];

  final futures = ids.take(5).map((id) async {
    try {
      final response = await ApiService.dio.get('/professionals/$id');
      return ProfessionalModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  });

  final results = await Future.wait(futures);
  return results.whereType<ProfessionalModel>().toList();
});

Future<void> addToRecentlyViewed(String professionalId) async {
  final prefs = await SharedPreferences.getInstance();
  final ids = prefs.getStringList('recently_viewed') ?? [];
  ids.remove(professionalId);
  ids.insert(0, professionalId);
  await prefs.setStringList('recently_viewed', ids.take(20).toList());
}

final salonProfileProvider = FutureProvider.family<ProfessionalModel, String>((ref, professionalId) async {
  final dio = ApiService.dio;
  final response = await dio.get('/professionals/$professionalId');
  return ProfessionalModel.fromJson(response.data['data'] as Map<String, dynamic>);
});

final similarProfessionalsProvider = FutureProvider.family<List<ProfessionalModel>, String>((ref, category) async {
  final loc = ref.watch(locationProvider);
  final dio = ApiService.dio;
  final response = await dio.get('/professionals', queryParameters: {
    'category': category.toLowerCase(),
    'limit': 6,
    ...zoneQueryParams(loc),
  });
  final data = response.data['data'] as List<dynamic>;
  return data.map((e) => ProfessionalModel.fromJson(e as Map<String, dynamic>)).toList();
});

// Category Professionals: fetch professionals by category for category sections
final categoryProfessionalsProvider = FutureProvider.family<List<ProfessionalModel>, String>((ref, category) async {
  final loc = ref.watch(locationProvider);
  final dio = ApiService.dio;
  print('Fetching category professionals for: $category (lowercase: ${category.toLowerCase()})');
  final response = await dio.get('/professionals', queryParameters: {
    'category': category.toLowerCase(),
    'limit': 6,
    'include': 'services',
    ...zoneQueryParams(loc),
  });
  print('Category professionals API response status: ${response.statusCode}');
  final data = response.data['data'] as List<dynamic>;
  print('Parsed ${data.length} category professionals');
  return data.map((e) => ProfessionalModel.fromJson(e as Map<String, dynamic>)).toList();
});
