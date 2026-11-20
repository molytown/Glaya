import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/text_styles.dart';
import '../../../../shared/widgets/bottom_nav.dart';
import '../../auth/presentation/providers/auth_notifier.dart';

class BookingsListScreen extends ConsumerStatefulWidget {
  const BookingsListScreen({super.key});

  @override
  ConsumerState<BookingsListScreen> createState() => _BookingsListScreenState();
}

class _BookingsListScreenState extends ConsumerState<BookingsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _loadBookings();
    }
  }

  // ── Status display helpers ─────────────────────────────────────────────────
  static String _statusLabel(String s) {
    const m = {
      'requested': 'Pending',
      'accepted': 'Accepted',
      'confirmed': 'Confirmed',
      'in_progress': 'In Progress',
      'completed': 'Completed',
      'cancelled': 'Cancelled',
    };
    return m[s] ?? s[0].toUpperCase() + s.substring(1);
  }

  static Color _statusColor(String s) {
    const m = {
      'requested': Color(0xFFF59E0B),
      'accepted': Color(0xFF3B82F6),
      'confirmed': Color(0xFF10B981),
      'in_progress': Color(0xFF8B5CF6),
      'completed': Color(0xFF059669),
      'cancelled': Color(0xFFEF4444),
    };
    return m[s] ?? GlayaColors.berry;
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      List<String> statuses;
      switch (_tabController.index) {
        case 1:
          statuses = ['completed'];
          break;
        case 2:
          statuses = ['cancelled'];
          break;
        default: // Upcoming: all active statuses
          statuses = ['requested', 'accepted', 'confirmed', 'in_progress'];
      }
      final response = await ApiService.dio.get('/bookings');
      final all = (response.data['data'] as List).cast<Map<String, dynamic>>();
      setState(() => _bookings = all
          .where((b) => statuses.contains(b['status'] as String? ?? ''))
          .toList());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load bookings: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Bookings'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: GlayaColors.berry,
          indicatorColor: GlayaColors.berry,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _bookings.length,
              itemBuilder: (context, index) {
                final booking = _bookings[index];
                final scheduledAt = DateTime.parse(
                    booking['scheduledAt'] as String? ??
                        booking['scheduled_at'] as String);
                final rawStatus = booking['status'] as String? ?? '';
                final label = _statusLabel(rawStatus);
                final color = _statusColor(rawStatus);
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFEEEEEE)),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.12),
                      child: Icon(Icons.content_cut, color: color, size: 18),
                    ),
                    title: Text(
                      booking['service']?['name'] as String? ?? 'Service',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A)),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 3),
                        Text(
                          DateFormat('EEE, MMM d • h:mm a').format(scheduledAt),
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF000000)),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: color.withValues(alpha: 0.3)),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: color)),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right,
                        color: Color(0xFFCCCCCC)),
                    onTap: () => context.push('/bookings/${booking['id']}'),
                  ),
                );
              },
            ),
      bottomNavigationBar: GlayaBottomNav(
        currentIndex: 1,
        userRole: user?.role,
      ),
    );
  }
}
