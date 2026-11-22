import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import 'dart:io';

import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/config_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/haptic_feedback.dart';
import '../../../../shared/widgets/bottom_nav.dart';
import '../../../../shared/widgets/booking_chat_dialog.dart';
import '../../../../shared/widgets/glaya_gradient_button.dart';
import '../../auth/presentation/providers/auth_notifier.dart';
import '../../home/presentation/screens/pick_map_screen.dart';
import '../../shared/presentation/widgets/address_editor.dart';
import '../../reels/data/repositories/reel_repository.dart';
import '../../reels/data/models/reel_model.dart';
import '../../reels/presentation/widgets/reels_widget.dart';
import '../../reels/presentation/reel_screen.dart';
import 'wallet_dialog.dart';

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

// ── Edit Profile bottom sheet ─────────────────────────────────────────────────
class _EditProfileSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onSaved;
  const _EditProfileSheet({required this.user, required this.onSaved});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _bioCtrl;
  bool _saving = false;
  String? _error;
  String? _selectedImagePath;
  bool _showPassword = false;

  // Location picker data
  LatLng? _selectedLocation;
  String? _selectedAddress;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.user['name'] as String? ?? '',
    );
    _phoneCtrl = TextEditingController(
      text: widget.user['phone'] as String? ?? '',
    );
    _passwordCtrl = TextEditingController();
    _bioCtrl = TextEditingController(
      text: widget.user['bio'] as String? ??
          widget.user['about'] as String? ??
          '',
    );

    // Initialize location from existing user data
    // API may return decimal columns as strings — parse defensively.
    final lat = _toDouble(widget.user['latitude']);
    final lng = _toDouble(widget.user['longitude']);
    final address = widget.user['fullAddress'] as String? ??
        widget.user['full_address'] as String?;
    if (lat != null && lng != null) {
      _selectedLocation = LatLng(lat, lng);
      _selectedAddress = address;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() => _selectedImagePath = image.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to pick image: $e');
      }
    }
  }

  Future<void> _uploadPhoto() async {
    print('[DEBUG] _uploadPhoto called');
    if (_selectedImagePath == null) {
      print('[DEBUG] No image selected');
      return;
    }

    print('[DEBUG] Selected image path: $_selectedImagePath');
    setState(() => _saving = true);
    try {
      print('[DEBUG] Creating FormData');
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(_selectedImagePath!),
      });

      print('[DEBUG] Sending POST request to /users/me/photo');
      final response = await ApiService.dio.post(
        '/users/me/photo',
        data: formData,
      );

      print('[DEBUG] Response status: ${response.statusCode}');
      print('[DEBUG] Response data: ${response.data}');

      if (mounted) {
        setState(() => _saving = false);
        setState(() => _error = null);
        setState(() => _selectedImagePath = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh profile to show new photo and update auth state
        widget.onSaved();
      }
    } catch (e) {
      print('[DEBUG] Photo upload error: $e');
      print('[DEBUG] Error type: ${e.runtimeType}');
      if (e is DioException) {
        print('[DEBUG] Dio error response: ${e.response}');
        print('[DEBUG] Dio error type: ${e.type}');
        print('[DEBUG] Dio error message: ${e.message}');
      }
      if (mounted) {
        setState(() => _saving = false);
        final msg =
            (e as dynamic).response?.data?['error'] as String? ?? e.toString();
        print('[DEBUG] Error message to display: $msg');
        setState(() => _error = msg);
      }
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

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final bio = _bioCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Name cannot be empty');
      return;
    }
    if (phone.length < 5) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }
    if (password.isNotEmpty && password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{'name': name, 'phone': phone};
      // Add password if provided
      if (password.isNotEmpty) {
        body['password'] = password;
      }
      // Add bio if provided
      if (bio.isNotEmpty) {
        body['bio'] = bio;
      }
      // Add location data if selected
      if (_selectedLocation != null) {
        body['latitude'] = _selectedLocation!.latitude;
        body['longitude'] = _selectedLocation!.longitude;
      }
      if (_selectedAddress != null) {
        body['fullAddress'] = _selectedAddress;
      }

      await ApiService.dio.put('/users/me', data: body);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
      }
    } catch (e) {
      final msg =
          (e as dynamic).response?.data?['message'] as String? ?? e.toString();
      if (mounted) {
        setState(() {
          _saving = false;
          _error = msg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Edit Profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 20),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: GlayaColors.berry.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _error!,
                  style:
                      const TextStyle(fontSize: 13, color: GlayaColors.berry),
                ),
              ),
              const SizedBox(height: 14),
            ],

            _field(
              'Full Name',
              _nameCtrl,
              Icons.person_outline,
              TextInputType.name,
            ),
            const SizedBox(height: 14),
            _field(
              'Phone Number',
              _phoneCtrl,
              Icons.phone_outlined,
              TextInputType.phone,
            ),
            const SizedBox(height: 14),
            _bioField(),
            const SizedBox(height: 14),
            _passwordField(),
            const SizedBox(height: 14),

            // Photo upload section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profile Photo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF000000),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Column(
                      children: [
                        if (_selectedImagePath != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_selectedImagePath!),
                              height: 100,
                              width: 100,
                              fit: BoxFit.cover,
                              cacheWidth: 200,
                              errorBuilder: (_, __, ___) => _photoPlaceholder(),
                            ),
                          )
                        else if (widget.user['photoUrl'] != null ||
                            widget.user['photo_url'] != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              ConfigService().replaceLocalhost(
                                (widget.user['photoUrl'] as String?) ??
                                    (widget.user['photo_url'] as String?) ??
                                    '',
                              ),
                              height: 100,
                              width: 100,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 100,
                                  width: 100,
                                  color:
                                      GlayaColors.berry.withValues(alpha: 0.1),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                      color: GlayaColors.berry,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                print(
                                  'EditProfileSheet: Image loading error: $error',
                                );
                                return _photoPlaceholder();
                              },
                            ),
                          )
                        else
                          _photoPlaceholder(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.camera_alt,
                              color: GlayaColors.berry,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedImagePath != null
                                  ? 'Change Photo'
                                  : 'Upload Photo',
                              style: const TextStyle(
                                fontSize: 14,
                                color: GlayaColors.berry,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_selectedImagePath != null) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _saving ? null : _uploadPhoto,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlayaColors.berry,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Upload Photo',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),

            // Location picker button
            GestureDetector(
              onTap: _openLocationPicker,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedLocation != null
                      ? GlayaColors.berry.withValues(alpha: 0.1)
                      : const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedLocation != null
                        ? GlayaColors.berry
                        : const Color(0xFFE0E0E0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: _selectedLocation != null
                          ? GlayaColors.berry
                          : GlayaColors.berry,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedAddress ?? 'Pick location on map',
                        style: TextStyle(
                          fontSize: 14,
                          color: _selectedLocation != null
                              ? GlayaColors.berry
                              : Color(0xFF000000),
                        ),
                      ),
                    ),
                    if (_selectedLocation != null)
                      const Icon(Icons.check_circle,
                          size: 18, color: GlayaColors.berry)
                    else
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlayaColors.berry,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    IconData icon,
    TextInputType type,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF000000),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: type,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: GlayaColors.berry, size: 18),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: GlayaColors.berry, width: 2),
            ),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
          ),
        ),
      ],
    );
  }

  Widget _passwordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'New Password (optional)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF000000),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordCtrl,
          obscureText: !_showPassword,
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: GlayaColors.berry,
              size: 18,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
                color: GlayaColors.berry,
                size: 18,
              ),
              onPressed: () {
                setState(() => _showPassword = !_showPassword);
              },
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: GlayaColors.berry, width: 2),
            ),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            hintText: 'Leave blank to keep current password',
            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _bioField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About Me',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF000000),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _bioCtrl,
          maxLines: 4,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.edit_note,
              color: GlayaColors.berry,
              size: 18,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: GlayaColors.berry, width: 2),
            ),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            hintText: 'Tell us about yourself...',
            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      height: 100,
      width: 100,
      decoration: BoxDecoration(
        color: GlayaColors.berry.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GlayaColors.berry.withValues(alpha: 0.3)),
      ),
      child: const Icon(Icons.person, size: 40, color: GlayaColors.berry),
    );
  }
}

