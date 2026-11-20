import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dio/dio.dart';

import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/config_service.dart';
import '../../../../shared/widgets/bottom_nav.dart';
import '../../auth/presentation/providers/auth_notifier.dart';
import '../../home/presentation/screens/pick_map_screen.dart';
import '../../shared/presentation/widgets/address_editor.dart';

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

String _getCurrencySymbol(String currencyCode) {
  switch (currencyCode.toUpperCase()) {
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'NGN':
      return '₦';
    case 'XAF':
      return 'FCFA ';
    case 'GHS':
      return 'GH₵ ';
    case 'KES':
      return 'KSh ';
    case 'ZAR':
      return 'R ';
    case 'INR':
      return '₹';
    case 'CAD':
      return 'C\$';
    case 'AUD':
      return 'A\$';
    case 'JPY':
      return '¥';
    case 'CNY':
      return '¥';
    case 'BRL':
      return 'R\$';
    case 'MXN':
      return 'MX\$';
    default:
      return '$currencyCode ';
  }
}

// ── Colours ───────────────────────────────────────────────────────────────────
const Color _pink = Color(0xFFD6006E);
const Color _purple = Color(0xFF880E4F);
const Color _gold = Color(0xFFD4AF37);
const Color _green = Color(0xFF10B981);
const Color _amber = Color(0xFFF59E0B);
const Color _blue = Color(0xFF3B82F6);
const Color _bg = Color(0xFFF4F6F9);
const Color _surface = Colors.white;
const Color _text1 = Color(0xFF1A1A1A);
const Color _text2 = Color(0xFF6B7280);

final professionalDashboardProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  print('[DEBUG] Loading dashboard data...');
  try {
    print('[DEBUG] Calling /professionals/me/dashboard');
    final results = await Future.wait([
      ApiService.dio.get('/professionals/me/dashboard'),
      ApiService.dio
          .get('/professionals/me/analytics?period=month')
          .catchError((e) {
        print('[DEBUG] Analytics failed, using dashboard instead: $e');
        return ApiService.dio.get('/professionals/me/dashboard');
      }),
    ]);
    print('[DEBUG] Dashboard API calls completed');
    print('[DEBUG] Dashboard response: ${results[0].data}');
    final dash = results[0].data['data'] as Map<String, dynamic>;
    print('[DEBUG] Dashboard data: $dash');
    try {
      dash['analytics'] = results[1].data['data'];
      print('[DEBUG] Analytics data: ${results[1].data}');
    } catch (e) {
      print('[DEBUG] No analytics data: $e');
    }
    return dash;
  } catch (e) {
    print('[DEBUG] Error loading dashboard: $e');
    print('[DEBUG] Error type: ${e.runtimeType}');
    if (e is DioException) {
      print('[DEBUG] Dio error response: ${e.response}');
      print('[DEBUG] Dio error type: ${e.type}');
      print('[DEBUG] Dio error message: ${e.message}');
    }
    rethrow;
  }
});

/// Period-aware professional analytics (week/month/year).
final dashboardAnalyticsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, period) async {
  final res = await ApiService.dio.get(
    '/professionals/me/analytics',
    queryParameters: {'period': period},
  );
  return res.data['data'] as Map<String, dynamic>? ?? {};
});

/// The signed-in professional's wallet (balance, pending, currency).
final proWalletProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final res = await ApiService.dio.get('/payments/wallets/me');
    return res.data['data'] as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
});

class ProfessionalDashboardScreen extends ConsumerStatefulWidget {
  const ProfessionalDashboardScreen({super.key});
  @override
  ConsumerState<ProfessionalDashboardScreen> createState() =>
      _ProfessionalDashboardScreenState();
}

