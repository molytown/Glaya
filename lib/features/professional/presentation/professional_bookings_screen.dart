import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';

// ── Currency helper ──────────────────────────────────────────────────────────
String _currencySym() {
  try {
    final locale = Intl.getCurrentLocale();
    if (locale.startsWith('en_US')) return '\$';
    if (locale.startsWith('en_GB')) return '£';
    if (locale.startsWith('fr_') ||
        locale.startsWith('de_') ||
        locale.startsWith('es_') ||
        locale.startsWith('it_')) return '€';
    if (locale.startsWith('en_KE')) return 'KSh ';
    if (locale.startsWith('en_GH')) return 'GH₵ ';
    if (locale.startsWith('en_ZA')) return 'R ';
    if (locale.startsWith('en_IN')) return '₹';
  } catch (_) {}
  return '₦';
}

class ProfessionalBookingsScreen extends ConsumerStatefulWidget {
  const ProfessionalBookingsScreen({super.key});

  @override
  ConsumerState<ProfessionalBookingsScreen> createState() =>
      _ProfessionalBookingsScreenState();
}

class _ProfessionalBookingsScreenState
    extends ConsumerState<ProfessionalBookingsScreen> {
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;
  String _filter = 'all';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.dio.get('/professionals/bookings');
      if (mounted) {
        setState(() {
          _bookings =
              (res.data['data'] as List? ?? []).cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredBookings {
    var filtered = _bookings;

    if (_filter != 'all') {
      filtered = filtered.where((b) => b['status'] == _filter).toList();
    }

    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((b) {
        final userName = b['user']?['name'] as String? ?? '';
        final bookingId = b['id'] as String? ?? '';
        return userName.toLowerCase().contains(query) ||
            bookingId.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  Future<void> _confirmBooking(String bookingId) async {
    try {
      await ApiService.dio.post('/bookings/$bookingId/accept');
      await _loadBookings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Booking confirmed'),
              backgroundColor: Colors.green),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to confirm booking'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectBooking(String bookingId) async {
    try {
      await ApiService.dio.post('/bookings/$bookingId/reject');
      await _loadBookings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Booking rejected'),
              backgroundColor: Colors.orange),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to reject booking'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showEditDialog(Map<String, dynamic> booking) {
    final scheduledAt = booking['scheduledAt'] ?? booking['scheduled_at'];
    DateTime? selectedDate;
    String? selectedTime;

    try {
      selectedDate = DateTime.parse(scheduledAt as String);
      selectedTime = DateFormat('HH:mm').format(selectedDate);
    } catch (_) {}

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Reschedule Booking'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  hintText: 'YYYY-MM-DD',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
                controller: TextEditingController(
                  text: selectedDate != null
                      ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                      : '',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedTime,
                decoration: const InputDecoration(labelText: 'Time'),
                items: const [
                  '08:00',
                  '09:00',
                  '10:00',
                  '11:00',
                  '12:00',
                  '14:00',
                  '15:00',
                  '16:00',
                  '17:00',
                  '18:00',
                  '19:00'
                ]
                    .map((time) =>
                        DropdownMenuItem(value: time, child: Text(time)))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedTime = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedDate != null && selectedTime != null) {
                  final parts = selectedTime!.split(':');
                  final newDateTime = DateTime(
                    selectedDate!.year,
                    selectedDate!.month,
                    selectedDate!.day,
                    int.parse(parts[0]),
                    int.parse(parts[1]),
                  );
                  try {
                    await ApiService.dio
                        .post('/bookings/${booking['id']}/reschedule', data: {
                      'newScheduledAt': newDateTime.toUtc().toIso8601String(),
                    });
                    await _loadBookings();
                    if (mounted) Navigator.pop(context);
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Failed to reschedule'),
                            backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: GlayaColors.berry),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _getSpecialistTitle(Map<String, dynamic>? service) {
    if (service == null) return 'Specialist';
    final name = (service['name'] as String? ?? '').toLowerCase();
    final category = (service['category'] as String? ?? '').toLowerCase();

    if (name.contains('hair') ||
        name.contains('braid') ||
        name.contains('wig') ||
        category.contains('hair')) {
      return 'Stylist';
    }
    if (name.contains('makeup') ||
        name.contains('face') ||
        name.contains('facial') ||
        category.contains('makeup') ||
        category.contains('face')) {
      return 'Makeup Artist';
    }
    if (name.contains('nail') ||
        name.contains('manicure') ||
        category.contains('nail')) {
      return 'Manicurist';
    }
    if (name.contains('pedicure') ||
        name.contains('feet') ||
        category.contains('feet')) {
      return 'Pedicurist';
    }
    return 'Specialist';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'requested':
        return const Color(0xFFF59E0B);
      case 'confirmed':
      case 'accepted':
        return const Color(0xFF10B981);
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'completed':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'requested':
        return 'Pending';
      case 'confirmed':
      case 'accepted':
        return 'Confirmed';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Booking Requests',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: GlayaColors.berry.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_outlined,
                color: GlayaColors.berry, size: 20),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: GlayaColors.berry))
                : _filteredBookings.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredBookings.length,
                        itemBuilder: (_, i) =>
                            _buildBookingCard(_filteredBookings[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search bookings...',
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All', 'all'),
                _filterChip('Pending', 'pending'),
                _filterChip('Confirmed', 'confirmed'),
                _filterChip('Completed', 'completed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: GlayaColors.berry,
        labelStyle: TextStyle(
          color: selected ? Colors.white : const Color(0xFF6B7280),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No bookings found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Try adjusting your filters',
              style: TextStyle(color: Color(0xFF9E9E9E))),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final service = booking['service'] as Map<String, dynamic>?;
    final user = booking['user'] as Map<String, dynamic>?;
    final status = booking['status'] as String? ?? 'pending';
    final scheduledAt = booking['scheduledAt'] ?? booking['scheduled_at'];
    String dateStr = '';
    try {
      final dt = DateTime.parse(scheduledAt as String);
      dateStr = DateFormat('EEE, MMM d • h:mm a').format(dt.toLocal());
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getStatusColor(status), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatStatus(status),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  booking['id'] as String? ?? '',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
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
                        borderRadius: BorderRadius.circular(12),
                        color: GlayaColors.berry.withValues(alpha: 0.1),
                      ),
                      child: const Icon(Icons.spa_outlined,
                          color: GlayaColors.berry, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service?['name'] as String? ?? 'Service',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            service?['category'] as String? ?? 'Beauty',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF9E9E9E)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${_currencySym()}${(service?['price'] ?? service?['basePrice'] ?? 0).toString()}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: GlayaColors.berry),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: GlayaColors.berry.withValues(alpha: 0.1),
                      child: const Icon(Icons.person,
                          color: GlayaColors.berry, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?['name'] as String? ?? 'Client',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            user?['phone'] as String? ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF9E9E9E)),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        // Navigate to chat or show contact options
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Text('Contact'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: GlayaColors.berry),
                        foregroundColor: GlayaColors.berry,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 16, color: Color(0xFF6B7280)),
                    const SizedBox(width: 8),
                    Text(dateStr,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF374151))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 16, color: Color(0xFF6B7280)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        booking['address'] as String? ?? 'Salon',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF374151)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (status == 'pending' || status == 'requested')
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showEditDialog(booking),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit Date/Time'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF9E9E9E)),
                        foregroundColor: const Color(0xFF374151),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectBooking(booking['id']),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmBooking(booking['id']),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Confirm'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
