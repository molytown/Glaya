import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/websocket_service.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/text_styles.dart';
import '../../payments/presentation/widgets/payment_deposit_dialog.dart';
import '../../payments/presentation/widgets/cod_payment_dialog.dart';
import '../../../../shared/services/notification_sound_service.dart';
import '../../../../shared/providers/chat_bubble_provider.dart';
import '../../auth/presentation/providers/auth_notifier.dart';

double? _toDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

class ChatScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final bool embedded;
  final VoidCallback? onClose;

  const ChatScreen({
    super.key,
    required this.bookingId,
    this.embedded = false,
    this.onClose,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _webSocketService = WebSocketService();
  List<Map<String, dynamic>> _messages = [];
  String? _userId;
  bool _isTyping = false;
  Map<String, dynamic>? _bookingDetails;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _userId = await StorageService.getUserId();
    _webSocketService.connect();
    _webSocketService.joinRoom(widget.bookingId);
    _webSocketService.messageStream.listen(_onMessageReceived);
    _webSocketService.typingStream.listen(_onTyping);
    _webSocketService.bookingControlStream.listen(_onBookingControl);
    await _loadMessages();
    await _loadBookingDetails();
    _markMessagesRead();
  }

  /// Persist read state server-side so unread counts don't come back on the
  /// chat list / floating bubble, then refresh the bubble from the server.
  Future<void> _markMessagesRead() async {
    try {
      await ApiService.dio.put('/chat/${widget.bookingId}/read');
      final resp = await ApiService.dio.get('/chats/list');
      final rooms = (resp.data['data'] as List).cast<Map<String, dynamic>>();
      if (mounted) {
        ref.read(chatBubbleProvider.notifier).updateFromChatList(rooms);
      }
    } catch (_) {}
  }

  Future<void> _loadBookingDetails() async {
    try {
      final response =
          await ApiService.dio.get('/bookings/${widget.bookingId}');
      if (mounted) {
        setState(() =>
            _bookingDetails = response.data['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      // Silently fail if booking details can't be loaded
    }
  }

  static const Color _senderColor = Color(0xFF7C3AED);
  static const Color _receiverColor = Color(0xFFFFD9C7);
  static const Color _receiverTextColor = Color(0xFF5C3A21);

  String? _messageSenderId(Map<String, dynamic> m) =>
      (m['sender_id'] ?? m['senderId'])?.toString();

  DateTime _messageTime(Map<String, dynamic> m) =>
      DateTime.tryParse(
          (m['created_at'] ?? m['createdAt'])?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _loadMessages() async {
    try {
      final response =
          await ApiService.dio.get('/chat/${widget.bookingId}/messages');
      final messages =
          (response.data['data'] as List).cast<Map<String, dynamic>>();
      messages.sort((a, b) => _messageTime(a).compareTo(_messageTime(b)));
      setState(() => _messages = messages);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load messages: ${e.toString()}')),
        );
      }
    }
  }

  void _onMessageReceived(dynamic message) {
    final msg = message as Map<String, dynamic>;
    final senderId = _messageSenderId(msg);
    final isMine = senderId != null && senderId == _userId;

    setState(() {
      // Dedupe — REST load and socket echo can deliver the same message
      final id = msg['id']?.toString();
      final exists =
          id != null && _messages.any((m) => m['id']?.toString() == id);
      if (!exists) {
        _messages.add(msg);
        // Sort by time to ensure correct order
        _messages.sort((a, b) => _messageTime(a).compareTo(_messageTime(b)));
      }
      if (!isMine) _isTyping = false;
    });
    _scrollToBottom();

    if (!isMine) {
      final user = ref.read(authNotifierProvider).valueOrNull;
      NotificationSoundService.instance.playMessageReceived(
        isProfessional: user?.role == 'professional' || user?.role == 'both',
      );
    }
  }

  void _onTyping(Map<String, dynamic> data) {
    if (data['userId'] != _userId) {
      setState(() => _isTyping = data['typing'] as bool);
      if (data['typing'] == true) {
        // Auto-clear in case typing:stop is missed
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _isTyping = false);
        });
      }
    }
  }

  void _onBookingControl(Map<String, dynamic> data) {
    // Handle booking control events (backend emits booking_id snake_case)
    final bid = data['bookingId'] ?? data['booking_id'];
    if (bid != null && bid.toString() == widget.bookingId) {
      _loadBookingDetails(); // Reload booking details when they change
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _userId == null) return;

    _webSocketService.sendTypingStop(widget.bookingId, _userId!);
    _webSocketService.sendMessage(widget.bookingId, _userId!, content, 'text');
    _messageController.clear();
  }

  void _sendQuickReply(String message) {
    if (_userId == null) return;
    _webSocketService.sendMessage(
        widget.bookingId, _userId!, message, 'quick_reply');
  }

  @override
  void dispose() {
    _webSocketService.leaveRoom(widget.bookingId);
    _webSocketService.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _chatTitleFor(bool isProfessional) {
    final details = _bookingDetails;
    if (details == null) return 'Chat';
    if (isProfessional) {
      final customer = details['customer'] as Map<String, dynamic>?;
      return (customer?['name'] as String?)?.trim().isNotEmpty == true
          ? customer!['name'] as String
          : 'Customer';
    }
    final professional = details['professional'] as Map<String, dynamic>?;
    final proUser = professional?['user'] as Map<String, dynamic>?;
    final name =
        (professional?['businessName'] as String?)?.trim().isNotEmpty == true
            ? professional!['businessName'] as String
            : (proUser?['name'] as String?)?.trim() ?? '';
    return name.isNotEmpty ? name : 'Professional';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final isProfessional = user?.role == 'professional' || user?.role == 'both';
    final bookingStatus = _bookingDetails?['status'] as String? ?? '';

    final chatBody = Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              final isMe = _messageSenderId(message) == _userId;
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMe ? _senderColor : _receiverColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    message['content'] as String,
                    style: GlayaTextStyles.bodyMedium(
                        color: isMe ? Colors.white : _receiverTextColor),
                  ),
                ),
              );
            },
          ),
        ),
        if (_isTyping)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Typing...', style: GlayaTextStyles.bodySmall()),
          ),
        // Professional controls
        if (isProfessional && bookingStatus == 'requested')
          _buildProfessionalControls(),
        if (isProfessional && bookingStatus == 'accepted')
          _buildFinalizeControl(),
        if (isProfessional && bookingStatus == 'in_progress')
          _buildServiceDoneControls(),
        // User controls
        if (!isProfessional && bookingStatus == 'deposit_required')
          _buildUserDepositControl(),
        if (!isProfessional &&
            bookingStatus == 'in_progress' &&
            (_outstandingBalance > 0 || _codRequested))
          _buildBalanceControls(),
        // Quick replies
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              'I\'m on my way',
              'I\'m here',
              'Running late',
            ]
                .map((text) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(text),
                        onPressed: () => _sendQuickReply(text),
                      ),
                    ))
                .toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(
                    color: Color(0xFF000000),
                    fontSize: 16,
                  ),
                  cursorColor: GlayaColors.berry,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: GlayaColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: GlayaColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                          color: GlayaColors.berry, width: 1.5),
                    ),
                  ),
                  onChanged: (_) {
                    if (_userId != null) {
                      _webSocketService.sendTypingStart(
                          widget.bookingId, _userId!);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: GlayaColors.berry,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return Material(
        color: Colors.white,
        child: Column(
          children: [
            _buildEmbeddedHeader(isProfessional, bookingStatus),
            Expanded(child: chatBody),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: GlayaColors.textPrimary,
        elevation: 0,
        title: Text(
          _chatTitleFor(isProfessional),
          style: GlayaTextStyles.titleLarge(),
          overflow: TextOverflow.ellipsis,
        ),
        actions: _buildAppBarActions(isProfessional, bookingStatus),
      ),
      body: chatBody,
    );
  }

  List<Widget> _buildAppBarActions(bool isProfessional, String bookingStatus) {
    return [
      if (isProfessional && bookingStatus == 'requested') ...[
        IconButton(
          icon: const Icon(Icons.event_available),
          onPressed: _showProposeTermsDialog,
          tooltip: 'Confirm Booking',
        ),
      ],
      if (isProfessional && bookingStatus == 'accepted')
        IconButton(
          icon: const Icon(Icons.check_circle),
          onPressed: _finalizeBooking,
          tooltip: 'Finalize Booking',
        ),
      if (!isProfessional && bookingStatus == 'deposit_required')
        IconButton(
          icon: const Icon(Icons.payment),
          onPressed: _showPayDepositDialog,
          tooltip: 'Pay Deposit',
        ),
    ];
  }

  Widget _buildEmbeddedHeader(bool isProfessional, String bookingStatus) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        right: 8,
        bottom: 8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: GlayaColors.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: GlayaColors.textPrimary),
            onPressed: widget.onClose ?? () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              _chatTitleFor(isProfessional),
              style: GlayaTextStyles.titleMedium(),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ..._buildAppBarActions(isProfessional, bookingStatus),
        ],
      ),
    );
  }

  static ButtonStyle get _bookButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: GlayaColors.berry,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      );

  Widget _buildProfessionalControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.event_available, size: 16),
              label: const Text('Confirm Booking'),
              onPressed: _showProposeTermsDialog,
              style: _bookButtonStyle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Decline'),
              onPressed: _confirmDecline,
              style: OutlinedButton.styleFrom(
                foregroundColor: GlayaColors.error,
                side: const BorderSide(color: GlayaColors.error),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalizeControl() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text('Finalize Booking'),
          onPressed: _finalizeBooking,
          style: _bookButtonStyle,
        ),
      ),
    );
  }

  Widget _buildUserDepositControl() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.payment, size: 18),
          label: const Text('Pay Deposit'),
          onPressed: _showPayDepositDialog,
          style: _bookButtonStyle,
        ),
      ),
    );
  }

  double get _outstandingBalance {
    final v = _bookingDetails?['outstandingBalance'] ??
        _bookingDetails?['outstanding_balance'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  bool get _codRequested =>
      _bookingDetails?['codRequested'] == true ||
      _bookingDetails?['cod_requested'] == true;

  Widget _buildServiceDoneControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.task_alt, size: 16),
              label: const Text('Service done'),
              onPressed: _serviceDone,
              style: _bookButtonStyle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.pin_outlined, size: 16),
              label: const Text('Payment Code'),
              onPressed: _showCodCode,
              style: OutlinedButton.styleFrom(
                foregroundColor: GlayaColors.berry,
                side: const BorderSide(color: GlayaColors.berry),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_outstandingBalance > 0)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.payment, size: 18),
                label: const Text('Pay Balance'),
                onPressed: _payBalance,
                style: _bookButtonStyle,
              ),
            ),
          if (_codRequested) ...[
            if (_outstandingBalance > 0) const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.pin_outlined, size: 18),
                label: const Text('Enter Payment Code'),
                onPressed: _verifyCod,
                style: OutlinedButton.styleFrom(
                  foregroundColor: GlayaColors.berry,
                  side: const BorderSide(color: GlayaColors.berry),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _serviceDone() async {
    try {
      final res = await ApiService.dio
          .post('/bookings/${widget.bookingId}/service-done');
      final data = res.data['data'] as Map<String, dynamic>? ?? {};
      await _loadBookingDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['completed'] == true
                ? 'Booking completed'
                : 'Service done — customer asked to pay the balance'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
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
      await _loadBookingDetails();
      _markMessagesRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Payment confirmed — booking completed')),
        );
      }
    }
  }

  Future<void> _payBalance() async {
    final paid = await showDialog<bool>(
      context: context,
      builder: (_) => PaymentDepositDialog(
          bookingId: widget.bookingId, paymentType: 'remaining'),
    );
    if (paid == true) {
      await _loadBookingDetails();
      _markMessagesRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Balance paid — booking completed')),
        );
      }
    }
  }

  double? _suggestedAmount() {
    final details = _bookingDetails;
    if (details == null) return null;
    final agreed =
        _toDoubleOrNull(details['agreedAmount'] ?? details['agreed_amount']);
    if (agreed != null && agreed > 0) return agreed;
    final service = details['service'];
    if (service is Map) {
      return _toDoubleOrNull(service['price'] ?? service['basePrice']);
    }
    return null;
  }

  void _showProposeTermsDialog() {
    showDialog(
      context: context,
      builder: (_) => _ProposeTermsDialog(
        suggestedAmount: _suggestedAmount(),
        onConfirm: _sendProposeTerms,
      ),
    );
  }

  Future<void> _sendProposeTerms(DateTime scheduledAt, double amount) async {
    try {
      await ApiService.dio
          .post('/chats/${widget.bookingId}/propose-terms', data: {
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        'amount': amount,
      });

      if (_userId != null) {
        _webSocketService.sendMessage(
          widget.bookingId,
          _userId!,
          'Booking confirmed for ${DateFormat('MMM d, h:mm a').format(scheduledAt)} — agreed amount ${amount.toStringAsFixed(0)}.',
          'booking_confirmed',
        );
      }

      await _loadBookingDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Booking terms sent — waiting for deposit')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to confirm booking: $e')),
        );
      }
    }
  }

  Future<void> _confirmDecline() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Decline Booking',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: const Text(
            'Decline this booking request? The customer will be notified.',
            style: TextStyle(fontSize: 14, color: Color(0xFF555555))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep',
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
            child: const Text('Decline',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true) _declineBooking();
  }

  Future<void> _declineBooking() async {
    try {
      await ApiService.dio.post('/chats/${widget.bookingId}/decline');
      if (_userId != null) {
        _webSocketService.sendMessage(
          widget.bookingId,
          _userId!,
          'Sorry, I am unable to take this booking.',
          'booking_declined',
        );
      }
      await _loadBookingDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking declined')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline booking: $e')),
        );
      }
    }
  }

  Future<void> _showPayDepositDialog() async {
    final paid = await showDialog<bool>(
      context: context,
      builder: (_) => PaymentDepositDialog(bookingId: widget.bookingId),
    );
    if (paid == true) {
      await _loadBookingDetails();
      _markMessagesRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deposit paid — booking confirmed')),
        );
      }
    }
  }

  Future<void> _finalizeBooking() async {
    try {
      await ApiService.dio.post('/chats/${widget.bookingId}/finalize');

      _webSocketService.sendMessage(
        widget.bookingId,
        _userId!,
        'Your booking has been confirmed!',
        'booking_confirmed',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking confirmed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to confirm booking: $e')),
        );
      }
    }
  }
}

