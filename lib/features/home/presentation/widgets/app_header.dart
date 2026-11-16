import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dio/dio.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/services/config_service.dart';
import '../../../../shared/widgets/notification_popup.dart';
import '../../../../shared/providers/notification_provider.dart';
import '../../../../shared/providers/location_provider.dart';
import '../../controller/location_controller.dart';
import '../screens/pick_map_screen.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../location/presentation/guest_location_picker_screen.dart';

class HomeAppHeader extends ConsumerWidget {
  final String? photoUrl;
  final int notificationCount;
  final String locationLabel;

  const HomeAppHeader({
    super.key,
    this.photoUrl,
    this.notificationCount = 3,
    required this.locationLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final isGuest = user == null;
    final unreadCount = ref.watch(notificationCountProvider);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GlayaColors.surface,
            GlayaColors.vibrantPink.withOpacity(0.03),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: GlayaColors.vibrantPink.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      child: Row(
        children: [
          Image.asset(
            'assets/logo.png',
            height: 56,
            width: 56,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              // Show location picker dialog
              showDialog(
                context: context,
                builder: (context) => const LocationPickerDialog(),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: GlayaColors.vibrantPink.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: GlayaColors.vibrantPink.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on,
                    color: GlayaColors.berry,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    locationLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: GlayaColors.textPrimary,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: GlayaColors.textPrimary,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Only show notification icon for logged-in users
          if (!isGuest)
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        contentPadding: EdgeInsets.zero,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        content: NotificationPopup(
                          onClose: () => Navigator.pop(context),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: GlayaColors.textPrimary,
                    size: 26,
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: GlayaColors.berry,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          if (!isGuest) const SizedBox(width: 8),
          // Show sign in button for guests, profile avatar for logged-in users
          if (isGuest)
            GestureDetector(
              onTap: () => context.push('/login'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: GlayaColors.berry,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Sign In',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () => context.push('/profile'),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: GlayaColors.vibrantPink.withOpacity(0.2),
                backgroundImage: photoUrl != null ? NetworkImage(ConfigService().replaceLocalhost(photoUrl!)) : null,
                child: photoUrl == null
                    ? const Icon(Icons.person, color: GlayaColors.berry, size: 22)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class LocationPickerDialog extends ConsumerWidget {
  const LocationPickerDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
        child: const LocationPickerDialogContent(),
      ),
    );
  }
}

class LocationPickerDialogContent extends ConsumerStatefulWidget {
  const LocationPickerDialogContent({super.key});

  @override
  ConsumerState<LocationPickerDialogContent> createState() => _LocationPickerDialogContentState();
}

class _LocationPickerDialogContentState extends ConsumerState<LocationPickerDialogContent> {
  bool _isLoading = false;
  String? _error;

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'Location services are disabled. Please enable them in settings.';
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _error = 'Location permission denied. Please enable it in settings.';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permission permanently denied. Please enable it in settings.';
          _isLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      // Update location provider
      await ref.read(locationProvider.notifier).setLocation(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to get location: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _openMapPicker() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MapPickerDialogContent(),
      ),
    );
  }

  void _skipLocation() {
    // Set default location (Douala, Cameroon)
    ref.read(locationProvider.notifier).setLocation(3.848, 11.502);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);

    return Container(
      decoration: BoxDecoration(
        color: GlayaColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: GlayaColors.vibrantPink.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: GlayaColors.textPrimary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set Your Location',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: GlayaColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Find beauty professionals near you',
                        style: TextStyle(
                          fontSize: 14,
                          color: GlayaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Current location button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: GlayaColors.softShadow,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.my_location,
                          size: 48,
                          color: GlayaColors.berry,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Use Current Location',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: GlayaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'We\'ll use your GPS to find nearby services',
                          style: TextStyle(
                            fontSize: 14,
                            color: GlayaColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _useCurrentLocation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GlayaColors.berry,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Use Current Location',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Map picker button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: GlayaColors.softShadow,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: 48,
                          color: GlayaColors.berry,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Pick on Map',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: GlayaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Select your location manually on the map',
                          style: TextStyle(
                            fontSize: 14,
                            color: GlayaColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _openMapPicker,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: GlayaColors.berry,
                              side: BorderSide(color: GlayaColors.berry),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Pick on Map',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Skip button
                  Center(
                    child: TextButton(
                      onPressed: _skipLocation,
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(
                          fontSize: 14,
                          color: GlayaColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  // Current location display
                  if (locationState.hasLocation)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: GlayaColors.berry.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: GlayaColors.berry, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Location Set',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: GlayaColors.berry,
                                  ),
                                ),
                                Text(
                                  '${locationState.lat!.toStringAsFixed(4)}, ${locationState.lng!.toStringAsFixed(4)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: GlayaColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

class MapPickerDialogContent extends ConsumerStatefulWidget {
  const MapPickerDialogContent({super.key});

  @override
  ConsumerState<MapPickerDialogContent> createState() => _MapPickerDialogContentState();
}

class _MapPickerDialogContentState extends ConsumerState<MapPickerDialogContent> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          color: GlayaColors.background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: GlayaColors.textPrimary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Pick Location on Map',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: GlayaColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SimpleMapPicker(
                onLocationSelected: (lat, lng) async {
                  await ref.read(locationProvider.notifier).setLocation(lat, lng);
                  if (mounted) {
                    Navigator.pop(context); // Close map picker
                    Navigator.pop(context); // Close location picker dialog
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SimpleMapPicker extends ConsumerStatefulWidget {
  final Function(double lat, double lng) onLocationSelected;

  const SimpleMapPicker({
    super.key,
    required this.onLocationSelected,
  });

  @override
  ConsumerState<SimpleMapPicker> createState() => _SimpleMapPickerState();
}

class _SimpleMapPickerState extends ConsumerState<SimpleMapPicker> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedAddress;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locationState = ref.read(locationProvider);
      if (locationState.hasLocation) {
        final lat = locationState.lat!;
        final lng = locationState.lng!;
        setState(() {
          _selectedLocation = LatLng(lat, lng);
          _isLoading = false;
        });
        await _getAddressFromCoordinates(lat, lng);
      } else {
        // Try to get current location
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always) {
            final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
            setState(() {
              _selectedLocation = LatLng(position.latitude, position.longitude);
              _isLoading = false;
            });
            await _getAddressFromCoordinates(position.latitude, position.longitude);
            return;
          }
        }
        // Fallback to default location
        setState(() {
          _selectedLocation = const LatLng(3.848, 11.502);
          _isLoading = false;
        });
        await _getAddressFromCoordinates(3.848, 11.502);
      }
    } catch (e) {
      setState(() {
        _selectedLocation = const LatLng(3.848, 11.502);
        _isLoading = false;
      });
      await _getAddressFromCoordinates(3.848, 11.502);
    }
  }

  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'format': 'json',
        },
        options: Options(
          headers: {
            'User-Agent': 'Glaya/1.0',
          },
        ),
      );

      if (response.data != null && response.data['address'] != null) {
        final address = response.data['address'] as Map<String, dynamic>;
        final parts = <String>[];

        // Build a readable address
        if (address['road'] != null) parts.add(address['road']);
        if (address['suburb'] != null) parts.add(address['suburb']);
        if (address['neighbourhood'] != null) parts.add(address['neighbourhood']);
        if (address['city'] != null || address['town'] != null || address['village'] != null) {
          parts.add(address['city'] ?? address['town'] ?? address['village']);
        }

        if (mounted) {
          setState(() {
            _selectedAddress = parts.isNotEmpty ? parts.join(', ') : 'Unknown location';
          });
        }
      }
    } catch (e) {
      // Silently fail on reverse geocoding error
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': 1,
        },
        options: Options(
          headers: {
            'User-Agent': 'Glaya/1.0',
          },
        ),
      );

      if (response.data != null && response.data is List && response.data.isNotEmpty) {
        final result = response.data[0] as Map<String, dynamic>;
        final lat = double.tryParse(result['lat'] as String? ?? '');
        final lon = double.tryParse(result['lon'] as String? ?? '');

        if (lat != null && lon != null && _mapController != null) {
          final newLocation = LatLng(lat, lon);
          setState(() {
            _selectedLocation = newLocation;
            _selectedAddress = result['display_name'] as String?;
          });
          await _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: newLocation, zoom: 16),
            ),
          );
        }
      }
    } catch (e) {
      // Silently fail on search error
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _selectedLocation == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _selectedLocation!,
            zoom: 15,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
          },
          onCameraMove: (position) {
            setState(() {
              _selectedLocation = position.target;
            });
          },
          onCameraIdle: () {
            if (_selectedLocation != null) {
              _getAddressFromCoordinates(_selectedLocation!.latitude, _selectedLocation!.longitude);
            }
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
        ),
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on,
              size: 50,
              color: GlayaColors.berry,
            ),
          ),
        ),
        Positioned(
          top: 20,
          left: 15,
          right: 15,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
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
                  color: GlayaColors.berry,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search location...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(fontSize: 16),
                    ),
                    style: const TextStyle(fontSize: 16),
                    onSubmitted: _searchLocation,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(
                    Icons.search,
                    size: 25,
                    color: Colors.grey,
                  ),
                  onPressed: () => _searchLocation(_searchController.text),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 15,
          right: 15,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Location',
                  style: TextStyle(
                    fontSize: 12,
                    color: GlayaColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedAddress ?? 'Loading address...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: GlayaColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => widget.onLocationSelected(
                      _selectedLocation!.latitude,
                      _selectedLocation!.longitude,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlayaColors.berry,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 80,
          right: 15,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            onPressed: _getCurrentLocation,
            child: const Icon(
              Icons.my_location,
              color: GlayaColors.berry,
            ),
          ),
        ),
      ],
    );
  }
}
