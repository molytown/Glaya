import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../widgets/booking_chat_dialog.dart';

/// Desktop messages dropdown widget — appears below the messages icon
/// with a scrollable list of conversations.
class MessagesDropdown extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const MessagesDropdown({super.key, required this.onClose});

  @override
  ConsumerState<MessagesDropdown> createState() =>
      _MessagesDropdownState();
}

class _MessagesDropdownState extends ConsumerState<MessagesDropdown> {
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final response = await ApiService.dio.get('/chats/list');
      setState(() => _messages =
          (response.data['data'] as List).cast<Map<String, dynamic>>());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load messages: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(dt);
  }

  Color _getSenderColor(Map<String, dynamic>? message) {
    if (message == null) return const Color(0xFF000000);
    final type = message['messageType'] as String?;
    if (type == 'booking') return const Color(0xFFE91E8C);
    if (type == 'support') {
      final senderType = message['senderType'] as String?;
      if (senderType == 'admin') return const Color(0xFFF44336);
      return const Color(0xFF4CAF50);
    }
    if (type == 'system') return const Color(0xFF000000);
    return const Color(0xFF000000);
  }

  void _handleMessageTap(Map<String, dynamic> message) {
    // /chats/list returns rooms, not messages — messageType lives on
    // lastMessage, so gate on bookingId like ChatListScreen does.
    final bookingId = message['bookingId'] ?? message['booking_id'];
    if (bookingId != null) {
      showBookingChatDialog(context, bookingId.toString());
    } else {
      final type = message['messageType'] as String?;
      if (type == 'support') {
        // Support chat - navigate to support chat route
        context.push('/support/chat');
      } else if (type == 'system') {
        context.push('/onboarding');
      }
    }
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      constraints: const BoxConstraints(maxHeight: 450),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF000000).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: const Color(0xFFE5E7EB)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Body
          Flexible(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _messages.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Chat rooms open when a booking is accepted',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        itemCount: _messages.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          indent: 12,
                          endIndent: 12,
                        ),
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final other = message['otherUser'] as Map<String, dynamic>?;
                          final last = message['lastMessage'] as Map<String, dynamic>?;
                          final unread = message['unreadCount'] as int? ?? 0;
                          final scheduledAt =
                              DateTime.tryParse((message['scheduledAt'] ?? '').toString());
                          final timeStr = last != null
                              ? _formatTime(DateTime.tryParse(last['created_at'] ?? ''))
                              : (scheduledAt != null
                                  ? DateFormat('MMM d').format(scheduledAt)
                                  : '');
                          final otherName = other?['name'] as String? ?? 'Unknown';
                          final otherPhoto = other?['photoUrl'] as String? ?? other?['photo_url'] as String?;

                          return InkWell(
                            onTap: () => _handleMessageTap(message),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: unread > 0
                                    ? GlayaColors.berry.withValues(alpha: 0.05)
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: _getSenderColor(message).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: otherPhoto != null
                                        ? ClipOval(
                                            child: Image.network(
                                              otherPhoto,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Icon(
                                                Icons.person,
                                                color: _getSenderColor(message),
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            Icons.person,
                                            color: _getSenderColor(message),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                otherName,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1A1A1A),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              timeStr,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF9CA3AF),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                last?['text'] as String? ?? 'No messages yet',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: unread > 0
                                                      ? const Color(0xFF1A1A1A)
                                                      : const Color(0xFF6B7280),
                                                  fontWeight: unread > 0
                                                      ? FontWeight.w500
                                                      : FontWeight.normal,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (unread > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: GlayaColors.berry,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  unread > 99 ? '99+' : '$unread',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
