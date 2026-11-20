import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';

class OpeningHoursDisplay extends ConsumerStatefulWidget {
  final String professionalId;
  final bool isOwnProfile;
  final VoidCallback? onEditClick;

  const OpeningHoursDisplay({
    super.key,
    required this.professionalId,
    this.isOwnProfile = false,
    this.onEditClick,
  });

  @override
  ConsumerState<OpeningHoursDisplay> createState() => _OpeningHoursDisplayState();
}

class _OpeningHoursDisplayState extends ConsumerState<OpeningHoursDisplay> {
  List<dynamic> _availability = [];
  bool _loading = true;

  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    try {
      final res = await ApiService.dio.get('/professionals/${widget.professionalId}/availability');
      final data = res.data['data'] as List<dynamic>? ?? [];
      setState(() {
        _availability = data;
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

    final today = DateTime.now().weekday % 7; // 0=Sunday

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
                  'Opening Hours',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                ),
              ),
              if (widget.isOwnProfile && widget.onEditClick != null)
                TextButton(
                  onPressed: widget.onEditClick,
                  child: const Text('Edit', style: TextStyle(color: GlayaColors.berry, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_availability.isEmpty)
            const Text('No schedule available', style: TextStyle(fontSize: 13, color: Color(0xFF888888)))
          else
            Column(
              children: List.generate(7, (dayIndex) {
                final slots = _getSlotsForDay(dayIndex);
                final isToday = dayIndex == today;
                return _buildDayRow(
                  _days[dayIndex],
                  _dayNames[dayIndex],
                  slots,
                  isToday,
                );
              }),
            ),
        ],
      ),
    );
  }

  List<dynamic> _getSlotsForDay(int dayOfWeek) {
    return _availability.where((a) {
      final day = a['dayOfWeek'] as int? ?? a['day_of_week'] as int? ?? 0;
      return day == dayOfWeek;
    }).toList();
  }

  Widget _buildDayRow(String shortDay, String fullDay, List<dynamic> slots, bool isToday) {
    final isOpen = slots.any((s) => !(s['isBlocked'] as bool? ?? s['is_blocked'] as bool? ?? false));
    final isClosed = slots.isEmpty;

    String timeRange = '';
    if (!isClosed && slots.isNotEmpty) {
      // Get open time slots
      final openSlots = slots.where((s) => !(s['isBlocked'] as bool? ?? s['is_blocked'] as bool? ?? false)).toList();
      if (openSlots.isNotEmpty) {
        final first = openSlots.first;
        final openTime = first['openTime'] ?? first['open_time'] ?? first['startTime'] ?? first['start_time'];
        final closeTime = first['closeTime'] ?? first['close_time'] ?? first['endTime'] ?? first['end_time'];
        if (openTime != null && closeTime != null) {
          timeRange = '${_formatTime(openTime)} - ${_formatTime(closeTime)}';
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isToday ? GlayaColors.berry.withValues(alpha: 0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              shortDay,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isToday ? GlayaColors.berry : const Color(0xFF666666),
              ),
            ),
          ),
          Expanded(
            child: Text(
              isClosed
                  ? 'Closed'
                  : isOpen
                      ? (timeRange.isNotEmpty ? timeRange : 'Open')
                      : 'Closed',
              style: TextStyle(
                fontSize: 13,
                color: isClosed
                    ? const Color(0xFF999999)
                    : isOpen
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFF999999),
              ),
            ),
          ),
          if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: GlayaColors.berry.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Today',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: GlayaColors.berry),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(dynamic time) {
    if (time == null) return '';
    final str = time.toString();
    // Handle "HH:MM:SS" format
    if (str.contains(':')) {
      final parts = str.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        final period = hour >= 12 ? 'PM' : 'AM';
        final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$hour12:${minute.toString().padLeft(2, '0')} $period';
      }
    }
    return str;
  }
}
