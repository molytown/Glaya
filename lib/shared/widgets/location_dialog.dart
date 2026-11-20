import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/colors.dart';
import '../services/api_service.dart';

/// Desktop location dialog — 3:4 portrait map overlay with
/// "Use current location" and "Confirm location" buttons.
class LocationDialog extends StatefulWidget {
  final LatLng? initialLocation;
  final String? initialAddress;
  final Function(LatLng, String) onConfirm;

  const LocationDialog({
    super.key,
    this.initialLocation,
    this.initialAddress,
    required this.onConfirm,
  });

  @override
  State<LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<LocationDialog> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isLoading = true;
  bool _isLocating = false;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _selectedAddress = widget.initialAddress;
    if (_selectedLocation != null) {
      _markers = {
        Marker(
          markerId: const MarkerId('selected'),
          position: _selectedLocation!,
          draggable: true,
          onDragEnd: (position) {
            _onMarkerDragged(position);
          },
        ),
      };
      _isLoading = false;
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedLocation = latLng;
        _markers = {
          Marker(
            markerId: const MarkerId('selected'),
            position: latLng,
            draggable: true,
            onDragEnd: (position) {
              _onMarkerDragged(position);
            },
          ),
        };
        _isLoading = false;
      });
      _reverseGeocode(latLng);
      if (_mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(latLng, 14));
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLocating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _reverseGeocode(LatLng latLng) async {
    try {
      final response = await ApiService.dio.get(
        '/geocode/reverse',
        queryParameters: {
          'lat': latLng.latitude,
          'lng': latLng.longitude,
        },
      );
      if (mounted && response.data != null) {
        setState(() {
          _selectedAddress = response.data['address'] as String? ??
              response.data['formatted_address'] as String? ??
              'Selected Location';
        });
      }
    } catch (e) {
      // Reverse geocode failed - keep current address
    }
  }

  void _onMarkerDragged(LatLng position) {
    setState(() {
      _selectedLocation = position;
      _markers = {
        Marker(
          markerId: const MarkerId('selected'),
          position: position,
          draggable: true,
          onDragEnd: (pos) {
            _onMarkerDragged(pos);
          },
        ),
      };
    });
    _reverseGeocode(position);
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _selectedLocation = position;
      _markers = {
        Marker(
          markerId: const MarkerId('selected'),
          position: position,
          draggable: true,
          onDragEnd: (pos) {
            _onMarkerDragged(pos);
          },
        ),
      };
    });
    _reverseGeocode(position);
  }

  void _onUseCurrentLocation() {
    _getCurrentLocation();
  }

  void _onConfirm() {
    if (_selectedLocation != null && _selectedAddress != null) {
      widget.onConfirm(_selectedLocation!, _selectedAddress!);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    var dialogH = screen.height * 0.8;
    var dialogW = dialogH * 3 / 4;
    final maxW = screen.width * 0.9;
    if (dialogW > maxW) {
      dialogW = maxW;
      dialogH = dialogW * 4 / 3;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Center(
        child: Container(
          width: dialogW,
          height: dialogH,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF000000).withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  border: Border(
                    bottom: BorderSide(color: const Color(0xFFE5E7EB)),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 20, color: GlayaColors.berry),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Set Your Location',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Map
              Expanded(
                child: Stack(
                  children: [
                    if (_isLoading)
                      const Center(
                        child: CircularProgressIndicator(),
                      )
                    else
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _selectedLocation ?? const LatLng(4.0511, 9.7679),
                          zoom: 14,
                        ),
                        markers: _markers,
                        onMapCreated: (controller) {
                          _mapController = controller;
                          if (_selectedLocation != null) {
                            controller.animateCamera(
                              CameraUpdate.newLatLngZoom(_selectedLocation!, 14),
                            );
                          }
                        },
                        onTap: _onMapTap,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: true,
                      ),
                    // Current location button
                    Positioned(
                      top: 12,
                      right: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'current_location',
                        backgroundColor: Colors.white,
                        onPressed: _isLocating ? null : _onUseCurrentLocation,
                        child: _isLocating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location, color: GlayaColors.berry),
                      ),
                    ),
                  ],
                ),
              ),
              // Footer with selected address and buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: const Color(0xFFE5E7EB)),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Selected address
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: GlayaColors.berry),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedAddress ?? 'Detecting area…',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1A1A1A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLocating ? null : _onUseCurrentLocation,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: GlayaColors.berry),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLocating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text(
                                    'Use current location',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: GlayaColors.berry,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _selectedLocation != null ? _onConfirm : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GlayaColors.berry,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Confirm location',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
