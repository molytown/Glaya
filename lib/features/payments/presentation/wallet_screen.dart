import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/currency_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/text_styles.dart';
import '../../../../shared/widgets/bottom_nav.dart';
import '../../auth/presentation/providers/auth_notifier.dart';
import 'widgets/withdraw_sheet.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  Map<String, dynamic>? _wallet;
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _payouts = [];
  bool _isLoading = false;
  bool _loadingPayouts = false;
  int _accountIndex = 0;
  final _pageController = PageController();
  final _amountController = TextEditingController();

  String _currencyCode = 'XAF';

  Map<String, dynamic>? get _currentAccount => _accounts.isEmpty
      ? null
      : _accounts[_accountIndex.clamp(0, _accounts.length - 1)];

  double get _currentBalance =>
      num.tryParse(_currentAccount?['balance']?.toString() ?? '')?.toDouble() ??
      num.tryParse(_wallet?['balance']?.toString() ?? '')?.toDouble() ??
      0;

  String get _currentCurrency =>
      (_currentAccount?['currency'] as String?)?.toUpperCase() ?? _currencyCode;

  @override
  void initState() {
    super.initState();
    _loadWallet();
    _loadAccounts();
    _loadPayouts();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    try {
      final userCurrency = await CurrencyService.getUserCurrency();
      final response = await ApiService.dio.get(
        '/payments/wallets/me',
        queryParameters: {'userCurrency': userCurrency},
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      if (!mounted || data == null) return;
      setState(() {
        _wallet = data;
        // Wallet currency is authoritative — it is always the owner's local currency
        final walletCurrency = (data['currency'] as String?)?.toUpperCase();
        _currencyCode = (walletCurrency != null && walletCurrency.isNotEmpty)
            ? walletCurrency
            : (userCurrency.isNotEmpty ? userCurrency : 'XAF');
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load wallet: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadAccounts() async {
    try {
      final res = await ApiService.dio.get('/payments/wallets/me/accounts');
      if (!mounted) return;
      final list = (res.data['data']?['accounts'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      setState(() {
        _accounts = list;
        if (_accountIndex >= list.length) _accountIndex = 0;
      });
    } catch (_) {
      // Accounts endpoint optional — fall back to single wallet display
    }
  }

  Future<void> _loadPayouts() async {
    setState(() => _loadingPayouts = true);
    try {
      final res = await ApiService.dio.get('/payments/payouts/me');
      if (!mounted) return;
      setState(() {
        _payouts = (res.data['data'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
      });
    } catch (_) {
      // Payout history is optional — ignore failures
    } finally {
      if (mounted) setState(() => _loadingPayouts = false);
    }
  }

  String _money(num? value, {int digits = 0, String? currency}) {
    final code = (currency ?? _currentCurrency).toUpperCase();
    final v = value ?? 0;
    final formatted =
        NumberFormat('#,##0${digits > 0 ? '.${'0' * digits}' : ''}', 'en_US')
            .format(v);
    return '${CurrencyService.getCurrencySymbol(code)}$formatted $code';
  }

  void _openWithdrawSheet(double balance) {
    WithdrawSheet.show(
      context,
      availableBalance: balance,
      currencyCode: _currentCurrency,
      onSubmitted: () {
        _loadWallet();
        _loadAccounts();
        _loadPayouts();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final transactions = (_wallet?['transactions'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final canWithdraw = user?.role == 'professional' || user?.role == 'both';
    final hasAccounts = _accounts.isNotEmpty;
    final pages = hasAccounts ? _accounts : [_wallet ?? {}];

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 110,
            child: PageView.builder(
              controller: _pageController,
              itemCount: pages.length,
              onPageChanged: (i) => setState(() => _accountIndex = i),
              itemBuilder: (context, i) {
                final acct = pages[i];
                final cur = (acct['currency'] as String? ?? _currencyCode)
                    .toUpperCase();
                final avail = num.tryParse(acct['balance']?.toString() ?? '')
                        ?.toDouble() ??
                    0;
                final pend =
                    num.tryParse(acct['pendingBalance']?.toString() ?? '')
                            ?.toDouble() ??
                        0;
                final isPrimary = acct['isPrimary'] == true ||
                    acct['is_primary'] == true ||
                    i == 0;
                return Row(
                  children: [
                    Expanded(
                        child: _buildBalanceCard('Available • $cur', avail,
                            currency: cur, subtitle: isPrimary ? 'Home' : '')),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildBalanceCard('Pending • $cur', pend,
                            currency: cur)),
                  ],
                );
              },
            ),
          ),
          if (pages.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pages.length, (i) {
                  final cur =
                      (pages[i]['currency'] as String? ?? '').toUpperCase();
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _accountIndex == i ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _accountIndex == i
                          ? GlayaColors.berry
                          : GlayaColors.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: cur.isEmpty ? null : null,
                  );
                }),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _showTopUpDialog,
                  child: const Text('Top Up'),
                ),
              ),
              if (pages.length > 1) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showConvertSheet,
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Convert'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GlayaColors.berry,
                      side: const BorderSide(color: GlayaColors.berry),
                    ),
                  ),
                ),
              ],
              if (canWithdraw) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _currentBalance > 0
                        ? () => _openWithdrawSheet(_currentBalance)
                        : null,
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text('Withdraw'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GlayaColors.berry,
                      side: const BorderSide(color: GlayaColors.berry),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (canWithdraw) ...[
            const SizedBox(height: 28),
            Text('Payout Requests', style: GlayaTextStyles.titleLarge()),
            const SizedBox(height: 8),
            _buildPayoutList(),
          ],
          const SizedBox(height: 24),
          Text('Transactions', style: GlayaTextStyles.titleLarge()),
          const SizedBox(height: 8),
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No transactions yet',
                    style: GlayaTextStyles.bodyMedium()
                        .copyWith(color: GlayaColors.textSecondary)),
              ),
            )
          else
            ...transactions.map((tx) {
              final isCredit =
                  (tx['type'] as String? ?? '').toLowerCase() == 'credit';
              final amount = num.tryParse(tx['amount']?.toString() ?? '') ?? 0;
              final reference = tx['reference'] as String? ?? 'Transaction';
              final createdAt = tx['createdAt'] ?? tx['created_at'];
              final dateText = createdAt != null
                  ? DateFormat('MMM d, yyyy • HH:mm').format(
                      DateTime.tryParse(createdAt.toString()) ?? DateTime.now())
                  : '';
              return ListTile(
                leading: Icon(
                  isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isCredit ? GlayaColors.success : GlayaColors.error,
                ),
                title: Text(reference,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(dateText),
                trailing: Text(
                  '${isCredit ? '+' : '−'}${_money(amount)}',
                  style: GlayaTextStyles.bodyMedium(
                    color: isCredit ? GlayaColors.success : GlayaColors.error,
                  ),
                ),
              );
            }),
        ],
      ),
      bottomNavigationBar: user?.role == 'customer'
          ? null
          : GlayaBottomNav(
              currentIndex: 4,
              userRole: user?.role,
            ),
    );
  }

  Widget _buildPayoutList() {
    if (_loadingPayouts) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child:
            Center(child: CircularProgressIndicator(color: GlayaColors.berry)),
      );
    }
    if (_payouts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('No withdrawal requests yet',
            style: GlayaTextStyles.bodyMedium()
                .copyWith(color: GlayaColors.textSecondary)),
      );
    }
    return Column(
      children: _payouts.map((p) {
        final status = (p['status'] as String? ?? 'pending').toLowerCase();
        final amount = num.tryParse(p['amount']?.toString() ?? '') ?? 0;
        final createdAt = p['createdAt'] ?? p['created_at'];
        final dateText = createdAt != null
            ? DateFormat('MMM d, yyyy').format(
                DateTime.tryParse(createdAt.toString()) ?? DateTime.now())
            : '';
        final (color, label) = switch (status) {
          'approved' => (GlayaColors.success, 'Approved'),
          'rejected' => (GlayaColors.error, 'Rejected'),
          'paid' => (GlayaColors.success, 'Paid'),
          _ => (GlayaColors.warning, 'Pending'),
        };
        final meta = p['metadata'] as Map<String, dynamic>?;
        final method = meta?['method'] as String?;
        final methodLabel = method == 'bank_transfer' ? 'Bank' : 'Mobile Money';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(Icons.payments_outlined, color: color),
            title: Text(_money(amount),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('$dateText • $methodLabel • $label'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBalanceCard(String label, double amount,
      {String? currency, String subtitle = ''}) {
    final cur = (currency ?? _currentCurrency).toUpperCase();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GlayaColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: GlayaColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(label,
              style: GlayaTextStyles.bodyMedium(), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            _money(amount, currency: cur),
            style: GlayaTextStyles.headlineSmall(color: GlayaColors.berry),
            textAlign: TextAlign.center,
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(subtitle,
                style: GlayaTextStyles.bodyMedium()
                    .copyWith(color: GlayaColors.textSecondary, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  void _showConvertSheet() {
    if (_accounts.length < 2) return;
    final fromCtrl = TextEditingController();
    var fromIdx = _accountIndex;
    var toIdx = _accountIndex == 0 ? 1 : 0;
    String? error;
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final fromAcct = _accounts[fromIdx];
          final toAcct = _accounts[toIdx];
          final fromCur = (fromAcct['currency'] as String? ?? '').toUpperCase();
          final toCur = (toAcct['currency'] as String? ?? '').toUpperCase();
          final fromBal =
              num.tryParse(fromAcct['balance']?.toString() ?? '') ?? 0;

          Future<void> submit() async {
            final amt = double.tryParse(fromCtrl.text) ?? 0;
            if (amt <= 0) {
              setSheetState(() => error = 'Enter a valid amount');
              return;
            }
            if (amt > fromBal) {
              setSheetState(() => error = 'Insufficient $fromCur balance');
              return;
            }
            setSheetState(() {
              loading = true;
              error = null;
            });
            try {
              await ApiService.dio.post('/payments/wallets/me/convert', data: {
                'fromCurrency': fromCur,
                'toCurrency': toCur,
                'amount': amt,
              });
              if (sheetContext.mounted) Navigator.pop(sheetContext);
              await _loadWallet();
              await _loadAccounts();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Converted $amt $fromCur → $toCur')),
                );
              }
            } catch (e) {
              setSheetState(() {
                loading = false;
                error = 'Conversion failed. Please try again.';
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Convert Currency', style: GlayaTextStyles.titleLarge()),
                const SizedBox(height: 16),
                Text('From', style: GlayaTextStyles.bodyMedium()),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: fromIdx,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                  items: [
                    for (var i = 0; i < _accounts.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                            '${_accounts[i]['currency']} — ${_money(num.tryParse(_accounts[i]['balance']?.toString() ?? '') ?? 0, currency: (_accounts[i]['currency'] as String? ?? '').toUpperCase())}'),
                      ),
                  ],
                  onChanged: (v) => setSheetState(() {
                    if (v != null) {
                      fromIdx = v;
                      if (toIdx == v) toIdx = (v == 0 ? 1 : 0);
                    }
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fromCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount ($fromCur)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text('To', style: GlayaTextStyles.bodyMedium()),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: toIdx,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                  items: [
                    for (var i = 0; i < _accounts.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                            '${_accounts[i]['currency']} — balance ${_money(num.tryParse(_accounts[i]['balance']?.toString() ?? '') ?? 0, currency: (_accounts[i]['currency'] as String? ?? '').toUpperCase())}'),
                      ),
                  ],
                  onChanged: (v) => setSheetState(() {
                    if (v != null) {
                      toIdx = v;
                      if (fromIdx == v) fromIdx = (v == 0 ? 1 : 0);
                    }
                  }),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlayaColors.berry,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('Convert to $toCur'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _topUp(double amount) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.dio.post('/payments/wallet/topup', data: {
        'amount': amount,
        'method': 'mobile_money',
        'currency': _currentCurrency,
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
                'Complete the payment in the browser. Your wallet updates automatically once confirmed.'),
            duration: Duration(seconds: 6),
          ));
        }
        // Give the webhook/poll a moment, then ask the backend to verify+credit
        await Future.delayed(const Duration(seconds: 8));
        if (reference != null) {
          try {
            await ApiService.dio.post('/payments/wallet/topup/complete',
                data: {'reference': reference});
          } catch (_) {}
        }
        await _loadWallet();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Could not start top-up. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Top-up failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showTopUpDialog() {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Top Up Wallet'),
        content: TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount ($_currentCurrency)',
            prefixText:
                '${CurrencyService.getCurrencySymbol(_currentCurrency)} ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) return;
              Navigator.pop(context);
              await _topUp(amount);
            },
            child: const Text('Top Up'),
          ),
        ],
      ),
    );
  }
}
