import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../../shared/theme/colors.dart';
import '../../../../../shared/theme/text_styles.dart';
import '../../../../../shared/utils/responsive_helper.dart';
import '../providers/auth_notifier.dart';
import '../../../home/presentation/screens/pick_map_screen.dart';

class CustomerSignupScreen extends ConsumerStatefulWidget {
  const CustomerSignupScreen({super.key});

  @override
  ConsumerState<CustomerSignupScreen> createState() =>
      _CustomerSignupScreenState();
}

class _CustomerSignupScreenState extends ConsumerState<CustomerSignupScreen> {
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _countryCode = '+234';

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralController = TextEditingController();

  // Location picker data
  LatLng? _selectedLocation;
  String? _selectedAddress;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    print('Customer signup submit button pressed');
    final name = _nameController.text.trim();
    final rawPhone = _phoneController.text.trim();
    final phone = '$_countryCode$rawPhone';
    final password = _passwordController.text;
    final referral = _referralController.text.trim();

    if (name.isEmpty) {
      _snack('Please enter your name');
      return;
    }
    if (phone.isEmpty) {
      _snack('Please enter your phone number');
      return;
    }
    if (password.length < 6) {
      _snack('Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).register(
            name: name,
            phone: phone,
            password: password,
            role: 'customer',
            referralCode: referral.isEmpty ? null : referral,
            latitude: _selectedLocation?.latitude,
            longitude: _selectedLocation?.longitude,
            fullAddress: _selectedAddress,
          );
      if (mounted) {
        final from = GoRouterState.of(context).uri.queryParameters['from'];
        context.go(from ?? '/');
      }
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF667EEA),
                    Color(0xFF764BA2),
                  ],
                ),
              ),
            ),
          ),
          // Form content
          SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 520.0 : double.infinity,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),

                        // Back button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => context.go('/signup-selection'),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Branding ──────────────────────────────────────────
                        Image.asset(
                          'assets/logo.png',
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Create your account',
                          style: TextStyle(fontSize: 15, color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 36),

                        // ── White form card ───────────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Color(0xFF000000).withValues(alpha: 0.15),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── Name ────────────────────────────────────────
                              TextField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                style:
                                    const TextStyle(color: Color(0xFF000000)),
                                decoration: InputDecoration(
                                  labelText: 'Full Name',
                                  hintText: 'Jane Doe',
                                  hintStyle:
                                      const TextStyle(color: Color(0xFF000000)),
                                  prefixIcon: const Icon(Icons.person_outline,
                                      color: GlayaColors.berry),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: GlayaColors.berry, width: 2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ── Phone ───────────────────────────────────────
                              Container(
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    // Country code picker
                                    CountryCodePicker(
                                      onChanged: (code) {
                                        setState(() => _countryCode =
                                            code.dialCode ?? '+234');
                                      },
                                      initialSelection: 'NG',
                                      favorite: const [
                                        'NG',
                                        'GB',
                                        'US',
                                        'GH',
                                        'KE',
                                        'ZA'
                                      ],
                                      showFlag: true,
                                      showFlagDialog: true,
                                      showFlagMain: true,
                                      showCountryOnly: false,
                                      showOnlyCountryWhenClosed: false,
                                      alignLeft: false,
                                      padding: EdgeInsets.zero,
                                      textStyle: const TextStyle(
                                        fontSize: 14,
                                        color: GlayaColors.textPrimary,
                                      ),
                                      dialogTextStyle: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF000000),
                                      ),
                                      dialogBackgroundColor: Colors.white,
                                      searchDecoration: InputDecoration(
                                        hintText: 'Search country...',
                                        hintStyle: const TextStyle(
                                            color: Color(0xFF000000)),
                                        prefixIcon: const Icon(Icons.search,
                                            color: GlayaColors.berry),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                      barrierColor: Color(0xFF000000)
                                          .withValues(alpha: 0.5),
                                      boxDecoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      pickerStyle: PickerStyle.bottomSheet,
                                    ),
                                    Container(
                                        width: 1,
                                        height: 40,
                                        color: Colors.grey.shade300),
                                    // Phone number input
                                    Expanded(
                                      child: TextField(
                                        controller: _phoneController,
                                        keyboardType: TextInputType.phone,
                                        style: const TextStyle(
                                            color: Color(0xFF000000)),
                                        decoration: const InputDecoration(
                                          hintText: '7XX XXX XXX',
                                          hintStyle: TextStyle(
                                              color: Color(0xFF000000)),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ── Password ─────────────────────────────────────
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style:
                                    const TextStyle(color: Color(0xFF000000)),
                                decoration: InputDecoration(
                                  hintText: 'Enter password',
                                  hintStyle:
                                      const TextStyle(color: Color(0xFF000000)),
                                  prefixIcon: const Icon(Icons.lock_outline,
                                      color: GlayaColors.berry),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: GlayaColors.berry),
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: GlayaColors.berry, width: 2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ── Referral code (optional) ───────
                              TextField(
                                controller: _referralController,
                                style:
                                    const TextStyle(color: Color(0xFF000000)),
                                decoration: InputDecoration(
                                  hintText: 'Enter referral code (optional)',
                                  hintStyle:
                                      const TextStyle(color: Color(0xFF000000)),
                                  prefixIcon: const Icon(
                                      Icons.card_giftcard_outlined,
                                      color: GlayaColors.berry),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: GlayaColors.berry, width: 2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Location picker button
                              GestureDetector(
                                onTap: _openLocationPicker,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: _selectedLocation != null
                                        ? GlayaColors.berry
                                            .withValues(alpha: 0.1)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _selectedLocation != null
                                          ? GlayaColors.berry
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 20,
                                        color: _selectedLocation != null
                                            ? GlayaColors.berry
                                            : Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _selectedAddress ??
                                              'Pick location on map (optional)',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: _selectedLocation != null
                                                ? GlayaColors.berry
                                                : Color(0xFF000000),
                                          ),
                                        ),
                                      ),
                                      if (_selectedLocation != null)
                                        const Icon(
                                          Icons.check_circle,
                                          size: 20,
                                          color: GlayaColors.berry,
                                        )
                                      else
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // ── Submit button ─────────────────────────────────
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: GlayaColors.berry,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : const Text(
                                          'Sign Up',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
