import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/currency_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/text_styles.dart';

/// Bottom sheet for topping up the wallet.
/// Posts to /payments/wallet/topup, launches the returned payment
/// authorization URL, then verifies via /payments/wallet/topup/complete.
class TopUpSheet extends StatefulWidget {
  final String currencyCode;
  final VoidCallback? onCompleted;

  const TopUpSheet({
    super.key,
    required this.currencyCode,
    this.onCompleted,
  });

  static Future<void> show(
    BuildContext context, {
    required String currencyCode,
    VoidCallback? onCompleted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TopUpSheet(
        currencyCode: currencyCode,
        onCompleted: onCompleted,
      ),
    );
  }

  @override
  State<TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<TopUpSheet> {
  final _amountCtrl = TextEditingController();
  bool _submitting = false;

  String get _symbol => CurrencyService.getCurrencySymbol(widget.currencyCode);

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      _toast('Enter a valid amount');
      return;
    }

    setState(() => _submitting = true);
    try {
      final res = await ApiService.dio.post('/payments/wallet/topup', data: {
        'amount': amount,
        'method': 'mobile_money',
        'currency': widget.currencyCode,
      });
      final data = res.data['data'] as Map<String, dynamic>? ?? {};
      final authUrl = data['authorizationUrl'] as String?;
      final reference = data['reference'] as String?;

      if (authUrl == null || authUrl.isEmpty) {
        _toast('Could not start top-up. Please try again.');
        return;
      }

      final uri = Uri.parse(authUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!mounted) return;
      _toast(
          'Complete the payment in the browser. Your wallet updates automatically once confirmed.');

      // Give the webhook/poll a moment, then ask the backend to verify+credit
      await Future.delayed(const Duration(seconds: 8));
      if (reference != null) {
        try {
          await ApiService.dio.post('/payments/wallet/topup/complete',
              data: {'reference': reference});
        } catch (_) {}
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCompleted?.call();
    } catch (e) {
      if (mounted) _toast('Top-up failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Up Wallet',
              style: GlayaTextStyles.titleLarge()
                  .copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'You will be redirected to complete the payment securely.',
            style:
                GlayaTextStyles.bodyMedium().copyWith(color: Color(0xFF000000)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount (${widget.currencyCode})',
              prefixText: '$_symbol ',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_card_outlined, size: 18),
              label: Text(_submitting ? 'Processing…' : 'Top Up'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlayaColors.berry,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
