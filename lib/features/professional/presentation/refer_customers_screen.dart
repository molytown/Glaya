import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/text_styles.dart';
import '../../../../shared/widgets/bottom_nav.dart';
import '../../auth/presentation/providers/auth_notifier.dart';

class ReferCustomersScreen extends ConsumerStatefulWidget {
  const ReferCustomersScreen({super.key});

  @override
  ConsumerState<ReferCustomersScreen> createState() =>
      _ReferCustomersScreenState();
}

class _ReferCustomersScreenState extends ConsumerState<ReferCustomersScreen> {
  Map<String, dynamic>? _referralData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReferralData();
  }

  Future<void> _loadReferralData() async {
    try {
      final response = await ApiService.dio.get('/referrals/me');
      setState(
          () => _referralData = response.data['data'] as Map<String, dynamic>);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load referral data: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareReferralLink() async {
    final referralCode = _referralData?['referralCode'] as String? ?? '';
    final referralLink = _referralData?['referralLink'] as String? ?? '';
    final message =
        'Use my referral code $referralCode to get discounts on Glaya! $referralLink';

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Share this: $message'),
            duration: const Duration(seconds: 3)),
      );
    }
  }

  Future<void> _copyReferralCode() async {
    final referralCode = _referralData?['referralCode'] as String? ?? '';
    // In a real app, you'd use flutter/services to copy to clipboard
    // For now, we'll show a snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Referral code: $referralCode')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final referralCode = _referralData?['referralCode'] as String? ?? '';
    final referralLink = _referralData?['referralLink'] as String? ?? '';
    final totalReferrals = _referralData?['totalReferrals'] as int? ?? 0;
    final successfulReferrals =
        _referralData?['successfulReferrals'] as int? ?? 0;
    final totalEarnings =
        (_referralData?['totalEarnings'] as num?)?.toDouble() ?? 0.0;
    final referralBonus =
        (_referralData?['referralBonus'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Refer & Earn'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Referral Stats Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [GlayaColors.berry, Color(0xFF880E4F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Your Referral Stats',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statItem('Total Referrals', '$totalReferrals'),
                            _statItem('Successful', '$successfulReferrals'),
                            _statItem('Earnings',
                                '\$${totalEarnings.toStringAsFixed(2)}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Referral Code Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Referral Code',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: GlayaColors.berry.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      GlayaColors.berry.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  referralCode.isEmpty
                                      ? 'Loading...'
                                      : referralCode,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: GlayaColors.berry,
                                    letterSpacing: 2,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: _copyReferralCode,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Referral Link Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Referral Link',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              referralLink.isEmpty
                                  ? 'Loading...'
                                  : referralLink,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Share Button
                  ElevatedButton.icon(
                    onPressed: _shareReferralLink,
                    icon: const Icon(Icons.share),
                    label: const Text('Share Referral Link'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlayaColors.berry,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // How it Works
                  const Text(
                    'How it Works',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _stepItem(1, 'Share your referral code or link with friends'),
                  _stepItem(2, 'Friends sign up using your code'),
                  _stepItem(3,
                      'You earn \$${referralBonus.toStringAsFixed(2)} for each successful referral'),
                  _stepItem(4, 'Friends get a discount on their first booking'),
                  const SizedBox(height: 24),

                  // Terms
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Terms: Referral bonus is credited after the referred user completes their first booking. Maximum of 10 referrals per month.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: user?.role == 'customer'
          ? null
          : GlayaBottomNav(
              currentIndex: 0,
              userRole: user?.role,
            ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _stepItem(int step, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: GlayaColors.berry,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '$step',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
