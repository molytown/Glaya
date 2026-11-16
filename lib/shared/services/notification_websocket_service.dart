import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'config_service.dart';
import 'notification_sound_service.dart';
import 'storage_service.dart';

class NotificationWebSocketService {
  static NotificationWebSocketService? _instance;
  static NotificationWebSocketService get instance =>
      _instance ??= NotificationWebSocketService._();

  NotificationWebSocketService._();

  IO.Socket? _socket;
  final _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _unreadCountController = StreamController<int>.broadcast();
  final _professionalMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  String? _userId;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final Set<String> _recentNotificationIds = {}; // For deduplication

  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationController.stream;
  Stream<int> get unreadCountStream => _unreadCountController.stream;
  Stream<Map<String, dynamic>> get professionalMessageStream =>
      _professionalMessageController.stream;

  /// Forward a foreground FCM message into the notification stream so the UI
  /// can show the popup / refresh the badge through a single code path.
  void emitForegroundNotification(Map<String, dynamic> data) {
    _notificationController.add(data);
  }

  /// Shared dedupe set — used by both the socket and FCM paths so the same
  /// notification doesn't alert twice.
  bool wasRecentlySeen(String id) => _recentNotificationIds.contains(id);

  void markSeen(String id) {
    _recentNotificationIds.add(id);
    if (_recentNotificationIds.length > 50) {
      _recentNotificationIds.remove(_recentNotificationIds.first);
    }
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );
    await _notifications.initialize(initializationSettings);
  }

  Future<void> _playNotificationSound(
    String notificationId, {
    String? title,
    String? body,
  }) async {
    // Deduplication: don't play sound if we've seen this notification recently
    if (_recentNotificationIds.contains(notificationId)) {
      print('Notification $notificationId already processed, skipping sound');
      return;
    }

    _recentNotificationIds.add(notificationId);

    // Clean up old notification IDs (keep only last 50)
    if (_recentNotificationIds.length > 50) {
      _recentNotificationIds.remove(_recentNotificationIds.first);
    }

    // Play the in-app sound immediately (works in foreground)
    _playInAppSound();

    if (Platform.isAndroid) {
      final androidDetails = AndroidNotificationDetails(
        'glaya_channel',
        'Glaya Notifications',
        channelDescription: 'Booking and chat notifications',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notification'),
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 200, 100, 200]),
        priority: Priority.high,
        showWhen: true,
      );
      final notificationDetails = NotificationDetails(android: androidDetails);
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title ?? 'New Notification',
        body ?? 'You have a new notification',
        notificationDetails,
      );
    }
  }

  Future<void> _playInAppSound() async {
    try {
      final userData = await StorageService.getUserData();
      var isProfessional = false;
      if (userData != null && userData.isNotEmpty) {
        final role =
            (jsonDecode(userData) as Map<String, dynamic>)['role'] as String?;
        isProfessional = role == 'professional' || role == 'both';
      }
      await NotificationSoundService.instance
          .playNotification(isProfessional: isProfessional);
    } catch (_) {}
  }

  void connect(String userId) async {
    if (_socket != null && _socket!.connected) {
      if (_userId == userId) return;
      disconnect();
    }

    _userId = userId;
    await _initializeNotifications();

    _socket = IO.io(
      ConfigService().socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      print('Notification WebSocket connected');
      _socket!.emit('join', {'room': 'user:$userId'});
      _socket!.emit('join', {'room': 'support:$userId'});
    });

    _socket!.on('notification:new', (data) {
      print('New notification received: $data');
      final notificationData = data as Map<String, dynamic>;
      _notificationController.add(notificationData);

      // Extract notification ID for deduplication
      final notificationId =
          notificationData['id']?.toString() ??
          notificationData['_id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();

      _playNotificationSound(
        notificationId,
        title: notificationData['title'] as String?,
        body: notificationData['body'] as String?,
      );
    });

    _socket!.on('notification:unread_count', (data) {
      print('Unread count updated: $data');
      _unreadCountController.add(data['count'] as int);
    });

    _socket!.on('professional:message', (data) {
      print('Professional message received: $data');
      final messageData = data as Map<String, dynamic>;
      _professionalMessageController.add(messageData);
    });

    _socket!.onDisconnect((_) {
      print('Notification WebSocket disconnected');
    });

    _socket!.onError((error) {
      print('Notification WebSocket error: $error');
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _userId = null;
  }

  void dispose() {
    disconnect();
    _notificationController.close();
    _unreadCountController.close();
    _professionalMessageController.close();
  }
}

final notificationWebSocketServiceProvider =
    Provider<NotificationWebSocketService>((ref) {
      return NotificationWebSocketService.instance;
    });
