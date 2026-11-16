import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/data/location_data.dart';
import '../../home/presentation/screens/pick_map_screen.dart';
import '../../auth/presentation/providers/auth_notifier.dart';

// ── Service option data ──────────────────────────────────────────────────────
class _ServiceOption {
  final String value;
  final String label;
  final String imageUrl;
  const _ServiceOption(this.value, this.label, this.imageUrl);
}

const _services = [
  _ServiceOption('hair', 'Hair',
      'https://images.unsplash.com/photo-1560066984-138dadb4c035?w=300&h=300&fit=crop'),
  _ServiceOption('nails', 'Nails',
      'https://images.unsplash.com/photo-1604654894610-df63bc536371?w=300&h=300&fit=crop'),
  _ServiceOption('barber', 'Barber',
      'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=300&h=300&fit=crop'),
  _ServiceOption('spa', 'Spa & Body',
      'https://images.unsplash.com/photo-1544161515-4ab6ce6db874?w=300&h=300&fit=crop'),
  _ServiceOption('makeup', 'Makeup',
      'https://images.unsplash.com/photo-1487412947147-5cebf100ffc2?w=300&h=300&fit=crop'),
  _ServiceOption('brows_lashes', 'Brows & Lashes',
      'https://images.unsplash.com/photo-1583001931096-959e9a1a6223?w=300&h=300&fit=crop'),
  _ServiceOption('skincare', 'Skincare',
      'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?w=300&h=300&fit=crop'),
  _ServiceOption('bridal', 'Bridal',
      'https://images.unsplash.com/photo-1519741497674-611481863552?w=300&h=300&fit=crop'),
  _ServiceOption('hair_coloring', 'Hair Coloring',
      'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=300&h=300&fit=crop'),
  _ServiceOption('massage', 'Massage',
      'https://images.unsplash.com/photo-1600334089648-b0d9d3028eb2?w=300&h=300&fit=crop'),
  _ServiceOption('waxing', 'Waxing',
      'https://images.unsplash.com/photo-1616394584738-fc6e612e71b9?w=300&h=300&fit=crop'),
  _ServiceOption('body_treatments', 'Body Treatments',
      'https://images.unsplash.com/photo-1515377905703-c4788e51af15?w=300&h=300&fit=crop'),
];

// ── Animated gradient painter ────────────────────────────────────────────────
class _AnimatedGradientPainter extends CustomPainter {
  final double phase;
  _AnimatedGradientPainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    // Animated gradient background
    final rect = Offset.zero & size;
    final shiftX = math.sin(phase * 2 * math.pi) * 0.4;
    final shiftY = math.cos(phase * 2 * math.pi * 0.7) * 0.3;
    final gradient = LinearGradient(
      begin: Alignment(-0.5 + shiftX, -0.5 + shiftY),
      end: Alignment(0.8 - shiftX, 0.8 - shiftY),
      colors: const [
        Color(0xFF5C3D2E),
        Color(0xFF8B6914),
        Color(0xFFA67C52),
        Color(0xFFD4A76A),
        Color(0xFFF5DEB3),
        Color(0xFFFFFFFF),
        Color(0xFFF5DEB3),
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // Ripple circles
    final ripple1Center = Offset(
      size.width * (0.5 + 0.3 * math.sin(phase * 2 * math.pi * 0.8)),
      size.height * (0.5 + 0.3 * math.cos(phase * 2 * math.pi * 0.6)),
    );
    canvas.drawCircle(
      ripple1Center,
      80 + 30 * math.sin(phase * 2 * math.pi),
      Paint()..color = Colors.white.withOpacity(0.12),
    );

    final ripple2Center = Offset(
      size.width * (0.7 + 0.2 * math.cos(phase * 2 * math.pi * 1.2)),
      size.height * (0.3 + 0.2 * math.sin(phase * 2 * math.pi * 0.9)),
    );
    canvas.drawCircle(
      ripple2Center,
      50 + 20 * math.cos(phase * 2 * math.pi * 1.1),
      Paint()..color = Colors.white.withOpacity(0.08),
    );
  }

  @override
  bool shouldRepaint(covariant _AnimatedGradientPainter old) =>
      old.phase != phase;
}

// ══════════════════════════════════════════════════════════════════════════════
class ProfessionalOnboardingScreen extends ConsumerStatefulWidget {
  const ProfessionalOnboardingScreen({super.key});

