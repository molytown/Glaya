import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/config_service.dart';

// ── Colours ───────────────────────────────────────────────────────────────────
const Color _pink = Color(0xFFD6006E);
const Color _gold = Color(0xFFD4AF37);
const Color _purple = Color(0xFF880E4F);
const Color _green = Color(0xFF10B981);
const Color _bg = Color(0xFFF4F6F9);
const Color _surface = Colors.white;
const Color _text1 = Color(0xFF1A1A1A);
const Color _text2 = Color(0xFF6B7280);

// ── Currency helper ──────────────────────────────────────────────────────────
String _currencySym() {
  try {
    final locale = Intl.getCurrentLocale();
    if (locale.startsWith('en_US')) return '\$';
    if (locale.startsWith('en_GB')) return '£';
    if (locale.startsWith('fr_') ||
        locale.startsWith('de_') ||
        locale.startsWith('es_') ||
        locale.startsWith('it_')) {
      return '€';
    }
    if (locale.startsWith('en_KE')) return 'KSh ';
    if (locale.startsWith('en_GH')) return 'GH₵ ';
    if (locale.startsWith('en_ZA')) return 'R ';
    if (locale.startsWith('en_IN')) return '₹';
  } catch (_) {}
  return '₦';
}

final subscriptionProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final response = await ApiService.dio.get('/professionals/me/subscription');
  return response.data['data'] as Map<String, dynamic>;
});

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isUpgrading = false;

  Future<void> _upgradeTo(String plan) async {
    setState(() => _isUpgrading = true);
    try {
      await ApiService.dio.post('/professionals/me/subscription', data: {
        'plan': plan,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully upgraded to $plan'),
            backgroundColor: _green,
          ),
        );
        ref.invalidate(subscriptionProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upgrade: $e'),
            backgroundColor: _pink,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpgrading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: const Text(
          'Subscription',
          style: TextStyle(
            color: _text1,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: subscription.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading subscription: $error'),
        ),
        data: (data) {
          final currentPlan = data['currentPlan'] as String? ?? 'free';
          final expiryDate = data['expiryDate'] as String?;
          final plans = data['plans'] as List<dynamic>? ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Plan Card
                _buildCurrentPlanCard(currentPlan, expiryDate),
                const SizedBox(height: 24),

                // Plan Options
                const Text(
                  'Upgrade Your Plan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _text1,
                  ),
                ),
                const SizedBox(height: 16),

                // Plan Cards
                ...plans.map((plan) {
                  final planData = plan as Map<String, dynamic>;
                  return _buildPlanCard(planData, currentPlan);
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentPlanCard(String plan, String? expiryDate) {
    final isFlex = plan == 'flex';
    final isElite = plan == 'elite';
    final badgeColor = isFlex ? _purple : (isElite ? _gold : _text2);
    final badgeText = isFlex ? 'FLEX' : (isElite ? 'ELITE' : 'FREE');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              if (expiryDate != null)
                Text(
                  'Expires: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(expiryDate))}',
                  style: const TextStyle(
                    color: _text2,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Current Plan: ${plan.toUpperCase()}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _text1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFlex
                ? 'Boost your visibility with featured listings and analytics'
                : isElite
                    ? 'Maximum visibility with premium features and COD support'
                    : 'Basic listing - upgrade to reach more customers',
            style: const TextStyle(
              color: _text2,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan, String currentPlan) {
    final planName = plan['name'] as String;
    final price = plan['price'] as num;
    final features = plan['features'] as List<dynamic>? ?? [];
    final isFlex = planName.toLowerCase() == 'flex';
    final isElite = planName.toLowerCase() == 'elite';
    final badgeColor = isFlex ? _purple : (isElite ? _gold : _text2);
    final isActive = currentPlan.toLowerCase() == planName.toLowerCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? badgeColor : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                planName.toUpperCase(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
              const Spacer(),
              Text(
                '${_currencySym()}${price.toStringAsFixed(0)}/month',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _text1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...features.map((feature) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: _green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature as String,
                      style: const TextStyle(
                        color: _text2,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isActive || _isUpgrading
                  ? null
                  : () => _upgradeTo(planName.toLowerCase()),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isActive ? badgeColor.withValues(alpha: 0.2) : badgeColor,
                disabledBackgroundColor: badgeColor.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isUpgrading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      isActive ? 'Current Plan' : 'Upgrade',
                      style: TextStyle(
                        color: isActive ? badgeColor : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
