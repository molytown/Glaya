import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../../../shared/theme/colors.dart';
import '../../../../../shared/theme/text_styles.dart';
import '../providers/auth_notifier.dart';

class PhoneInputScreen extends ConsumerStatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  ConsumerState<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends ConsumerState<PhoneInputScreen> {
  bool _useOtp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _staySignedIn = false;
  String _countryCode = '+234';

  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStaySignedIn();
  }

  Future<void> _loadStaySignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _staySignedIn = prefs.getBool('stay_signed_in') ?? false;
    });
  }

  Future<void> _saveStaySignedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('stay_signed_in', value);
  }

  Future<void> _submit() async {
    print('Sign-in submit button pressed');
    final rawPhone = _phoneController.text.trim();
    final phone = '$_countryCode$rawPhone';
    final password = _passwordController.text;

    if (phone.isEmpty) {
      _snack('Please enter your phone number');
      return;
    }
    if (!_useOtp && password.length < 6) {
      _snack('Password must be at least 6 characters');
      return;
    }

    // Set loading state immediately without delay
    if (mounted) setState(() => _isLoading = true);

    try {
      print('[LOGIN] Attempting login with phone: $phone');

      // Use Future.microtask to prevent blocking the main thread
      await Future.microtask(() async {
        if (_useOtp) {
          await ref.read(authNotifierProvider.notifier).requestOtp(phone);
          print('[LOGIN] OTP requested, navigating to OTP verify');
          final ambassadorCode =
              GoRouterState.of(context).uri.queryParameters['ambassador'];
          final otpPath = ambassadorCode != null
              ? '/otp-verify?ambassador=$ambassadorCode'
              : '/otp-verify';
          if (mounted) context.push(otpPath, extra: phone);
          return;
        }
        await ref.read(authNotifierProvider.notifier).login(
              phone: phone,
              password: password,
              rememberMe: _staySignedIn,
            );
      });

      print('[LOGIN] Login successful, navigating to home');
      if (mounted) {
        final from = GoRouterState.of(context).uri.queryParameters['from'];
        print('[LOGIN] Navigation target: ${from ?? '/'}');
        context.go(from ?? '/');
      }
    } catch (e) {
      print('[LOGIN] Login failed: $e');
      String errorMessage = 'Login failed. Please try again.';

      if (e is DioException) {
        final status = e.response?.statusCode;
        final data = e.response?.data;

        if (status == 401) {
          errorMessage = 'Invalid phone number or password';
        } else if (status == 404) {
          errorMessage = 'User not found. Please sign up first';
        } else if (status == 500) {
          errorMessage = 'Server error. Please try again later';
        } else if (data != null && data['message'] != null) {
          errorMessage = data['message'];
        } else {
          errorMessage = 'Network error. Please check your connection';
        }
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please check your connection';
      }

      if (mounted) _snack(errorMessage);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    return SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/pink_gradient_background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: MediaQuery.of(context).padding.top + 52,
              bottom: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 80,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Welcome back',
                  style: TextStyle(fontSize: 15, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF000000).withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CountryCodePicker(
                              onChanged: (code) {
                                setState(() =>
                                    _countryCode = code.dialCode ?? '+234');
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
                                  fontSize: 14, color: GlayaColors.textPrimary),
                              dialogTextStyle: const TextStyle(
                                  fontSize: 14, color: Color(0xFF000000)),
                              dialogBackgroundColor: Colors.white,
                              searchDecoration: InputDecoration(
                                hintText: 'Search country...',
                                hintStyle:
                                    const TextStyle(color: Color(0xFF000000)),
                                prefixIcon: const Icon(Icons.search,
                                    color: GlayaColors.berry),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              searchStyle: const TextStyle(color: Color(0xFF000000)),
                              barrierColor:
                                  Color(0xFF000000).withValues(alpha: 0.5),
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
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style:
                                    const TextStyle(color: Color(0xFF000000)),
                                decoration: const InputDecoration(
                                  hintText: '7XX XXX XXX',
                                  hintStyle:
                                      TextStyle(color: Color(0xFF000000)),
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.symmetric(horizontal: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!_useOtp) ...[
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Color(0xFF000000)),
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
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
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
                        Row(
                          children: [
                            Checkbox(
                              value: _staySignedIn,
                              onChanged: (value) {
                                setState(() {
                                  _staySignedIn = value ?? false;
                                  _saveStaySignedIn(_staySignedIn);
                                });
                              },
                              activeColor: GlayaColors.berry,
                              side: const BorderSide(
                                  color: GlayaColors.berry, width: 2),
                            ),
                            const Text('Stay signed in',
                                style: TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Sign in with OTP',
                              style: TextStyle(
                                  color: Color(0xFF6B7280), fontSize: 14)),
                          Switch(
                              value: _useOtp,
                              onChanged: (v) => setState(() => _useOtp = v),
                              activeThumbColor: GlayaColors.berry),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GlayaColors.berry,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text(_useOtp ? 'Send OTP' : 'Sign In',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?",
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: GlayaColors.berry, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextButton(
                        onPressed: () {
                          print('Sign Up button pressed on sign-in screen');
                          context.push('/signup-selection');
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Sign Up',
                            style: TextStyle(
                                color: GlayaColors.berry,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
