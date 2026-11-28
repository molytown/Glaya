import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/currency_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/text_styles.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const PaymentScreen({super.key, required this.bookingId});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String _payType = 'deposit'; // 'deposit' | 'full'
  String _method = 'mobile_money'; // 'mobile_money' | 'wallet'
  bool _isLoading = false;
  bool _bookingLoading = true;
  Map<String, dynamic>? _booking;
  double? _walletBalance;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _locationType() {
    final b = _booking ?? {};
    return (b['locationType'] ?? b['location_type'] ?? 'salon').toString();
  }

  bool get _isHomeVisit => _locationType().toLowerCase().contains('home');

  Future<void> _loadBooking() async {
    try {
      final response =
          await ApiService.dio.get('/bookings/${widget.bookingId}');
      if (mounted) {
        setState(() {
          _booking = response.data['data'] as Map<String, dynamic>;
          _bookingLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _bookingLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load booking: ${e.toString()}')),
        );
      }
    }
    _loadWalletBalance();
  }

  Future<void> _loadWalletBalance() async {
    try {
      final res = await ApiService.dio.get('/payments/wallets/me');
      final bal = res.data['data']?['balance'];
      if (mounted) {
        setState(() => _walletBalance =
            bal == null ? null : double.tryParse(bal.toString()));
      }
    } catch (_) {
      // Wallet info is optional — leave null
    }
  }

  double get _agreedAmount {
    final v =
        _toDouble(_booking?['agreedAmount'] ?? _booking?['agreed_amount']);
    return v > 0 ? v : 0;
  }

  double get _servicePrice => _agreedAmount > 0
      ? _agreedAmount
      : _toDouble(
          _booking?['service']?['price'] ?? _booking?['service']?['basePrice']);
  double get _depositAmount => _toDouble(_booking?['depositAmount'] ??
      _booking?['deposit_amount'] ??
      _booking?['deposit']);
  double get _payAmount => _payType == 'full' ? _servicePrice : _depositAmount;
  String get _payLabel => _payType == 'full' ? 'Pay Booking' : 'Pay Deposit';

  Future<void> _pay() async {
    setState(() => _isLoading = true);
    try {
      print('[Payment] Initiating payment for booking ${widget.bookingId}, type: $_payType, method: $_method');
      final res = await ApiService.dio.post('/payments/initiate', data: {
        'bookingId': widget.bookingId,
        'type': _payType,
        'method': _method == 'wallet' ? 'wallet' : 'notchpay',
      });
      print('[Payment] Response: ${res.data}');
      final data = res.data['data'] as Map<String, dynamic>? ?? {};

      if (_method == 'wallet' || data['gateway'] == 'wallet') {
        // Wallet debit is instant — booking is confirmed server-side
        if (mounted) {
          await _showBookingConfirmedDialog();
        }
        return;
      }

      final authUrl = data['authorizationUrl'] as String?;
      final reference = data['reference'] as String?;
      if (authUrl != null && authUrl.isNotEmpty) {
        if (!mounted) return;
        final paid = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => NotchPayCheckoutDialog(
            authorizationUrl: authUrl,
            reference: reference,
            bookingId: widget.bookingId,
          ),
        );
        if (paid == true && mounted) {
          await _showBookingConfirmedDialog();
        }
      } else {
        throw Exception('No checkout URL returned');
      }
    } on DioException catch (e) {
      print('[Payment] DioException: ${e.message}, response: ${e.response?.data}');
      final serverMsg = e.response?.data is Map
          ? (e.response!.data['error'] ?? e.response!.data['message'])
              ?.toString()
          : null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Payment failed: ${serverMsg ?? e.message}'),
              backgroundColor: GlayaColors.error),
        );
      }
    } catch (e) {
      print('[Payment] Exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Shows the "Booking Confirmed" dialog and returns to the booking detail.
  Future<void> _showBookingConfirmedDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BookingConfirmedDialog(isHomeVisit: _isHomeVisit),
    );
    if (mounted) {
      context.go('/bookings/${widget.bookingId}');
    }
  }

  Widget _buildPayTypeSelector() {
    Widget option(String value, String title, String subtitle, IconData icon) {
      final sel = _payType == value;
      return GestureDetector(
        onTap: () => setState(() => _payType = value),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: sel ? GlayaColors.blushPink : Colors.white,
            border: Border.all(
                color: sel ? GlayaColors.berry : const Color(0xFFEEEEEE),
                width: sel ? 2 : 1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon,
                  color: sel ? GlayaColors.berry : const Color(0xFF000000),
                  size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: sel
                                ? GlayaColors.berry
                                : const Color(0xFF1A1A1A))),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF000000))),
                  ],
                ),
              ),
              Icon(
                sel ? Icons.check_circle : Icons.radio_button_unchecked,
                color: sel ? GlayaColors.berry : const Color(0xFFCCCCCC),
                size: 22,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        option(
            'deposit',
            'Pay Deposit',
            'Secure your booking now, pay the rest at your appointment',
            Icons.hourglass_top_outlined),
        const SizedBox(height: 12),
        option(
            'full',
            'Pay Full Booking',
            'Pay the entire amount now — nothing due later',
            Icons.check_circle_outline),
      ],
    );
  }

  Widget _buildMethodSelector() {
    Widget option(String value, String title, String subtitle, IconData icon) {
      final sel = _method == value;
      return GestureDetector(
        onTap: () => setState(() => _method = value),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: sel ? GlayaColors.blushPink : Colors.white,
            border: Border.all(
                color: sel ? GlayaColors.berry : const Color(0xFFEEEEEE),
                width: sel ? 2 : 1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon,
                  color: sel ? GlayaColors.berry : const Color(0xFF000000),
                  size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: sel
                                ? GlayaColors.berry
                                : const Color(0xFF1A1A1A))),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF000000))),
                  ],
                ),
              ),
              Icon(
                sel ? Icons.check_circle : Icons.radio_button_unchecked,
                color: sel ? GlayaColors.berry : const Color(0xFFCCCCCC),
                size: 22,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        option(
            'mobile_money',
            'Mobile Money',
            'MTN, Airtel, Orange — secure checkout',
            Icons.phone_android_outlined),
        const SizedBox(height: 12),
        option(
            'wallet',
            'Glaya Wallet',
            'Pay instantly from your wallet balance',
            Icons.account_balance_wallet_outlined),
        if (_walletBalance != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Wallet balance: ${_formatAmount(_walletBalance!)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF000000)),
            ),
          ),
        ],
      ],
    );
  }

  String _formatAmount(double amount) {
    final currency = ((_booking?['service']?['currency'] ??
            _booking?['currency'] ??
            'XAF') as String)
        .toUpperCase();
    final symbol = CurrencyService.getCurrencySymbol(currency);
    return '$symbol${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)} $currency';
  }

  @override
  Widget build(BuildContext context) {
    final currency = ((_booking?['service']?['currency'] ??
            _booking?['currency'] ??
            'XAF') as String)
        .toUpperCase();
    final symbol = CurrencyService.getCurrencySymbol(currency);

    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCE4EC),
        elevation: 0,
        centerTitle: true,
        title: const Text('Complete Payment',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A))),
      ),
      body: _bookingLoading
          ? const Center(
              child: CircularProgressIndicator(color: GlayaColors.berry))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Amount card
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: GlayaColors.berry.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _payType == 'full'
                                      ? 'Full Booking Amount'
                                      : 'Deposit Amount',
                                  style: GlayaTextStyles.bodyLarge(),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$symbol${_payAmount.toStringAsFixed(_payAmount.truncateToDouble() == _payAmount ? 0 : 2)} $currency',
                                  style: GlayaTextStyles.headlineLarge(
                                      color: GlayaColors.berry),
                                ),
                                if (_payType == 'deposit' &&
                                    _servicePrice > _depositAmount) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Balance ${_formatAmount(_servicePrice - _depositAmount)} due at your appointment',
                                    style: const TextStyle(
                                        fontSize: 12, color: Color(0xFF000000)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text('Payment Type',
                              style: GlayaTextStyles.titleLarge()),
                          const SizedBox(height: 12),
                          _buildPayTypeSelector(),
                          const SizedBox(height: 24),
                          Text('Payment Method',
                              style: GlayaTextStyles.titleLarge()),
                          const SizedBox(height: 12),
                          _buildMethodSelector(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _pay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlayaColors.berry,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(_payLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }
}

/// In-app NotchPay checkout. Watches navigation for the return URL and offers
/// a manual "verify" action — closes with `true` only when payment completed.
class NotchPayCheckoutDialog extends StatefulWidget {
  final String authorizationUrl;
  final String? reference;
  final String bookingId;

  const NotchPayCheckoutDialog({
    super.key,
    required this.authorizationUrl,
    required this.reference,
    required this.bookingId,
  });

  @override
  State<NotchPayCheckoutDialog> createState() => NotchPayCheckoutDialogState();
}

class NotchPayCheckoutDialogState extends State<NotchPayCheckoutDialog> {
  late final WebViewController _controller;
  bool _verifying = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url;
            // Payment finished when NotchPay redirects off its own domain
            // (return/callback URL points back to Glaya).
            final host = Uri.tryParse(url)?.host ?? '';
            final isNotchpay =
                host.contains('notchpay') || host.contains('notch');
            if (!isNotchpay &&
                (host.contains('glaya') ||
                    url.contains('payment') ||
                    url.contains('return'))) {
              _verifyAndClose();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  Future<void> _verifyAndClose() async {
    if (_finished || _verifying) return;
    setState(() => _verifying = true);
    try {
      // Ask the backend to verify the transaction directly with NotchPay.
      final ref = widget.reference;
      if (ref != null && ref.isNotEmpty) {
        final res = await ApiService.dio.get(
          '/payments/verify/notchpay/$ref',
        );
        final data = res.data['data'] ?? res.data;
        final tx = data is Map ? (data['transaction'] ?? data) : null;
        final status =
            tx is Map ? (tx['status'] ?? data?['status'])?.toString() : null;
        if (status == 'complete' ||
            status == 'completed' ||
            status == 'success') {
          _finished = true;
          if (mounted) Navigator.pop(context, true);
          return;
        }
      }
      // Reference unknown or still pending — ask NotchPay via booking payment
      // fallback: check booking payments through the API.
      final bookingRes =
          await ApiService.dio.get('/bookings/${widget.bookingId}');
      final booking = bookingRes.data['data'] as Map<String, dynamic>?;
      final payments = booking?['payments'] as List?;
      final hasCompleted = payments?.any((p) =>
              (p['status'] ?? '').toString().toLowerCase() == 'completed') ??
          false;
      if (hasCompleted) {
        _finished = true;
        if (mounted) Navigator.pop(context, true);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Payment not confirmed yet. If you completed it, it may take a moment — try again.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not verify payment yet. Please try again in a moment.')),
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: const BoxDecoration(
                color: GlayaColors.blushPink,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline,
                      color: GlayaColors.berry, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Secure Checkout — NotchPay',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _verifying
                        ? null
                        : () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
            // WebView
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: WebViewWidget(controller: _controller),
              ),
            ),
            // Footer actions
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                      color: Color(0xFF000000).withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2))
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _verifying
                          ? null
                          : () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF555555),
                        side: const BorderSide(color: Color(0xFFDDDDDD)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _verifying ? null : _verifyAndClose,
                      icon: _verifying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.verified_outlined, size: 18),
                      label: Text(
                          _verifying ? 'Verifying…' : "I've Completed Payment",
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlayaColors.berry,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
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
}

/// "Booking Confirmed" dialog shown after successful payment.
class _BookingConfirmedDialog extends StatelessWidget {
  final bool isHomeVisit;

  const _BookingConfirmedDialog({required this.isHomeVisit});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline,
                color: Color(0xFF10B981), size: 40),
          ),
          const SizedBox(height: 16),
          const Text('Booking Confirmed',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            isHomeVisit
                ? 'Your booking has been confirmed and registered. Please be ready in time.'
                : "Your booking has been confirmed and registered. Please don't be late.",
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF555555), height: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GlayaColors.accentPurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: GlayaColors.accentPurple.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'Warning: Please arrive on time. Late cancellations or no-shows may result in penalties on your account.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: GlayaColors.accentPurple,
                  height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlayaColors.berry,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Done',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
