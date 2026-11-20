import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../providers/notification_provider.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../../features/reels/data/models/reel_model.dart';
import '../../features/reels/presentation/reel_screen.dart';
import '../services/config_service.dart';
import '../providers/chat_bubble_provider.dart';

/// Desktop notification dropdown widget — appears below the notification icon
/// with a scrollable list and "Mark all as read" button.
class NotificationDropdown extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const NotificationDropdown({super.key, required this.onClose});

  @override
  ConsumerState<NotificationDropdown> createState() =>
      _NotificationDropdownState();
}

class _NotificationDropdownState extends ConsumerState<NotificationDropdown> {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load notifications: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await ApiService.dio.put('/notifications/$id/read');
      ref.read(notificationCountProvider.notifier).refresh();
      await _loadNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as read: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await ApiService.dio.put('/notifications/read-all');
      ref.read(notificationCountProvider.notifier).refresh();
      await _loadNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to mark all as read: ${e.toString()}')),
        );
      }
    }
  }

  IconData _iconForType(String type) {
    if (type.contains('booking')) return Icons.calendar_today;
    if (type.contains('chat') || type.contains('message')) return Icons.chat_bubble;
    if (type.contains('reel')) return Icons.play_circle;
    if (type.contains('review')) return Icons.star;
    if (type.contains('offer')) return Icons.local_offer;
    return Icons.notifications;
  }

  Future<void> _openReelFromNotification(String reelId) async {
    try {
      final res = await ApiService.dio.get('/reels/$reelId');
      final reel = Reel.fromJson(res.data['data'] as Map<String, dynamic>);
      if (!mounted) return;
      if (reel.isPhoto) {
        final url = ConfigService().replaceLocalhost(reel.videoUrl);
        showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              children: [
                InteractiveViewer(
                  child: Center(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 64,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReelScreen(
                reels: [reel],
                initialIndex: 0,
                engagement: const {},
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open reel: ${e.toString()}')),
        );
      }
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final type = notification['type'] as String?;
    final isChat = type?.contains('chat') == true ||
        type?.contains('message') == true;
    if (isChat) {
      final notifier = ref.read(chatBubbleProvider.notifier);
      notifier.undismiss();
      ApiService.dio.get('/chats/list').then((resp) {
        final rooms = (resp.data['data'] as List)
            .cast<Map<String, dynamic>>();
        notifier.updateFromChatList(rooms);
      }).catchError((_) {});
    }
    _markAsRead(notification['id'] as String);
    if (mounted) {
      final payload =
          notification['payload'] as Map<String, dynamic>?;
      final reelId = payload?['reelId'] as String?;
      final bookingId = payload?['bookingId'] as String?;
      if (reelId != null) {
        _openReelFromNotification(reelId);
      } else if (bookingId != null) {
        context.push('/bookings/$bookingId');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications
        .where((n) => !(n['read'] as bool? ?? false))
        .length;

    return Container(
      width: 380,
      constraints: const BoxConstraints(maxHeight: 450),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
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
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                if (unreadCount > 0)
                  TextButton(
                    onPressed: _markAllAsRead,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: GlayaColors.berry.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: GlayaColors.berry,
                      ),
                    ),
                  ),
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
                : _notifications.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.notifications_outlined,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No notifications yet',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          indent: 12,
                          endIndent: 12,
                        ),
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          final read = notification['read'] as bool? ?? false;
                          final createdAt =
                              DateTime.parse(notification['createdAt'] as String);
                          return InkWell(
                            onTap: () => _handleNotificationTap(notification),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: read
                                    ? null
                                    : GlayaColors.berry.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: GlayaColors.berry,
                                    child: Icon(
                                      _iconForType(
                                          notification['type'] as String? ?? ''),
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notification['title'] ??
                                              'Notification',
                                          style: GlayaTextStyles.titleMedium(
                                            color: read
                                                ? GlayaColors.textSecondary
                                                : GlayaColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          notification['body'] ?? '',
                                          style: GlayaTextStyles.bodySmall(),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat('MMM d, h:mm a')
                                              .format(createdAt),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF9CA3AF),
                                          ),
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