class _ProfessionalDashboardScreenState
    extends ConsumerState<ProfessionalDashboardScreen> {
  bool _isAvailable = true;
  bool _availabilitySynced = false;
  String _analyticsPeriod = 'week';
  String? _professionalCurrency;

  // Location picker data
  LatLng? _selectedLocation;
  String? _selectedAddress;

  Future<void> _toggleAvailability() async {
    final next = _isAvailable ? 'offline' : 'online';
    try {
      await ApiService.dio.put(
        '/professionals/me/status',
        data: {'status': next},
      );
      setState(() => _isAvailable = !_isAvailable);
    } catch (_) {}
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PickMapScreen(
          fromSignUp: true,
          fromAddAddress: false,
          canRoute: false,
          route: null,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedLocation = result['position'];
        _selectedAddress = result['address'];
      });
      // Save location to professional profile
      await _saveLocation();
    }
  }

  Future<void> _saveLocation() async {
    if (_selectedLocation == null) return;
    try {
      final data = <String, dynamic>{};
      data['location'] = {
        'lat': _selectedLocation!.latitude,
        'lng': _selectedLocation!.longitude,
      };
      if (_selectedAddress != null) {
        data['businessAddress'] = _selectedAddress;
      }
      await ApiService.dio.put('/professionals/me', data: data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated'),
            backgroundColor: _pink,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update location: $e'),
            backgroundColor: _pink,
          ),
        );
      }
    }
  }

  Future<void> _handleBookingAction(String bookingId, String action) async {
    try {
      await ApiService.dio.put('/bookings/$bookingId/$action');
      ref.invalidate(professionalDashboardProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e'), backgroundColor: _pink),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final dashAsync = ref.watch(professionalDashboardProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: dashAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _pink)),
        error: (e, _) =>
            _buildError(() => ref.refresh(professionalDashboardProvider)),
        data: (data) => _buildBody(context, data, user),
      ),
      bottomNavigationBar: GlayaBottomNav(
        currentIndex: 4, // Dashboard is the 5th item (index 4) in pro nav
        userRole: user?.role,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    Map<String, dynamic> data,
    dynamic user,
  ) {
    final pro = data['professional'] as Map<String, dynamic>? ?? {};
    final subscription = data['subscription'] as Map<String, dynamic>? ?? {};
    final currentPlan = subscription['currentPlan'] as String? ?? 'free';
    final todayEarnings = (data['todayEarnings'] as num?)?.toDouble() ?? 0.0;
    final todayCount = data['todayAppointmentsCount'] as int? ?? 0;
    final pendingCount = data['pendingRequestsCount'] as int? ?? 0;
    final totalBookings = (pro['totalBookings'] as num?)?.toInt() ?? 0;
    final totalReviews = (pro['totalReviews'] as num?)?.toInt() ?? 0;
    final avgRating =
        num.tryParse(pro['avgRating']?.toString() ?? '')?.toStringAsFixed(1) ??
            '0.0';
    final trustScore = (pro['trustScore'] as num?)?.toInt() ?? 0;
    final businessName =
        pro['businessName'] as String? ?? user?.name ?? 'My Business';
    final portfolioUrls = (pro['portfolioUrls'] as List<dynamic>?) ??
        (pro['portfolioGalleries'] as List<dynamic>?) ??
        const [];
    final todaySchedule = (data['todayAppointments'] as List<dynamic>?) ?? [];
    final pendingReqs = (data['pendingRequests'] as List<dynamic>?) ?? [];

    // Sync availability toggle with the server-side online status once
    if (!_availabilitySynced) {
      _availabilitySynced = true;
      final status = pro['onlineStatus']?.toString().toLowerCase();
      _isAvailable =
          status != 'offline' && status != 'away' && status != 'busy';
    }

    // Get professional's currency
    final currency = pro['currency'] as String? ?? 'XAF';
    setState(() => _professionalCurrency = currency);

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return RefreshIndicator(
      onRefresh: () => ref.refresh(professionalDashboardProvider.future),
      color: _pink,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Greeting header ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _buildHeader(greeting, businessName, avgRating, user),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                // Today's schedule (Priority 1: Bookings)
                _buildTodaySchedule(todaySchedule, todayCount),
                const SizedBox(height: 20),
                // Pending requests (Priority 1: Bookings)
                if (pendingCount > 0) ...[
                  _buildPendingRequests(pendingReqs, pendingCount),
                  const SizedBox(height: 20),
                ],
                // KPI strip (Revenue focus)
                _buildKpiStrip(todayEarnings, todayCount, pendingCount),
                const SizedBox(height: 20),
                // Revenue analytics (Priority 2: Finances)
                _buildRevenueAnalytics(),
                const SizedBox(height: 20),
                // Wallet summary (Priority 2: Finances)
                _buildWalletSummary(data),
                const SizedBox(height: 20),
                // Subscription card
                _buildSubscriptionCard(currentPlan),
                const SizedBox(height: 20),
                // Quick actions
                _buildQuickActions(context),
                const SizedBox(height: 20),
                // Performance metrics
                _buildPerformance(
                  totalBookings,
                  totalReviews,
                  avgRating,
                  trustScore,
                  data['analytics'],
                ),
                const SizedBox(height: 20),
                // Business health
                _buildBusinessHealth(data['analytics']),
                const SizedBox(height: 20),
                // Location
                _buildLocationSection(pro),
                const SizedBox(height: 20),
                // About Me / Bio
                _buildBioSection(pro),
                const SizedBox(height: 20),
                // Portfolio
                _buildPortfolio(portfolioUrls),
                const SizedBox(height: 20),
                // Business growth
                _buildBusinessGrowth(data),
                const SizedBox(height: 20),
                // Marketing
                _buildMarketing(context),
                const SizedBox(height: 20),
                // Settings
                _buildBusinessSettings(context),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────
  Widget _buildHeader(
    String greeting,
    String bizName,
    String rating,
    dynamic user,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_pink, _purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bizName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Verified Business',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFD700),
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          rating,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Avatar + availability toggle
              Column(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    backgroundImage: user?.photoUrl != null
                        ? NetworkImage(
                            ConfigService().replaceLocalhost(user!.photoUrl!),
                          )
                        : null,
                    child: user?.photoUrl == null
                        ? const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 28,
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _toggleAvailability,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _isAvailable
                            ? _green.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 7,
                            color: _isAvailable ? Colors.white : Colors.white60,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isAvailable ? 'Available' : 'Away',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── KPI strip ────────────────────────────────────────────────────────────────
  Widget _buildKpiStrip(double earnings, int appts, int pending) {
    final symbol = _professionalCurrency != null
        ? _getCurrencySymbol(_professionalCurrency!)
        : _currencySym();

    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            'Today\'s Revenue',
            '$symbol${earnings.toStringAsFixed(0)}',
            Icons.trending_up_rounded,
            _green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _kpiCard(
            'Appointments',
            '$appts',
            Icons.calendar_today_outlined,
            _pink,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _kpiCard(
            'Pending',
            '$pending',
            Icons.hourglass_empty_outlined,
            _amber,
          ),
        ),
      ],
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: _text2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  double _rate(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;

  // ── Performance ───────────────────────────────────────────────────────────────
  Widget _buildPerformance(
      int total, int reviews, String rating, int trust, dynamic analytics) {
    final a = analytics is Map<String, dynamic> ? analytics : const {};
    final completed = (a['completedBookings'] as num?)?.toInt() ?? 0;
    final cancelled = (a['cancelledBookings'] as num?)?.toInt() ?? 0;
    final active = (a['activeBookings'] as num?)?.toInt() ?? 0;
    final onTimePct = (_rate(a['onTimeRate']) * 100).round();
    return _card(
      title: 'Performance',
      icon: Icons.bar_chart_outlined,
      child: SizedBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _perfRow('Total Bookings', '$total', Icons.bookmark_outline, _pink),
            _divider(),
            _perfRow(
              'Completed',
              '$completed',
              Icons.check_circle_outline,
              _green,
            ),
            _divider(),
            _perfRow(
              'Cancelled',
              '$cancelled',
              Icons.cancel_outlined,
              Colors.redAccent,
            ),
            _divider(),
            _perfRow(
                'Active', '$active', Icons.pending_actions_outlined, _blue),
            _divider(),
            _perfRow(
                'On-time Rate', '$onTimePct%', Icons.timer_outlined, _blue),
            _divider(),
            _perfRow(
              'Trust Score',
              '$trust / 100',
              Icons.verified_outlined,
              _purple,
            ),
            _divider(),
            _perfRow('Avg Rating', '$rating / 5.0', Icons.star_outline, _amber),
            _divider(),
            _perfRow(
              'Total Reviews',
              '$reviews',
              Icons.rate_review_outlined,
              _pink,
            ),
          ],
        ),
      ),
    );
  }

  Widget _perfRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: _text2),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _text1,
            ),
          ),
        ],
      ),
    );
  }

  // ── Revenue Analytics ─────────────────────────────────────────────────────────
  Widget _buildRevenueAnalytics() {
    final analyticsAsync =
        ref.watch(dashboardAnalyticsProvider(_analyticsPeriod));
    final symbol = _professionalCurrency != null
        ? _getCurrencySymbol(_professionalCurrency!)
        : _currencySym();

    return _card(
      title: 'Revenue Analytics',
      icon: Icons.show_chart_outlined,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['week', 'month', 'year']
            .map(
              (p) => GestureDetector(
                onTap: () => setState(() => _analyticsPeriod = p),
                child: Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _analyticsPeriod == p ? _pink : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    p[0].toUpperCase() + p.substring(1),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _analyticsPeriod == p ? Colors.white : _text2,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
      child: analyticsAsync.when(
        loading: () => const SizedBox(
          height: 90,
          child: Center(child: CircularProgressIndicator(color: _pink)),
        ),
        error: (_, __) => const SizedBox(
          height: 90,
          child: Center(
            child: Text('Could not load analytics',
                style: TextStyle(fontSize: 12, color: _text2)),
          ),
        ),
        data: (a) {
          final earnings = (a['earnings'] as num?)?.toDouble() ?? 0;
          final completed = (a['completedBookings'] as num?)?.toInt() ?? 0;
          final cancelled = (a['cancelledBookings'] as num?)?.toInt() ?? 0;
          final onTime = (_rate(a['onTimeRate']) * 100).round();

          Widget stat(String label, String value, Color color, IconData icon) {
            return Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 9, color: _text2),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            );
          }

          return SizedBox(
            height: 96,
            child: Row(
              children: [
                stat(
                    'Earnings',
                    '$symbol${NumberFormat('#,##0').format(earnings)}',
                    _green,
                    Icons.payments_outlined),
                const SizedBox(width: 8),
                stat('Completed', '$completed', _blue,
                    Icons.check_circle_outline),
                const SizedBox(width: 8),
                stat('Cancelled', '$cancelled', Colors.redAccent,
                    Icons.cancel_outlined),
                const SizedBox(width: 8),
                stat('On-time', '$onTime%', _purple, Icons.timer_outlined),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Today's Schedule ──────────────────────────────────────────────────────────
  Widget _buildTodaySchedule(List<dynamic> schedule, int count) {
    return _card(
      title: "Today's Schedule ($count)",
      icon: Icons.event_note_outlined,
      child: schedule.isEmpty
          ? _emptyState('No appointments today', Icons.event_available_outlined)
          : Column(
              children: schedule.map((b) {
                final booking = b as Map<String, dynamic>?;
                if (booking == null) return const SizedBox.shrink();

                final dt = DateTime.tryParse(
                  booking['scheduled_at']?.toString() ?? '',
                );
                final timeStr = dt != null
                    ? DateFormat('h:mm a').format(dt.toLocal())
                    : '--:--';
                final customer =
                    booking['customer_name'] as String? ?? 'Customer';
                final service = booking['service_name'] as String? ?? 'Service';
                final status = booking['status'] as String? ?? '';
                final statusColor = status == 'confirmed'
                    ? _green
                    : status == 'in_progress'
                        ? _purple
                        : _amber;
                final bookingId = booking['id']?.toString();

                return GestureDetector(
                  onTap: bookingId != null
                      ? () => context.push('/bookings/$bookingId')
                      : null,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: _pink.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              timeStr,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _pink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _text1,
                                ),
                              ),
                              Text(
                                service,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _text2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ── Upcoming Bookings ─────────────────────────────────────────────────────────
  Widget _buildUpcomingBookings(List<dynamic> bookings) {
    return _card(
      title: 'Upcoming Bookings',
      icon: Icons.calendar_today_outlined,
      trailing: GestureDetector(
        onTap: () => context.push('/bookings'),
        child: const Text(
          'View All',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey,
          ),
        ),
      ),
      child: SizedBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: bookings.map((b) {
            final booking = b as Map<String, dynamic>?;
            if (booking == null) return const SizedBox.shrink();

            final dt = DateTime.tryParse(
              booking['scheduled_at']?.toString() ?? '',
            );
            final timeStr = dt != null
                ? DateFormat('EEE, MMM d • h:mm a').format(dt.toLocal())
                : '';
            final customer = booking['customer_name'] as String? ?? 'Customer';
            final service = booking['service_name'] as String? ?? 'Service';
            final status = booking['status'] as String? ?? '';
            final statusColor = status == 'confirmed'
                ? _green
                : status == 'in_progress'
                    ? _purple
                    : _amber;
            final bookingId = booking['id']?.toString();

            return GestureDetector(
              onTap: bookingId != null
                  ? () => context.push('/bookings/$bookingId')
                  : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _pink.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          timeStr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _pink,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _text1,
                            ),
                          ),
                          Text(
                            service,
                            style: const TextStyle(fontSize: 11, color: _text2),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Pending Requests ──────────────────────────────────────────────────────────
  Widget _buildPendingRequests(List<dynamic> reqs, int count) {
    return _card(
      title: 'Pending Requests ($count)',
      icon: Icons.pending_actions_outlined,
      child: SizedBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: reqs.map((b) {
            final booking = b as Map<String, dynamic>?;
            if (booking == null) return const SizedBox.shrink();

            final dt = DateTime.tryParse(
              booking['scheduled_at']?.toString() ?? '',
            );
            final timeStr = dt != null
                ? DateFormat('EEE, MMM d • h:mm a').format(dt.toLocal())
                : '';
            final customer = booking['customer_name'] as String? ?? 'Customer';
            final service = booking['service_name'] as String? ?? 'Service';
            final id = booking['id']?.toString();

            if (id == null || id.isEmpty) {
              return const SizedBox.shrink();
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _amber.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          customer,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _text1,
                          ),
                        ),
                      ),
                      Text(
                        timeStr,
                        style: const TextStyle(fontSize: 11, color: _text2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    service,
                    style: const TextStyle(fontSize: 12, color: _text2),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleBookingAction(id, 'accept'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _green,
                            elevation: 0,
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Accept',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleBookingAction(id, 'reject'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Reject',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      (Icons.content_cut_outlined, 'Add Service', '/services'),
      (Icons.calendar_month_outlined, 'Calendar', '/bookings'),
      (Icons.schedule_outlined, 'Availability', '/availability'),
      (Icons.account_balance_wallet_outlined, 'Wallet', '/wallet'),
      (Icons.chat_bubble_outline_rounded, 'Messages', '/chat/list'),
      (Icons.group_outlined, 'Customers', '/bookings'),
      (Icons.photo_library_outlined, 'Portfolio', '/portfolio'),
      (Icons.campaign_outlined, 'Promotions', '/promotions'),
      (Icons.workspace_premium_outlined, 'Subscription', '/subscription'),
    ];

    return _card(
      title: 'Quick Actions',
      icon: Icons.bolt_outlined,
      child: SizedBox(
        height: 160,
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 8,
          childAspectRatio: 0.85,
          children: actions.map((a) {
            return GestureDetector(
              onTap: () => context.push(a.$3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _pink.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(a.$1, color: _pink, size: 20),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    a.$2,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: _text2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Subscription Card ───────────────────────────────────────────────────────────
  Widget _buildSubscriptionCard(String currentPlan) {
    final isFlex = currentPlan.toLowerCase() == 'flex';
    final isElite = currentPlan.toLowerCase() == 'elite';
    final badgeColor = isFlex ? _purple : (isElite ? _gold : _text2);
    final badgeText = isFlex ? 'FLEX' : (isElite ? 'ELITE' : 'FREE');

    return GestureDetector(
      onTap: () => context.push('/subscription'),
      child: _card(
        title: 'Subscription',
        icon: Icons.workspace_premium_outlined,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isElite
                  ? [
                      _gold.withValues(alpha: 0.1),
                      _gold.withValues(alpha: 0.05)
                    ]
                  : isFlex
                      ? [
                          _pink.withValues(alpha: 0.1),
                          _pink.withValues(alpha: 0.05)
                        ]
                      : [
                          _text2.withValues(alpha: 0.05),
                          _text2.withValues(alpha: 0.02)
                        ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isElite
                      ? 'Maximum visibility with premium features'
                      : isFlex
                          ? 'Boost your visibility with featured listings'
                          : 'Upgrade to reach more customers',
                  style: const TextStyle(
                    color: _text2,
                    fontSize: 13,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: _text2,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Business Health ───────────────────────────────────────────────────────────
  Widget _buildBusinessHealth(dynamic analytics) {
    final a = analytics is Map<String, dynamic> ? analytics : const {};
    final completed = (a['completedBookings'] as num?)?.toInt() ?? 0;
    final cancelled = (a['cancelledBookings'] as num?)?.toInt() ?? 0;
    final late = (a['lateCount'] as num?)?.toInt() ?? 0;
    final total = completed + cancelled;
    final completionPct = total > 0 ? (completed / total * 100).round() : 0;
    final latePct = completed > 0 ? (late / completed * 100).round() : 0;
    final rating = _rate(a['avgRating']);
    final satisfactionPct = rating > 0 ? (rating / 5 * 100).round() : 0;

    final metrics = [
      ('Completion Rate', '$completionPct%', _green),
      (
        'Late Arrivals',
        '$latePct%',
        latePct > 10 ? Colors.redAccent : Colors.orangeAccent
      ),
      ('Customer Satisfaction', '$satisfactionPct%', _green),
      ('Avg Rating', rating > 0 ? rating.toStringAsFixed(1) : '—', _amber),
      ('Total Reviews', '${a['totalReviews'] ?? 0}', _blue),
    ];

    return _card(
      title: 'Business Health',
      icon: Icons.health_and_safety_outlined,
      child: SizedBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: metrics
              .map(
                (m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.$1,
                          style: const TextStyle(fontSize: 13, color: _text2),
                        ),
                      ),
                      Text(
                        m.$2,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: m.$3,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // ── Location Section ─────────────────────────────────────────────────────────
  Widget _buildLocationSection(Map<String, dynamic> pro) {
    final location = pro['location'] as Map<String, dynamic>?;
    final businessAddress =
        pro['businessAddress'] as String? ?? pro['business_address'] as String?;
    final city = pro['city'] as String?;
    final state = pro['state'] as String?;
    final country = pro['country'] as String?;

    String? displayAddress;
    if (businessAddress != null && businessAddress.isNotEmpty) {
      displayAddress = businessAddress;
    } else if (city != null || state != null || country != null) {
      displayAddress = [
        city,
        state,
        country,
      ].where((e) => e != null && e.isNotEmpty).join(', ');
    }

    return _card(
      title: 'Business Location',
      icon: Icons.location_on_outlined,
      trailing: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddressEditor(isProfessional: true),
            ),
          );
        },
        child: const Text(
          'Edit',
          style: TextStyle(
            fontSize: 12,
            color: _pink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (displayAddress != null) ...[
            Text(
              displayAddress,
              style: const TextStyle(fontSize: 14, color: _text1),
            ),
            const SizedBox(height: 8),
          ],
          if (location != null) ...[
            Row(
              children: [
                const Icon(Icons.map_outlined, size: 16, color: _text2),
                const SizedBox(width: 6),
                Text(
                  'Lat: ${location['lat']?.toStringAsFixed(4)}, Lng: ${location['lng']?.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 12, color: _text2),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          GestureDetector(
            onTap: _openLocationPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _pink.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _pink.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.edit_location_outlined,
                    size: 18,
                    color: _pink,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Update Location on Map',
                    style: TextStyle(
                      fontSize: 13,
                      color: _pink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.arrow_forward_ios, size: 14, color: _pink),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bio / About Me Section ─────────────────────────────────────────────────────
  Widget _buildBioSection(Map<String, dynamic> pro) {
    final bio = pro['bio'] as String? ?? '';
    final displayBio =
        bio.isEmpty ? 'Add your bio to tell customers about yourself...' : bio;

    return _card(
      title: 'About Me',
      icon: Icons.person_outline,
      trailing: GestureDetector(
        onTap: () => _showBioEditor(bio),
        child: const Text(
          'Edit',
          style: TextStyle(
            fontSize: 12,
            color: _pink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayBio,
            style: const TextStyle(fontSize: 14, color: _text1, height: 1.5),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (bio.length > 150) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showBioEditor(bio),
              child: const Text(
                'Read more',
                style: TextStyle(
                  fontSize: 12,
                  color: _pink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showBioEditor(String currentBio) async {
    final controller = TextEditingController(text: currentBio);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit About Me'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                maxLines: 5,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText:
                      'Tell customers about yourself, your experience, and what makes you unique...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value != null && value.length > 1000) {
                    return 'Bio must be less than 1000 characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _pink),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _saveBio(controller.text);
    }
  }

  Future<void> _saveBio(String bio) async {
    try {
      await ApiService.dio.put('/professionals/me', data: {'bio': bio});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bio updated successfully'),
            backgroundColor: _pink,
          ),
        );
        ref.invalidate(professionalDashboardProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update bio: $e'),
            backgroundColor: _pink,
          ),
        );
      }
    }
  }

  // ── Portfolio ─────────────────────────────────────────────────────────────────
  Widget _buildPortfolio(List<dynamic> galleries) {
    // portfolioUrls are plain URL strings; legacy portfolioGalleries are maps
    final displayUrls = galleries.take(8).map((item) {
      if (item is String) return item;
      if (item is Map<String, dynamic>) {
        final coverMedia = item['coverMedia'] as Map<String, dynamic>?;
        final media = item['media'] as List<dynamic>?;
        return (coverMedia?['mediaUrl'] as String?) ??
            (media?.firstOrNull?['mediaUrl'] as String?) ??
            '';
      }
      return '';
    }).toList();

    // Pad with empty strings to show 8 grid items
    while (displayUrls.length < 8) {
      displayUrls.add('');
    }

    return _card(
      title: 'Recent Work',
      icon: Icons.photo_library_outlined,
      trailing: GestureDetector(
        onTap: () => context.push('/portfolio'),
        child: const Text(
          'Manage',
          style: TextStyle(
            fontSize: 12,
            color: _pink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0, // 1:1 aspect ratio
        children: displayUrls.take(8).map((url) {
          if (url.isEmpty) {
            return GestureDetector(
              onTap: () => context.push('/portfolio'),
              child: Container(
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _pink.withValues(alpha: 0.2),
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: _pink,
                  size: 26,
                ),
              ),
            );
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              ConfigService().replaceLocalhost(url),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: _pink.withValues(alpha: 0.08),
                child: const Icon(Icons.image_outlined, color: _pink),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Business Growth ───────────────────────────────────────────────────────────
  Widget _buildBusinessGrowth(Map<String, dynamic> data) {
    final pro = data['professional'] as Map<String, dynamic>? ?? {};
    final a = data['analytics'] is Map<String, dynamic>
        ? data['analytics'] as Map<String, dynamic>
        : const {};
    final portfolioCount =
        (pro['portfolioUrls'] as List<dynamic>?)?.length ?? 0;
    final totalBookings = (pro['totalBookings'] as num?)?.toInt() ?? 0;
    final monthBookings = ((a['completedBookings'] as num?)?.toInt() ?? 0) +
        ((a['cancelledBookings'] as num?)?.toInt() ?? 0);
    final rating = num.tryParse(pro['avgRating']?.toString() ?? '') ?? 0;

    return _card(
      title: 'Business Growth',
      icon: Icons.trending_up_outlined,
      child: SizedBox(
        height: 80,
        child: Row(
          children: [
            _growthStat('Portfolio', '$portfolioCount',
                Icons.photo_library_outlined, _pink),
            _growthStat('Total Bookings', '$totalBookings',
                Icons.bookmark_outline, _blue),
            _growthStat('This Month', '$monthBookings',
                Icons.calendar_today_outlined, _green),
            _growthStat('Rating', rating > 0 ? rating.toStringAsFixed(1) : '—',
                Icons.star_outline, _amber),
          ],
        ),
      ),
    );
  }

  Widget _growthStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: SizedBox(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, color: _text2),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  // ── Marketing ─────────────────────────────────────────────────────────────────
  Widget _buildMarketing(BuildContext context) {
    final options = [
      (Icons.local_offer_outlined, 'Create Promotion', '/promotions'),
      (Icons.discount_outlined, 'Coupons', '/coupons'),
      (Icons.person_add_outlined, 'Refer Customers', '/refer'),
      (Icons.rocket_launch_outlined, 'Boost Profile', '/boost'),
      (Icons.analytics_outlined, 'Boost Analytics', '/boost/analytics'),
    ];
    return _card(
      title: 'Marketing',
      icon: Icons.campaign_outlined,
      child: SizedBox(
        height: 80,
        child: Row(
          children: options
              .map(
                (o) => Expanded(
                  child: GestureDetector(
                    onTap: () => context.push(o.$3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _purple.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(o.$1, color: _purple, size: 20),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          o.$2,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 9,
                            color: _text2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // ── Wallet Summary ────────────────────────────────────────────────────────────
  Widget _buildWalletSummary(Map<String, dynamic> data) {
    final walletAsync = ref.watch(proWalletProvider);
    final a = data['analytics'] is Map<String, dynamic>
        ? data['analytics'] as Map<String, dynamic>
        : const {};
    final monthEarnings = (a['earnings'] is num
                ? a['earnings'] as num
                : num.tryParse('${a['earnings']}'))
            ?.toDouble() ??
        0;

    return GestureDetector(
      onTap: () => context.push('/wallet'),
      child: _card(
        title: 'Wallet',
        icon: Icons.account_balance_wallet_outlined,
        child: walletAsync.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator(color: _pink)),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (wallet) {
            if (wallet == null) {
              return const SizedBox(
                height: 80,
                child: Center(
                  child: Text('No wallet yet',
                      style: TextStyle(fontSize: 12, color: _text2)),
                ),
              );
            }
            final currency =
                (wallet['currency'] as String? ?? 'XAF').toUpperCase();
            final sym = _getCurrencySymbol(currency);
            num? toNum(dynamic v) => v is num ? v : num.tryParse('$v');
            final balance = toNum(wallet['balance'])?.toDouble() ?? 0;
            final pending = toNum(wallet['pendingBalance'])?.toDouble() ?? 0;
            String fmt(num v) => '$sym${NumberFormat('#,##0').format(v)}';

            return SizedBox(
              height: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _walletStat('Balance', fmt(balance), _green),
                  _walletStat('This Month', fmt(monthEarnings), _blue),
                  _walletStat('Pending', fmt(pending), _amber),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _walletStat(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _text2)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Business Settings ─────────────────────────────────────────────────────────
  Widget _buildBusinessSettings(BuildContext context) {
    final items = [
      (Icons.business_outlined, 'Business Information', '/settings'),
      (Icons.access_time_outlined, 'Operating Hours', '/availability'),
      (Icons.account_balance_outlined, 'Bank Accounts', '/wallet'),
      (Icons.verified_outlined, 'Verification', '/settings'),
      (Icons.notifications_outlined, 'Notifications', '/notifications'),
      (Icons.logout, 'Logout', '__logout__'),
    ];
    return _card(
      title: 'Settings',
      icon: Icons.settings_outlined,
      child: SizedBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: items
              .map(
                (t) => InkWell(
                  onTap: () {
                    if (t.$3 == '__logout__') {
                      ref.read(authNotifierProvider.notifier).logout();
                      context.go('/login');
                    } else {
                      context.push(t.$3);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          t.$1,
                          size: 20,
                          color: t.$3 == '__logout__' ? _pink : _text2,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t.$2,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: t.$3 == '__logout__' ? _pink : _text1,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: Color(0xFFCCCCCC),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // ── Shared primitives ─────────────────────────────────────────────────────────
  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              Icon(icon, size: 16, color: _pink),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _text1,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, color: Color(0xFFF0F0F0));

  Widget _emptyState(String msg, IconData icon) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Column(
            children: [
              Icon(icon, size: 36, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text(msg, style: const TextStyle(fontSize: 13, color: _text2)),
            ],
          ),
        ),
      );

  Widget _buildError(VoidCallback onRetry) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Failed to load dashboard',
                style: TextStyle(color: _text2)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: _pink),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
}
