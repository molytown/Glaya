import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/providers/notification_provider.dart';
import '../../../../shared/providers/chat_bubble_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/text_styles.dart';
import '../../reels/data/models/reel_model.dart';
import '../../reels/presentation/reel_screen.dart';
import '../../../../shared/services/config_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
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
      setState(() => _notifications = (response.data['data'] as List).cast<Map<String, dynamic>>());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load notifications: ${e.toString()}')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                final read = notification['read'] as bool;
                final createdAt = DateTime.parse(notification['createdAt'] as String);
                return ListTile(
                  tileColor: read ? null : GlayaColors.berry.withOpacity(0.05),
                  leading: CircleAvatar(
                    backgroundColor: GlayaColors.berry,
                    child: Icon(
                      _iconForType(notification['type'] as String),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    notification['title'] ?? 'Notification',
                    style: GlayaTextStyles.titleMedium(
                      color: read ? GlayaColors.textSecondary : GlayaColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '${notification['body'] ?? ''}\n${DateFormat('MMM d, h:mm a').format(createdAt)}',
                    style: GlayaTextStyles.bodySmall(),
                  ),
                  isThreeLine: true,
                  onTap: () {
                    final type = notification['type'] as String?;
                    final isChat = type?.contains('chat') == true ||
                        type?.contains('message') == true;
                    if (isChat) {
                      // Restore a dismissed bubble immediately,
                      // then refresh its data in the background
                      final notifier =
                          ref.read(chatBubbleProvider.notifier);
                      notifier.undismiss();
                      ApiService.dio.get('/chats/list').then((resp) {
                        final rooms = (resp.data['data'] as List)
                            .cast<Map<String, dynamic>>();
                        notifier.updateFromChatList(rooms);
                      }).catchError((_) {});
                    }
                    _markAsRead(notification['id'] as String);
                    if (mounted) {
                      final payload = notification['payload'] as Map<String, dynamic>?;
                      final reelId = payload?['reelId'] as String?;
                      final bookingId = payload?['bookingId'] as String?;
                      if (reelId != null) {
                        _openReelFromNotification(reelId);
                      } else if (bookingId != null) {
                        context.push('/bookings/$bookingId');
                      }
                    }
                  },
                );
              },
            ),
    );
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
                  top: 24,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(_),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReelScreen(reels: [reel], initialIndex: 0),
          ),
        );
      }
    } catch (_) {}
  }

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
}
