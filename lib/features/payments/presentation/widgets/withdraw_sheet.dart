import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/currency_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/text_styles.dart';

/// Bottom sheet for requesting a payout/withdrawal.
/// Shows available balance, amount or "Withdraw All", payout method
/// (mobile money / bank transfer) with account details, optional reason.
class WithdrawSheet extends StatefulWidget {
  final double availableBalance;
  final String currencyCode;
  final VoidCallback? onSubmitted;

  const WithdrawSheet({
    super.key,
    required this.availableBalance,
    required this.currencyCode,
    this.onSubmitted,
  });

  static Future<void> show(
    BuildContext context, {
    required double availableBalance,
    required String currencyCode,
    VoidCallback? onSubmitted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => WithdrawSheet(
        availableBalance: availableBalance,
        currencyCode: currencyCode,
        onSubmitted: onSubmitted,
      ),
    );
  }

  @override
  State<WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<WithdrawSheet> {
  final _amountCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _networkCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  String _method = 'mobile_money';
  bool _withdrawAll = false;
  bool _submitting = false;

  String get _symbol => CurrencyService.getCurrencySymbol(widget.currencyCode);

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    _networkCtrl.dispose();
    _bankCtrl.dispose();
    _accountCtrl.dispose();
    _accountNameCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _money(num value) {
    final formatted = NumberFormat('#,##0', 'en_US').format(value);
    return '$_symbol$formatted ${widget.currencyCode}';
  }

  Future<void> _submit() async {
    double? amount;
    if (!_withdrawAll) {
      amount = double.tryParse(_amountCtrl.text.trim());
      if (amount == null || amount <= 0) {
        _toast('Enter a valid amount');
        return;
      }
      if (amount > widget.availableBalance) {
        _toast('Amount exceeds available balance');
        return;
      }
    }

    final accountDetails = <String, dynamic>{};
    if (_method == 'mobile_money') {
      if (_phoneCtrl.text.trim().isEmpty) {
        _toast('Mobile money number is required');
        return;
      }
      accountDetails['phoneNumber'] = _phoneCtrl.text.trim();
      if (_networkCtrl.text.trim().isNotEmpty) {
        accountDetails['network'] = _networkCtrl.text.trim();
      }
    } else {
      if (_bankCtrl.text.trim().isEmpty || _accountCtrl.text.trim().isEmpty) {
        _toast('Bank name and account number are required');
        return;
      }
      accountDetails['bankName'] = _bankCtrl.text.trim();
      accountDetails['accountNumber'] = _accountCtrl.text.trim();
      if (_accountNameCtrl.text.trim().isNotEmpty) {
        accountDetails['accountName'] = _accountNameCtrl.text.trim();
      }
    }

    setState(() => _submitting = true);
    try {
      await ApiService.dio.post('/payments/payouts/request', data: {
        if (amount != null) 'amount': amount,
        if (_withdrawAll) 'withdrawAll': true,
        'currency': widget.currencyCode,
        'method': _method,
        'accountDetails': accountDetails,
        if (_reasonCtrl.text.trim().isNotEmpty)
          'reason': _reasonCtrl.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSubmitted?.call();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Withdrawal request submitted — an admin will review and approve it.'),
        duration: Duration(seconds: 4),
      ));
    } catch (e) {
      if (!mounted) return;
      _toast('Withdrawal failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Withdraw Earnings',
                style: GlayaTextStyles.titleLarge()
                    .copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Available: ${_money(widget.availableBalance)}',
              style: GlayaTextStyles.bodyMedium()
                  .copyWith(color: GlayaColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // Method selector
            Row(
              children: [
                Expanded(
                  child: _methodChip('mobile_money', 'Mobile Money',
                      Icons.phone_android_outlined),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _methodChip('bank_transfer', 'Bank Transfer',
                      Icons.account_balance_outlined),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Amount / withdraw all
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _amountCtrl,
                    enabled: !_withdrawAll,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount (${widget.currencyCode})',
                      prefixText: '$_symbol ',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        setState(() => _withdrawAll = !_withdrawAll),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          _withdrawAll ? Colors.white : GlayaColors.berry,
                      backgroundColor:
                          _withdrawAll ? GlayaColors.berry : null,
                      side: const BorderSide(color: GlayaColors.berry),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('All',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            if (_withdrawAll) ...[
              const SizedBox(height: 8),
              Text('Full balance of ${_money(widget.availableBalance)} will be requested.',
                  style: GlayaTextStyles.bodySmall()
                      .copyWith(color: GlayaColors.textSecondary)),
            ],
            const SizedBox(height: 14),

            // Account details
            if (_method == 'mobile_money') ...[
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Mobile Money Number',
                  hintText: '+237 6XX XXX XXX',
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _networkCtrl,
                decoration: InputDecoration(
                  labelText: 'Network (optional)',
                  hintText: 'MTN / Orange',
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ] else ...[
              TextField(
                controller: _bankCtrl,
                decoration: InputDecoration(
                  labelText: 'Bank Name',
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _accountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Account Number',
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _accountNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Account Name (optional)',
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
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
                    : const Icon(Icons.payments_outlined, size: 18),
                label: Text(_submitting ? 'Submitting…' : 'Request Withdrawal'),
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
      ),
    );
  }

  Widget _methodChip(String value, String label, IconData icon) {
    final selected = _method == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _method = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? GlayaColors.pinkLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? GlayaColors.berry : GlayaColors.divider,
              width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 20,
                color: selected ? GlayaColors.berry : GlayaColors.textSecondary),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? GlayaColors.berry
                        : GlayaColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
