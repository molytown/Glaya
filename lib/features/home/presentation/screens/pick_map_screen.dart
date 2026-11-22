import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../shared/services/api_service.dart';
import '../../controller/location_controller.dart';
import '../../models/address_model.dart';
import 'location_search_dialog.dart';

class PickMapScreen extends StatefulWidget {
  final bool fromSignUp;
  final bool fromAddAddress;
  final bool canRoute;
  final String? route;
  final GoogleMapController? googleMapController;

  const PickMapScreen({
    super.key,
    required this.fromSignUp,
    required this.fromAddAddress,
    required this.canRoute,
    required this.route,
    this.googleMapController,
  });

  @override
  State<PickMapScreen> createState() => _PickMapScreenState();
}

class _PickMapScreenState extends State<PickMapScreen> {
  GoogleMapController? _mapController;
  CameraPosition? _cameraPosition;
  late LatLng _initialPosition;
  Set<Marker> _servicePointMarkers = {};
  List<Map<String, dynamic>> _servicePoints = [];
  bool _isLoadingServicePoints = false;

  @override
  void initState() {
    super.initState();

    if (widget.fromAddAddress) {
      Get.find<LocationController>().setPickData();
    }

    _initialPosition = const LatLng(0, 0);

    // Auto-get current location when screen opens (for signup and main map)
    if (!widget.fromAddAddress) {
      _getCurrentLocationOnLoad();
    }

    // For signup, also ensure location controller has the address
    if (widget.fromSignUp) {
      _ensureLocationLoaded();
    }
  }

  Future<void> _ensureLocationLoaded() async {
    try {
      final locationController = Get.find<LocationController>();
      if (locationController.pickAddress == null ||
          locationController.pickAddress!.isEmpty) {
        await locationController.getCurrentLocation(false);
      }
    } catch (e) {
      print('Error ensuring location loaded: $e');
    }
  }

  Future<void> _loadNearbyServicePoints(LatLng center) async {
    if (_isLoadingServicePoints) return;

    setState(() => _isLoadingServicePoints = true);
    try {
      final response = await ApiService.dio.get(
        '/professionals/service-points',
        queryParameters: {
          'lat': center.latitude,
          'lng': center.longitude,
          'radiusKm': 10,
        },
      );

      final servicePoints =
          (response.data['data'] as List? ?? []).cast<Map<String, dynamic>>();

      if (mounted) {
        setState(() {
          _servicePoints = servicePoints;
          _servicePointMarkers = servicePoints
              .map((sp) {
                final location = sp['location'] as Map<String, dynamic>?;
                if (location == null) return null;

                return Marker(
                  markerId: MarkerId(sp['id'] as String),
                  position: LatLng(
                    (location['lat'] as num?)?.toDouble() ?? 0,
                    (location['lng'] as num?)?.toDouble() ?? 0,
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure),
                  onTap: () => _showServicePointInfo(sp),
                );
              })
              .whereType<Marker>()
              .toSet();
        });
      }
    } catch (e) {
      // Silently fail if service points can't be loaded
      print('Error loading service points: $e');
    } finally {
      if (mounted) setState(() => _isLoadingServicePoints = false);
    }
  }

