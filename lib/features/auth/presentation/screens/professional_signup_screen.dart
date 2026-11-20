import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../shared/data/location_data.dart';
import '../../../../shared/services/api_service.dart';
import '../../../home/presentation/screens/pick_map_screen.dart';
import '../providers/auth_notifier.dart';

// ── Category option data ──────────────────────────────────────────────────────
class _CategoryOption {
  final String id;
  final String name;
  final String? icon;
  const _CategoryOption(this.id, this.name, this.icon);
}

// ══════════════════════════════════════════════════════════════════════════════
class ProfessionalSignupScreen extends ConsumerStatefulWidget {
  const ProfessionalSignupScreen({super.key});

  @override
  ConsumerState<ProfessionalSignupScreen> createState() =>
      _ProfessionalSignupScreenState();
}

class _ProfessionalSignupScreenState
    extends ConsumerState<ProfessionalSignupScreen> {
  final _nameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _neighborhoodController = TextEditingController();

  String? _locationCountryIso;
  String? _phoneCountryIso = 'NG';
  String? _selectedState;
  String? _selectedCity;
  String? _selectedNeighborhood;
  final Set<String> _selectedCategoryIds = {};
  bool _isLoading = false;
  bool _obscurePassword = true;
  File? _profilePhotoFile;
  String? _uploadedPhotoUrl;
  List<_CategoryOption> _categories = [];

  // Location picker data
  LatLng? _selectedLocation;
  String? _selectedAddress;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await ApiService.dio.get('/categories');
      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'];
        setState(() {
          _categories = data
              .map((c) => _CategoryOption(
                    c['id'],
                    c['name'],
                    c['icon'],
                  ))
              .toList();
        });
      }
    } catch (e) {
      print('Failed to load categories: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
      setState(() {
        _profilePhotoFile = File(pickedFile.path);
      });
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
    print('Professional signup submit button pressed');
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name')),
      );
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number')),
      );
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address')),
      );
      return;
    }
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }
    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category')),
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

      // Upload photo first if present
      String? photoUrlToUse;
      if (_profilePhotoFile != null) {
        photoUrlToUse = await ref
            .read(authNotifierProvider.notifier)
            .uploadProfilePhoto(_profilePhotoFile!);
      }

      // Register the user with basic info (as customer first, will upgrade on admin approval)
      await ref.read(authNotifierProvider.notifier).register(
            name: _nameController.text.trim(),
            phone: '$_phoneCode${_phoneController.text.trim()}',
            password: _passwordController.text,
            role:
                'professional', // Backend will create as customer, pending professional approval
            email: _emailController.text.trim(),
            businessName: _businessNameController.text.trim(),
            categoryIds: _selectedCategoryIds.toList(),
            country: countryName,
            regionState: _selectedState,
            city: _selectedCity,
            neighborhood: _selectedNeighborhood?.trim() ??
                _neighborhoodController.text.trim(),
            latitude: _selectedLocation?.latitude,
            longitude: _selectedLocation?.longitude,
            fullAddress: _selectedAddress,
            photoUrl: photoUrlToUse,
          );

      if (mounted) {
        // Refresh user data to ensure photo is loaded
        await ref.read(authNotifierProvider.notifier).refreshUser();
        context.go('/');
      }
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
          SnackBar(content: Text('Registration failed: $message')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/signup-selection'),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/professional_signup_background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header Content ──
                const Padding(
                  padding: EdgeInsets.fromLTRB(0, 8, 0, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Professional Sign Up',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Join our community of beauty professionals',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
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
                                        color: const Color(0xFFD4AF37),
                                        width: 3),
                                    color: const Color(0xFFE0E0E0),
                                  ),
                                  child: _profilePhotoFile != null
                                      ? ClipOval(
                                          child: Image.file(
                                            _profilePhotoFile!,
                                            fit: BoxFit.cover,
                                            width: 88,
                                            height: 88,
                                            cacheWidth: 176,
                                          ),
                                        )
                                      : const Icon(Icons.person,
                                          size: 32, color: Color(0xFF9E9E9E)),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFFD4AF37),
                                    ),
                                    child: const Icon(Icons.add,
                                        color: Colors.white, size: 14),
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
                                color: Color(0xFFD4AF37),
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Tap to choose from gallery or camera',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF999999)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                          _nameController, 'Full Name', Icons.person_outline),
                      const SizedBox(height: 12),
                      _buildTextField(_businessNameController,
                          'Business Name (optional)', Icons.business_outlined),
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
                                        child: Text('${c.flag} ${c.code}',
                                            style:
                                                const TextStyle(fontSize: 13)),
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
                      const SizedBox(height: 12),
                      _buildTextField(
                          _passwordController, 'Password', Icons.lock_outline,
                          obscureText: true),
                      const SizedBox(height: 20),

                      // ── Categories Dropdown ──
                      const Text('What Do You Do?',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E))),
                      const SizedBox(height: 4),
                      const Text(
                          'Select all categories you offer (at least one)',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF757575))),
                      const SizedBox(height: 10),
                      _buildCategoryDropdown(),
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
                      // Show dropdown for Cameroon neighborhoods, otherwise text field
                      _locationCountryIso == 'CM' &&
                              _selectedCity != null &&
                              getNeighborhoodsForCity(_selectedCity).isNotEmpty
                          ? _buildDropdown<String>(
                              value: _selectedNeighborhood,
                              hint: 'Select Neighborhood',
                              icon: Icons.map_outlined,
                              items: getNeighborhoodsForCity(_selectedCity)
                                  .map((n) => DropdownMenuItem(
                                        value: n,
                                        child: Text(n),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() {
                                _selectedNeighborhood = v;
                                _neighborhoodController.text = v ?? '';
                              }),
                            )
                          : _buildTextField(_neighborhoodController,
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
                                ? const Color(0xFFD4AF37).withValues(alpha: 0.1)
                                : const Color(0xFFF9F9F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _selectedLocation != null
                                  ? const Color(0xFFD4AF37)
                                  : const Color(0xFFE0E0E0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 20,
                                color: _selectedLocation != null
                                    ? const Color(0xFFD4AF37)
                                    : const Color(0xFF757575),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedAddress ?? 'Pick location on map',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _selectedLocation != null
                                        ? const Color(0xFFD4AF37)
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              if (_selectedLocation != null)
                                const Icon(
                                  Icons.check_circle,
                                  size: 20,
                                  color: Color(0xFFD4AF37),
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
      ),
    );
  }

  // ── TEXT FIELD ─────────────────────────────────────────────────────────────
  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {TextInputType keyboardType = TextInputType.text,
      bool obscureText = false}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText ? _obscurePassword : false,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black87),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF757575)),
        suffixIcon: obscureText
            ? IconButton(
                icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: const Color(0xFFD4AF37)),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
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
          borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
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
        initialValue: value,
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

  // ── CATEGORY DROPDOWN + SHEET ─────────────────────────────────────────────
  Widget _buildCategoryDropdown() {
    final selectedNames = _categories
        .where((c) => _selectedCategoryIds.contains(c.id))
        .map((c) => c.name)
        .join(', ');

    return GestureDetector(
      onTap: _openCategorySheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.category_outlined,
                size: 20, color: Color(0xFF757575)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedNames.isEmpty ? 'Select categories' : selectedNames,
                style: TextStyle(
                  fontSize: 14,
                  color: selectedNames.isEmpty
                      ? Colors.black87
                      : const Color(0xFF1A1A2E),
                  fontWeight: selectedNames.isEmpty
                      ? FontWeight.normal
                      : FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down,
                size: 20, color: Color(0xFF757575)),
          ],
        ),
      ),
    );
  }

  void _openCategorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'What Do You Do?',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A2E)),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Select all categories you offer',
                          style:
                              TextStyle(fontSize: 13, color: Color(0xFF757575)),
                        ),
                      ),
                    ),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0xFFF0F0F0)),
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final isSelected =
                              _selectedCategoryIds.contains(cat.id);
                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedCategoryIds.remove(cat.id);
                                } else {
                                  _selectedCategoryIds.add(cat.id);
                                }
                              });
                              setSheetState(() {});
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              child: Row(
                                children: [
                                  Text(cat.icon ?? '✂️',
                                      style: const TextStyle(fontSize: 22)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      cat.name,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? const Color(0xFFD4AF37)
                                            : const Color(0xFF1A1A2E),
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle,
                                        color: Color(0xFFD4AF37), size: 20)
                                  else
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: const Color(0xFFE0E0E0),
                                            width: 1.5),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24)),
                          ),
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Text(
                            _selectedCategoryIds.isEmpty
                                ? 'Done'
                                : 'Done (${_selectedCategoryIds.length} selected)',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── SUBMIT BUTTON ─────────────────────────────────────────────────────────
  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _submit,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF5C3D2E),
              Color(0xFF8B6914),
              Color(0xFFA67C52),
            ],
          ),
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
                'Create Account',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}