  @override
  ConsumerState<ProfessionalOnboardingScreen> createState() =>
      _ProfessionalOnboardingScreenState();
}

class _ProfessionalOnboardingScreenState
    extends ConsumerState<ProfessionalOnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _neighborhoodController = TextEditingController();

  String? _locationCountryIso;
  String? _phoneCountryIso = 'NG';
  String? _selectedState;
  String? _selectedCity;
  final Set<String> _selectedServices = {};
  bool _isLoading = false;
  late AnimationController _animController;
  XFile? _profilePhoto;
  Uint8List? _profilePhotoBytes;
  String? _uploadedPhotoUrl;
  bool _isUploadingPhoto = false;
  bool _isLoggedIn = false;

  // Location picker data
  LatLng? _selectedLocation;
  String? _selectedAddress;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final notifier = ref.read(authNotifierProvider.notifier);
    setState(() => _isLoggedIn = notifier.isAuthenticated);

    // If logged in, pre-fill data from user profile
    if (_isLoggedIn) {
      final user = notifier.currentUser;
      if (user != null) {
        setState(() {
          if (user.name != null) _nameController.text = user.name!;
          if (user.phone != null) _phoneController.text = user.phone!;
          // Note: User entity doesn't have email, address fields in current implementation
          // These would need to be fetched from a full profile API or added to User entity
        });
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _businessNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _neighborhoodController.dispose();
    super.dispose();
  }

  String get _phoneCode {
    if (_phoneCountryIso == null) return '';
    final c = countries.where((c) => c.iso == _phoneCountryIso).firstOrNull;
    return c?.code ?? '';
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _profilePhoto = pickedFile;
        _profilePhotoBytes = bytes;
      });
      await _uploadPhoto();
    }
  }

  Future<void> _uploadPhoto() async {
    if (_profilePhoto == null || _profilePhotoBytes == null) return;
    setState(() => _isUploadingPhoto = true);
    try {
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromBytes(
          _profilePhotoBytes!,
          filename: _profilePhoto!.name,
        ),
      });
      final response = await ApiService.dio.post(
        '/users/me/photo',
        data: formData,
        options: ApiService.multipartOptions(),
      );
      final photoUrl = response.data['data']['photoUrl'] as String;
      setState(() => _uploadedPhotoUrl = photoUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PickMapScreen(
          fromSignUp: true,
          fromAddAddress: false,
          canRoute: false,
          route: null,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedLocation = result['position'];
        _selectedAddress = result['address'];
      });
    }
  }

  Future<void> _submit() async {
    if (_businessNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your business name')),
      );
      return;
    }
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one service')),
      );
      return;
    }
    if (_locationCountryIso == null ||
        _selectedState == null ||
        _selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your location')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final countryName = countries
              .where((c) => c.iso == _locationCountryIso)
              .firstOrNull
              ?.name ??
          '';
      final data = {
        'businessName': _businessNameController.text.trim(),
        'services': _selectedServices.toList(),
        'category': _selectedServices.first,
        'country': countryName,
        'state': _selectedState,
        'city': _selectedCity,
        'neighborhood': _neighborhoodController.text.trim(),
      };
      // Add location data if selected
      if (_selectedLocation != null) {
        data['location'] = {
          'lat': _selectedLocation!.latitude,
          'lng': _selectedLocation!.longitude,
        };
      }
      if (_selectedAddress != null) {
        data['businessAddress'] = _selectedAddress;
      }
      if (_uploadedPhotoUrl != null) {
        data['photoUrl'] = _uploadedPhotoUrl;
      }
      await ApiService.dio.post('/users/me/professional', data: data);
      if (mounted) _showSuccessDialog();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final message = e.response?.data?['message'] ?? e.toString();
      final lower = message.toLowerCase();
      if (status == 409 || lower.contains('email') && lower.contains('exist')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'This email is already registered. Please use a different email.')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $message')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF5C3D2E),
                      Color(0xFF8B6914),
                      Color(0xFFA67C52)
                    ],
                  ),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'Application Submitted!',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Thank you for applying to join Glaya. We\'ll review your application and get back to you via email.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: Color(0xFF757575), height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C3D2E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.pop();
                  },
                  child: const Text('Done',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _AnimatedGradientPainter(_animController.value),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Header Content ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Back button
                            GestureDetector(
                              onTap: () => context.pop(),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.arrow_back,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Become a Professional',
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Join our community of beauty professionals',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Profile Photo Picker ──
                            Column(
                              children: [
                                GestureDetector(
                                  onTap: _pickPhoto,
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 88,
                                        height: 88,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: const Color(0xFFD6006E),
                                              width: 3),
                                          color: const Color(0xFFE0E0E0),
                                        ),
                                        child: _profilePhotoBytes != null
                                            ? ClipOval(
                                                child: Image.memory(
                                                  _profilePhotoBytes!,
                                                  fit: BoxFit.cover,
                                                  width: 88,
                                                  height: 88,
                                                  cacheWidth: 176,
                                                ),
                                              )
                                            : const Icon(Icons.person,
                                                size: 32,
                                                color: Color(0xFF9E9E9E)),
                                      ),
                                      if (!_isUploadingPhoto)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color(0xFFD6006E),
                                            ),
                                            child: const Icon(Icons.add,
                                                color: Colors.white, size: 14),
                                          ),
                                        ),
                                      if (_isUploadingPhoto)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color(0xFFD6006E),
                                            ),
                                            child: const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(Colors.white),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Add Profile Photo',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFD6006E),
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Tap to choose from gallery or camera',
                                  style: TextStyle(
                                      fontSize: 11, color: Color(0xFF999999)),
                                ),
                                if (_isUploadingPhoto)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Uploading...',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFFD6006E)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Only show personal fields if not logged in
                            if (!_isLoggedIn) ...[
                              _buildTextField(_nameController, 'Full Name',
                                  Icons.person_outline),
                              const SizedBox(height: 12),
                              // ── Phone with country code ──
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 110,
                                    child: _buildDropdown<String>(
                                      value: _phoneCountryIso,
                                      hint: 'Code',
                                      icon: Icons.phone_outlined,
                                      items: countries
                                          .map((c) => DropdownMenuItem(
                                                value: c.iso,
                                                child: Text(
                                                    '${c.flag} ${c.code}',
                                                    style: const TextStyle(
                                                        fontSize: 13)),
                                              ))
                                          .toList(),
                                      onChanged: (v) =>
                                          setState(() => _phoneCountryIso = v),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildTextField(_phoneController,
                                        'Phone Number', Icons.phone_outlined,
                                        keyboardType: TextInputType.phone),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(_emailController, 'Email Address',
                                  Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress),
                              const SizedBox(height: 20),
                            ],
                            _buildTextField(
                                _businessNameController,
                                'Business Name (optional)',
                                Icons.business_outlined),
                            const SizedBox(height: 12),

                            // ── Services Grid ──
                            const Text('Service(s)',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A1A2E))),
                            const SizedBox(height: 10),
                            _buildServicesGrid(),
                            const SizedBox(height: 20),

                            // ── Location Fields ──
                            const Text('Location',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A1A2E))),
                            const SizedBox(height: 10),
                            _buildDropdown<String>(
                              value: _locationCountryIso,
                              hint: 'Select Country',
                              icon: Icons.public,
                              items: countries
                                  .map((c) => DropdownMenuItem(
                                        value: c.iso,
                                        child: Text('${c.flag} ${c.name}'),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() {
                                _locationCountryIso = v;
                                _selectedState = null;
                                _selectedCity = null;
                              }),
                            ),
                            const SizedBox(height: 12),
                            _buildDropdown<String>(
                              value: _selectedState,
                              hint: 'Select State / Region',
                              icon: Icons.location_city,
                              items: getStatesForCountry(_locationCountryIso)
                                  .map((s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s),
                                      ))
                                  .toList(),
                              onChanged: _locationCountryIso == null
                                  ? null
                                  : (v) => setState(() {
                                        _selectedState = v;
                                        _selectedCity = null;
                                      }),
                            ),
                            const SizedBox(height: 12),
                            _buildDropdown<String>(
                              value: _selectedCity,
                              hint: 'Select City',
                              icon: Icons.location_on_outlined,
                              items: getCitiesForState(
                                      _locationCountryIso, _selectedState)
                                  .map((c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c),
                                      ))
                                  .toList(),
                              onChanged: _selectedState == null
                                  ? null
                                  : (v) => setState(() {
                                        _selectedCity = v;
                                      }),
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(_neighborhoodController,
                                'Neighborhood', Icons.map_outlined),
                            const SizedBox(height: 12),

                            // Location picker button
                            GestureDetector(
                              onTap: _openLocationPicker,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  color: _selectedLocation != null
                                      ? const Color(0xFFD6006E).withOpacity(0.1)
                                      : const Color(0xFFF9F9F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _selectedLocation != null
                                        ? const Color(0xFFD6006E)
                                        : const Color(0xFFE0E0E0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 20,
                                      color: _selectedLocation != null
                                          ? const Color(0xFFD6006E)
                                          : const Color(0xFF757575),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _selectedAddress ??
                                            'Pick location on map',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: _selectedLocation != null
                                              ? const Color(0xFFD6006E)
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (_selectedLocation != null)
                                      const Icon(
                                        Icons.check_circle,
                                        size: 20,
                                        color: Color(0xFFD6006E),
                                      )
                                    else
                                      const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Color(0xFF757575),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ── Submit Button ──
                            _buildSubmitButton(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── TEXT FIELD ─────────────────────────────────────────────────────────────
  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black87),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF757575)),
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD6006E), width: 1.5),
        ),
      ),
    );
  }

  // ── DROPDOWN ───────────────────────────────────────────────────────────────
  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonFormField<T>(
        value: value,
        hint: Text(hint,
            style: const TextStyle(fontSize: 14, color: Colors.black87)),
        icon: const Icon(Icons.keyboard_arrow_down, size: 20),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 20, color: const Color(0xFF757575)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        isExpanded: true,
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  // ── SERVICES GRID ─────────────────────────────────────────────────────────
  Widget _buildServicesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: _services.length,
      itemBuilder: (context, index) {
        final svc = _services[index];
        final isSelected = _selectedServices.contains(svc.value);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedServices.remove(svc.value);
              } else {
                _selectedServices.add(svc.value);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    isSelected ? const Color(0xFFD6006E) : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: const Color(0xFFD6006E).withOpacity(0.25),
                          blurRadius: 8)
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Photo
                  Image.network(
                    svc.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFE0E0E0),
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
                  // Gradient overlay
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0x00000000),
                          Color(0xB3000000)
                        ],
                        stops: [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                  // Label
                  Positioned(
                    bottom: 6,
                    left: 6,
                    right: 6,
                    child: Text(
                      svc.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Checkbox
                  Positioned(
                    top: 4,
                    right: 4,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFD6006E)
                            : const Color(0x33000000),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFD6006E)
                              : Colors.white.withOpacity(0.6),
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 14)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── SUBMIT BUTTON ─────────────────────────────────────────────────────────
  Widget _buildSubmitButton() {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final shiftX = math.sin(_animController.value * 2 * math.pi) * 0.3;
        return GestureDetector(
          onTap: _isLoading ? null : _submit,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment(-0.5 + shiftX, 0),
                end: Alignment(0.8 - shiftX, 0),
                colors: const [
                  Color(0xFF5C3D2E),
                  Color(0xFF8B6914),
                  Color(0xFFA67C52),
                ],
              ),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF5C3D2E).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            alignment: Alignment.center,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Submit Application',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
          ),
        );
      },
    );
  }
}
