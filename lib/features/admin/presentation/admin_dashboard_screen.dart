import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/text_styles.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  Map<String, dynamic>? _analytics;
  List<Map<String, dynamic>> _pendingProfessionals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final analyticsResponse = await ApiService.dio.get('/admin/analytics');
      final professionalsResponse = await ApiService.dio.get(
        '/admin/professionals/pending',
        queryParameters: {'verificationStatus': 'pending'},
      );
      setState(() {
        _analytics = analyticsResponse.data['data'] as Map<String, dynamic>;
        _pendingProfessionals = (professionalsResponse.data['data'] as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyProfessional(String id, String status) async {
    try {
      await ApiService.dio.put('/admin/professionals/$id/verify', data: {'status': status});
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () => context.push('/admin/professionals'),
            tooltip: 'Manage Professionals',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Analytics', style: GlayaTextStyles.titleLarge()),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildMetricCard('Users', _analytics?['totalUsers']?.toString() ?? '0'),
                      _buildMetricCard('Professionals', _analytics?['totalProfessionals']?.toString() ?? '0'),
                      _buildMetricCard('Bookings', _analytics?['totalBookings']?.toString() ?? '0'),
                      _buildMetricCard('Revenue', '\$${_analytics?['totalRevenue']?.toString() ?? '0'}'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Pending Verifications', style: GlayaTextStyles.titleLarge()),
                      TextButton.icon(
                        onPressed: () => context.push('/admin/professionals'),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._pendingProfessionals.map((p) {
                    final name = (p['user']?['name'] ?? 'Unknown') as String;
                    final category = p['category'] as String;
                    return Card(
                      child: ListTile(
                        title: Text(name),
                        subtitle: Text(category),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: GlayaColors.success),
                              onPressed: () => _verifyProfessional(p['id'] as String, 'approved'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: GlayaColors.error),
                              onPressed: () => _verifyProfessional(p['id'] as String, 'rejected'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard(String label, String value) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GlayaColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: GlayaColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(value, style: GlayaTextStyles.headlineMedium(color: GlayaColors.berry)),
          const SizedBox(height: 4),
          Text(label, style: GlayaTextStyles.bodySmall()),
        ],
      ),
    );
  }
}
