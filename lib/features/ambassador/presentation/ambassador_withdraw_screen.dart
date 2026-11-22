import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/theme/colors.dart';
import '../data/ambassador_repository.dart';

const _pink = GlayaColors.berry;

final _numFmt = _NF();
class _NF {
  String format(num n) {
    final s = n.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

String _fmt(num? n, [String currency = 'XAF']) {
  final grouped = _numFmt.format(n ?? 0);
  return currency == 'XAF' ? '$grouped FCFA' : '$grouped $currency';
}

String _fmtDate(dynamic d) {
  if (d == null) return '—';
  try {
    final dt = DateTime.parse(d.toString()).toLocal();
    return '${dt.day}/${dt.month}/${dt.year}';
  } catch (_) {
    return d.toString();
  }
}

/// Full payout-request screen (MOGO "Withdraw" parity): amount + method +
/// account details form, plus payout history below.
class AmbassadorWithdrawScreen extends StatefulWidget {
  const AmbassadorWithdrawScreen({super.key});

  @override
  State<AmbassadorWithdrawScreen> createState() =>
      _AmbassadorWithdrawScreenState();
}

class _AmbassadorWithdrawScreenState extends State<AmbassadorWithdrawScreen> {
  final _repo = AmbassadorRepository();
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _accCtrl = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String _method = 'mobile_money';
  String _provider = 'MTN';
  double _available = 0;
  String _currency = 'XAF';
  List<dynamic> _payouts = [];
  String? _error;

  static const double _minPayout = 1000;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _bankCtrl.dispose();
    _accCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await _repo.getProfile();
      final payouts = await _repo.getPayouts(limit: 20);
      if (!mounted) return;
      setState(() {
        _available = ((profile?['stats']?['available'] as num?) ?? 0).toDouble();
        _currency = (profile?['profile']?['currency'] as String?) ?? 'XAF';
        _payouts = payouts['items'] as List? ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount < _minPayout) {
      setState(() => _error = 'Minimum withdrawal is ${_fmt(_minPayout, _currency)}');
      return;
    }
    if (amount > _available) {
      setState(() => _error = 'Amount exceeds available balance');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final accountDetails = _method == 'mobile_money'
          ? {
              'provider': _provider,
              'phone': _phoneCtrl.text.trim(),
              'accountName': _nameCtrl.text.trim()
            }
          : {
              'bankName': _bankCtrl.text.trim(),
              'accountNumber': _accCtrl.text.trim(),
              'accountName': _nameCtrl.text.trim()
            };
      await _repo.requestPayout(
        amount: amount,
        method: _method,
        accountDetails: accountDetails,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout request submitted')),
      );
      _amountCtrl.clear();
      _load();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlayaColors.background,
      appBar: AppBar(
        title: const Text('Withdraw Funds'),
        backgroundColor: Colors.white,
        foregroundColor: GlayaColors.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Available balance card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Available Balance',
                          style: TextStyle(
                              fontSize: 13,
                              color: GlayaColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(_fmt(_available, _currency),
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text('Minimum withdrawal: ${_fmt(_minPayout, _currency)}',
                          style: const TextStyle(
                              fontSize: 12, color: GlayaColors.warning)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Withdrawal Details',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_error != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: GlayaColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(_error!,
                              style: const TextStyle(
                                  fontSize: 13, color: GlayaColors.error)),
                        ),
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        decoration: InputDecoration(
                          labelText: 'Amount ($_currency)',
                          helperText: 'Minimum: ${_fmt(_minPayout, _currency)}',
                          helperStyle: const TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Enter a valid amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _method,
                        decoration: InputDecoration(
                          labelText: 'Payment Method',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'mobile_money',
                              child: Text('Mobile Money')),
                          DropdownMenuItem(
                              value: 'bank_transfer',
                              child: Text('Bank Transfer')),
                        ],
                        onChanged: (v) =>
                            setState(() => _method = v ?? _method),
                      ),
                      const SizedBox(height: 12),
                      if (_method == 'mobile_money') ...[
                        DropdownButtonFormField<String>(
                          initialValue: _provider,
                          decoration: InputDecoration(
                            labelText: 'Provider',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'MTN', child: Text('MTN Mobile Money')),
                            DropdownMenuItem(
                                value: 'Orange',
                                child: Text('Orange Money')),
                          ],
                          onChanged: (v) =>
                              setState(() => _provider = v ?? _provider),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Mobile money number',
                            hintText: '6XX XXX XXX',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _bankCtrl,
                          decoration: InputDecoration(
                            labelText: 'Bank name',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _accCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Account number',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Account holder name',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _pink,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Submit Request',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text('Payout History',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                if (_payouts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('No payout history yet',
                          style: TextStyle(color: GlayaColors.textSecondary)),
                    ),
                  )
                else
                  ..._payouts.map((p) {
                    final m = p as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.black.withOpacity(0.05)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_fmt((m['amount'] as num?) ?? 0, _currency),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                                Text(
                                  '${(m['method'] ?? '').toString().replaceAll('_', ' ')} · ${_fmtDate(m['createdAt'])}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: GlayaColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          _statusPill((m['status'] ?? '').toString()),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _statusPill(String s) {
    final color = switch (s) {
      'completed' || 'paid' => GlayaColors.success,
      'pending' || 'processing' || 'requested' => GlayaColors.warning,
      'failed' || 'rejected' => GlayaColors.error,
      _ => GlayaColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(s.isEmpty ? '—' : s[0].toUpperCase() + s.substring(1),
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
