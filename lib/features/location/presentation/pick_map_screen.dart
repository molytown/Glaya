import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../shared/theme/colors.dart';

class PickMapScreen extends StatefulWidget {
  final Function(double lat, double lng, String address) onLocationPicked;

  const PickMapScreen({
    super.key,
    required this.onLocationPicked,
  });

  @override
  State<PickMapScreen> createState() => _PickMapScreenState();
}

class _PickMapScreenState extends State<PickMapScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  Marker? _marker;
  String _address = 'Select a location';
  bool _isLoading = false;

  static const LatLng _defaultLocation =
      LatLng(3.848, 11.502); // Douala, Cameroon

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          setState(() {
            _selectedLocation = LatLng(position.latitude, position.longitude);
            _marker = Marker(
              markerId: const MarkerId('selected'),
              position: _selectedLocation!,
              draggable: true,
              onDragEnd: (LatLng newLocation) {
                _onLocationChanged(newLocation);
              },
            );
          });
          _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: _selectedLocation!, zoom: 15),
            ),
          );
          setState(() {
            _address =
                '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
          });
        }
      }
    } catch (e) {
      // Use default location if current location fails
      setState(() {
        _selectedLocation = _defaultLocation;
        _marker = Marker(
          markerId: const MarkerId('selected'),
          position: _defaultLocation,
          draggable: true,
          onDragEnd: (LatLng newLocation) {
            _onLocationChanged(newLocation);
          },
        );
        _address = '3.848, 11.502';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onLocationChanged(LatLng location) {
    setState(() {
      _selectedLocation = location;
      _marker = Marker(
        markerId: const MarkerId('selected'),
        position: location,
        draggable: true,
        onDragEnd: (LatLng newLocation) {
          _onLocationChanged(newLocation);
        },
      );
      _address =
          '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
    });
  }

  void _confirmLocation() {
    if (_selectedLocation != null) {
      widget.onLocationPicked(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
        _address,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _defaultLocation,
              zoom: 12,
            ),
            markers: _marker != null ? {_marker!} : {},
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              if (_selectedLocation != null) {
                controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _selectedLocation!, zoom: 15),
                  ),
                );
              }
            },
            onTap: _onLocationChanged,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _address,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _confirmLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlayaColors.berry,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Confirm Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
