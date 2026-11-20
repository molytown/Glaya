import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/currency_service.dart';
import '../../../../shared/theme/colors.dart';
import '../payment_screen.dart';
import 'cod_payment_dialog.dart';

/// Embedded payment step shown as a dialog (e.g. over the booking chat).
/// [paymentType] 'deposit' (default) or 'remaining' (post-service balance,
/// which also offers the cash/COD code flow). Pops with `true` on success.
class PaymentDepositDialog extends StatefulWidget {
  final String bookingId;
  final String paymentType;

  const PaymentDepositDialog(
      {super.key, required this.bookingId, this.paymentType = 'deposit'});

  @override
  State<PaymentDepositDialog> createState() => _PaymentDepositDialogState();
}

class _PaymentDepositDialogState extends State<PaymentDepositDialog> {
  bool _loading = true;
  bool _paying = false;
  String _method = 'mobile_money'; // 'mobile_money' | 'wallet' | 'cod'
  Map<String, dynamic>? _booking;
  double? _walletBalance;

  bool get _isRemaining => widget.paymentType == 'remaining';

  double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  double get _depositAmount => _toDouble(_booking?['depositAmount'] ??
      _booking?['deposit_amount'] ??
      _booking?['deposit']);

  /// Amount actually charged: outstanding balance for 'remaining', else deposit.
  double get _payAmount {
    if (_isRemaining) {
      final outstanding = _toDoubleOrNull(
          _booking?['outstandingBalance'] ?? _booking?['outstanding_balance']);
      if (outstanding != null && outstanding > 0) return outstanding;
      final rest = _totalAmount - _depositAmount;
      return rest > 0 ? rest : _totalAmount;
    }
    return _depositAmount;
  }

  String get _payLabel => _isRemaining ? 'Remaining Balance' : 'Deposit Amount';
  String get _actionLabel => _isRemaining ? 'Pay Balance' : 'Pay Deposit';
  String get _title => _isRemaining ? 'Pay Balance' : 'Pay Deposit';

  double get _agreedAmount {
    final v =
        _toDouble(_booking?['agreedAmount'] ?? _booking?['agreed_amount']);
    return v > 0 ? v : 0;
  }

  double get _totalAmount {
    if (_agreedAmount > 0) return _agreedAmount;
    final service = _booking?['service'];
    if (service is Map) {
      return _toDouble(service['price'] ?? service['basePrice']);
    }
    return 0;
  }

  String get _currency {
    final service = _booking?['service'];
    final serviceCurrency = service is Map ? service['currency'] : null;
    return ((serviceCurrency ?? _booking?['currency'] ?? 'XAF') as String)
        .toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.dio.get('/bookings/${widget.bookingId}');
      final booking = res.data['data'] as Map<String, dynamic>?;
      double? balance;
      try {
        final w = await ApiService.dio.get('/payments/wallets/me');
        final bal = w.data['data']?['balance'];
        balance = bal == null ? null : double.tryParse(bal.toString());
      } catch (_) {}
      if (mounted) {
        setState(() {
          _booking = booking;
          _walletBalance = balance;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _format(double amount) {
    final symbol = CurrencyService.getCurrencySymbol(_currency);
    return '$symbol${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)} $_currency';
  }

  Future<void> _pay() async {
    if (_method == 'cod') {
      await _payCod();
      return;
    }
    setState(() => _paying = true);
    try {
      final res = await ApiService.dio.post('/payments/initiate', data: {
        'bookingId': widget.bookingId,
        'type': widget.paymentType,
        'method': _method == 'wallet' ? 'wallet' : 'notchpay',
      });
      final data = res.data['data'] as Map<String, dynamic>? ?? {};

      if (_method == 'wallet' || data['gateway'] == 'wallet') {
        if (mounted) Navigator.of(context).pop(true);
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
        if (paid == true && mounted) Navigator.of(context).pop(true);
      } else {
        throw Exception('No checkout URL returned');
      }
    } on DioException catch (e) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Payment failed: $e'),
              backgroundColor: GlayaColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  /// Cash on Delivery: request a code, then the customer enters the code the
  /// professional shares to confirm payment and complete the booking.
  Future<void> _payCod() async {
    setState(() => _paying = true);
    try {
      await ApiService.dio.post('/bookings/${widget.bookingId}/cod/request');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Cash payment requested — ask your professional for the 5-digit code')),
      );
      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CodCodeEntryDialog(bookingId: widget.bookingId),
      );
      if (verified == true && mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['error'] ?? e.response!.data['message'])
              ?.toString()
          : null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Could not request cash payment: ${msg ?? e.message}'),
              backgroundColor: GlayaColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Widget _methodOption(
      String value, String title, String subtitle, IconData icon) {
    final sel = _method == value;
    return GestureDetector(
      onTap: () => setState(() => _method = value),
      child: Container(
        padding: const EdgeInsets.all(14),
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
                size: 24),
            const SizedBox(width: 12),
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
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                    child: CircularProgressIndicator(color: GlayaColors.berry)),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_title,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A1A))),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _paying
                              ? null
                              : () => Navigator.of(context).pop(false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: GlayaColors.berry.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Text(_payLabel,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF000000))),
                          const SizedBox(height: 4),
                          Text(_format(_payAmount),
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: GlayaColors.berry)),
                          if (!_isRemaining &&
                              _totalAmount > _depositAmount) ...[
                            const SizedBox(height: 4),
                            Text(
                                'of ${_format(_totalAmount)} — rest due at your appointment',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF000000))),
                          ],
                          if (_isRemaining) ...[
                            const SizedBox(height: 4),
                            const Text('Due after your service',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF000000))),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _methodOption(
                        'mobile_money',
                        'Mobile Money',
                        'MTN, Airtel, Orange — secure checkout',
                        Icons.phone_android_outlined),
                    const SizedBox(height: 10),
                    _methodOption(
                        'wallet',
                        'Glaya Wallet',
                        'Pay instantly from your wallet balance',
                        Icons.account_balance_wallet_outlined),
                    if (_isRemaining) ...[
                      const SizedBox(height: 10),
                      _methodOption(
                          'cod',
                          'Cash (COD)',
                          'Pay your professional in cash — they give you a 5-digit code',
                          Icons.payments_outlined),
                    ],
                    if (_walletBalance != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Wallet balance: ${_format(_walletBalance!)}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF000000)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _paying ? null : _pay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlayaColors.berry,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _paying
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(_actionLabel,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