  void _showServicePointInfo(Map<String, dynamic> servicePoint) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(servicePoint['businessName'] ??
            servicePoint['name'] ??
            'Service Point'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (servicePoint['category'] != null)
              Text('Category: ${servicePoint['category']}'),
            const SizedBox(height: 8),
            if (servicePoint['businessAddress'] != null)
              Text('Address: ${servicePoint['businessAddress']}'),
            const SizedBox(height: 8),
            if (servicePoint['distance'] != null)
              Text(
                  'Distance: ${(servicePoint['distance'] as num).toStringAsFixed(1)} km'),
            const SizedBox(height: 8),
            if (servicePoint['city'] != null || servicePoint['state'] != null)
              Text('Location: ${[
                servicePoint['city'],
                servicePoint['state']
              ].where((e) => e != null).join(', ')}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocationOnLoad() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _initialPosition = LatLng(position.latitude, position.longitude);
      });
      // Load service points after getting location
      _loadNearbyServicePoints(_initialPosition);
    } catch (e) {
      // Keep default position if location fetch fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: const Color(0xFFD6006E),
        elevation: 0,
      ),
      body: GetBuilder<LocationController>(
        builder: (locationController) {
          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: widget.fromAddAddress
                      ? LatLng(
                          locationController.position.latitude,
                          locationController.position.longitude,
                        )
                      : _initialPosition,
                  zoom: 16,
                ),
                markers: _servicePointMarkers,
                minMaxZoomPreference: const MinMaxZoomPreference(0, 16),
                onMapCreated: (GoogleMapController mapController) {
                  _mapController = mapController;
                  if (!widget.fromAddAddress) {
                    Get.find<LocationController>().getCurrentLocation(false,
                        mapController: mapController);
                  }
                },
                zoomControlsEnabled: false,
                onCameraMove: (CameraPosition cameraPosition) {
                  _cameraPosition = cameraPosition;
                },
                onCameraMoveStarted: () {
                  locationController.disableButton();
                },
                onCameraIdle: () {
                  Get.find<LocationController>()
                      .updatePosition(_cameraPosition, false);
                  // Reload service points when camera stops
                  if (_cameraPosition != null) {
                    _loadNearbyServicePoints(_cameraPosition!.target);
                  }
                },
              ),
              Center(
                child: !locationController.loading
                    ? Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF000000).withValues(alpha: 0.3),
                              spreadRadius: 2,
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on,
                          size: 50,
                          color: Color(0xFFD6006E),
                        ),
                      )
                    : const CircularProgressIndicator(),
              ),
              Positioned(
                top: 20,
                left: 15,
                right: 15,
                child: InkWell(
                  onTap: () => showDialog(
                    context: context,
                    builder: (context) =>
                        LocationSearchDialog(mapController: _mapController),
                  ),
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF000000).withValues(alpha: 0.2),
                          spreadRadius: 1,
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 25,
                          color: Color(0xFFD6006E),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            locationController.pickAddress ??
                                'Search location...',
                            style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFFD6006E),
                                fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.search,
                          size: 25,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 100,
                right: 15,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () => _checkPermission(() {
                    Get.find<LocationController>().getCurrentLocation(false,
                        mapController: _mapController);
                  }),
                  child: const Icon(
                    Icons.my_location,
                    color: Color(0xFFD6006E),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 15,
                right: 15,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD6006E),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: (locationController.buttonDisabled ||
                            locationController.loading)
                        ? null
                        : () {
                            if (locationController.pickPosition.latitude != 0 &&
                                locationController.pickAddress!.isNotEmpty) {
                              if (widget.fromAddAddress) {
                                if (widget.googleMapController != null) {
                                  widget.googleMapController!.moveCamera(
                                    CameraUpdate.newCameraPosition(
                                      CameraPosition(
                                        target: LatLng(
                                          locationController
                                              .pickPosition.latitude,
                                          locationController
                                              .pickPosition.longitude,
                                        ),
                                        zoom: 17,
                                      ),
                                    ),
                                  );
                                  locationController.setAddAddressData();
                                }
                                Navigator.pop(context);
                              } else {
                                AddressModel address = AddressModel(
                                  latitude: locationController
                                      .pickPosition.latitude
                                      .toString(),
                                  longitude: locationController
                                      .pickPosition.longitude
                                      .toString(),
                                  addressType: 'others',
                                  address: locationController.pickAddress,
                                );
                                _saveAddressAndNavigate(address);
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select a location'),
                                ),
                              );
                            }
                          },
                    child: locationController.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            locationController.inZone
                                ? widget.fromAddAddress
                                    ? 'Pick Address'
                                    : 'Pick Location'
                                : 'Service not available in this area',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _checkPermission(Function onTap) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have to allow location permission'),
        ),
      );
    } else if (permission == LocationPermission.deniedForever) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Location Permission'),
          content: const Text(
            'Location permission is permanently denied. Please enable it from app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Geolocator.openAppSettings(),
              child: const Text('Settings'),
            ),
          ],
        ),
      );
    } else {
      onTap();
    }
  }

  void _saveAddressAndNavigate(AddressModel address) async {
    final locationController = Get.find<LocationController>();

    // Get zone data for the selected location
    final response = await locationController.getZone(
      address.latitude!,
      address.longitude!,
      false,
    );

    if (response.isSuccess) {
      address.zoneId = response.zoneIds.isNotEmpty ? response.zoneIds[0] : 0;
      address.zoneIds = [];
      address.zoneIds!.addAll(response.zoneIds);
      address.zoneData = [];
      address.zoneData!.addAll(response.zoneData);

      await locationController.saveUserAddress(address);

      if (mounted) {
        // Return the picked position + address so callers (edit profile,
        // signup) can display/save it. Existing callers that ignore the
        // result are unaffected.
        Navigator.pop(context, {
          'position': LatLng(
            double.tryParse(address.latitude ?? '') ??
                locationController.pickPosition.latitude,
            double.tryParse(address.longitude ?? '') ??
                locationController.pickPosition.longitude,
          ),
          'address': address.address ?? locationController.pickAddress ?? '',
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
