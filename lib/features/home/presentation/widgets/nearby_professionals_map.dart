import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../discovery/data/professional_model.dart';
import '../../../../shared/providers/location_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/marker_icon_helper.dart';

class NearbyProfessionalsMap extends ConsumerStatefulWidget {
  final List<ProfessionalModel> professionals;
  final bool isFullScreen;

  const NearbyProfessionalsMap({
    super.key,
    required this.professionals,
    this.isFullScreen = false,
  });

  @override
  ConsumerState<NearbyProfessionalsMap> createState() =>
      _NearbyProfessionalsMapState();
}

class _NearbyProfessionalsMapState
    extends ConsumerState<NearbyProfessionalsMap> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    print('NearbyProfessionalsMap: initState called');
    print(
        'NearbyProfessionalsMap: Professionals count = ${widget.professionals.length}');
    _initializeMarkers();
  }

  @override
  void didUpdateWidget(NearbyProfessionalsMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.professionals != widget.professionals) {
      _initializeMarkers();
    }
  }

  Future<void> _initializeMarkers() async {
    print('NearbyProfessionalsMap: _initializeMarkers called');
    final locationState = ref.read(locationProvider);
    double userLat;
    double userLng;

    if (locationState.hasLocation) {
      userLat = locationState.lat!;
      userLng = locationState.lng!;
    } else {
      // Fallback to Douala, Cameroon
      userLat = 3.8480;
      userLng = 11.5021;
    }

    print('NearbyProfessionalsMap: User location = ($userLat, $userLng)');

    final professionalsWithLocation = widget.professionals
        .where((p) =>
            p.location != null &&
            p.location!['lat'] != null &&
            p.location!['lng'] != null)
        .toList();

    print(
        'NearbyProfessionalsMap: Professionals with location = ${professionalsWithLocation.length}');

    final markers = (await Future.wait(professionalsWithLocation.map((p) async {
      final icon = await MarkerIconHelper.getIcon(p.photoUrl, name: p.name);
      return Marker(
        markerId: MarkerId(p.id),
        position: LatLng(p.location!['lat'], p.location!['lng']),
        icon: icon ?? BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(
          title: p.businessName ?? p.name,
          snippet:
              'Rating: ${p.avgRating?.toStringAsFixed(1) ?? 'N/A'} (${p.totalReviews} reviews)',
          onTap: () {
            context.push('/professional/${p.id}');
          },
        ),
      );
    })))
        .toSet();

    if (!mounted) return;
    setState(() {
      _markers = markers;
    });

    print('NearbyProfessionalsMap: Initialized ${markers.length} markers');
  }

  void _showProfessionalBottomSheet(ProfessionalModel professional) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: professional.photoUrl != null
                      ? Image.network(
                          professional.photoUrl!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[300],
                              child: const Icon(Icons.person, size: 30),
                            );
                          },
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(Icons.person, size: 30),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        professional.businessName ?? professional.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            professional.avgRating?.toStringAsFixed(1) ?? 'N/A',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${professional.totalReviews} reviews)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/professional/${professional.id}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlayaColors.berry,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'View Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    double userLat;
    double userLng;

    if (locationState.hasLocation) {
      userLat = locationState.lat!;
      userLng = locationState.lng!;
    } else {
      // Fallback to Douala, Cameroon
      userLat = 3.8480;
      userLng = 11.5021;
    }

    final mapWidget = GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(userLat, userLng),
        zoom: 12,
      ),
      markers: _markers,
      onMapCreated: (controller) {
        _mapController = controller;
        print('NearbyProfessionalsMap: GoogleMap created');
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      compassEnabled: false,
      mapToolbarEnabled: false,
    );

    if (widget.isFullScreen) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Nearby Professionals'),
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF000000),
          elevation: 0,
        ),
        body: mapWidget,
      );
    }

    return SizedBox(
      height: 200,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: mapWidget,
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
