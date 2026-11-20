import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/providers/notification_provider.dart';
import '../../../../shared/providers/chat_bubble_provider.dart';
import 'booking_chat_dialog.dart';

class NotificationPopup extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const NotificationPopup({super.key, required this.onClose});

  @override
  ConsumerState<NotificationPopup> createState() => _NotificationPopupState();
}

class _NotificationPopupState extends ConsumerState<NotificationPopup> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final response = await ApiService.dio.get('/notifications');
      setState(() => _notifications =
          (response.data['data'] as List).cast<Map<String, dynamic>>());
    } catch (e) {
      // Silently fail for popup
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await ApiService.dio.put('/notifications/read-all');
      ref.read(notificationCountProvider.notifier).refresh();
      await _loadNotifications();
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await ApiService.dio.put('/notifications/$id/read');
      // Refresh the notification count provider
      ref.read(notificationCountProvider.notifier).refresh();
      await _loadNotifications();
    } catch (e) {
      // Silently fail
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      height: 450,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: GlayaColors.vibrantPink.withValues(alpha: 0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                if (_notifications.any((n) => !(n['read'] as bool? ?? true)))
                  TextButton(
                    onPressed: _markAllAsRead,
                    child: const Text(
                      'Mark all',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: GlayaColors.vibrantPink,
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: () {
                    widget.onClose();
                    Navigator.of(context).pop();
                    context.push('/notifications');
                  },
                  child: const Text(
                    'See All',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: GlayaColors.vibrantPink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: GlayaColors.vibrantPink))
                : _notifications.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none,
                                size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              'No notifications',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _notifications.length > 5
                            ? 5
                            : _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          final read = notification['read'] as bool;
                          final createdAt = DateTime.parse(
                              notification['createdAt'] as String);
                          return _NotificationItem(
                            notification: notification,
                            read: read,
                            createdAt: createdAt,
                            onTap: () {
                              final bookingId = notification['payload']
                                  ?['bookingId'] as String?;
                              final type = notification['type'] as String?;
                              final isChat = type?.contains('chat') == true ||
                                  type?.contains('message') == true;
                              if (isChat) {
                                // Restore a dismissed bubble immediately,
                                // then refresh its data in the background
                                final notifier =
                                    ref.read(chatBubbleProvider.notifier);
                                notifier.undismiss();
                                _markAsRead(notification['id'] as String);
                                ApiService.dio.get('/chats/list').then((resp) {
                                  final rooms = (resp.data['data'] as List)
                                      .cast<Map<String, dynamic>>();
                                  notifier.updateFromChatList(rooms);
                                }).catchError((_) {});
                              } else {
                                _markAsRead(notification['id'] as String);
                              }
                              if (bookingId != null) {
                                widget.onClose();
                                // Open chat dialog for chat notifications, navigate for others
                                if (isChat) {
                                  showBookingChatDialog(context, bookingId);
                                } else {
                                  context.push('/bookings/$bookingId');
                                }
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final Map<String, dynamic> notification;
  final bool read;
  final DateTime createdAt;
  final VoidCallback onTap;

  const _NotificationItem({
    required this.notification,
    required this.read,
    required this.createdAt,
    required this.onTap,
  });

  IconData _iconForType(String type) {
    switch (type) {
      case 'booking':
        return Icons.calendar_today;
      case 'payment':
        return Icons.payment;
      case 'chat':
        return Icons.chat;
      case 'alert':
        return Icons.warning;
      case 'reminder':
        return Icons.alarm;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: read ? null : GlayaColors.vibrantPink.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor:
                read ? Colors.grey.shade200 : GlayaColors.vibrantPink,
            child: Icon(
              _iconForType(notification['type'] as String),
              color: read ? Colors.grey : Colors.white,
              size: 18,
            ),
          ),
          title: Text(
            notification['title'] ?? 'Notification',
            style: TextStyle(
              fontSize: 13,
              fontWeight: read ? FontWeight.w500 : FontWeight.w700,
              color: read ? const Color(0xFF666666) : const Color(0xFF1A1A1A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification['body'] ?? '',
                style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM d, h:mm a').format(createdAt),
                style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA)),
              ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
