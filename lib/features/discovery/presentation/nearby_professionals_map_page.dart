import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/presentation/widgets/nearby_professionals_map.dart';
import '../presentation/discovery_provider.dart';
import '../../../../shared/providers/location_provider.dart';
import '../../../../shared/services/location_service.dart';

class NearbyProfessionalsMapPage extends ConsumerStatefulWidget {
  const NearbyProfessionalsMapPage({super.key});

  @override
  ConsumerState<NearbyProfessionalsMapPage> createState() =>
      _NearbyProfessionalsMapPageState();
}

class _NearbyProfessionalsMapPageState
    extends ConsumerState<NearbyProfessionalsMapPage> {
  double? _lastLat;
  double? _lastLng;

  @override
  void initState() {
    super.initState();
    // Delay the initial fetch to avoid modifying provider during build
    Future.microtask(() async {
      final locationState = ref.read(locationProvider);
      double lat;
      double lng;

      if (locationState.hasLocation) {
        lat = locationState.lat!;
        lng = locationState.lng!;
      } else {
        // Try to get default location from backend
        final defaultLocation = await LocationService.getDefaultLocation();
        if (defaultLocation != null) {
          lat = defaultLocation.latitude;
          lng = defaultLocation.longitude;
        } else {
          // Fallback to Douala, Cameroon
          lat = 3.8480;
          lng = 11.5021;
        }
      }

      _lastLat = lat;
      _lastLng = lng;
      ref.read(nearbyProfessionalsProvider.notifier).fetchNearby(lat, lng);
    });
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    double lat;
    double lng;

    if (locationState.hasLocation) {
      lat = locationState.lat!;
      lng = locationState.lng!;
    } else {
      // Fallback to Douala, Cameroon
      lat = 3.8480;
      lng = 11.5021;
    }

    // Trigger nearby professionals fetch when location changes (after build)
    if (_lastLat != lat || _lastLng != lng) {
      _lastLat = lat;
      _lastLng = lng;
      // Use Future.microtask to defer the provider modification
      Future.microtask(() {
        ref.read(nearbyProfessionalsProvider.notifier).fetchNearby(lat, lng);
      });
    }

    final nearbyAsync = ref.watch(nearbyProfessionalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Professionals'),
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF000000),
        elevation: 0,
      ),
      body: nearbyAsync.when(
        data: (professionals) {
          return NearbyProfessionalsMap(
            professionals: professionals,
            isFullScreen: true,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Failed to load nearby professionals')),
      ),
    );
  }
}