// ── Currency helper ──────────────────────────────────────────────────────────
String _getCurrencySymbol() {
  // Resolve from user locale; default to ₦ (NGN) as base
  try {
    final locale = Intl.getCurrentLocale();
    if (locale.startsWith('en_US')) return '\$';
    if (locale.startsWith('en_GB')) return '£';
    if (locale.startsWith('fr_') ||
        locale.startsWith('de_') ||
        locale.startsWith('es_') ||
        locale.startsWith('it_')) {
      return '€';
    }
    if (locale.startsWith('ar_') || locale.startsWith('en_AE')) return 'د.إ';
    if (locale.startsWith('en_KE')) return 'KSh ';
    if (locale.startsWith('en_GH')) return 'GH₵ ';
    if (locale.startsWith('en_ZA')) return 'R ';
    if (locale.startsWith('en_IN')) return '₹';
    if (locale.startsWith('ja_')) return '¥';
    if (locale.startsWith('zh_')) return '¥';
  } catch (_) {}
  return '₦';
}

// ── Status helpers ────────────────────────────────────────────────────────────
String _statusLabel(String s) {
  const m = {
    'requested': 'Pending',
    'accepted': 'Accepted',
    'confirmed': 'Confirmed',
    'in_progress': 'In Progress',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
  };
  return m[s] ?? (s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s);
}

Color _statusColor(String s) {
  const m = {
    'requested': Color(0xFFF59E0B),
    'accepted': Color(0xFF3B82F6),
    'confirmed': Color(0xFF10B981),
    'in_progress': Color(0xFF8B5CF6),
    'completed': Color(0xFF059669),
    'cancelled': Color(0xFFEF4444),
  };
  return m[s] ?? GlayaColors.berry;
}

