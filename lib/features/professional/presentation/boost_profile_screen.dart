import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/text_styles.dart';
import '../../../../shared/widgets/bottom_nav.dart';
import '../../auth/presentation/providers/auth_notifier.dart';

class BoostProfileScreen extends ConsumerStatefulWidget {
  const BoostProfileScreen({super.key});

  @override
  ConsumerState<BoostProfileScreen> createState() => _BoostProfileScreenState();
}

class _BoostProfileScreenState extends ConsumerState<BoostProfileScreen> {
  Map<String, dynamic>? _boostData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBoostData();
  }

  Future<void> _loadBoostData() async {
    try {
      final response = await ApiService.dio.get('/professionals/me/boost');
      setState(
          () => _boostData = response.data['data'] as Map<String, dynamic>);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load boost data: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _purchaseBoost(String boostType, int duration) async {
    try {
      await ApiService.dio.post('/professionals/me/boost', data: {
        'boostType': boostType,
        'duration': duration,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Boost purchased successfully!')),
        );
        await _loadBoostData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to purchase boost: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;

    // Role check - only professionals can access
    if (user?.role != 'professional' && user?.role != 'both') {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Access Denied',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'This feature is only available for professional accounts',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      );
    }

    final currentBoost = _boostData?['currentBoost'] as Map<String, dynamic>?;
    final isBoosted = currentBoost != null;
    final boostExpiry = currentBoost != null
        ? DateTime.tryParse(currentBoost['expiryDate'] as String? ?? '')
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boost Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Current Boost Status
                  if (isBoosted) ...[
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
                          const Icon(Icons.rocket_launch,
                              size: 48, color: Colors.white),
                          const SizedBox(height: 12),
                          const Text(
                            'Your Profile is Boosted!',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (boostExpiry != null)
                            Text(
                              'Expires: ${_formatDate(boostExpiry)}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _boostStat('Profile Views',
                                  '+${currentBoost['profileViewsIncrease'] ?? 0}'),
                              _boostStat('Bookings',
                                  '+${currentBoost['bookingsIncrease'] ?? 0}'),
                              _boostStat(
                                  'Rank', '#${currentBoost['rank'] ?? 0}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.trending_up,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'Boost Your Profile',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Get more visibility and bookings',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Boost Options
                  const Text(
                    'Choose a Boost Package',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _boostOptionCard(
                    'Basic Boost',
                    '24 hours',
                    9.99,
                    'Increased visibility in search results',
                    Icons.flash_on,
                    'basic',
                    1,
                  ),
                  const SizedBox(height: 12),
                  _boostOptionCard(
                    'Standard Boost',
                    '7 days',
                    49.99,
                    'Top placement in your category',
                    Icons.local_fire_department,
                    'standard',
                    7,
                  ),
                  const SizedBox(height: 12),
                  _boostOptionCard(
                    'Premium Boost',
                    '30 days',
                    149.99,
                    'Featured on homepage and search',
                    Icons.star,
                    'premium',
                    30,
                  ),
                  const SizedBox(height: 24),

                  // Benefits
                  const Text(
                    'Boost Benefits',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _benefitItem(Icons.visibility, 'Up to 3x more profile views'),
                  _benefitItem(
                      Icons.calendar_today, 'Up to 2x more booking requests'),
                  _benefitItem(
                      Icons.trending_up, 'Higher ranking in search results'),
                  _benefitItem(Icons.star, 'Featured badge on your profile'),
                  _benefitItem(Icons.people, 'Increased customer trust'),
                  const SizedBox(height: 24),

                  // Terms
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Terms: Boosts are non-refundable. Results may vary based on location and competition. Boost duration starts immediately after purchase.',
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

  Widget _boostStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
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

  Widget _boostOptionCard(
    String title,
    String duration,
    double price,
    String description,
    IconData icon,
    String boostType,
    int days,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: GlayaColors.berry.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: GlayaColors.berry),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GlayaTextStyles.titleMedium(),
                      ),
                      Text(
                        duration,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$$price',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: GlayaColors.berry,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _purchaseBoost(boostType, days),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlayaColors.berry,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Purchase Boost'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _benefitItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: GlayaColors.berry, size: 20),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
