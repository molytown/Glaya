import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';

class UpcomingAppointment extends ConsumerStatefulWidget {
  final String professionalId;
  final bool isOwnProfile;

  const UpcomingAppointment({
    super.key,
    required this.professionalId,
    this.isOwnProfile = false,
  });

  @override
  ConsumerState<UpcomingAppointment> createState() => _UpcomingAppointmentState();
}

class _UpcomingAppointmentState extends ConsumerState<UpcomingAppointment> {
  List<dynamic> _appointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    try {
      final res = await ApiService.dio.get('/bookings');
      final data = res.data['data'] as List<dynamic>? ?? [];
      // Filter for this professional's appointments
      final filtered = data.where((a) {
        final proId = a['professionalId'] ?? a['professional']?['id'];
        return proId == widget.professionalId;
      }).toList();
      // Sort by date
      filtered.sort((a, b) {
        final aDate = DateTime.tryParse(a['scheduledAt'] ?? a['scheduled_at'] ?? '') ?? DateTime(1970);
        final bDate = DateTime.tryParse(b['scheduledAt'] ?? b['scheduled_at'] ?? '') ?? DateTime(1970);
        return aDate.compareTo(bDate);
      });
      setState(() {
        _appointments = filtered;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: const Center(child: CircularProgressIndicator(color: GlayaColors.berry)),
      );
    }

    if (_appointments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Column(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 32, color: Color(0xFFCCCCCC)),
            const SizedBox(height: 8),
            const Text('No upcoming appointments', style: TextStyle(fontSize: 14, color: Color(0xFF000000))),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.push('/bookings'),
              style: OutlinedButton.styleFrom(
                foregroundColor: GlayaColors.berry,
                side: const BorderSide(color: GlayaColors.berry),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('View Bookings'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Upcoming Appointments',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/bookings'),
                child: const Text('View all', style: TextStyle(color: GlayaColors.berry, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._appointments.take(3).map((appt) => _buildAppointmentCard(appt)),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(dynamic appt) {
    final customerName = appt['customer']?['name'] ?? appt['customerName'] ?? 'Customer';
    final serviceName = appt['service']?['name'] ?? appt['serviceName'] ?? 'Service';
    final scheduledAt = appt['scheduledAt'] ?? appt['scheduled_at'];
    final status = appt['status'] ?? 'pending';
    final location = appt['location'] ?? appt['address'] ?? 'Salon';

    DateTime? date;
    try {
      date = DateTime.parse(scheduledAt?.toString() ?? '');
    } catch (_) {}

    final isToday = date != null && DateUtils.isSameDay(date, DateTime.now());
    final isTomorrow = date != null && DateUtils.isSameDay(date, DateTime.now().add(const Duration(days: 1)));

    String dateText = '';
    String timeText = '';
    if (date != null) {
      if (isToday) {
        dateText = 'Today';
      } else if (isTomorrow) {
        dateText = 'Tomorrow';
      } else {
        dateText = DateFormat('MMM d').format(date);
      }
      timeText = DateFormat('h:mm a').format(date);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: GlayaColors.berry.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                customerName.toString().isNotEmpty ? customerName.toString()[0].toUpperCase() : 'C',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: GlayaColors.berry),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                Text(serviceName, style: const TextStyle(fontSize: 12, color: Color(0xFF000000))),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF000000)),
                    const SizedBox(width: 4),
                    Expanded(child: Text(location, style: const TextStyle(fontSize: 11, color: Color(0xFF000000)), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 12, color: Color(0xFF000000)),
                    const SizedBox(width: 4),
                    Text('$dateText · $timeText', style: const TextStyle(fontSize: 11, color: Color(0xFF000000))),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status.toString(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor(status)),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return const Color(0xFF16A34A);
      case 'confirmed':
      case 'accepted': return const Color(0xFF2563EB);
      case 'cancelled':
      case 'rejected': return const Color(0xFFDC2626);
      case 'requested': return const Color(0xFFD97706);
      default: return const Color(0xFF6B7280);
    }
  }
}
