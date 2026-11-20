import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../auth/presentation/providers/auth_notifier.dart';

class BoostAnalyticsScreen extends ConsumerStatefulWidget {
  const BoostAnalyticsScreen({super.key});

  @override
  ConsumerState<BoostAnalyticsScreen> createState() =>
      _BoostAnalyticsScreenState();
}

class _BoostAnalyticsScreenState extends ConsumerState<BoostAnalyticsScreen> {
  String _period = 'week';
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.dio.get(
        '/professionals/me/boost/analytics',
        queryParameters: {'period': _period},
      );
      setState(() {
        _analytics = response.data['data'] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatPrice(num price, String currency) {
    final symbols = {
      'NGN': '₦',
      'GHS': '₵',
      'KES': 'KSh',
      'ZAR': 'R',
      'XAF': 'FCFA',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
    };
    final symbol = symbols[currency] ?? '\$';
    return '$symbol${price.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;

    // Role check
    if (user?.role != 'professional' && user?.role != 'both') {
      return Scaffold(
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GlayaColors.berry,
        foregroundColor: Colors.white,
        title: const Text('Boost Analytics'),
        actions: [
          DropdownButton<String>(
            value: _period,
            dropdownColor: Colors.white,
            style: const TextStyle(color: Colors.white),
            underline: Container(),
            items: ['week', 'month', 'all']
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p[0].toUpperCase() + p.substring(1)),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() => _period = v!);
              _loadAnalytics();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analytics == null
              ? const Center(child: Text('No analytics data available'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Boost Status
                      if (_analytics != null &&
                          _analytics!['currentBoost'] != null) ...[
                        _buildCurrentBoostCard(_analytics!['currentBoost']
                            as Map<String, dynamic>),
                        const SizedBox(height: 24),
                      ],

                      // ROI Card
                      if (_analytics != null &&
                          _analytics!['metrics'] != null &&
                          _analytics!['metrics'] is Map<String, dynamic> &&
                          (_analytics!['metrics']
                                  as Map<String, dynamic>)['revenue'] !=
                              null) ...[
                        _buildROICard((_analytics!['metrics']
                                as Map<String, dynamic>)['revenue']
                            as Map<String, dynamic>),
                        const SizedBox(height: 24),
                      ],

                      // Metrics Grid
                      if (_analytics != null && _analytics!['metrics'] != null)
                        _buildMetricsGrid(
                            _analytics!['metrics'] as Map<String, dynamic>),
                      const SizedBox(height: 24),

                      // Comparison Section
                      if (_analytics != null && _analytics!['metrics'] != null)
                        _buildComparisonSection(
                            _analytics!['metrics'] as Map<String, dynamic>),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCurrentBoostCard(Map<String, dynamic> boost) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rocket_launch, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Active Boost',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      boost['type'].toString().toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoChip(
              'Expires',
              DateFormat('MMM d, yyyy')
                  .format(DateTime.parse(boost['expiryDate'])),
              Icons.calendar_today),
          const SizedBox(height: 8),
          _buildInfoChip('Cost', _formatPrice(boost['cost'], boost['currency']),
              Icons.payments),
        ],
      ),
    );
  }

  Widget _buildROICard(Map<String, dynamic> revenue) {
    final roi = double.parse(revenue['roi']);
    final isPositive = roi >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPositive ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Return on Investment',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${roi.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: isPositive ? Colors.green : Colors.red,
                ),
              ),
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: isPositive ? Colors.green : Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildRevenueItem('Revenue', revenue['total']),
              _buildRevenueItem('Cost', revenue['cost']),
              _buildRevenueItem('Profit', revenue['profit']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueItem(String label, dynamic value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(Map<String, dynamic> metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance Metrics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildMetricCard(
          'Profile Views',
          metrics['profileViews']['current'],
          metrics['profileViews']['increase'],
          metrics['profileViews']['percentage'],
          Icons.visibility,
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          'Bookings',
          metrics['bookings']['current'],
          metrics['bookings']['increase'],
          metrics['bookings']['percentage'],
          Icons.calendar_today,
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          'Current Rank',
          '#${metrics['ranking']['current']}',
          metrics['ranking']['change'],
          null,
          Icons.bar_chart,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    dynamic value,
    dynamic increase,
    dynamic percentage,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (percentage != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+$percentage%',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComparisonSection(Map<String, dynamic> metrics) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Before vs After Boost',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildComparisonBar(
              'Profile Views',
              metrics['profileViews']['baseline'],
              metrics['profileViews']['current']),
          const SizedBox(height: 12),
          _buildComparisonBar('Bookings', metrics['bookings']['baseline'],
              metrics['bookings']['current']),
        ],
      ),
    );
  }

  Widget _buildComparisonBar(String label, num baseline, num current) {
    final max = baseline > current ? baseline : current;
    final baselinePercent = baseline / max;
    final currentPercent = current / max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Before',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      widthFactor: baselinePercent,
                    ),
                  ),
                  Text(baseline.toString(),
                      style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('After',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: GlayaColors.berry,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      widthFactor: currentPercent,
                    ),
                  ),
                  Text(current.toString(),
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 8),
        Text(
          '$label: $value',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
