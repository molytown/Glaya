import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/providers/location_provider.dart';
import '../../auth/presentation/providers/auth_notifier.dart';
import '../../../../shared/widgets/booking_chat_dialog.dart';
import '../../payments/presentation/widgets/payment_deposit_dialog.dart';
import '../../payments/presentation/widgets/cod_payment_dialog.dart';

class BookingDetailScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  ConsumerState<BookingDetailScreen> createState() =>
      _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  Map<String, dynamic>? _booking;
  bool _isLoading = true;
  bool _actionLoading = false;

  num _parsePrice(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    try {
      final res = await ApiService.dio.get('/bookings/${widget.bookingId}');
      if (mounted) {
        setState(() => _booking = res.data['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      if (mounted) _snack('Failed to load booking: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performAction(String action) async {
    setState(() => _actionLoading = true);
    try {
      await ApiService.dio.put('/bookings/${widget.bookingId}/$action');
      await _loadBooking();
      if (mounted && action == 'cancel') {
        _snack('Appointment cancelled successfully');
      }
    } catch (e) {
      if (mounted) _snack('Action failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _confirmCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Appointment',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: const Text(
            'Are you sure you want to cancel this appointment? This action cannot be undone.',
            style: TextStyle(fontSize: 14, color: Color(0xFF555555))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Appointment',
                style: TextStyle(
                    color: Color(0xFF555555), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: GlayaColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Yes, Cancel',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true) _performAction('cancel');
  }

  double get _outstandingBalance {
    final v =
        _booking?['outstandingBalance'] ?? _booking?['outstanding_balance'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  bool get _codRequested =>
      _booking?['codRequested'] == true || _booking?['cod_requested'] == true;

  Future<void> _serviceDone() async {
    setState(() => _actionLoading = true);
    try {
      final res = await ApiService.dio
          .post('/bookings/${widget.bookingId}/service-done');
      final data = res.data['data'] as Map<String, dynamic>? ?? {};
      await _loadBooking();
      if (!mounted) return;
      if (data['completed'] == true) {
        _snack('Booking completed');
      } else {
        _snack(
            'Service done — the customer has been asked to pay the remaining balance');
      }
    } catch (e) {
      if (mounted) _snack('Action failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _showCodCode() async {
    await showDialog(
      context: context,
      builder: (_) => CodCodeDisplayDialog(bookingId: widget.bookingId),
    );
  }

  Future<void> _verifyCod() async {
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CodCodeEntryDialog(bookingId: widget.bookingId),
    );
    if (verified == true) {
      await _loadBooking();
      if (mounted) _snack('Payment confirmed — booking completed');
    }
  }

  Future<void> _payBalance() async {
    final paid = await showDialog<bool>(
      context: context,
      builder: (_) => PaymentDepositDialog(
          bookingId: widget.bookingId, paymentType: 'remaining'),
    );
    if (paid == true) {
      await _loadBooking();
      if (mounted) _snack('Balance paid — booking completed');
    }
  }

  Future<void> _showGlayaScore() async {
    final customerId = _booking?['customerId'] ?? _booking?['customer_id'];
    if (customerId == null) return;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => _GlayaScoreDialog(
        bookingId: widget.bookingId,
        customerId: customerId.toString(),
      ),
    );
    if (submitted == true) {
      if (mounted) _snack('Glaya Score submitted — thank you');
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? GlayaColors.error : GlayaColors.berry,
    ));
  }

  Future<void> _editBooking() async {
    // Show edit dialog to modify time or add services
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EditBookingDialog(
        currentScheduledAt:
            _booking?['scheduledAt'] ?? _booking?['scheduled_at'],
      ),
    );
    if (result != null) {
      setState(() => _actionLoading = true);
      try {
        await ApiService.dio.post('/bookings/${widget.bookingId}/reschedule',
            data: {'newScheduledAt': result['scheduledAt']});
        await _loadBooking();
        if (mounted) _snack('Booking updated successfully');
      } catch (e) {
        if (mounted) _snack('Failed to update booking: $e', error: true);
      } finally {
        if (mounted) setState(() => _actionLoading = false);
      }
    }
  }

  Future<void> _postponeBooking() async {
    // Send postpone request message to professional via chat
    setState(() => _actionLoading = true);
    try {
      await ApiService.dio.post('/chats/${widget.bookingId}/messages', data: {
        'message':
            'I would like to reschedule this appointment. Can we find a new time?',
        'type': 'postpone_request',
      });
      if (mounted) {
        _snack('Reschedule request sent to professional');
        showBookingChatDialog(context, widget.bookingId);
      }
    } catch (e) {
      if (mounted) _snack('Failed to send reschedule request: $e', error: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _deleteBooking() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Booking',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: const Text(
            'Are you sure you want to delete this booking? This action cannot be undone.',
            style: TextStyle(fontSize: 14, color: Color(0xFF555555))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(
                    color: Color(0xFF555555), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: GlayaColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _actionLoading = true);
      try {
        await ApiService.dio.delete('/bookings/${widget.bookingId}');
        if (mounted) {
          _snack('Booking deleted successfully');
          context.pop(); // Go back to bookings list
        }
      } catch (e) {
        if (mounted) _snack('Failed to delete booking: $e', error: true);
      } finally {
        if (mounted) setState(() => _actionLoading = false);
      }
    }
  }

  // ── Status helpers ───────────────────────────────────────────────────────────
  static const _statusColors = {
    'requested': Color(0xFFF59E0B),
    'accepted': Color(0xFF3B82F6),
    'deposit_required': Color(0xFFF59E0B),
    'confirmed': Color(0xFF10B981),
    'in_progress': Color(0xFF8B5CF6),
    'completed': Color(0xFF059669),
    'cancelled': Color(0xFFEF4444),
    'rejected': Color(0xFFEF4444),
  };
  static const _statusLabels = {
    'requested': 'Pending',
    'accepted': 'Accepted',
    'deposit_required': 'Deposit Required',
    'confirmed': 'Confirmed',
    'in_progress': 'In Progress',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
    'rejected': 'Rejected',
  };

  bool get _canCancel {
    final s = _booking?['status'] as String? ?? '';
    return s == 'requested' ||
        s == 'accepted' ||
        s == 'deposit_required' ||
        s == 'confirmed';
  }

  bool get _canEdit {
    final s = _booking?['status'] as String? ?? '';
    return s == 'requested' ||
        s == 'accepted' ||
        s == 'deposit_required' ||
        s == 'confirmed';
  }

  bool get _canPostpone {
    final s = _booking?['status'] as String? ?? '';
    return s == 'requested' ||
        s == 'accepted' ||
        s == 'deposit_required' ||
        s == 'confirmed';
  }

  bool get _canDelete {
    final s = _booking?['status'] as String? ?? '';
    return s == 'requested' ||
        s == 'accepted' ||
        s == 'deposit_required' ||
        s == 'confirmed' ||
        s == 'cancelled';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCE4EC),
        elevation: 0,
        centerTitle: true,
        title: const Text('Booking Details',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Color(0xFF1A1A1A)),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: GlayaColors.berry))
          : _booking == null
              ? _buildEmpty()
              : _buildContent(),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('Booking not found',
                style: TextStyle(color: Color(0xFF9E9E9E))),
          ],
        ),
      );

  Widget _buildContent() {
    final b = _booking!;
    final status = b['status'] as String? ?? '';
    final statusColor = _statusColors[status] ?? GlayaColors.berry;
    final statusLabel = _statusLabels[status] ?? status.toUpperCase();

    final serviceName = b['service']?['name'] as String? ?? 'Service';
    final agreedPrice = _parsePrice(b['agreedAmount'] ?? b['agreed_amount']);
    final rawPrice = agreedPrice > 0
        ? agreedPrice
        : _parsePrice(
            b['service']?['price'] ?? b['service']?['basePrice'] ?? 0);
    final proName =
        b['professional']?['user']?['name'] as String? ?? 'Professional';
    final proCategory =
        (b['professional']?['category'] as String? ?? '').replaceAll('_', ' ');
    final proInitial = proName.isNotEmpty ? proName[0].toUpperCase() : 'P';
    final location =
        b['locationType'] as String? ?? b['location_type'] as String? ?? '';
    final address = b['address'] as String? ?? 'No address provided';
    final proId = b['professional']?['id'] as String? ?? '';
    final deposit = _parsePrice(b['deposit'] ?? b['depositAmount'] ?? 0);
    final professionalCurrency =
        b['professional']?['currency'] as String? ?? 'XAF';
    final currencyAsync = ref.watch(userCurrencyProvider);
    final convertedAsync = rawPrice > 0
        ? ref.watch(convertedPriceProvider(
            (amount: rawPrice.toDouble(), fromCurrency: professionalCurrency)))
        : null;
    final depositAsync = deposit > 0
        ? ref.watch(convertedPriceProvider(
            (amount: deposit.toDouble(), fromCurrency: professionalCurrency)))
        : null;

    String dateStr = '—';
    try {
      final dt =
          DateTime.parse((b['scheduledAt'] ?? b['scheduled_at']) as String);
      dateStr = DateFormat('EEEE, MMMM d, y • h:mm a').format(dt);
    } catch (_) {}

    final user = ref.watch(authNotifierProvider).valueOrNull;
    final isPro = user?.role == 'professional' || user?.role == 'both';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Status banner ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(_statusIcon(status), color: statusColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(statusLabel,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: statusColor)),
                      const SizedBox(height: 2),
                      if (status == 'requested')
                        const Text(
                          'Waiting for stylist to confirm',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF888888),
                              fontStyle: FontStyle.italic),
                        )
                      else
                        Text(dateStr,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF555555))),
                      if (status == 'requested') ...[
                        const SizedBox(height: 1),
                        Text(dateStr,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF888888))),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Booking info card ────────────────────────────────────────
          _card(children: [
            _sectionTitle('Service'),
            const SizedBox(height: 12),
            _infoRow(Icons.content_cut_outlined, serviceName,
                sub: _priceLabel(rawPrice, convertedAsync, currencyAsync)),
            const Divider(height: 24),
            _sectionTitle('Stylist'),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: GlayaColors.berry.withValues(alpha: 0.15),
                  child: Text(proInitial,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: GlayaColors.berry)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(proName,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A))),
                      if (proCategory.isNotEmpty)
                        Text(proCategory,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF9E9E9E))),
                    ],
                  ),
                ),
                if (proId.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => context.push('/professional/$proId'),
                    icon: const Icon(Icons.person_outline, size: 16),
                    label: const Text('View Profile'),
                  ),
              ],
            ),
            const Divider(height: 24),
            _sectionTitle('Location'),
            const SizedBox(height: 12),
            _infoRow(Icons.location_on_outlined,
                location.isNotEmpty ? location : 'Home visit',
                sub: address),
            if (deposit > 0) ...[
              const Divider(height: 24),
              _sectionTitle('Payment'),
              const SizedBox(height: 12),
              _paymentSummary(rawPrice, deposit, convertedAsync, depositAsync,
                  currencyAsync),
            ],
          ]),
          const SizedBox(height: 20),

          // ── Primary actions ──────────────────────────────────────────
          _buildPrimaryActions(status, isPro),

          // ── Secondary actions (Edit, Postpone, Delete) — customer only ──
          if (!isPro && (_canEdit || _canPostpone || _canDelete)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (_canEdit) ...[
                  Expanded(
                    child: _secondaryActionBtn('Edit', Icons.edit_outlined,
                        onTap: _actionLoading ? null : _editBooking),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_canPostpone) ...[
                  Expanded(
                    child: _secondaryActionBtn(
                        'Postpone', Icons.schedule_outlined,
                        onTap: _actionLoading ? null : _postponeBooking),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_canDelete)
                  Expanded(
                    child: _secondaryActionBtn('Delete', Icons.delete_outline,
                        onTap: _actionLoading ? null : _deleteBooking,
                        isDestructive: true),
                  ),
              ],
            ),
          ],

          // ── Cancel Appointment ────────────────────────────────────────
          if (_canCancel) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _actionLoading ? null : _confirmCancel,
                icon: _actionLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: GlayaColors.error))
                    : const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancel Appointment',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: GlayaColors.error,
                  side: const BorderSide(color: GlayaColors.error),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPrimaryActions(String status, bool isPro) {
    switch (status) {
      case 'requested':
        if (isPro) {
          // Professional coordinates time + price in chat, then confirms terms
          return _actionBtn('Chat', Icons.chat_bubble_outline,
              onTap: () => showBookingChatDialog(context, widget.bookingId));
        }
        // Customer: show Chat button
        return _actionBtn('Chat', Icons.chat_bubble_outline,
            onTap: () => showBookingChatDialog(context, widget.bookingId));
      case 'accepted':
      case 'deposit_required':
        if (isPro) {
          return _actionBtn(
              'Confirm & Request Deposit', Icons.request_quote_outlined,
              onTap: () => showBookingChatDialog(context, widget.bookingId));
        }
        return Column(children: [
          _actionBtn('Pay Now', Icons.payment_outlined,
              onTap: () => context.push('/payment/${widget.bookingId}')),
          const SizedBox(height: 8),
          _actionBtn('Chat', Icons.chat_bubble_outline,
              outlined: true,
              onTap: () => showBookingChatDialog(context, widget.bookingId)),
        ]);
      case 'confirmed':
        if (isPro) {
          return Column(children: [
            _actionBtn('Check In', Icons.login_outlined,
                onTap: () => _performAction('checkin')),
            const SizedBox(height: 8),
            _actionBtn('Chat', Icons.chat_bubble_outline,
                outlined: true,
                onTap: () => showBookingChatDialog(context, widget.bookingId)),
          ]);
        }
        final customerCheckedIn = _booking?['customerCheckedInAt'] != null ||
            _booking?['customer_checked_in_at'] != null;
        return Column(children: [
          if (customerCheckedIn)
            _actionBtn('Checked In', Icons.check_circle_outline,
                outlined: true, onTap: null)
          else
            _actionBtn("I'm Here", Icons.login_outlined,
                onTap: () => _performAction('customer-checkin')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _actionBtn('Message', Icons.chat_bubble_outline,
                    outlined: true,
                    onTap: () =>
                        showBookingChatDialog(context, widget.bookingId))),
            const SizedBox(width: 8),
            Expanded(
                child: _actionBtn('Call', Icons.call_outlined,
                    outlined: true,
                    onTap: () => context.push('/call/${widget.bookingId}'))),
          ]),
        ]);
      case 'in_progress':
        if (isPro) {
          return Column(children: [
            _actionBtn('Service done', Icons.task_alt_outlined,
                onTap: () => _serviceDone()),
            const SizedBox(height: 8),
            _actionBtn('Payment Code', Icons.pin_outlined,
                outlined: true, onTap: _showCodCode),
            const SizedBox(height: 8),
            _actionBtn('Chat', Icons.chat_bubble_outline,
                outlined: true,
                onTap: () => showBookingChatDialog(context, widget.bookingId)),
          ]);
        }
        return Column(children: [
          if (_outstandingBalance > 0) ...[
            _actionBtn('Pay Balance', Icons.payment_outlined,
                onTap: _payBalance),
            const SizedBox(height: 8),
          ],
          if (_codRequested) ...[
            _actionBtn('Enter Payment Code', Icons.pin_outlined,
                onTap: _verifyCod),
            const SizedBox(height: 8),
          ],
          _actionBtn('Chat', Icons.chat_bubble_outline,
              outlined: true,
              onTap: () => showBookingChatDialog(context, widget.bookingId)),
        ]);
      case 'completed':
        if (isPro) {
          // Professionals rate the customer (Glaya Score); they don't review
          // their own service.
          return Column(children: [
            _actionBtn('Rate Customer', Icons.star_outline,
                onTap: _showGlayaScore),
            const SizedBox(height: 8),
            _actionBtn('Chat', Icons.chat_bubble_outline,
                outlined: true,
                onTap: () => showBookingChatDialog(context, widget.bookingId)),
          ]);
        }
        return _actionBtn('Leave a Review', Icons.star_outline,
            onTap: () => context.push('/review/${widget.bookingId}'));
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Shared helpers ────────────────────────────────────────────────────────────
  Widget _card({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9E9E9E),
          letterSpacing: 0.8));

  Widget _infoRow(IconData icon, String title, {String? sub}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: GlayaColors.berry, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A))),
              if (sub != null)
                Text(sub,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9E9E9E))),
            ]),
          ),
        ],
      );

  Widget _actionBtn(String label, IconData icon,
      {VoidCallback? onTap, bool outlined = false}) {
    if (outlined) {
      return SizedBox(
        height: 46,
        child: OutlinedButton.icon(
          onPressed: _actionLoading ? null : onTap,
          icon: Icon(icon, size: 16),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: GlayaColors.berry,
            side: const BorderSide(color: GlayaColors.berry),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _actionLoading ? null : onTap,
        icon: _actionLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 18),
        label: Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: GlayaColors.berry,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  String _priceLabel(
      num base, AsyncValue<double>? converted, String? currency) {
    final symbol = _currencySymbol(currency);
    final convertedVal = converted?.valueOrNull;
    if (convertedVal != null && convertedVal != base.toDouble()) {
      return '$symbol${convertedVal.toStringAsFixed(0)}';
    }
    return '$symbol${base.toStringAsFixed(0)}';
  }

  String _currencySymbol(String? code) {
    const symbols = <String, String>{
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'XAF': 'XAF',
      'XOF': 'CFA',
      'NGN': '₦',
      'GHS': '₵',
      'KES': 'KSh',
      'ZAR': 'R',
      'EGP': 'E£',
      'MAD': 'DH',
      'ETB': 'Br',
      'TZS': 'TSh',
      'UGX': 'USh',
      'CDF': 'FC',
      'AED': 'د.إ',
      'SAR': '﷼',
      'INR': '₹',
      'CNY': '¥',
      'JPY': '¥',
      'CAD': 'C\$',
    };
    return symbols[code] ?? code ?? 'XAF';
  }

  Widget _paymentSummary(
      num total,
      num deposit,
      AsyncValue<double>? totalConverted,
      AsyncValue<double>? depositConverted,
      String? currency) {
    final remaining = total - deposit;
    final rows = <Widget>[
      _paymentRow('Total', total, totalConverted, currency),
      _paymentRow('Deposit Amount', deposit, depositConverted, currency),
    ];
    if (remaining > 0) {
      rows.add(_paymentRow('Remaining', remaining, null, currency));
    }
    return Column(children: rows);
  }

  Widget _paymentRow(
      String label, num amount, AsyncValue<double>? converted, String? currency,
      {bool positive = false}) {
    final symbol = _currencySymbol(currency);
    final convertedVal = converted?.valueOrNull;
    final display = convertedVal != null && convertedVal != amount.toDouble()
        ? '$symbol${convertedVal.toStringAsFixed(0)}'
        : '$symbol${amount.toStringAsFixed(0)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          Text(display,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: positive
                      ? GlayaColors.success
                      : GlayaColors.textPrimary)),
        ],
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'requested':
        return Icons.hourglass_empty_outlined;
      case 'accepted':
        return Icons.thumb_up_outlined;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'in_progress':
        return Icons.access_time_outlined;
      case 'completed':
        return Icons.task_alt_outlined;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Widget _secondaryActionBtn(String label, IconData icon,
      {VoidCallback? onTap, bool isDestructive = false}) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor:
              isDestructive ? GlayaColors.error : GlayaColors.berry,
          side: BorderSide(
              color: isDestructive ? GlayaColors.error : GlayaColors.berry),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _EditBookingDialog extends StatefulWidget {
  final String? currentScheduledAt;
  const _EditBookingDialog({this.currentScheduledAt});

  @override
  State<_EditBookingDialog> createState() => _EditBookingDialogState();
}

class _EditBookingDialogState extends State<_EditBookingDialog> {
  DateTime? _selectedDate;
  String? _selectedTime;

  @override
  void initState() {
    super.initState();
    if (widget.currentScheduledAt != null) {
      try {
        _selectedDate = DateTime.parse(widget.currentScheduledAt!);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Edit Booking',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select new date and time',
              style: TextStyle(fontSize: 13, color: Color(0xFF555555))),
          const SizedBox(height: 16),
          ListTile(
            title: Text(_selectedDate != null
                ? DateFormat('MMMM d, y').format(_selectedDate!)
                : 'Select Date'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
          const SizedBox(height: 8),
          ListTile(
            title: Text(_selectedTime != null ? _selectedTime! : 'Select Time'),
            trailing: const Icon(Icons.access_time),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (picked != null) {
                setState(() => _selectedTime = picked.format(context));
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(
                  color: Color(0xFF555555), fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(
          onPressed: _selectedDate != null && _selectedTime != null
              ? () {
                  final dt = DateTime(
                    _selectedDate!.year,
                    _selectedDate!.month,
                    _selectedDate!.day,
                  );
                  final timeParts = _selectedTime!.split(' ');
                  final hourMin = timeParts[0].split(':');
                  final hour = int.parse(hourMin[0]);
                  final minute = int.parse(hourMin[1]);
                  final isPM = timeParts.length > 1 &&
                      timeParts[1].toLowerCase() == 'pm';
                  final finalHour = isPM && hour != 12
                      ? hour + 12
                      : (isPM ? hour : hour % 12);
                  final scheduledAt =
                      DateTime(dt.year, dt.month, dt.day, finalHour, minute);
                  Navigator.pop(context,
                      {'scheduledAt': scheduledAt.toUtc().toIso8601String()});
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: GlayaColors.berry,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child:
              const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

/// Professional → customer rating shown after a completed booking.
/// Posts a 'glaya_score' review (review_type set server-side by direction).
class _GlayaScoreDialog extends StatefulWidget {
  final String bookingId;
  final String customerId;

  const _GlayaScoreDialog({required this.bookingId, required this.customerId});

  @override
  State<_GlayaScoreDialog> createState() => _GlayaScoreDialogState();
}

class _GlayaScoreDialogState extends State<_GlayaScoreDialog> {
  int _rating = 5;
  bool _submitting = false;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ApiService.dio.post('/reviews', data: {
        'bookingId': widget.bookingId,
        'revieweeId': widget.customerId,
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'punctualityScore': _rating,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to submit score: $e'),
              backgroundColor: GlayaColors.error),
        );
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Glaya Score',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('How was the customer? This becomes their Glaya Score.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return IconButton(
                icon: Icon(
                  i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: const Color(0xFFFFD700),
                  size: 36,
                ),
                onPressed: () => setState(() => _rating = i + 1),
              );
            }),
          ),
          TextField(
            controller: _commentController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Add a note (optional)',
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Skip',
              style: TextStyle(
                  color: Color(0xFF555555), fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: GlayaColors.berry,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit',
                  style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
