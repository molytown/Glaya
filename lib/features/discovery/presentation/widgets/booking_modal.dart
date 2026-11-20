import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../data/professional_model.dart';

class BookingModal extends ConsumerStatefulWidget {
  final ProfessionalModel professional;
  final ServiceItem? initialService;
  final VoidCallback onClose;
  final VoidCallback? onSuccess;

  const BookingModal({
    super.key,
    required this.professional,
    this.initialService,
    required this.onClose,
    this.onSuccess,
  });

  @override
  ConsumerState<BookingModal> createState() => _BookingModalState();
}

class _BookingModalState extends ConsumerState<BookingModal> {
  ServiceItem? _selectedService;
  DateTime? _selectedDate;
  String _serviceType = 'salon';
  bool _submitting = false;
  String? _error;
  bool _success = false;
  String? _bookingId;

  @override
  void initState() {
    super.initState();
    _selectedService = widget.initialService;
    // Default to tomorrow
    _selectedDate = DateTime.now().add(const Duration(days: 1));
  }

  Future<void> _submit() async {
    if (_selectedService == null) {
      setState(() => _error = 'Please select a service');
      return;
    }
    if (_selectedDate == null) {
      setState(() => _error = 'Please select a date');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final userId = await StorageService.getUserId();
      final bookingData = <String, dynamic>{
        'userId': userId,
        'professionalId': widget.professional.id,
        'serviceId': _selectedService!.id,
        'locationType': _serviceType,
        'status': 'requested',
        'scheduledAt': DateFormat('yyyy-MM-dd').format(_selectedDate!),
      };

      final res = await ApiService.dio.post('/bookings', data: bookingData);
      final data = res.data['data'] as Map<String, dynamic>?;
      setState(() {
        _success = true;
        _bookingId = data?['id']?.toString();
        _submitting = false;
      });
      widget.onSuccess?.call();
    } catch (e) {
      setState(() {
        _error = 'Failed to create booking: $e';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = (widget.professional.services ?? []).cast<ServiceItem>();
    final isAuthenticated = ref.watch(authNotifierProvider).valueOrNull != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Book Appointment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF000000)),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _success
                    ? _buildSuccess()
                    : _buildForm(services, isAuthenticated),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: GlayaColors.berry.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle, color: GlayaColors.berry, size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          'Booking Request Sent!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
        ),
        const SizedBox(height: 8),
        Text(
          'Your request has been sent to ${widget.professional.name}. You\'ll be notified once confirmed.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF000000)),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  widget.onClose();
                  if (_bookingId != null) {
                    Navigator.of(context).pushNamed('/bookings/$_bookingId');
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('View Booking'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: widget.onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlayaColors.berry,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildForm(List<ServiceItem> services, bool isAuthenticated) {
    if (!isAuthenticated) {
      return Column(
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.lock_outline, size: 48, color: Color(0xFF000000)),
          const SizedBox(height: 16),
          const Text(
            'Sign in to book',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please sign in to book an appointment',
            style: TextStyle(fontSize: 14, color: Color(0xFF000000)),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: widget.onClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: GlayaColors.berry,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Close'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Professional info
        _buildReadonlyField('Stylist', widget.professional.name),
        _buildReadonlyField('Salon', widget.professional.businessName ?? 'Independent'),
        const SizedBox(height: 16),
        // Service selector
        _buildLabel('Service'),
        // ignore: deprecated_member_use
        DropdownButtonFormField<String>(
          value: _selectedService?.id,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('Select a service')),
            ...services.map((s) => DropdownMenuItem(
                  value: s.id,
                  child: Text(s.name),
                )),
          ],
          onChanged: (v) {
            setState(() {
              _selectedService = services.firstWhere((s) => s.id == v, orElse: () => services.first);
              _error = null;
            });
          },
        ),
        const SizedBox(height: 16),
        // Date picker
        _buildLabel('Date'),
        InkWell(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFDDDDDD)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Color(0xFF000000)),
                const SizedBox(width: 8),
                Text(
                  _selectedDate != null
                      ? DateFormat('MMM d, yyyy').format(_selectedDate!)
                      : 'Select date',
                  style: TextStyle(
                    fontSize: 14,
                    color: _selectedDate != null ? const Color(0xFF1A1A1A) : const Color(0xFF000000),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Time note
        _buildLabel('Time'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Time will be confirmed with the professional via chat after booking.',
            style: TextStyle(fontSize: 13, color: Color(0xFF000000)),
          ),
        ),
        const SizedBox(height: 16),
        // Amount
        _buildLabel('Amount'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _selectedService != null
                ? '${_selectedService!.price.toStringAsFixed(0)} ${widget.professional.currency ?? 'XAF'}'
                : 'Select a service',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
          ),
        ),
        const SizedBox(height: 16),
        // Service type
        _buildLabel('Service Type'),
        // ignore: deprecated_member_use
        DropdownButtonFormField<String>(
          value: _serviceType,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: [
            const DropdownMenuItem(value: 'salon', child: Text('Book Appointment')),
            if (widget.professional.homeService)
              const DropdownMenuItem(value: 'home', child: Text('Home Service')),
          ],
          onChanged: (v) => setState(() => _serviceType = v ?? 'salon'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: GlayaColors.berry,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(_submitting ? 'Sending...' : 'Send Booking Request'),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A1A),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildReadonlyField(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF000000), fontSize: 13)),
          Text(value, style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }
}