/// Date/time + agreed-amount editor shown to the professional via "Confirm Booking".
class _ProposeTermsDialog extends StatefulWidget {
  final double? suggestedAmount;
  final void Function(DateTime scheduledAt, double amount) onConfirm;

  const _ProposeTermsDialog({
    required this.suggestedAmount,
    required this.onConfirm,
  });

  @override
  State<_ProposeTermsDialog> createState() => _ProposeTermsDialogState();
}

class _ProposeTermsDialogState extends State<_ProposeTermsDialog> {
  DateTime? _date;
  TimeOfDay? _time;
  late final TextEditingController _amountController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.suggestedAmount != null
          ? widget.suggestedAmount!.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim());
    if (_date == null || _time == null) {
      setState(() => _error = 'Please select a date and time');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount');
      return;
    }
    final scheduledAt = DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );
    widget.onConfirm(scheduledAt, amount);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Confirm Booking',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A))),
            const SizedBox(height: 4),
            const Text(
                'Set the schedule and agreed price — the customer pays the deposit to confirm.',
                style: TextStyle(fontSize: 12, color: Color(0xFF000000))),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined,
                  color: GlayaColors.berry),
              title: Text(
                _date != null
                    ? DateFormat('EEEE, MMM d, y').format(_date!)
                    : 'Select date',
                style: const TextStyle(fontSize: 14),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.schedule_outlined, color: GlayaColors.berry),
              title: Text(
                _time != null ? _time!.format(context) : 'Select time',
                style: const TextStyle(fontSize: 14),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickTime,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Agreed amount',
                prefixText: 'XAF ',
                errorText: _error,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: GlayaColors.berry),
                ),
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 8),
            Text(
              'Deposit is calculated automatically from this amount.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: GlayaColors.berry,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Send to Customer',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
