import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/currency_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/text_styles.dart';
import '../../auth/presentation/providers/auth_notifier.dart';
import '../../payments/presentation/widgets/withdraw_sheet.dart';

/// Wallet popup — shows total balance, pending balance, top-up/withdraw
/// actions and transaction history. All data is loaded live from
/// `/payments/wallets/me`.
class WalletDialog extends ConsumerStatefulWidget {
  const WalletDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const WalletDialog(),
    );
  }

  @override
  ConsumerState<WalletDialog> createState() => _WalletDialogState();
}

class _WalletDialogState extends ConsumerState<WalletDialog> {
  Map<String, dynamic>? _wallet;
  bool _loading = true;
  bool _busy = false;
  String _currencyCode = 'XAF';
  String _currencySymbol = 'FCFA';

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() => _loading = true);
    try {
      final userCurrency = await CurrencyService.getUserCurrency();
      final code = userCurrency.isNotEmpty ? userCurrency : 'XAF';
      final res = await ApiService.dio.get(
        '/payments/wallets/me',
        queryParameters: {'userCurrency': code},
      );
      if (!mounted) return;
      final data = res.data['data'] as Map<String, dynamic>?;
      final walletCurrency = (data?['currency'] as String?)?.toUpperCase();
      setState(() {
        _wallet = data;
        // Wallet currency is authoritative — always the owner's local currency
        _currencyCode = (walletCurrency != null && walletCurrency.isNotEmpty)
            ? walletCurrency
            : code;
        _currencySymbol = CurrencyService.getCurrencySymbol(_currencyCode);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load wallet: $e')),
      );
    }
  }

  String _money(num? value) {
    final v = value ?? 0;
    final formatted = NumberFormat('#,##0.00', 'en_US').format(v);
    return '$_currencySymbol $formatted $_currencyCode';
  }

  Future<void> _topUp(double amount) async {
    setState(() => _busy = true);
    try {
      final res = await ApiService.dio.post('/payments/wallet/topup', data: {
        'amount': amount,
        'method': 'mobile_money',
        'currency': _currencyCode,
      });
      final data = res.data['data'] as Map<String, dynamic>? ?? {};
      final authUrl = data['authorizationUrl'] as String?;
      final reference = data['reference'] as String?;

      if (authUrl != null && authUrl.isNotEmpty) {
        final uri = Uri.parse(authUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Complete the payment in the browser. Your wallet updates once confirmed.'),
            duration: Duration(seconds: 6),
          ));
        }
        await Future.delayed(const Duration(seconds: 8));
        if (reference != null) {
          try {
            await ApiService.dio.post('/payments/wallet/topup/complete',
                data: {'reference': reference});
          } catch (_) {}
        }
        await _loadWallet();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not start top-up. Please try again.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Top-up failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showTopUpSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Up Wallet',
                style: GlayaTextStyles.titleLarge()
                    .copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Amount ($_currencyCode)',
                prefixText: '$_currencySymbol ',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlayaColors.berry,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final amount =
                      double.tryParse(controller.text.trim()) ?? 0;
                  if (amount <= 0) return;
                  Navigator.pop(sheetContext);
                  _topUp(amount);
                },
                child: const Text('Continue to Payment',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balance = num.tryParse(
            (_wallet?['balance'] ?? _wallet?['available'])?.toString() ?? '0')
        ?.toDouble() ??
        0;
    final pending = num.tryParse(
            (_wallet?['pendingBalance'] ?? _wallet?['pending'])?.toString() ??
                '0')
        ?.toDouble() ??
        0;
    final transactions =
        (_wallet?['transactions'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [];

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      color: GlayaColors.berry, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('My Wallet',
                        style: GlayaTextStyles.titleLarge()
                            .copyWith(fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD6006E), Color(0xFF880E4F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Balance',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(
                      _money(balance),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.schedule,
                            size: 14, color: Colors.white.withOpacity(0.8)),
                        const SizedBox(width: 5),
                        Text('Pending: ${_money(pending)}',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Builder(builder: (context) {
                final user = ref.watch(authNotifierProvider).valueOrNull;
                final canWithdraw =
                    user?.role == 'professional' || user?.role == 'both';
                return Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _showTopUpSheet,
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.add_card, size: 18),
                        label: Text(_busy ? 'Processing…' : 'Top Up'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlayaColors.berry,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    if (canWithdraw && balance > 0) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => WithdrawSheet.show(
                            context,
                            availableBalance: balance,
                            currencyCode: _currencyCode,
                            onSubmitted: _loadWallet,
                          ),
                          icon: const Icon(Icons.payments_outlined, size: 18),
                          label: const Text('Withdraw'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: GlayaColors.berry,
                            side: const BorderSide(color: GlayaColors.berry),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              }),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Transaction History',
                    style: GlayaTextStyles.titleMedium()
                        .copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : transactions.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text('No transactions yet',
                                  style: GlayaTextStyles.bodyMedium()
                                      .copyWith(color: Colors.grey)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: transactions.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final tx = transactions[i];
                              final type =
                                  (tx['type'] as String? ?? '').toLowerCase();
                              final isCredit = type == 'credit';
                              final amount =
                                  num.tryParse(tx['amount']?.toString() ??
                                          '') ??
                                      0;
                              final reference =
                                  tx['reference'] as String? ?? 'Transaction';
                              final createdAt = tx['createdAt'] ??
                                  tx['created_at'];
                              final dateText = createdAt != null
                                  ? DateFormat('MMM d, yyyy • HH:mm')
                                      .format(DateTime.tryParse(
                                              createdAt.toString()) ??
                                          DateTime.now())
                                  : '';
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isCredit
                                      ? const Color(0xFFE8F5E9)
                                      : const Color(0xFFFFEBEE),
                                  child: Icon(
                                    isCredit
                                        ? Icons.south_east
                                        : Icons.north_east,
                                    size: 16,
                                    color: isCredit
                                        ? GlayaColors.success
                                        : GlayaColors.error,
                                  ),
                                ),
                                title: Text(reference,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  dateText,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Text(
                                  '${isCredit ? '+' : '−'}${_money(amount)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isCredit
                                        ? GlayaColors.success
                                        : GlayaColors.error,
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
