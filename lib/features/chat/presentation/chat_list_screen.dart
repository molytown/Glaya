import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import '../../../../shared/widgets/booking_chat_dialog.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/config_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../auth/presentation/providers/auth_notifier.dart';
import '../../../../shared/widgets/bottom_nav.dart';
import '../../../../shared/providers/chat_bubble_provider.dart';

final chatListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final resp = await ApiService.dio.get('/chats/list');
  final data = resp.data['data'] as List<dynamic>;
  final chatRooms = data.cast<Map<String, dynamic>>();

  // Update chat bubble state with latest conversation
  Future.microtask(() {
    ref.read(chatBubbleProvider.notifier).updateFromChatList(chatRooms);
  });

  return chatRooms;
});

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatListAsync = ref.watch(chatListProvider);
    final user = ref.watch(authNotifierProvider).valueOrNull;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: GlayaColors.berry,
        foregroundColor: Colors.white,
        title: const Text('Messages',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: chatListAsync.when(
        data: (rooms) {
          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('No conversations yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('Chat rooms open when a booking is accepted',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(chatListProvider.future),
            child: ListView.separated(
              itemCount: rooms.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final room = rooms[i];
                final other = room['otherUser'] as Map<String, dynamic>?;
                final last = room['lastMessage'] as Map<String, dynamic>?;
                final unread = room['unreadCount'] as int? ?? 0;
                final scheduledAt =
                    DateTime.tryParse((room['scheduledAt'] ?? '').toString());
                final timeStr = last != null
                    ? _formatTime(DateTime.tryParse(last['created_at'] ?? ''))
                    : (scheduledAt != null
                        ? DateFormat('MMM d').format(scheduledAt)
                        : '');

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: GlayaColors.berry.withValues(alpha: 0.15),
                    backgroundImage: other?['photoUrl'] != null
                        ? NetworkImage(ConfigService()
                            .replaceLocalhost(other!['photoUrl'] as String))
                        : null,
                    child: other?['photoUrl'] == null
                        ? Text(
                            ((other?['name'] as String?) ?? '?')[0]
                                .toUpperCase(),
                            style: const TextStyle(
                              color: GlayaColors.berry,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          )
                        : null,
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          other?['name'] as String? ?? 'Unknown',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(timeStr,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room['serviceName'] as String? ?? '',
                        style: const TextStyle(
                            fontSize: 12,
                            color: GlayaColors.berry,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        last?['content'] as String? ?? 'No messages yet',
                        style: TextStyle(
                          fontSize: 13,
                          color: unread > 0 ? Color(0xFF000000) : Colors.grey[600],
                          fontWeight:
                              unread > 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  trailing: unread > 0
                      ? Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                              color: GlayaColors.berry, shape: BoxShape.circle),
                          child: Center(
                            child: Text(
                              unread > 9 ? '9+' : unread.toString(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      : null,
                  onTap: () {
                    final bookingId = room['bookingId'] as String?;
                    if (bookingId != null) {
                      showBookingChatDialog(context, bookingId);
                    }
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Failed to load messages',
                  style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.refresh(chatListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          GlayaBottomNav(currentIndex: 3, userRole: user?.role),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat('h:mm a').format(dt);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('MMM d').format(dt);
  }
}
