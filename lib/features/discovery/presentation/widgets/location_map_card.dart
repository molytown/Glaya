import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/providers/location_provider.dart';
import '../../../../shared/utils/marker_icon_helper.dart';
import '../../data/professional_model.dart';

class LocationMapCard extends ConsumerStatefulWidget {
  final ProfessionalModel professional;

  const LocationMapCard({super.key, required this.professional});

  @override
  ConsumerState<LocationMapCard> createState() => _LocationMapCardState();
}

class _LocationMapCardState extends ConsumerState<LocationMapCard> {
  Set<Marker> _markers = {};
  bool _iconLoading = true;

  ProfessionalModel get professional => widget.professional;

  @override
  void initState() {
    super.initState();
    _loadMarker();
  }

  @override
  void didUpdateWidget(LocationMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.professional.id != widget.professional.id ||
        oldWidget.professional.photoUrl != widget.professional.photoUrl ||
        oldWidget.professional.location != widget.professional.location) {
      _loadMarker();
    }
  }

  Future<void> _loadMarker() async {
    final loc = professional.location;
    final lat = loc?['lat'];
    final lng = loc?['lng'];
    if (lat == null || lng == null) {
      if (mounted) setState(() => _iconLoading = false);
      return;
    }

    final icon = await MarkerIconHelper.getIcon(professional.photoUrl);
    if (!mounted) return;
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('pro_location'),
          position: LatLng((lat as num).toDouble(), (lng as num).toDouble()),
          icon: icon ?? BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(
            title: professional.businessName ?? professional.name,
          ),
        ),
      };
      _iconLoading = false;
    });
  }

  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // km
    final dLat = _degToRadians(lat2 - lat1);
    final dLng = _degToRadians(lng2 - lng1);
    final a = math.pow(dLat / 2, 2) +
        _degToRadians(lat1) * _degToRadians(lat2) * math.pow(dLng / 2, 2);
    final c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _degToRadians(double deg) => deg * (3.14159265359 / 180);

  @override
  Widget build(BuildContext context) {
    final address = professional.displayArea ?? 'Location not set';
    final locationState = ref.watch(locationProvider);
    final loc = professional.location;
    final proLat = loc?['lat'];
    final proLng = loc?['lng'];
    final hasCoords = proLat != null && proLng != null;

    String distanceText = '';
    if (hasCoords && locationState.hasLocation) {
      final distance = _calculateDistance(
        locationState.lat!,
        locationState.lng!,
        (proLat as num).toDouble(),
        (proLng as num).toDouble(),
      );
      if (distance < 1) {
        distanceText = '${(distance * 1000).round()} m';
      } else {
        distanceText = '${distance.toStringAsFixed(1)} km';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFEEEEEE))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Location',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A))),
              const SizedBox(height: 12),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasCoords
                    ? Stack(
                        children: [
                          GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(
                                (proLat as num).toDouble(),
                                (proLng as num).toDouble(),
                              ),
                              zoom: 14,
                            ),
                            markers: _markers,
                            zoomControlsEnabled: false,
                            mapToolbarEnabled: false,
                            compassEnabled: false,
                            myLocationButtonEnabled: false,
                            scrollGesturesEnabled: false,
                            zoomGesturesEnabled: false,
                            rotateGesturesEnabled: false,
                            tiltGesturesEnabled: false,
                          ),
                          if (_iconLoading)
                            const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          if (distanceText.isNotEmpty)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                        color:
                                            Color(0xFF000000).withValues(alpha: 0.1),
                                        blurRadius: 4)
                                  ],
                                ),
                                child: Text(distanceText,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A1A1A))),
                              ),
                            ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map_outlined,
                                size: 48,
                                color:
                                    GlayaColors.berry.withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            Text(address,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF000000))),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final Uri mapUri = Uri(
                        scheme: 'https',
                        host: 'maps.google.com',
                        path: '/search',
                        queryParameters: {'api': '1', 'query': address});
                    if (await canLaunchUrl(mapUri)) {
                      launchUrl(mapUri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.directions_outlined,
                      size: 18, color: GlayaColors.berry),
                  label: const Text('Get Directions',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: GlayaColors.berry)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GlayaColors.berry),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
