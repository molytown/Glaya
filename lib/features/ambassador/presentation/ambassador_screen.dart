import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/config_service.dart';
import '../data/ambassador_repository.dart';
import 'ambassador_withdraw_screen.dart';

const _pink = GlayaColors.berry;
const _pinkDark = GlayaColors.pinkDark;
const _gold = Color(0xFFD4AF37);
const _goldDark = Color(0xFFB8860B);
const _bronze = Color(0xFF8B6914);
const _cream = Color(0xFFFBF6EA);

final _numFmt = NumberFormat('#,##0');
String _fmt(num? n, [String currency = 'XAF']) {
  final grouped = _numFmt.format((n ?? 0).round());
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

String _statusLabel(String s) => switch (s) {
      'accrued' => 'Earned',
      'reversed' => 'Reversed',
      'credit' => 'Credit',
      'debit' => 'Debit',
      'lock' => 'Locked',
      _ => s.isEmpty ? '—' : s[0].toUpperCase() + s.substring(1),
    };

Color _statusColor(String s) => switch (s) {
      'accrued' || 'credit' || 'completed' => GlayaColors.success,
      'pending' || 'processing' || 'lock' => GlayaColors.warning,
      'reversed' || 'failed' || 'rejected' || 'debit' => GlayaColors.error,
      _ => GlayaColors.textSecondary,
    };

class AmbassadorScreen extends StatefulWidget {
  const AmbassadorScreen({super.key});

  @override
  State<AmbassadorScreen> createState() => _AmbassadorScreenState();
}

class _AmbassadorScreenState extends State<AmbassadorScreen>
    with SingleTickerProviderStateMixin {
  final _repo = AmbassadorRepository();
  late final TabController _tabController;

  bool _loading = true;
  bool _isAmbassador = false;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _user;

  final Map<String, List<dynamic>> _items = {
    'commissions': [],
    'referrals': [],
    'payouts': [],
    'ledger': [],
  };
  final Map<String, int> _totals = {
    'commissions': 0,
    'referrals': 0,
    'payouts': 0,
    'ledger': 0
  };
  final Map<String, int> _pages = {
    'commissions': 1,
    'referrals': 1,
    'payouts': 1,
    'ledger': 1
  };
  final Map<String, bool> _loadingMore = {};

  static const _tabs = [
    ('commissions', 'Commissions'),
    ('referrals', 'Referrals'),
    ('payouts', 'Payouts'),
    ('ledger', 'Activity'),
  ];

  String get _currency => (_profile?['currency'] as String?) ?? 'XAF';
  num get _available => (_stats?['available'] as num?) ?? 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final results = await Future.wait([
        _repo.getProfile(),
        ApiService.dio.get('/users/me'),
      ]);
      if (!mounted) return;
      final data = results[0] as Map<String, dynamic>?;
      final userResp = results[1] as dynamic;
      final udata = userResp.data is Map ? userResp.data['data'] : null;
      setState(() => _user = udata is Map<String, dynamic> ? udata : null);
      if (data == null) {
        setState(() => _isAmbassador = false);
      } else {
        setState(() {
          _isAmbassador = true;
          _profile = data['profile'] as Map<String, dynamic>?;
          _stats = data['stats'] as Map<String, dynamic>?;
        });
        _loadTab('commissions', reset: true);
        _loadTab('referrals', reset: true);
        _loadTab('payouts', reset: true);
      }
    } catch (_) {
      if (mounted) setState(() => _isAmbassador = false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadTab(String key, {bool reset = false}) async {
    if (reset) {
      _pages[key] = 1;
      _items[key] = [];
    }
    final page = _pages[key] ?? 1;
    try {
      final result = switch (key) {
        'commissions' => await _repo.getCommissions(page: page),
        'referrals' => await _repo.getReferrals(page: page),
        'payouts' => await _repo.getPayouts(page: page),
        _ => await _repo.getLedger(page: page),
      };
      if (!mounted) return;
      setState(() {
        _items[key] = [...?_items[key], ...result['items'] as List];
        _totals[key] = (result['total'] as num?)?.toInt() ?? 0;
        _pages[key] = page + 1;
      });
    } catch (_) {}
  }

  Future<void> _loadMore(String key) async {
    setState(() => _loadingMore[key] = true);
    await _loadTab(key);
    if (mounted) setState(() => _loadingMore[key] = false);
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('$what copied'), duration: const Duration(seconds: 1)),
    );
  }

  void _share() {
    final link = _profile?['referralLink'] as String? ?? '';
    if (link.isEmpty) return;
    Share.share('Book beauty & wellness services on Glaya with my link: $link');
  }

  Future<void> _refresh() async {
    await _init();
    for (final key in _tabs.map((t) => t.$1)) {
      _loadTab(key, reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlayaColors.background,
      appBar: AppBar(
        title: const Text('Ambassador Program'),
        backgroundColor: Colors.white,
        foregroundColor: GlayaColors.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : !_isAmbassador
              ? _buildNotAmbassador()
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 14),
                      _buildEarningsCard(),
                      const SizedBox(height: 14),
                      _buildWithdrawalRequests(),
                      const SizedBox(height: 14),
                      _buildReferralCard(),
                      const SizedBox(height: 14),
                      _buildTopReferrals(),
                      const SizedBox(height: 14),
                      _buildStats(),
                      const SizedBox(height: 14),
                      _buildTabs(),
                      _buildList(),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Refresh Dashboard'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _goldDark,
                            side: const BorderSide(color: _gold),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildNotAmbassador() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups_outlined, size: 56, color: Colors.black26),
            const SizedBox(height: 16),
            const Text('Ambassador Program',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'You are not an ambassador yet. Ambassadors earn a percentage of every booking made by people who sign up through their link.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade600, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  String? get _userPhotoUrl {
    final raw = (_user?['photoUrl'] ?? _user?['photo_url']) as String?;
    if (raw == null || raw.isEmpty) return null;
    return ConfigService().replaceLocalhost(raw);
  }

  Widget _buildHeader() {
    final rate = _profile?['commissionRate'];
    final verified = _profile?['verified'] == true;
    final userName = (_user?['name'] as String?)?.trim() ?? '';
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [_gold, _goldDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: _goldDark.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withOpacity(0.25),
                  border: Border.all(color: Colors.white.withOpacity(0.4)),
                ),
                clipBehavior: Clip.antiAlias,
                child: _userPhotoUrl != null
                    ? Image.network(_userPhotoUrl!,
                        width: 60, height: 60, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 30))
                    : const Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            userName.isEmpty ? 'Ambassador' : userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: _cream, size: 18),
                        ],
                      ],
                    ),
                    Text('Ambassador · Earn ${rate ?? 0}% of Glaya\'s earnings',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.85), fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('Total earned: ${_fmt((_stats?['totalEarned'] as num?) ?? 0, _currency)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statChip(Icons.group_outlined, 'Referrals', '${_stats?['referrals'] ?? 0}'),
              _statChip(Icons.account_balance_wallet_outlined, 'Available', _fmt(_available, _currency)),
              _statChip(Icons.trending_up, 'Earned', _fmt((_stats?['totalEarned'] as num?) ?? 0, _currency)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(height: 3),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.75), fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final stats = [
      (Icons.group_outlined, 'Referrals', '${_stats?['referrals'] ?? 0}'),
      (
        Icons.account_balance_wallet_outlined,
        'Available',
        _fmt(_available, _currency)
      ),
      (
        Icons.schedule_outlined,
        'In payout',
        _fmt((_stats?['locked'] as num?) ?? 0, _currency)
      ),
      (
        Icons.trending_up,
        'Total earned',
        _fmt((_stats?['totalEarned'] as num?) ?? 0, _currency)
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.9,
      children: stats
          .map(
            (s) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Icon(s.$1, size: 20, color: _goldDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(s.$3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                        Text(s.$2,
                            style: const TextStyle(
                                fontSize: 11,
                                color: GlayaColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildEarningsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Available Balance',
                      style: TextStyle(
                          fontSize: 12, color: GlayaColors.textSecondary)),
                  Text(_fmt(_available, _currency),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Pending',
                      style: TextStyle(
                          fontSize: 12, color: GlayaColors.textSecondary)),
                  Text(_fmt((_stats?['locked'] as num?) ?? 0, _currency),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: GlayaColors.warning)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _available >= 1000
                      ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const AmbassadorWithdrawScreen()))
                      : null,
                  icon: const Icon(Icons.account_balance_wallet_outlined,
                      size: 16),
                  label: const Text('Withdraw'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _available > 0 ? _showTransferSheet : null,
                  icon: const Icon(Icons.account_balance_outlined, size: 16),
                  label: const Text('To Wallet'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _pinkDark,
                    side: const BorderSide(color: _pink),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalRequests() {
    final payouts = _items['payouts'] ?? [];
    if (payouts.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Withdrawal Requests',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              TextButton(
                onPressed: () => _tabController.animateTo(2),
                child: const Text('See all',
                    style: TextStyle(fontSize: 12, color: _goldDark)),
              ),
            ],
          ),
          ...payouts.take(2).map((p) {
            final e = p as Map<String, dynamic>;
            final status = (e['status'] ?? '').toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _cream,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(_statusIcon(status),
                      color: _statusColor(status), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_fmt((e['amount'] as num?) ?? 0, _currency),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(_fmtDate(e['createdAt']),
                            style: const TextStyle(
                                fontSize: 11,
                                color: GlayaColors.textSecondary)),
                      ],
                    ),
                  ),
                  _pill(status),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  IconData _statusIcon(String s) => switch (s) {
        'completed' || 'paid' || 'approved' => Icons.check_circle,
        'pending' || 'processing' || 'requested' => Icons.schedule,
        'failed' || 'rejected' => Icons.cancel,
        _ => Icons.help_outline,
      };

  Widget _buildReferralCard() {
    final code = _profile?['referralCode'] as String? ?? '';
    final link = _profile?['referralLink'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Referral Code',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(code.isEmpty ? '—' : code,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: _bronze)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: code.isEmpty ? null : () => _copy(code, 'Code'),
                  icon: const Icon(Icons.copy, size: 15),
                  label: const Text('Copy Code',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _goldDark,
                    side: const BorderSide(color: _gold),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: link.isEmpty ? null : () => _copy(link, 'Link'),
                  icon: const Icon(Icons.link, size: 15),
                  label: const Text('Copy Link',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _goldDark,
                    side: const BorderSide(color: _gold),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: _share,
                icon: const Icon(Icons.share, size: 18),
                style: IconButton.styleFrom(
                    backgroundColor: _gold, foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopReferrals() {
    final refs = (_items['referrals'] ?? []).take(3).toList();
    final rankColors = [
      const Color(0xFFF59E0B),
      const Color(0xFF9CA3AF),
      const Color(0xFFB45309),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Top Referrals',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              if ((_totals['referrals'] ?? 0) > 3)
                GestureDetector(
                  onTap: () => _tabController.animateTo(1),
                  child: Text('View all (${_totals['referrals']})',
                      style: const TextStyle(fontSize: 12, color: _goldDark)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (refs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text('No referrals yet — start sharing your link!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: GlayaColors.textSecondary)),
              ),
            )
          else
            ...refs.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value as Map<String, dynamic>;
              final user = e['user'] as Map?;
              final name = (user?['name'] as String?)?.trim() ?? 'Customer';
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: _cream,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: rankColors[i % 3].withOpacity(0.2),
                      child: Text('#${i + 1}',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: rankColors[i % 3])),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    Text(_fmtDate(e['signupAt'] ?? e['createdAt']),
                        style: const TextStyle(
                            fontSize: 11,
                            color: GlayaColors.textSecondary)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (i) => _loadTab(_tabs[i].$1, reset: true),
        labelColor: _goldDark,
        unselectedLabelColor: GlayaColors.textSecondary,
        indicatorColor: _goldDark,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        tabs: _tabs.map((t) => Tab(text: t.$2)).toList(),
      ),
    );
  }

  Widget _buildList() {
    final key = _tabs[_tabController.index].$1;
    final items = _items[key] ?? [];
    final total = _totals[key] ?? 0;
    if (items.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text('Nothing here yet',
              style: TextStyle(color: GlayaColors.textSecondary, fontSize: 14)),
        ),
      );
    }
    return Column(
      children: [
        ...items.map((e) => _buildRow(key, e as Map<String, dynamic>)),
        if (items.length < total)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextButton(
              onPressed:
                  _loadingMore[key] == true ? null : () => _loadMore(key),
              child: _loadingMore[key] == true
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Load more'),
            ),
          ),
      ],
    );
  }

  Widget _buildRow(String tab, Map<String, dynamic> e) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_rowTitle(tab, e),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(_rowSubtitle(tab, e),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: GlayaColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_rowAmount(tab, e) != null)
                Text(_rowAmount(tab, e)!,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _pill(_rowStatus(tab, e)),
                  const SizedBox(width: 8),
                  Text(_fmtDate(_rowDate(tab, e)),
                      style: const TextStyle(
                          fontSize: 11, color: GlayaColors.textTertiary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _rowTitle(String tab, Map<String, dynamic> e) => switch (tab) {
        'commissions' => _fmt((e['commissionAmount'] as num?) ?? 0,
            (e['currency'] as String?) ?? _currency),
        'referrals' => ((e['user'] as Map?)?['name'] as String?) ?? 'Customer',
        'payouts' => _fmt((e['amount'] as num?) ?? 0,
            (e['currency'] as String?) ?? _currency),
        _ => _fmt((e['amount'] as num?) ?? 0, _currency),
      };

  String _rowSubtitle(String tab, Map<String, dynamic> e) => switch (tab) {
        'commissions' =>
          '${(e['customer'] as Map?)?['name'] ?? 'Customer'} · booking ${_fmt((e['bookingAmount'] as num?) ?? 0, (e['currency'] as String?) ?? _currency)}',
        'referrals' =>
          '${(e['user'] as Map?)?['phone'] ?? ''} · via ${e['source'] ?? 'link'}',
        'payouts' =>
          '${e['method'] == 'mobile_money' ? 'Mobile money' : 'Bank transfer'}${e['reference'] != null ? ' · Ref ${e['reference']}' : ''}',
        _ => '${e['reference'] ?? e['type'] ?? ''}',
      };

  String? _rowAmount(String tab, Map<String, dynamic> e) => switch (tab) {
        'commissions' => null,
        'ledger' =>
          '${e['type'] == 'debit' ? '−' : e['type'] == 'credit' ? '+' : ''}${_fmt((e['amount'] as num?) ?? 0, _currency)}',
        _ => null,
      };

  String _rowStatus(String tab, Map<String, dynamic> e) {
    if (tab == 'ledger') {
      final type = e['type'] as String? ?? '';
      if (type == 'lock' && e['settled'] != true) return 'pending';
      return type;
    }
    return (e['status'] as String?) ?? '';
  }

  dynamic _rowDate(String tab, Map<String, dynamic> e) =>
      e['createdAt'] ?? e['signupAt'];

  Widget _pill(String status) {
    final s = status.isEmpty ? '—' : status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _statusColor(s).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(_statusLabel(s),
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _statusColor(s))),
    );
  }

  // ── Transfer to wallet sheet ──────────────────────────────────────────────
  void _showTransferSheet() {
    final amountCtrl = TextEditingController();
    bool busy = false;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Transfer to wallet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Available: ${_fmt(_available, _currency)}',
                  style: const TextStyle(
                      fontSize: 13, color: GlayaColors.textSecondary)),
              const SizedBox(height: 16),
              if (error != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: GlayaColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(error!,
                      style: const TextStyle(
                          fontSize: 13, color: GlayaColors.error)),
                ),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Amount (${_currency})',
                  hintText: 'Up to ${_fmt(_available, _currency)}',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    amountCtrl.text = _available.round().toString();
                  },
                  child: const Text('Transfer all'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final amount =
                              double.tryParse(amountCtrl.text.trim()) ?? 0;
                          if (amount <= 0) {
                            setSheet(
                                () => error = 'Please enter a valid amount');
                            return;
                          }
                          if (amount > _available) {
                            setSheet(() =>
                                error = 'Amount exceeds available balance');
                            return;
                          }
                          setSheet(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            final res = await _repo.transferToWallet(
                                amount: amount);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Transferred ${_fmt((res['amount'] as num?) ?? amount, _currency)} to your wallet',
                                  ),
                                ),
                              );
                              _init();
                              _loadTab('ledger', reset: true);
                            }
                          } catch (e) {
                            setSheet(() {
                              busy = false;
                              error =
                                  e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Transfer',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
