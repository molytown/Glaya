import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/haptic_feedback.dart';
import '../../../../shared/widgets/price_display.dart';
import '../../auth/presentation/providers/auth_notifier.dart';

// Currency code to symbol mapping
const _currencySymbols = <String, String>{
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

String _getCurrencySymbol(String currencyCode) {
  return _currencySymbols[currencyCode] ?? currencyCode;
}

String _formatPrice(double price, String? currency) {
  final symbol = _getCurrencySymbol(currency ?? 'XAF');
  return '$symbol${price.toStringAsFixed(0)}';
}

class BookingFlowScreen extends ConsumerStatefulWidget {
  final String professionalId;
  final String? initialServiceId;
  const BookingFlowScreen(
      {super.key, required this.professionalId, this.initialServiceId});

  @override
  _BookingFlowScreenState createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends ConsumerState<BookingFlowScreen> {
  // ── Step tracking ────────────────────────────────────────────────────────────
  int _step =
      0; // 0=service 1=datetime 2=location 3=address/summary → send request

  // ── Selections ───────────────────────────────────────────────────────────────
  Map<String, dynamic>? _selectedService;
  DateTime? _selectedDate;
  String? _selectedTime;
  String _locationType = 'salon';
  final _addressCtrl = TextEditingController();

  // ── Data ─────────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _services = [];
  List<String> _slots = [];
  Map<String, dynamic>? _professional;
  bool _loadingServices = true;
  bool _loadingSlots = false;
  bool _submitting = false;

  // ── Steps meta ───────────────────────────────────────────────────────────────
  static const _stepTitles = [
    'Choose Service',
    'Date & Time',
    'Location',
    'Address'
  ];
  static const _stepIcons = [
    Icons.spa_outlined,
    Icons.calendar_today_outlined,
    Icons.location_on_outlined,
    Icons.home_outlined
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.dio.get('/professionals/${widget.professionalId}'),
        ApiService.dio.get('/services',
            queryParameters: {'professional_id': widget.professionalId}),
      ]);
      if (mounted) {
        setState(() {
          _professional = results[0].data['data'] as Map<String, dynamic>?;
          _services = (results[1].data['data'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          _loadingServices = false;
        });
        // Preselect service if provided
        if (widget.initialServiceId != null) {
          final initialService = _services.firstWhere(
            (s) => s['id'] == widget.initialServiceId,
            orElse: () => _services.isNotEmpty ? _services[0] : {},
          );
          if (initialService.isNotEmpty && mounted) {
            setState(() => _selectedService = initialService);
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingServices = false);
    }
  }

  Future<void> _loadSlots(DateTime date) async {
    setState(() {
      _loadingSlots = true;
      _slots = [];
      _selectedTime = null;
    });
    try {
      final res = await ApiService.dio.get(
        '/professionals/${widget.professionalId}/availability',
        queryParameters: {'date': DateFormat('yyyy-MM-dd').format(date)},
      );
      final raw = res.data['data'];
      if (mounted) {
        setState(() {
          _slots = raw is List ? raw.cast<String>() : <String>[];
        });
      }
    } catch (_) {
      // Fallback: show hourly slots 9am–6pm
      if (mounted) {
        setState(() {
          _slots = List.generate(9, (i) {
            final h = 9 + i;
            return '${h.toString().padLeft(2, '0')}:00';
          });
        });
      }
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  // ── Booking submission ───────────────────────────────────────────────────────
  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final userId = await StorageService.getUserId();
      final bookingData = <String, dynamic>{
        'userId': userId,
        'professionalId': widget.professionalId,
        'serviceId': _selectedService!['id'],
        'locationType': _locationType,
        'status': 'requested',
        if (_selectedTime != null)
          'scheduledAt': DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            int.parse(_selectedTime!.split(':')[0]),
            int.parse(_selectedTime!.split(':')[1]),
          ).toIso8601String()
        else
          'scheduledAt': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        if (_locationType == 'home' && _addressCtrl.text.trim().isNotEmpty)
          'address': _addressCtrl.text.trim(),
      };
      final bookingRes =
          await ApiService.dio.post('/bookings', data: bookingData);
      final bookingId = bookingRes.data['data']['id'] as String;

      if (mounted) {
        HapticFeedback.success();
        _showSuccessDialog(bookingId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Booking failed: $e'),
          backgroundColor: GlayaColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Navigation ───────────────────────────────────────────────────────────────
  void _next() {
    if (_step == 0 && _selectedService == null) {
      HapticFeedback.error();
      _snack('Please select a service');
      return;
    }
    if (_step == 1) {
      if (_selectedDate == null) {
        HapticFeedback.error();
        _snack('Please pick a date');
        return;
      }
      // Time is optional — the professional confirms the exact slot via chat
    }
    if (_step == 3) {
      // Address validation for home visits
      if (_locationType == 'home' && _addressCtrl.text.trim().isEmpty) {
        HapticFeedback.error();
        _snack('Please enter your address');
        return;
      }
    }
    if (_step == 3) {
      // Final step (address/summary) — submit booking request
      final authNotifier = ref.read(authNotifierProvider.notifier);
      if (!authNotifier.isAuthenticated) {
        HapticFeedback.warning();
        _showLoginPrompt();
        return;
      }
      _submit();
      return;
    }
    HapticFeedback.light();
    setState(() => _step++);
  }

  void _back() {
    if (_step > 0) {
      HapticFeedback.light();
      setState(() => _step--);
    } else {
      HapticFeedback.light();
      context.pop();
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: GlayaColors.berry));

  void _showLoginPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: GlayaColors.berry.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline,
                  color: GlayaColors.berry, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Sign in to continue',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'You need to create an account to submit booking requests.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF555555), height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF555555),
                      side: const BorderSide(color: Color(0xFFEEEEEE)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/auth/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlayaColors.berry,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Sign In',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(String bookingId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: Color(0xFF10B981), size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Booking Request Sent!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'The professional will review and confirm your booking. Once confirmed, you can complete the payment to validate it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF555555), height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF555555),
                      side: const BorderSide(color: Color(0xFFEEEEEE)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Close',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                      context.push('/bookings/$bookingId');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlayaColors.berry,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('View Booking',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final proName =
        _professional?['user']?['name'] as String? ?? 'Professional';

    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCE4EC),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Color(0xFF1A1A1A)),
          onPressed: _back,
        ),
        title: Column(
          children: [
            Text('Book with $proName',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A))),
            Text(_stepTitles[_step],
                style: const TextStyle(
                    fontSize: 12,
                    color: GlayaColors.berry,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildStepper(),
          Expanded(
            child: _loadingServices
                ? const Center(
                    child: CircularProgressIndicator(color: GlayaColors.berry))
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    child: [
                      _buildStep0(),
                      _buildStep1(),
                      _buildStep2(),
                      _buildStep3(),
                    ][_step],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ── Step indicator ───────────────────────────────────────────────────────────
  Widget _buildStepper() {
    return Container(
      color: const Color(0xFFFCE4EC),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: List.generate(_stepTitles.length, (i) {
          final done = i < _step;
          final current = i == _step;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: current ? 42 : 34,
                        height: current ? 42 : 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done || current
                              ? GlayaColors.berry
                              : GlayaColors.blushPink,
                          boxShadow: done || current
                              ? [
                                  BoxShadow(
                                    color: GlayaColors.roseGold
                                        .withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [
                                  const BoxShadow(
                                    color: GlayaColors.softShadow,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Icon(
                          done ? Icons.check_rounded : _stepIcons[i],
                          size: current ? 20 : 16,
                          color: done || current
                              ? Colors.white
                              : GlayaColors.berry,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(_stepTitles[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                current ? FontWeight.w700 : FontWeight.w600,
                            color: current
                                ? GlayaColors.berry
                                : GlayaColors.textSecondary,
                          )),
                    ],
                  ),
                ),
                if (i < _stepTitles.length - 1)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: i < _step
                              ? [GlayaColors.berry, GlayaColors.roseGold]
                              : [GlayaColors.blushPink, GlayaColors.blushPink],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Step 0: Service selection ────────────────────────────────────────────────
  Widget _buildStep0() {
    if (_services.isEmpty) {
      return _emptyState(Icons.spa_outlined, 'No services found',
          'This professional has no services listed yet.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select a Service',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A))),
        const SizedBox(height: 4),
        const Text('Choose the service you\'d like to book',
            style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
        const SizedBox(height: 16),
        ..._services.map((s) {
          final selected = _selectedService?['id'] == s['id'];
          final duration = s['durationMinutes'] ?? s['duration'] ?? '';
          return GestureDetector(
            onTap: () {
              HapticFeedback.selection();
              setState(() => _selectedService = s);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: selected ? GlayaColors.blushPink : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? GlayaColors.berry : GlayaColors.blushPink,
                  width: selected ? 2 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: GlayaColors.roseGold.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        const BoxShadow(
                          color: GlayaColors.softShadow,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color:
                          selected ? GlayaColors.berry : GlayaColors.blushPink,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: selected
                              ? GlayaColors.roseGold.withValues(alpha: 0.3)
                              : GlayaColors.softShadow,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.spa_outlined,
                        color: selected ? Colors.white : GlayaColors.berry,
                        size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['name'] as String? ?? 'Service',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? GlayaColors.berry
                                    : GlayaColors.textPrimary)),
                        if (duration != '') ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.access_time,
                                  size: 12, color: GlayaColors.textSecondary),
                              const SizedBox(width: 4),
                              Text('$duration min',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: GlayaColors.textSecondary)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      PriceDisplay(
                        amount: double.tryParse(
                                (s['price'] ?? s['basePrice'] ?? 0)
                                    .toString()) ??
                            0.0,
                        fromCurrency: _professional?['currency'] as String?,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? GlayaColors.berry
                                : GlayaColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked,
                        color: selected
                            ? GlayaColors.berry
                            : GlayaColors.textTertiary,
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Step 1: Date + time ──────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Date & Time',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A))),
        const SizedBox(height: 16),
        // Horizontal date strip — next 14 days
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 14,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final date = DateTime.now().add(Duration(days: i));
              final selected = _selectedDate != null &&
                  _selectedDate!.day == date.day &&
                  _selectedDate!.month == date.month;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedDate = date);
                  _loadSlots(date);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 56,
                  decoration: BoxDecoration(
                    color: selected ? GlayaColors.berry : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: selected
                            ? GlayaColors.berry
                            : const Color(0xFFEEEEEE)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6)
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(DateFormat('EEE').format(date),
                          style: TextStyle(
                              fontSize: 11,
                              color: selected
                                  ? Colors.white70
                                  : const Color(0xFF9E9E9E))),
                      const SizedBox(height: 4),
                      Text('${date.day}',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF1A1A1A))),
                      Text(DateFormat('MMM').format(date),
                          style: TextStyle(
                              fontSize: 10,
                              color: selected
                                  ? Colors.white70
                                  : const Color(0xFF9E9E9E))),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        if (_selectedDate == null)
          _infoBox(Icons.touch_app_outlined,
              'Pick a date above to see available time slots')
        else if (_loadingSlots)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
                child: CircularProgressIndicator(color: GlayaColors.berry)),
          )
        else if (_slots.isEmpty)
          _infoBox(Icons.event_busy_outlined,
              'No slots available for this date. Try another day.')
        else ...[
          const Text('Available Times',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _slots.map((slot) {
              final sel = _selectedTime == slot;
              return GestureDetector(
                onTap: () => setState(() => _selectedTime = slot),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? GlayaColors.berry : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                            sel ? GlayaColors.berry : const Color(0xFFEEEEEE)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6)
                    ],
                  ),
                  child: Text(slot,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : const Color(0xFF333333))),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // ── Step 2: Location ─────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Where would you like the service?',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A))),
        const SizedBox(height: 4),
        const Text('Choose a location type',
            style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
        const SizedBox(height: 20),
        _locationOption(
          icon: Icons.store_outlined,
          title: 'At the Salon',
          subtitle: 'Visit the professional\'s salon',
          value: 'salon',
        ),
        const SizedBox(height: 12),
        _locationOption(
          icon: Icons.home_outlined,
          title: 'Home Visit',
          subtitle: 'Professional comes to you',
          value: 'home',
        ),
        if (_locationType == 'home') ...[
          const SizedBox(height: 20),
          const Text('Your Address',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 8),
          TextField(
            controller: _addressCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter your full address...',
              hintStyle: const TextStyle(color: Colors.black87),
              prefixIcon: const Icon(Icons.location_on_outlined,
                  color: GlayaColors.berry),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: GlayaColors.berry, width: 2)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ],
    );
  }

  Widget _locationOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
  }) {
    final sel = _locationType == value;
    return GestureDetector(
      onTap: () => setState(() => _locationType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: sel ? GlayaColors.berry.withValues(alpha: 0.07) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: sel ? GlayaColors.berry : const Color(0xFFEEEEEE),
              width: sel ? 2 : 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: sel
                    ? GlayaColors.berry.withValues(alpha: 0.12)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: sel ? GlayaColors.berry : const Color(0xFF9E9E9E),
                  size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: sel
                              ? GlayaColors.berry
                              : const Color(0xFF1A1A1A))),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9E9E9E))),
                ],
              ),
            ),
            Icon(
              sel ? Icons.check_circle : Icons.radio_button_unchecked,
              color: sel ? GlayaColors.berry : const Color(0xFFCCCCCC),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 3: Address ──────────────────────────────────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Booking summary ────────────────────────────────────────────
        Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('BOOKING SUMMARY',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9E9E9E),
                      letterSpacing: 0.8)),
              const SizedBox(height: 14),
              _summaryRow(
                  Icons.spa_outlined,
                  _selectedService?['name'] as String? ?? '—',
                  _selectedService != null
                      ? _formatPrice(
                          double.tryParse((_selectedService!['price'] ??
                                      _selectedService!['basePrice'] ??
                                      0)
                                  .toString()) ??
                              0.0,
                          _professional?['currency'] as String?)
                      : '—'),
              const Divider(height: 20),
              _summaryRow(
                  Icons.calendar_today_outlined,
                  _selectedDate != null
                      ? DateFormat('EEE, MMM d, y').format(_selectedDate!)
                      : '—',
                  _selectedTime ?? '—'),
              const Divider(height: 20),
              _summaryRow(
                _locationType == 'salon'
                    ? Icons.store_outlined
                    : Icons.home_outlined,
                _locationType == 'salon' ? 'At Salon' : 'Home Visit',
                _locationType == 'home' && _addressCtrl.text.isNotEmpty
                    ? _addressCtrl.text.trim()
                    : '',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Address setup (for home visits) ─────────────────────────────────
        if (_locationType == 'home') ...[
          const Text('Your Address',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 12),
          TextField(
            controller: _addressCtrl,
            decoration: InputDecoration(
              labelText: 'Street Address',
              hintText: 'Enter your address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: GlayaColors.berry, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: 'City',
              hintText: 'Enter your city',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: GlayaColors.berry, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: 'Additional Instructions (optional)',
              hintText: 'Landmark, gate code, etc.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: GlayaColors.berry, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ] else ...[
          const Text('Service Location',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFCE4EC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.store_outlined, color: GlayaColors.berry),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _professional?['businessName'] as String? ??
                            'Professional\'s Salon',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        _professional?['businessAddress'] as String? ??
                            'Address will be provided',
                        style: const TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: GlayaColors.berry, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A))),
        ),
        Text(value,
            style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
      ],
    );
  }

  // ── Bottom bar ───────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final isLastStep = _step == 3;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4))
        ],
      ),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: _submitting ? null : _next,
          style: ElevatedButton.styleFrom(
            backgroundColor: GlayaColors.berry,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLastStep ? 'Send Booking Request' : 'Continue',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Icon(isLastStep ? Icons.send : Icons.arrow_forward_rounded,
                        size: 20),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  Widget _emptyState(IconData icon, String title, String sub) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF555555))),
            const SizedBox(height: 4),
            Text(sub,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
          ],
        ),
      );

  Widget _infoBox(IconData icon, String msg) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GlayaColors.berry.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GlayaColors.berry.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: GlayaColors.berry, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(msg,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF555555)))),
          ],
        ),
      );
}