// ── Profile Screen ────────────────────────────────────────────────────────────
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _wallet;
  Map<String, dynamic>? _loyalty;
  Map<String, dynamic>? _ambassador;
  Map<String, dynamic>? _upcomingBooking;
  List<Map<String, dynamic>> _pastBookings = [];
  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _recentActivity = [];
  int _reviewCount = 0;
  bool _isLoading = true;
  String _appVersion = '1.0.0';
  final Map<String, bool> _notifToggles = {
    'appointmentReminders': true,
    'messages': true,
    'promotions': false,
    'beautyTips': false,
    'discounts': true,
    'walletUpdates': true,
  };
  List<Reel> _reels = [];
  List<Reel> _photos = [];
  bool _isLoadingReels = false;
  final ReelRepository _reelRepository = ReelRepository();

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _loadAll();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = info.version);
    } catch (_) {}
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadUserProfile(),
      _loadBookings(),
      _loadWallet(),
      _loadLoyalty(),
      _loadAmbassador(),
      _loadReviews(),
      _loadFavorites(),
      _loadReels(),
    ]);
    if (mounted) {
      setState(() {
        _recentActivity = _deriveRecentActivity();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final r = await ApiService.dio.get('/users/me');
      final data = r.data['data'] as Map<String, dynamic>?;
      print('ProfileScreen: Full user data received: $data');
      if (mounted && data != null) {
        print('ProfileScreen: User ID: ${data['id']}');
        print('ProfileScreen: User name: ${data['name']}');
        print('ProfileScreen: Photo URL (photoUrl): ${data['photoUrl']}');
        print('ProfileScreen: Photo URL (photo_url): ${data['photo_url']}');
        print('ProfileScreen: All keys in user data: ${data.keys.toList()}');
        setState(() {
          _user = data;
          _notifToggles['appointmentReminders'] =
              (data['notificationOptIn'] as bool?) ?? true;
          _notifToggles['messages'] =
              (data['notificationOptIn'] as bool?) ?? true;
          _notifToggles['walletUpdates'] =
              (data['notificationOptIn'] as bool?) ?? true;
        });
      }
    } catch (e) {
      print('ProfileScreen: Error loading user profile: $e');
    }
  }

  Future<void> _loadBookings() async {
    try {
      final res = await ApiService.dio.get('/bookings');
      final list =
          (res.data['data'] as List? ?? []).cast<Map<String, dynamic>>();
      final upcoming = list.where((b) {
        final s = b['status'] as String? ?? '';
        return s == 'confirmed' ||
            s == 'accepted' ||
            s == 'requested' ||
            s == 'in_progress';
      }).toList();
      final past = list.where((b) {
        final s = b['status'] as String? ?? '';
        return s == 'completed' || s == 'cancelled';
      }).toList();
      if (mounted) {
        setState(() {
          _upcomingBooking = upcoming.isNotEmpty ? upcoming.first : null;
          _pastBookings = past;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadWallet() async {
    try {
      final r = await ApiService.dio.get('/payments/wallets/me');
      if (mounted) {
        setState(() => _wallet = r.data['data'] as Map<String, dynamic>?);
      }
    } catch (_) {}
  }

  Future<void> _loadLoyalty() async {
    try {
      final r = await ApiService.dio.get('/loyalty/me');
      if (mounted) {
        setState(() => _loyalty = r.data['data'] as Map<String, dynamic>?);
      }
    } catch (_) {}
  }

  Future<void> _loadAmbassador() async {
    try {
      final r = await ApiService.dio.get('/ambassadors/me');
      final data = r.data['data'] as Map<String, dynamic>?;
      if (mounted && data != null && data['isAmbassador'] == true) {
        setState(() => _ambassador = data);
      }
    } catch (_) {}
  }

  Future<void> _loadReviews() async {
    try {
      final r = await ApiService.dio.get('/reviews/me');
      final list = (r.data['data'] as List? ?? []).cast<Map<String, dynamic>>();
      if (mounted) setState(() => _reviewCount = list.length);
    } catch (_) {}
  }

  Future<void> _loadFavorites() async {
    try {
      final r = await ApiService.dio.get('/favorites');
      final list = (r.data['data'] as List? ?? []).cast<Map<String, dynamic>>();
      if (mounted) setState(() => _favorites = list.take(5).toList());
    } catch (_) {}
  }

  Future<void> _loadReels() async {
    final userId = _user?['id']?.toString() ??
        ref.read(authNotifierProvider).valueOrNull?.id;
    if (userId == null || userId.isEmpty) return;
    setState(() => _isLoadingReels = true);
    try {
      final reels = await _reelRepository.getReelsByUser(userId);
      if (mounted) {
        setState(() {
          _reels = reels.where((r) => !r.isPhoto).toList();
          _photos = reels.where((r) => r.isPhoto).toList();
        });
      }
    } catch (e) {
      print('Error loading reels: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingReels = false);
      }
    }
  }

  List<Map<String, dynamic>> _deriveRecentActivity() {
    final activities = <Map<String, dynamic>>[];
    for (final b
        in _pastBookings.where((b) => b['status'] == 'completed').take(2)) {
      activities.add({
        'title': 'Booking Completed',
        'subtitle':
            b['professional']?['user']?['name'] as String? ?? 'Professional',
        'date': b['scheduledAt'] ?? b['scheduled_at'],
      });
    }
    final loyaltyHistory =
        (_loyalty?['history'] as List? ?? []).cast<Map<String, dynamic>>();
    for (final h in loyaltyHistory.take(1)) {
      final type = h['type'] as String? ?? '';
      activities.add({
        'title': type == 'review_given' ? 'Review Submitted' : 'Deposit Paid',
        'subtitle': h['description'] as String? ?? '',
        'date': h['createdAt'] ?? h['created_at'],
      });
    }
    return activities.take(3).toList();
  }

  Future<void> _updateNotificationToggle(String key, bool value) async {
    HapticFeedback.selection();
    setState(() => _notifToggles[key] = value);
    try {
      await ApiService.dio.put('/users/me', data: {'notificationOptIn': value});
    } catch (_) {}
  }

  Future<void> _logout() async {
    try {
      await ApiService.dio.post('/auth/logout');
    } catch (_) {}
    ref.read(authNotifierProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  int get _completedCount =>
      _pastBookings.where((b) => b['status'] == 'completed').length;
  int get _totalBookings =>
      (_pastBookings.length) + (_upcomingBooking != null ? 1 : 0);
  int get _reliabilityScore =>
      (_user?['reliabilityScore'] as num?)?.toInt() ?? 95;
  // Glaya Score — average rating professionals gave this customer.
  // Null when the customer has never been rated.
  double? get _glayaScore {
    final v = _user?['glayaScore'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  String? get _location =>
      (_user?['currentLocation']?['address'] as String?) ??
      (_user?['current_location']?['address'] as String?);
  int get _loyaltyPoints => (_loyalty?['points'] as num?)?.toInt() ?? 0;
  String get _loyaltyTier => (_loyalty?['tier'] as String?) ?? 'bronze';

  String get _displayName => (_user?['name'] as String?) ?? 'User';
  String? get _photoUrl {
    final url =
        (_user?['photoUrl'] as String?) ?? (_user?['photo_url'] as String?);
    print('ProfileScreen: Raw photo URL from user data: $url');
    if (url != null) {
      final replacedUrl = ConfigService().replaceLocalhost(url);
      print('ProfileScreen: Final photo URL: $replacedUrl');
      return replacedUrl;
    }
    print('ProfileScreen: No photo URL found');
    return null;
  }

  String get _role => (_user?['role'] as String?) ?? 'customer';
  String get _initials => _displayName.trim().isNotEmpty
      ? _displayName
          .trim()
          .split(' ')
          .map((w) => w[0])
          .take(2)
          .join()
          .toUpperCase()
      : 'U';

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final body = _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: GlayaColors.berry),
          )
        : _role == 'customer'
            ? _buildCustomerProfile()
            : _buildProfessionalProfile();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F0F4),
      body: isDesktop
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: body,
                ),
              ),
            )
          : body,
      bottomNavigationBar: GlayaBottomNav(currentIndex: 4, userRole: _role),
    );
  }

  Widget _buildCustomerProfile() {
    return _CustomerProfileView(
      user: _user,
      photoUrl: _photoUrl,
      displayName: _displayName,
      initials: _initials,
      role: _role,
      upcomingBooking: _upcomingBooking,
      pastBookings: _pastBookings,
      totalBookings: _totalBookings,
      glayaScore: _user?['glayaScore'] is num
          ? (_user!['glayaScore'] as num).toDouble()
          : double.tryParse(_user?['glayaScore']?.toString() ?? ''),
      reels: _reels,
      photos: _photos,
      ambassador: _ambassador,
      logout: _logout,
      refreshUser: () => ref.read(authNotifierProvider.notifier).refreshUser(),
      onEditProfile: _openEditProfile,
    );
  }

  Widget _buildProfessionalProfile() {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 16),
              _buildEditProfileCard(),
              const SizedBox(height: 16),
              _buildBeautyTrustScore(),
              const SizedBox(height: 16),
              _buildUpcomingAppointment(),
              const SizedBox(height: 16),
              _buildWalletSection(),
              if (_ambassador != null) ...[
                const SizedBox(height: 16),
                _buildAmbassadorCard(),
              ],
              const SizedBox(height: 16),
              _buildBeautyPassport(),
              const SizedBox(height: 16),
              _buildBeautyJourney(),
              const SizedBox(height: 16),
              _buildMyServices(),
              const SizedBox(height: 16),
              _buildMyPortfolio(),
              const SizedBox(height: 16),
              _buildQuickActions(),
              const SizedBox(height: 16),
              _buildReelsSection(),
              const SizedBox(height: 16),
              _buildRecentActivity(),
              const SizedBox(height: 16),
              _buildNotificationToggles(),
              const SizedBox(height: 16),
              _buildSecuritySection(),
              const SizedBox(height: 16),
              _buildSupportSection(),
              const SizedBox(height: 16),
              _buildAboutSection(),
              const SizedBox(height: 16),
              _buildLogoutButton(),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ],
    );
  }

  // ── Sliver App Bar ────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    final sinceYear = () {
      try {
        final createdAt = _user?['createdAt'] ?? _user?['created_at'];
        if (createdAt != null) {
          return DateTime.parse(createdAt as String).year.toString();
        }
      } catch (_) {}
      return DateTime.now().year.toString();
    }();

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: GlayaColors.berry,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFD6006E), Color(0xFF880E4F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    // Avatar
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF000000).withValues(alpha: 0.2),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: _buildAvatarWithFallback(_photoUrl),
                        ),
                        GestureDetector(
                          onTap:
                              _user == null ? null : () => _openEditProfile(),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 15,
                              color: GlayaColors.berry,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 8),
                    Text(
                      _displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Beauty Enthusiast • Since $sinceYear',
                      style:
                          const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    if (_location != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.white70,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _location!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (_user != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _openEditProfile(),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text(
                                'Edit Profile',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: GlayaColors.berry,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => WalletDialog.show(context),
                              icon: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 16),
                              label: const Text(
                                'Wallet',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: GlayaColors.berry,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    OutlinedButton.icon(
                      onPressed: () => context.push('/profile'),
                      icon: const Icon(
                        Icons.share,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Share',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_glayaScore != null)
                  Positioned(
                    right: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(child: _buildGlayaScoreBadge()),
                  ),
              ],
            ),
          ),
        ),
      ),
      title: Text(
        _displayName,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () => context.push('/notifications'),
        ),
      ],
    );
  }

  Widget _buildGlayaScoreBadge() {
    final score = _glayaScore;
    if (score == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 20),
          const SizedBox(height: 2),
          Text(
            score.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const Text(
            'GLAYA SCORE',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() => Container(
        color: GlayaColors.berry.withValues(alpha: 0.3),
        child: Center(
          child: Text(
            _initials,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      );

  Widget _buildAvatarWithFallback(String? url) {
    print('ProfileScreen: Building avatar with URL: $url');
    if (url == null || url.isEmpty) {
      print('ProfileScreen: URL is null or empty, using fallback');
      return _avatarFallback();
    }

    return ClipOval(
      child: Image.network(
        url,
        fit: BoxFit.cover,
        width: 96,
        height: 96,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 96,
            height: 96,
            color: GlayaColors.berry.withValues(alpha: 0.3),
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('ProfileScreen: Image loading error for URL $url: $error');
          print('ProfileScreen: Stack trace: $stackTrace');
          return _avatarFallback();
        },
      ),
    );
  }

  void _openEditProfile() {
    print('[DEBUG] _openEditProfile called');
    print('[DEBUG] User data: $_user');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        print('[DEBUG] EditProfileSheet builder called');
        return _EditProfileSheet(
          user: _user!,
          onSaved: () async {
            print('[DEBUG] Profile onSaved callback called');
            await _loadUserProfile();
            // Refresh auth state to update photo URL in home screen header
            await ref.read(authNotifierProvider.notifier).refreshUser();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile updated successfully'),
                  backgroundColor: GlayaColors.berry,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        );
      },
    ).then((_) {
      print('[DEBUG] Bottom sheet closed');
    }).catchError((e) {
      print('[DEBUG] Error showing bottom sheet: $e');
    });
  }

  // ── Edit Profile Card ────────────────────────────────────────────────────────────
  Widget _buildEditProfileCard() {
    return GestureDetector(
      onTap: _user == null ? null : () => _openEditProfile(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF000000).withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFD6006E), Color(0xFF880E4F)],
                ),
              ),
              child: Center(
                child: Text(
                  _initials,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _user?['phone'] as String? ?? 'No phone',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: GlayaColors.berry.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, size: 16, color: GlayaColors.berry),
                  SizedBox(width: 4),
                  Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: GlayaColors.berry,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Beauty Trust Score ───────────────────────────────────────────────────────
  Widget _buildBeautyTrustScore() {
    final score = _reliabilityScore;
    final starRating = (score / 20.0).clamp(0.0, 5.0).toStringAsFixed(1);
    final tier = _loyaltyTier.toLowerCase();
    final tierLabel = tier == 'gold'
        ? 'Platinum Member'
        : '${tier[0].toUpperCase()}${tier.substring(1)} Member';
    final completionRate =
        _totalBookings > 0 ? (_completedCount / _totalBookings) * 100 : 100.0;
    final beautyLevel = _loyaltyPoints ~/ 100;
    final levelProgress = ((_loyaltyPoints % 100) / 100.0).clamp(0.0, 1.0);

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionTitle('Beauty Trust Score', Icons.verified_outlined),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push('/loyalty'),
                child: const Row(
                  children: [
                    Text(
                      'View Reputation Details',
                      style: TextStyle(
                        fontSize: 12,
                        color: GlayaColors.berry,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: GlayaColors.berry,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Animated circular progress indicator for trust score
              SizedBox(
                width: 70,
                height: 70,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: score / 100.0,
                      strokeWidth: 6,
                      backgroundColor: GlayaColors.blushPink,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        GlayaColors.roseGold,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFD700),
                          size: 16,
                        ),
                        Text(
                          starRating,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trust Score',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF000000),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$score/100',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: GlayaColors.berry,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: GlayaColors.blushPink,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: GlayaColors.roseGold.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tier == 'platinum'
                          ? Icons.diamond
                          : tier == 'gold'
                              ? Icons.emoji_events
                              : tier == 'silver'
                                  ? Icons.military_tech
                                  : Icons.workspace_premium,
                      size: 16,
                      color: GlayaColors.berry,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tierLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: GlayaColors.berry,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _progressRow('On-Time Rate', score.toDouble(), 100.0),
          const SizedBox(height: 14),
          _progressRow('Booking Completion', completionRate, 100.0),
          const SizedBox(height: 16),
          Row(
            children: [
              _statColumn('Reviews Received', '$_reviewCount'),
              _statColumn('Beauty Level', '$beautyLevel'),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Level Progress',
                    style: TextStyle(fontSize: 12, color: Color(0xFF555555)),
                  ),
                  Text(
                    '${(levelProgress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: GlayaColors.berry,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: levelProgress,
                  backgroundColor: GlayaColors.blushPink,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    GlayaColors.roseGold,
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressRow(String label, double value, double max) {
    final pct = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
            ),
            Text(
              '${(pct * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: GlayaColors.berry,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: GlayaColors.blushPink,
            valueColor: const AlwaysStoppedAnimation<Color>(
              GlayaColors.roseGold,
            ),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _statColumn(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF000000)),
          ),
        ],
      ),
    );
  }

  // ── Beauty Journey stats ──────────────────────────────────────────────────────
  Widget _buildBeautyJourney() {
    final completed = _completedCount;
    final favoriteSalon = _favorites.isNotEmpty
        ? (_favorites.first['name'] as String? ?? '—')
        : '—';
    final favoriteStylist = _favorites.isNotEmpty
        ? (_favorites.first['name'] as String? ?? '—')
        : '—';
    final favoriteService = () {
      final counts = <String, int>{};
      for (final b in _pastBookings.where((b) => b['status'] == 'completed')) {
        final name = b['service']?['name'] as String? ?? 'Service';
        counts[name] = (counts[name] ?? 0) + 1;
      }
      if (counts.isEmpty) return '—';
      return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }();
    final streakMonths = (_loyaltyPoints ~/ 30).clamp(0, 99);
    final moneySaved = _loyaltyPoints * 0.5;

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('My Beauty Journey', Icons.auto_awesome_outlined),
          const SizedBox(height: 14),
          _journeyRow('Appointments Completed', '$completed'),
          _journeyRow('Favorite Salon', favoriteSalon),
          _journeyRow('Favorite Stylist', favoriteStylist),
          _journeyRow('Favorite Service', favoriteService),
          _journeyRow('Beauty Streak', '$streakMonths Months'),
          _journeyRow(
            'Money Saved',
            '${_getCurrencySymbol()}${moneySaved.toStringAsFixed(0)}',
          ),
        ],
      ),
    );
  }

  // ── My Services (Professional only) ────────────────────────────────────────────
  Widget _buildMyServices() {
    final professionalId = _user?['professionalId'] as String?;
    if (professionalId == null) return const SizedBox.shrink();

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionTitle('My Services', Icons.content_cut),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push('/services'),
                child: const Row(
                  children: [
                    Text(
                      'Manage Services',
                      style: TextStyle(
                        fontSize: 12,
                        color: GlayaColors.berry,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: GlayaColors.berry,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _emptyRow('Manage your services', () => context.push('/services')),
        ],
      ),
    );
  }

  // ── My Portfolio (Professional only) ──────────────────────────────────────────
  Widget _buildMyPortfolio() {
    final professionalId = _user?['professionalId'] as String?;
    if (professionalId == null) return const SizedBox.shrink();

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionTitle('My Portfolio', Icons.photo_library_outlined),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push('/portfolio'),
                child: const Row(
                  children: [
                    Text(
                      'Manage Portfolio',
                      style: TextStyle(
                        fontSize: 12,
                        color: GlayaColors.berry,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: GlayaColors.berry,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _emptyRow('Manage your portfolio', () => context.push('/portfolio')),
        ],
      ),
    );
  }

  Widget _journeyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  // ── Upcoming Appointment ──────────────────────────────────────────────────────
  Widget _buildUpcomingAppointment() {
    final b = _upcomingBooking;
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Upcoming Appointment', Icons.event_outlined),
          const SizedBox(height: 12),
          if (b == null)
            _emptyRow('No upcoming appointments', () => context.push('/book'))
          else ...[
            _upcomingAppointmentCard(b),
          ],
        ],
      ),
    );
  }

  Widget _upcomingAppointmentCard(Map<String, dynamic> b) {
    final serviceName = b['service']?['name'] as String? ?? 'Service';
    final stylistName =
        b['professional']?['user']?['name'] as String? ?? 'Stylist';
    final rawStatus = b['status'] as String? ?? '';
    final sLabel = _statusLabel(rawStatus);
    final sColor = _statusColor(rawStatus);
    final bookingId = b['id'] as String?;
    String dateStr = '';
    try {
      final dt = DateTime.parse(
        (b['scheduledAt'] ?? b['scheduled_at']) as String,
      );
      dateStr = DateFormat('EEE, MMM d • h:mm a').format(dt.toLocal());
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            GlayaColors.berry.withValues(alpha: 0.06),
            const Color(0xFF880E4F).withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GlayaColors.berry.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: GlayaColors.berry.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.spa_outlined,
                  color: GlayaColors.berry,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      'with $stylistName',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: sColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  sLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: sColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.access_time_outlined,
                size: 13,
                color: Color(0xFF000000),
              ),
              const SizedBox(width: 4),
              Text(
                dateStr,
                style: const TextStyle(fontSize: 12, color: Color(0xFF000000)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: bookingId != null
                      ? () => showBookingChatDialog(context, bookingId)
                      : null,
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                    color: GlayaColors.berry,
                  ),
                  label: const Text(
                    'Chat',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: GlayaColors.berry,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GlayaColors.berry),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: bookingId != null
                      ? () => context.push('/call/$bookingId')
                      : null,
                  icon: const Icon(
                    Icons.phone_outlined,
                    size: 16,
                    color: GlayaColors.berry,
                  ),
                  label: const Text(
                    'Call',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: GlayaColors.berry,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GlayaColors.berry),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: bookingId != null
                      ? () => context.push('/bookings/$bookingId')
                      : null,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text(
                    'View',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlayaColors.berry,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Wallet Section ───────────────────────────────────────────────────────────
  Widget _buildWalletSection() {
    final balance = (_wallet?['balance'] ?? _wallet?['available'] ?? 0.0);
    final balanceStr =
        '${_getCurrencySymbol()}${(balance is num ? balance : 0.0).toStringAsFixed(0)}';
    final cashback = (_wallet?['pendingBalance'] ?? 0.0);

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: GlayaColors.berry,
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                'Wallet',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push('/wallet'),
                child: const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Color(0xFFCCCCCC),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Available Balance',
            style: TextStyle(fontSize: 12, color: Color(0xFF000000)),
          ),
          const SizedBox(height: 4),
          Text(
            balanceStr,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 12),
          _walletSubRow('Beauty Credits', '${_getCurrencySymbol()}30'),
          const SizedBox(height: 8),
          _walletSubRow(
            'Cashback',
            '${_getCurrencySymbol()}${(cashback is num ? cashback : 0.0).toStringAsFixed(0)}',
          ),
          const SizedBox(height: 8),
          _walletSubRow('Pending Refund', '${_getCurrencySymbol()}0'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push('/wallet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlayaColors.berry,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Top Up',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton(
                  onPressed: () => context.push('/wallet'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Transactions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: GlayaColors.berry,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _walletSubRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  // ── Beauty Passport ────────────────────────────────────────────────────────────
  Widget _buildBeautyPassport() {
    final score = _reliabilityScore;
    final badges = <Map<String, dynamic>>[
      {
        'icon': Icons.emoji_events_outlined,
        'label': 'First Booking',
        'unlocked': _pastBookings.isNotEmpty,
      },
      {
        'icon': Icons.emoji_events_outlined,
        'label': '10 Appointments',
        'unlocked': _completedCount >= 10,
      },
      {
        'icon': Icons.emoji_events_outlined,
        'label': 'Platinum Customer',
        'unlocked': _loyaltyTier == 'gold',
      },
      {
        'icon': Icons.emoji_events_outlined,
        'label': 'Never Missed',
        'unlocked': score >= 95,
      },
      {
        'icon': Icons.emoji_events_outlined,
        'label': 'Top Reviewer',
        'unlocked': _reviewCount >= 10,
      },
      {
        'icon': Icons.emoji_events_outlined,
        'label': 'Referral Champion',
        'unlocked': (_user?['referralCode'] ?? _user?['referral_code']) != null,
      },
    ];
    final level = _loyaltyPoints ~/ 100;
    final progress = ((_loyaltyPoints % 100) / 100.0).clamp(0.0, 1.0);

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Beauty Passport', Icons.card_membership_outlined),
          const SizedBox(height: 14),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: badges.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, i) {
                final badge = badges[i];
                final unlocked = badge['unlocked'] as bool;
                final color = unlocked
                    ? const Color(0xFFFFD700)
                    : const Color(0xFFCCCCCC);
                return Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        badge['icon'] as IconData,
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 68,
                      child: Text(
                        badge['label'] as String,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: unlocked
                              ? const Color(0xFF333333)
                              : const Color(0xFFAAAAAA),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Beauty Level',
                style: TextStyle(fontSize: 12, color: Color(0xFF555555)),
              ),
              Text(
                'Level $level',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFFEEEEEE),
            valueColor: const AlwaysStoppedAnimation<Color>(GlayaColors.berry),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbassadorCard() {
    final profile = _ambassador?['profile'] as Map<String, dynamic>?;
    final stats = _ambassador?['stats'] as Map<String, dynamic>?;
    final code = profile?['referralCode'] as String? ?? '';
    final available = (stats?['available'] as num?) ?? 0;
    final earned = (stats?['totalEarned'] as num?) ?? 0;
    final referrals = stats?['referrals'] ?? 0;
    final currency = profile?['currency'] as String? ?? 'XAF';
    final label = currency == 'XAF' ? 'FCFA' : currency;
    return InkWell(
      onTap: () => context.push('/ambassador'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.handshake_outlined,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Ambassador Program',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _ambassadorStat('$referrals', 'Referrals'),
                _ambassadorStat(
                    '${available.toStringAsFixed(0)} $label', 'Available'),
                _ambassadorStat(
                    '${earned.toStringAsFixed(0)} $label', 'Earned'),
              ],
            ),
            const SizedBox(height: 10),
            Text('Your code: $code',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.9))),
          ],
        ),
      ),
    );
  }

  Widget _ambassadorStat(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: Colors.white.withOpacity(0.75))),
        ],
      ),
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    final actions = [
      (Icons.favorite_outline, 'Saved Professionals', '/search'),
      (Icons.location_on_outlined, 'Addresses', 'addresses'),
      (Icons.credit_card_outlined, 'Payment Methods', '/wallet'),
      (Icons.card_giftcard_outlined, 'Rewards', '/loyalty'),
      (Icons.handshake_outlined, 'Ambassador', '/ambassador'),
      (Icons.star_outline, 'Reviews', '/reviews'),
      (Icons.photo_library_outlined, 'Inspiration Gallery', '/search'),
      (Icons.calendar_today_outlined, 'Booking History', '/bookings'),
      (Icons.bookmark_outline, 'Wishlist', '/search'),
    ];

    // Add dashboard action for professionals
    if (_role == 'professional' || _role == 'both') {
      actions.insert(0, (
        Icons.business_outlined,
        'Business Dashboard',
        '/professional/dashboard',
      ));
    }

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Quick Actions', Icons.apps_outlined),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.4,
            ),
            itemCount: actions.length,
            itemBuilder: (_, i) {
              final a = actions[i];
              return InkWell(
                onTap: () {
                  if (a.$3 == 'addresses') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const AddressEditor(isProfessional: false),
                      ),
                    );
                  } else {
                    context.push(a.$3);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Row(
                    children: [
                      Icon(a.$1, color: GlayaColors.berry, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          a.$2,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Reels Section ─────────────────────────────────────────────────────────────
  Widget _buildReelsSection() {
    if (_isLoadingReels) {
      return _sectionCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(color: GlayaColors.berry),
          ),
        ),
      );
    }

    if (_reels.isEmpty) {
      return const SizedBox.shrink();
    }

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('My Glam Reels', Icons.videocam_outlined),
          const SizedBox(height: 14),
          ReelsWidget(reels: _reels),
        ],
      ),
    );
  }

  // ── Recent Activity ───────────────────────────────────────────────────────────
  Widget _buildRecentActivity() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Recent Activity', Icons.access_time_outlined),
          const SizedBox(height: 12),
          if (_recentActivity.isEmpty)
            const Text(
              'No recent activity',
              style: TextStyle(fontSize: 13, color: Color(0xFF000000)),
            )
          else
            ..._recentActivity.map((a) {
              String dateStr = '';
              try {
                final dt = DateTime.parse((a['date'] as String?) ?? '');
                dateStr = DateFormat('MMM d').format(dt.toLocal());
              } catch (_) {}
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Color(0xFF10B981),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a['title'] as String,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          Text(
                            a['subtitle'] as String,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF000000),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Notification Toggles ──────────────────────────────────────────────────────
  Widget _buildNotificationToggles() {
    final toggles = [
      ('appointmentReminders', 'Appointment Reminders', true),
      ('messages', 'Messages', true),
      ('promotions', 'Promotions', false),
      ('beautyTips', 'Beauty Tips', false),
      ('discounts', 'Discounts', true),
      ('walletUpdates', 'Wallet Updates', true),
    ];

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Notifications', Icons.notifications_none),
          const SizedBox(height: 8),
          ...toggles.map((t) {
            final key = t.$1;
            return Material(
              color: Colors.transparent,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _notifToggles[key] ?? t.$3,
                onChanged: (v) => _updateNotificationToggle(key, v),
                title: Text(
                  t.$2,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                activeTrackColor: GlayaColors.berry.withValues(alpha: 0.4),
                activeThumbColor: GlayaColors.berry,
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Security ──────────────────────────────────────────────────────────────────
  Widget _buildSecuritySection() {
    final items = [
      (
        Icons.phone_outlined,
        'Phone Number',
        null,
        _user?['phone'] as String? ?? '—',
      ),
      (Icons.lock_outline, 'Two-Factor Authentication', '/settings', null),
      (Icons.devices_outlined, 'Devices', '/settings', null),
      (Icons.language_outlined, 'Language', '/settings', null),
      (
        Icons.privacy_tip_outlined,
        'Privacy Settings',
        '/cms/privacy-policy',
        null
      ),
    ];
    return _menuSection('Security', Icons.shield_outlined, items);
  }

  // ── Support ───────────────────────────────────────────────────────────────────
  Widget _buildSupportSection() {
    final items = [
      (Icons.smart_toy_outlined, 'Gigi (AI Support)', '/support/gigi', null),
      (Icons.help_outline, 'Help Centre', '/cms/support', null),
      (Icons.chat_bubble_outline, 'Human Support', '/support/chat', null),
      (Icons.report_problem_outlined, 'Report Issue', '/cms/support', null),
      (Icons.menu_book_outlined, 'FAQs', '/cms/support', null),
    ];
    return _menuSection('Support', Icons.support_agent_outlined, items);
  }

  // ── About ─────────────────────────────────────────────────────────────────────
  Widget _buildAboutSection() {
    final items = [
      (Icons.info_outline, 'About Glaya', '/cms/about-us', null),
      (
        Icons.privacy_tip_outlined,
        'Privacy Policy',
        '/cms/privacy-policy',
        null
      ),
      (
        Icons.description_outlined,
        'Terms of Service',
        '/cms/terms-of-service',
        null
      ),
      (Icons.new_releases_outlined, 'Version $_appVersion', null, null),
    ];
    return _menuSection('About', Icons.info_outline, items);
  }

  Widget _menuSection(
    String title,
    IconData icon,
    List<(IconData, String, String?, String?)> items,
  ) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title, icon),
          const SizedBox(height: 8),
          ...items.map(
            (t) => InkWell(
              onTap: t.$3 != null ? () => context.push(t.$3!) : null,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
                child: Row(
                  children: [
                    Icon(t.$1, size: 20, color: const Color(0xFF555555)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t.$2,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    if (t.$4 != null)
                      Text(
                        t.$4!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF000000),
                        ),
                      ),
                    if (t.$3 != null)
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Color(0xFFCCCCCC),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Logout Button ─────────────────────────────────────────────────────────────
  Widget _buildLogoutButton() {
    return _sectionCard(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout, size: 18),
          label: const Text(
            'LOG OUT',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  // ── Shared primitives ─────────────────────────────────────────────────────────
  Widget _sectionCard({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF000000).withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );

  Widget _sectionTitle(String title, IconData icon) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: GlayaColors.berry),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      );

  Widget _emptyRow(String msg, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: GlayaColors.berry.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: GlayaColors.berry.withValues(alpha: 0.1)),
          ),
          child: Center(
            child: Text(
              msg,
              style: const TextStyle(
                fontSize: 13,
                color: GlayaColors.berry,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
}

// ── Customer Profile View (New UI) ─────────────────────────────────────────────
class _CustomerProfileView extends StatefulWidget {
  final Map<String, dynamic>? user;
  final String? photoUrl;
  final String displayName;
  final String initials;
  final String role;
  final Map<String, dynamic>? upcomingBooking;
  final List<Map<String, dynamic>> pastBookings;
  final int totalBookings;
  final double? glayaScore;
  final List<Reel> reels;
  final List<Reel> photos;
  final Map<String, dynamic>? ambassador;
  final VoidCallback logout;
  final VoidCallback refreshUser;
  final VoidCallback onEditProfile;

  const _CustomerProfileView({
    required this.user,
    required this.photoUrl,
    required this.displayName,
    required this.initials,
    required this.role,
    required this.upcomingBooking,
    required this.pastBookings,
    required this.totalBookings,
    this.glayaScore,
    this.reels = const [],
    this.photos = const [],
    this.ambassador,
    required this.logout,
    required this.refreshUser,
    required this.onEditProfile,
  });

  @override
  State<_CustomerProfileView> createState() => _CustomerProfileViewState();
}

class _CustomerProfileViewState extends State<_CustomerProfileView> {
  BookingTab _tab = BookingTab.upcoming;
  bool _homeService = true;
  bool _reminders = true;

  // Glaya color scheme — mirrors the React app palette
  static const ground = GlayaColors.pinkBg; // #FFF0F5
  static const ink = GlayaColors.textPrimary; // #1A1A2E
  static const muted = Color(0xFF000000); // #6B7280
  static const accent = GlayaColors.berry; // #E91E8C
  static const accentDark = GlayaColors.pinkDark; // #C2185B
  static const accentSoft = GlayaColors.pinkLight; // #FCE4EC
  static const line = GlayaColors.divider; // #E5E7EB
  static const segment = GlayaColors.pinkBg;
  static const switchOff = Color(0xFF000000); // #9CA3AF

  List<BookingItem> get _upcomingList {
    if (widget.upcomingBooking == null) return [];
    return [
      BookingItem(
        widget.upcomingBooking!['service']?['name'] as String? ?? 'Service',
        'with ${widget.upcomingBooking!['professional']?['user']?['name'] as String? ?? 'Stylist'}',
        widget.upcomingBooking!['isHomeService'] == true
            ? 'Home visit'
            : 'Salon',
        _formatDate(
          widget.upcomingBooking!['scheduledAt'] ??
              widget.upcomingBooking!['scheduled_at'],
        ),
        'Details',
      ),
    ];
  }

  List<BookingItem> get _pastList {
    return widget.pastBookings.take(5).map((b) {
      return BookingItem(
        b['service']?['name'] as String? ?? 'Service',
        'with ${b['professional']?['user']?['name'] as String? ?? 'Stylist'}',
        b['isHomeService'] == true ? 'Home visit' : 'Salon',
        'Completed',
        'Rebook',
      );
    }).toList();
  }

  List<BookingItem> get _savedList {
    // TODO: Fetch saved professionals from API
    return [];
  }

  void _openEditProfile() {
    print('[DEBUG] _CustomerProfileView: _openEditProfile called');
    // Call the parent's edit profile callback
    widget.onEditProfile();
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'TBD';
    try {
      final dt = DateTime.parse(date as String);
      final now = DateTime.now();
      if (dt.isAfter(now)) {
        return '${[
          'Mon',
          'Tue',
          'Wed',
          'Thu',
          'Fri',
          'Sat',
          'Sun'
        ][dt.weekday - 1]}, ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return 'Completed';
    } catch (_) {
      return 'TBD';
    }
  }

  Map<BookingTab, List<BookingItem>> get _lists => {
        BookingTab.upcoming: _upcomingList,
        BookingTab.past: _pastList,
        BookingTab.saved: _savedList,
      };

  @override
  Widget build(BuildContext context) {
    final sinceYear = () {
      try {
        final createdAt =
            widget.user?['createdAt'] ?? widget.user?['created_at'];
        if (createdAt != null) {
          return DateTime.parse(createdAt as String).year.toString();
        }
      } catch (_) {}
      return DateTime.now().year.toString();
    }();

    return Scaffold(
      backgroundColor: ground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            _header(),
            const SizedBox(height: 20),
            _profileCard(sinceYear),
            const SizedBox(height: 20),
            _reelsGridSection(),
            _photosGridSection(),
            _modeToggle(),
            const SizedBox(height: 20),
            _stats(),
            const SizedBox(height: 20),
            _tabs(),
            const SizedBox(height: 12),
            if (_lists[_tab]!.isEmpty)
              _emptyBookings()
            else
              for (final item in _lists[_tab]!) ...[
                _bookingCard(item),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 8),
            if (widget.ambassador != null) ...[
              _ambassadorBanner(),
              const SizedBox(height: 12),
            ],
            _settingsCard(),
            const SizedBox(height: 12),
            TextButton(
              onPressed: widget.logout,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: accentDark,
              ),
              child: const Text(
                'Log out',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Profile',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: ink,
            ),
          ),
          Material(
            color: Colors.white,
            shape: const CircleBorder(side: BorderSide(color: line)),
            child: IconButton(
              tooltip: 'Settings',
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined, color: ink),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ),
        ],
      );

  Widget _profileCard(String sinceYear) => _card(
        radius: 24,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Hero section - mirrors React gp-hero
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 40,
                  backgroundColor: accent,
                  backgroundImage: widget.photoUrl != null
                      ? NetworkImage(widget.photoUrl!)
                      : null,
                  child: widget.photoUrl == null
                      ? Text(
                          widget.initials,
                          style: const TextStyle(
                              fontSize: 28, color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.displayName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Member badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFD54F)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                size: 14, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 4),
                            Text(
                              'Member',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFB8860B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Subtitle
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome,
                              size: 16, color: accent),
                          const SizedBox(width: 4),
                          Text(
                            'Beauty Enthusiast',
                            style: TextStyle(
                              fontSize: 13,
                              color: accent.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Location
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: muted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.user?['currentLocation'] as String? ??
                                  'Location not set',
                              style:
                                  const TextStyle(fontSize: 13, color: muted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Action buttons - mirrors React gp-hero-actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openEditProfile,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit Profile'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      foregroundColor: accent,
                      side: const BorderSide(color: accent, width: 1.5),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlayaGradientButton(
                    label: 'Wallet',
                    icon: Icons.account_balance_wallet_outlined,
                    small: true,
                    onPressed: () => WalletDialog.show(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Share button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Implement share functionality
                },
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share Profile'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: accent,
                  side: const BorderSide(color: accent, width: 1.5),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Beauty Level section - mirrors React gp-beauty-level
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Beauty Level',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '18',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Progress bar
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: 0.65,
                            child: Container(
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '750 pts to next level',
                          style: TextStyle(
                            fontSize: 11,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Medal emoji
                  const Text('🏅', style: TextStyle(fontSize: 48)),
                ],
              ),
            ),
          ],
        ),
      );

  // ── Reels / Photos grids (3-column) ──────────────────────────────────────
  Widget _reelsGridSection() {
    if (widget.reels.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MY REELS',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: muted,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.72,
          ),
          itemCount: widget.reels.length,
          itemBuilder: (_, i) => _mediaCard(widget.reels[i]),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _photosGridSection() {
    if (widget.photos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MY PHOTOS',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: muted,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.72,
          ),
          itemCount: widget.photos.length,
          itemBuilder: (_, i) => _mediaCard(widget.photos[i]),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _mediaCard(Reel reel) {
    final url = ConfigService().replaceLocalhost(reel.videoUrl);
    return GestureDetector(
      onTap: () => _openMedia(reel),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            border: Border.all(color: line),
          ),
          child: reel.isPhoto
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _mediaPlaceholder(reel),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    _mediaPlaceholder(reel),
                    const Center(
                      child: Icon(Icons.play_circle_fill,
                          color: Colors.white70, size: 36),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _mediaPlaceholder(Reel reel) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A154B), Color(0xFF2D1B4E)],
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (reel.title != null && reel.title!.isNotEmpty)
            Text(
              reel.title!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  void _openMedia(Reel reel) {
    if (reel.isPhoto) {
      final url = ConfigService().replaceLocalhost(reel.videoUrl);
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Color(0xFF000000),
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              InteractiveViewer(
                child: Center(
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 24,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final list = reel.isPhoto ? widget.photos : widget.reels;
      final index = list.indexWhere((r) => r.id == reel.id);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReelScreen(
            reels: list,
            initialIndex: index < 0 ? 0 : index,
          ),
        ),
      );
    }
  }

  Widget _modeToggle() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'I USUALLY BOOK',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: muted,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: segment,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                _segment(
                  'At home',
                  _homeService,
                  () => setState(() => _homeService = true),
                ),
                const SizedBox(width: 4),
                _segment(
                  'At a salon',
                  !_homeService,
                  () => setState(() => _homeService = false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _homeService
                ? 'Stylists come to you. We will show home-service pros first.'
                : 'We will show salons near you first.',
            style: const TextStyle(fontSize: 14, color: muted),
          ),
        ],
      );

  Widget _segment(String label, bool selected, VoidCallback onTap) => Expanded(
        child: Material(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: SizedBox(
              height: 44,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? ink : muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _stats() => Row(
        children: [
          _stat(widget.totalBookings.toString(), 'Bookings'),
          const SizedBox(width: 10),
          _stat('0', 'Saved'),
          const SizedBox(width: 10),
          _stat('0', 'Reviews'),
        ],
      );

  Widget _stat(String value, String label) => Expanded(
        child: _card(
          radius: 16,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 24, color: ink)),
              Text(label, style: const TextStyle(fontSize: 12, color: muted)),
            ],
          ),
        ),
      );

  Widget _tabs() {
    const labels = {
      BookingTab.upcoming: 'Upcoming',
      BookingTab.past: 'Past',
      BookingTab.saved: 'Saved',
    };
    return Row(
      children: [
        for (final t in BookingTab.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _tab == t ? ink : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: _tab == t ? null : Border.all(color: line),
                ),
                child: Text(
                  labels[t]!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: _tab == t ? FontWeight.w700 : FontWeight.w500,
                    color: _tab == t ? Colors.white : ink,
                  ),
                ),
              ),
            ),
          ),
          if (t != BookingTab.saved) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _emptyBookings() => _card(
        radius: 20,
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              _tab == BookingTab.upcoming
                  ? Icons.calendar_today_outlined
                  : _tab == BookingTab.past
                      ? Icons.history_outlined
                      : Icons.bookmark_outline,
              size: 48,
              color: muted,
            ),
            const SizedBox(height: 16),
            Text(
              _tab == BookingTab.upcoming
                  ? 'No upcoming bookings'
                  : _tab == BookingTab.past
                      ? 'No past bookings'
                      : 'No saved professionals',
              style: const TextStyle(fontSize: 16, color: ink),
            ),
            const SizedBox(height: 8),
            Text(
              _tab == BookingTab.upcoming
                  ? 'Book your first beauty service'
                  : _tab == BookingTab.past
                      ? 'Your completed bookings will appear here'
                      : 'Save your favorite professionals',
              style: const TextStyle(fontSize: 14, color: muted),
            ),
          ],
        ),
      );

  Widget _bookingCard(BookingItem item) => _card(
        radius: 20,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        style: const TextStyle(fontSize: 14, color: muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.tag,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accentDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.when,
                    style: const TextStyle(fontSize: 14, color: ink)),
                FilledButton(
                  onPressed: () => context.push('/bookings'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    item.cta,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _ambassadorBanner() {
    final profile = widget.ambassador?['profile'] as Map<String, dynamic>?;
    final stats = widget.ambassador?['stats'] as Map<String, dynamic>?;
    final code = profile?['referralCode'] as String? ?? '';
    final available = (stats?['available'] as num?) ?? 0;
    final currency = profile?['currency'] as String? ?? 'XAF';
    final label = currency == 'XAF' ? 'FCFA' : currency;
    return InkWell(
      onTap: () => context.push('/ambassador'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.handshake_outlined,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ambassador Program',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    'Code $code · ${available.toStringAsFixed(0)} $label available',
                    style: TextStyle(
                        fontSize: 12, color: Colors.white.withOpacity(0.85)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _settingsCard() => _card(
        radius: 20,
        child: Column(
          children: [
            _row('Saved addresses', onTap: () => context.push('/addresses')),
            _divider(),
            _row('Payment methods', onTap: () => context.push('/wallet')),
            _divider(),
            _row('Ambassador Program',
                onTap: () => context.push('/ambassador')),
            _divider(),
            _row('Language', trailingText: 'English', onTap: () {}),
            _divider(),
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Appointment reminders',
                      style: TextStyle(fontSize: 15, color: ink),
                    ),
                    Switch(
                      value: _reminders,
                      onChanged: (v) => setState(() => _reminders = v),
                      activeThumbColor: Colors.white,
                      activeTrackColor: accent,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: switchOff,
                      trackOutlineColor: const WidgetStatePropertyAll(
                        Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _divider(),
            _row('Help & support', onTap: () => context.push('/support')),
          ],
        ),
      );

  Widget _row(String label, {String? trailingText, VoidCallback? onTap}) =>
      InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontSize: 15, color: ink)),
                Row(
                  children: [
                    if (trailingText != null)
                      Text(
                        trailingText,
                        style: const TextStyle(fontSize: 14, color: muted),
                      ),
                    const Icon(Icons.chevron_right, color: muted),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _divider() => const Divider(height: 1, thickness: 1, color: line);

  Widget _card({
    required Widget child,
    double radius = 20,
    EdgeInsetsGeometry? padding,
  }) =>
      Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: line),
        ),
        child: child,
      );
}

enum BookingTab { upcoming, past, saved }

class BookingItem {
  final String title, subtitle, tag, when, cta;
  const BookingItem(this.title, this.subtitle, this.tag, this.when, this.cta);
}
