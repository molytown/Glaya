import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../auth/presentation/providers/auth_notifier.dart';
import '../../../../shared/widgets/bottom_nav.dart';

final loyaltyProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final resp = await ApiService.dio.get('/loyalty/me');
  return resp.data['data'] as Map<String, dynamic>;
});

final referralCodeProvider = FutureProvider<String>((ref) async {
  final resp = await ApiService.dio.get('/loyalty/referral-code');
  return resp.data['data']['code'] as String;
});

class LoyaltyScreen extends ConsumerStatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  ConsumerState<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends ConsumerState<LoyaltyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _referralCodeController = TextEditingController();
  bool _applyingCode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _applyReferral() async {
    final code = _referralCodeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _applyingCode = true);
    try {
      await ApiService.dio.post('/loyalty/use-referral', data: {'code': code});
      ref.invalidate(loyaltyProvider);
      _referralCodeController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Referral code applied! You earned 25 points.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _applyingCode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loyaltyAsync = ref.watch(loyaltyProvider);
    final referralAsync = ref.watch(referralCodeProvider);
    final user = ref.watch(authNotifierProvider).valueOrNull;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: GlayaColors.berry,
        foregroundColor: Colors.white,
        title: const Text('Loyalty & Rewards', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'My Points'),
            Tab(text: 'Referrals'),
          ],
        ),
      ),
      body: loyaltyAsync.when(
        data: (data) => TabBarView(
          controller: _tabController,
          children: [
            _buildPointsTab(data),
            _buildReferralTab(referralAsync),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(e.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.refresh(loyaltyProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: GlayaBottomNav(currentIndex: 4, userRole: user?.role),
    );
  }

  Widget _buildPointsTab(Map<String, dynamic> data) {
    final points = data['points'] as int? ?? 0;
    final tier = data['tier'] as String? ?? 'bronze';
    final nextTierIn = data['nextTierIn'] as int? ?? 0;
    final history = data['history'] as List<dynamic>? ?? [];

    final tierColor = tier == 'gold'
        ? const Color(0xFFFFD700)
        : tier == 'silver'
            ? const Color(0xFFC0C0C0)
            : const Color(0xFFCD7F32);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Points Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [GlayaColors.berry, GlayaColors.berry.withOpacity(0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Your Points', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        Text(
                          NumberFormat('#,##0').format(points),
                          style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: tierColor, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        tier.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                if (nextTierIn > 0) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: tier == 'bronze' ? points / 100 : (points - 100) / 400,
                          backgroundColor: Colors.white30,
                          valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                          borderRadius: BorderRadius.circular(4),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$nextTierIn more points to ${tier == 'bronze' ? 'Silver' : 'Gold'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tier benefits
          const Text('Tier Benefits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildTierCard('Bronze', 'Standard perks', '0+ pts', const Color(0xFFCD7F32), tier == 'bronze'),
          const SizedBox(height: 8),
          _buildTierCard('Silver', 'Priority booking + 5% discount', '100+ pts', const Color(0xFFC0C0C0), tier == 'silver'),
          const SizedBox(height: 8),
          _buildTierCard('Gold', 'Dedicated support + 10% off + free gift', '500+ pts', const Color(0xFFFFD700), tier == 'gold'),
          const SizedBox(height: 24),

          // History
          const Text('Points History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No points activity yet', style: TextStyle(color: Colors.grey))),
            )
          else
            ...history.map((e) {
              final entry = e as Map<String, dynamic>;
              final pts = entry['points'] as int? ?? 0;
              final isCredit = pts >= 0;
              final createdAt = DateTime.tryParse(entry['createdAt']?.toString() ?? '');
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: isCredit ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
                  child: Icon(
                    isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline,
                    color: isCredit ? Colors.green : Colors.red,
                  ),
                ),
                title: Text(entry['description']?.toString() ?? entry['eventType']?.toString() ?? '',
                    style: const TextStyle(fontSize: 14)),
                subtitle: createdAt != null
                    ? Text(DateFormat('MMM d, y').format(createdAt),
                        style: const TextStyle(fontSize: 12, color: Colors.grey))
                    : null,
                trailing: Text(
                  '${isCredit ? '+' : ''}$pts pts',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCredit ? Colors.green : Colors.red,
                    fontSize: 15,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTierCard(String name, String benefit, String threshold, Color color, bool isCurrent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent ? color.withOpacity(0.12) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCurrent ? color : Colors.grey.shade200, width: isCurrent ? 2 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(child: Text(name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(benefit, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Text(threshold, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralTab(AsyncValue<String> referralAsync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // My referral code
          referralAsync.when(
            data: (code) => _buildMyReferralCode(code),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),

          // How it works
          const Text('How it works', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildHowItWorksStep('1', 'Share your code', 'Send your referral code to friends', Icons.share),
          _buildHowItWorksStep('2', 'Friend signs up', 'They enter your code when joining', Icons.person_add),
          _buildHowItWorksStep('3', 'Both get rewarded', 'You earn 50 pts, they earn 25 pts', Icons.card_giftcard),
          const SizedBox(height: 24),

          // Enter a referral code
          const Text('Have a referral code?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _referralCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'Enter referral code',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.card_giftcard),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _applyingCode ? null : _applyReferral,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlayaColors.berry,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                child: _applyingCode
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Apply', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyReferralCode(String code) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [GlayaColors.berry, GlayaColors.berry.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('Your Referral Code', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            code,
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied to clipboard!')),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: GlayaColors.berry),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksStep(String step, String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: GlayaColors.berry, shape: BoxShape.circle),
            child: Center(
              child: Text(step, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ),
          Icon(icon, color: GlayaColors.berry.withOpacity(0.5)),
        ],
      ),
    );
  }
}
