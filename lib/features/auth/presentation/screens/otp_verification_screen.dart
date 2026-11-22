import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../shared/theme/colors.dart';
import '../../../../../shared/theme/text_styles.dart';
import '../../../../../shared/services/ambassador_attribution.dart';
import '../providers/auth_notifier.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String phone;

  const OtpVerificationScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _referralController = TextEditingController();
  int _secondsRemaining = 300;
  Timer? _timer;
  bool _isLoading = false;
  String? _ambassadorCode;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadAmbassadorCode();
  }

  Future<void> _loadAmbassadorCode() async {
    final fromUri = GoRouterState.of(context).uri.queryParameters['ambassador'];
    if (fromUri != null) await captureAmbassadorCode(fromUri);
    final stored = await getAmbassadorCode();
    if (mounted) setState(() => _ambassadorCode = stored);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a 6-digit OTP')),
      );
      return;
    }

    final uriAmbassador =
        GoRouterState.of(context).uri.queryParameters['ambassador'];
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      // Checkbox is hidden in OTP mode — keep persistent session (null = default)
      final rememberMe = prefs.getBool('stay_signed_in');
      var ambassadorCode = _ambassadorCode ?? uriAmbassador;
      if (ambassadorCode != null) await captureAmbassadorCode(ambassadorCode);
      ambassadorCode ??= await getAmbassadorCode();
      final referralCode = _referralController.text.trim();
      await ref.read(authNotifierProvider.notifier).verifyOtp(widget.phone, otp,
          rememberMe: rememberMe,
          ambassadorCode: ambassadorCode,
          referralCode: referralCode.isEmpty ? null : referralCode);
      await clearAmbassadorCode();
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    try {
      await ref.read(authNotifierProvider.notifier).requestOtp(widget.phone);
      setState(() => _secondsRemaining = 300);
      _startTimer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resend OTP: ${e.toString()}')),
        );
      }
    }
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the 6-digit code sent to ${widget.phone}',
                style: GlayaTextStyles.bodyLarge(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: GlayaTextStyles.headlineMedium(color: GlayaColors.berry),
                decoration: const InputDecoration(
                  hintText: '000000',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              if (_ambassadorCode != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Ambassador invite applied — code $_ambassadorCode',
                    style: GlayaTextStyles.bodySmall(color: GlayaColors.berry),
                    textAlign: TextAlign.center,
                  ),
                ),
              TextField(
                controller: _referralController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'Referral / Ambassador code (optional)',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _formatTime(_secondsRemaining),
                style: GlayaTextStyles.titleMedium(color: Color(0xFF000000)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Verify'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _secondsRemaining > 0 ? null : _resendOtp,
                child: Text(_secondsRemaining > 0
                    ? 'Resend OTP in ${_formatTime(_secondsRemaining)}'
                    : 'Resend OTP'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
