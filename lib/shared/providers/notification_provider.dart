import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/notification_websocket_service.dart';

final unreadCountProvider = StateProvider<int>((ref) => 0);

final unreadCountAsyncProvider = FutureProvider<int>((ref) async {
  try {
    final response = await ApiService.dio.get('/notifications/unread-count');
    return response.data['data']['count'] as int;
  } catch (e) {
    return 0;
  }
});

class NotificationNotifier extends StateNotifier<int> {
  NotificationNotifier(this.ref) : super(0) {
    _init();
  }

  final Ref ref;

  void _init() {
    final wsService = ref.read(notificationWebSocketServiceProvider);

    // Listen to WebSocket updates
    wsService.unreadCountStream.listen((count) {
      state = count;
    });

    // New notification arrived → refresh the badge count from the server
    wsService.notificationStream.listen((_) {
      refresh();
    });

    // Load the current count on startup
    refresh();
  }

  Future<void> refresh() async {
    try {
      final response = await ApiService.dio.get('/notifications/unread-count');
      state = response.data['data']['count'] as int;
    } catch (e) {
      // Keep current state on error
    }
  }
}

final notificationCountProvider = StateNotifierProvider<NotificationNotifier, int>((ref) {
  return NotificationNotifier(ref);
});
