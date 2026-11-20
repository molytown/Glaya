import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'shared/router/app_router.dart';
import 'shared/services/api_service.dart';
import 'shared/services/config_service.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/colors.dart';
import 'shared/constants/api_constants.dart';
import 'shared/utils/responsive_helper.dart';
import 'ui/app_theme_glaya2.dart';
import 'features/home/controller/location_controller.dart';
import 'shared/widgets/floating_chat_bubble.dart';
import 'shared/widgets/glaya_scroll_behavior.dart';
import 'shared/widgets/booking_chat_dialog.dart';
import 'shared/providers/chat_bubble_provider.dart';
import 'shared/providers/location_provider.dart';
import 'shared/providers/notification_provider.dart';
import 'shared/providers/onboarding_provider.dart';
import 'shared/services/websocket_service.dart';
import 'shared/services/notification_websocket_service.dart';
import 'shared/services/notification_sound_service.dart';
import 'shared/services/storage_service.dart';
import 'features/auth/presentation/providers/auth_notifier.dart';
import 'features/reels/data/models/reel_model.dart';
import 'features/reels/presentation/reel_screen.dart';

// Conditional import for web-specific Google Maps script loading
import 'google_maps_web_loader.dart'
    if (dart.library.io) 'google_maps_stub.dart';
import 'features/home/repository/location_repository.dart';

String _deviceType() {
  if (kIsWeb) return 'web';
  if (defaultTargetPlatform == TargetPlatform.android) return 'android';
  if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
  return 'android'; // Default fallback
}

final fcmTokenProvider = StateProvider<String?>((_) => null);

// Cached FCM token + pending deep-link from a notification tap
String? _cachedFcmToken;
String? pendingNotificationRoute;
String? pendingNotificationBookingId;

Future<void> _registerFcmToken(String? token) async {
  if (token == null || token.isEmpty) return;
  _cachedFcmToken = token;
  try {
    await ApiService.dio.post(
      '/notifications/fcm-token',
      data: {'token': token, 'deviceType': _deviceType()},
    );
  } catch (_) {}
}

// Re-register the cached FCM token — call after login so push works for fresh sessions
Future<void> registerFcmTokenForCurrentUser() async {
  await _registerFcmToken(_cachedFcmToken);
}

Future<void> _setupFCM() async {
  if (kIsWeb) return;

  final messaging = FirebaseMessaging.instance;
  final androidChannel = AndroidNotificationChannel(
    'glaya_channel',
    'Glaya Notifications',
    description: 'Booking and chat notifications',
    importance: Importance.high,
    sound: const RawResourceAndroidNotificationSound('notification'),
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 200, 100, 200]),
    showBadge: true,
  );
  final flutterLocalNotifications = FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  final initializationSettings = InitializationSettings(
    android: androidSettings,
  );
  await flutterLocalNotifications.initialize(initializationSettings);

  await flutterLocalNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(androidChannel);

  await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  final token = await messaging.getToken();
  if (token != null) {
    await _registerFcmToken(token);
  }

  messaging.onTokenRefresh.listen((newToken) async {
    await _registerFcmToken(newToken);
  });

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    // Check if this is a chat message
    final isChat = data['type']?.toString().contains('chat') == true ||
        data['type']?.toString().contains('message') == true;

    // Dedupe against the socket channel — whichever arrives first alerts,
    // the other is skipped for sound/system-notification purposes.
    final notificationId = data['notificationId']?.toString() ?? '';
    final wsService = NotificationWebSocketService.instance;
    final alreadySeen =
        notificationId.isNotEmpty && wsService.wasRecentlySeen(notificationId);
    if (notificationId.isNotEmpty) wsService.markSeen(notificationId);

    // Play the in-app notification sound (foreground)
    if (!alreadySeen) {
      try {
        final userData = await StorageService.getUserData();
        var isProfessional = false;
        if (userData != null && userData.isNotEmpty) {
          final role =
              (jsonDecode(userData) as Map<String, dynamic>)['role'] as String?;
          isProfessional = role == 'professional' || role == 'both';
        }
        // Use message sound for chat, notification sound for others
        if (isChat) {
          await NotificationSoundService.instance.playMessageReceived(
            isProfessional: isProfessional,
          );
        } else {
          await NotificationSoundService.instance.playNotification(
            isProfessional: isProfessional,
          );
        }
      } catch (_) {}
    }

    // Show system notification
    if (!alreadySeen && notification != null) {
      flutterLocalNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            androidChannel.id,
            androidChannel.name,
            channelDescription: androidChannel.description,
            icon: '@mipmap/ic_launcher',
            sound: const RawResourceAndroidNotificationSound('notification'),
            playSound: true,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 200, 100, 200]),
            priority: Priority.high,
            importance: Importance.high,
            showWhen: true,
          ),
        ),
      );
    }

    // Forward into the shared notification stream so the in-app popup and
    // unread badge update through the same path as socket notifications.
    wsService.emitForegroundNotification({
      'id': notificationId.isNotEmpty
          ? notificationId
          : 'fcm-${notification?.hashCode ?? DateTime.now().millisecondsSinceEpoch}',
      'type': data['type']?.toString() ?? 'system',
      'title': notification?.title ?? 'Notification',
      'body': notification?.body ?? '',
      'payload': {
        'bookingId': data['bookingId'] ?? data['booking_id'],
      },
      'createdAt': DateTime.now().toIso8601String(),
    });
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final parsed = _parseNotificationData(message.data);
    if (parsed != null) {
      if (parsed['bookingId'] != null && parsed['isChat'] == true) {
        pendingNotificationBookingId = parsed['bookingId'];
      } else if (parsed['route'] != null) {
        pendingNotificationRoute = parsed['route'];
      }
    }
  });

  // Cold-start notification tap (app launched from terminated state)
  final initialMessage = await messaging.getInitialMessage();
  final initialParsed = initialMessage != null
      ? _parseNotificationData(initialMessage.data)
      : null;
  if (initialParsed != null) {
    if (initialParsed['bookingId'] != null && initialParsed['isChat'] == true) {
      pendingNotificationBookingId = initialParsed['bookingId'];
    } else if (initialParsed['route'] != null) {
      pendingNotificationRoute = initialParsed['route'];
    }
  }
}

// Parse FCM payload data - returns map with 'route', 'bookingId', 'isChat'
Map<String, dynamic>? _parseNotificationData(Map<String, dynamic> data) {
  final explicit = data['route'] as String?;
  if (explicit != null && explicit.isNotEmpty) {
    return {'route': explicit, 'bookingId': null, 'isChat': false};
  }

  final bookingId =
      data['bookingId']?.toString() ?? data['booking_id']?.toString();
  final type = data['type']?.toString() ?? '';
  if (bookingId != null && bookingId.isNotEmpty) {
    if (type.contains('message') || type.contains('chat')) {
      return {'route': null, 'bookingId': bookingId, 'isChat': true};
    }
    return {
      'route': '/bookings/$bookingId',
      'bookingId': null,
      'isChat': false
    };
  }
  return {'route': '/notifications', 'bookingId': null, 'isChat': false};
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mirror framework errors into logcat (print → 'I/flutter' tag) so they can
  // be captured via adb — the default dump only reaches the VM service console.
  // Deduped: repeating fallout (e.g. semantics.parentDataDirty spam) is logged
  // once per unique signature so the FIRST real exception stays visible.
  final seenErrorSignatures = <String>{};
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    try {
      final signature = '${details.exceptionAsString()}|${details.context}';
      if (seenErrorSignatures.add(signature)) {
        final buf = StringBuffer('FLUTTER_ERROR: ');
        buf.writeln(details.exceptionAsString());
        final ctx = details.context;
        if (ctx != null) buf.writeln('context: ${ctx.toStringDeep()}');
        details.informationCollector?.call().forEach((node) {
          buf.writeln(node.toStringDeep(minLevel: DiagnosticLevel.debug));
        });
        final stack = details.stack;
        if (stack != null) buf.writeln(stack);
        final s = buf.toString();
        for (var i = 0; i < s.length; i += 3000) {
          final end = (i + 3000 < s.length) ? i + 3000 : s.length;
          // ignore: avoid_print
          print(s.substring(i, end));
        }
        // First occurrence: let the framework report normally too.
        if (previousOnError != null) {
          previousOnError(details);
        } else {
          FlutterError.presentError(details);
        }
      }
      // Duplicate fallout (e.g. semantics.parentDataDirty spam): swallow it
      // so the console/logcat stays readable and the first real exception
      // isn't buried.
    } catch (_) {}
  };

  // Set platform-specific base URL for mobile devices
  if (!kIsWeb) {
    final deviceType = _deviceType();
    ConfigService().setMobilePlatformConfig(deviceType);
  }

  ApiService.setupInterceptors();

  // Initialize GetX LocationController
  final locationRepository = LocationRepository(
    baseUrl: ApiConstants.baseUrl,
    googleMapApiKey: ApiConstants.googleMapsApiKey,
  );
  Get.put(
    LocationController(locationRepository: locationRepository),
    permanent: true,
  );

  // Restore the cached location BEFORE runApp so the first provider builds
  // are already zone-scoped — avoids a second full data-fetch cycle on launch.
  LocationNotifier.seedState = await readCachedLocation();

  // Render the app immediately — config fetch, Firebase and FCM setup run in
  // the background so they don't block the first frame.
  runApp(const ProviderScope(child: GlayaApp()));

  unawaited(_bootstrap());
}

/// Heavy startup work that doesn't need to finish before the first frame:
/// remote config (Maps key), Firebase init and FCM registration.
Future<void> _bootstrap() async {
  // Load configuration from backend (with fallback on failure)
  try {
    await ConfigService().loadConfig();
  } catch (e) {
    // If config loading fails, use fallback values
    ConfigService().setFallbackConfig();
  }

  // Update Dio base URL after config is loaded
  ApiService.updateBaseUrl();

  // Load Google Maps script dynamically after config is loaded
  loadGoogleMapsScript(ConfigService().googleMapsApiKey);

  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      await _setupFCM();
    } catch (e) {
      print('[BOOTSTRAP] Firebase/FCM init failed: $e');
    }
  }
}

class GlayaApp extends ConsumerWidget {
  const GlayaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final user = ref.watch(authNotifierProvider).valueOrNull;

    return MaterialApp.router(
      title: 'Glaya',
      debugShowCheckedModeBanner: false,
      theme: GlayaTheme2.theme,
      darkTheme: GlayaAppTheme.darkTheme,
      themeMode: ThemeMode.light,
      scrollBehavior: const GlayaScrollBehavior(),
      routerConfig: router,
      builder: (context, child) {
        return _AppWithBubble(user: user, child: child!);
      },
    );
  }
}

class _AppWithBubble extends ConsumerStatefulWidget {
  final Widget child;
  final dynamic user;

  const _AppWithBubble({required this.child, required this.user});

  @override
  ConsumerState<_AppWithBubble> createState() => _AppWithBubbleState();
}

class _AppWithBubbleState extends ConsumerState<_AppWithBubble> {
  final _webSocketService = WebSocketService();
  final _notificationService = NotificationWebSocketService.instance;
  String? _userId;
  bool _listenersAttached = false;
  final Set<String> _recentPopupIds = {};

  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
  }

  @override
  void didUpdateWidget(_AppWithBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // User logged in mid-session → connect notification services + register FCM
    final newId = widget.user?.id?.toString();
    if (newId != null && newId != _userId) {
      _initializeWebSocket();
    }
  }

  Future<void> _initializeWebSocket() async {
    // Prefer live user id, fall back to stored one (cold start)
    final liveId = widget.user?.id?.toString();
    _userId = liveId ?? await StorageService.getUserId();
    if (_userId == null) return;

    _webSocketService.connect();
    _notificationService.connect(_userId!);

    // Register FCM token now that we have an authenticated session
    registerFcmTokenForCurrentUser();

    if (_listenersAttached) return;
    _listenersAttached = true;

    // Listen for new booking events
    _webSocketService.newBookingStream.listen((data) {
      ref.read(chatBubbleProvider.notifier).updateFromNewBooking(data);
    });

    // Listen for admin message events
    _webSocketService.adminMessageStream.listen((data) {
      ref.read(chatBubbleProvider.notifier).updateFromNewMessage(data);
    });

    // Listen for professional message events (support chat)
    _webSocketService.professionalMessageStream.listen((data) {
      ref.read(chatBubbleProvider.notifier).updateFromNewMessage(data);
    });

    // Join support room for this user
    _webSocketService.joinSupportRoom(_userId!);

    // Listen for new in-app notifications (socket + foreground FCM)
    _notificationService.notificationStream.listen(_onIncomingNotification);

    // Listen for booking control events
    _webSocketService.bookingControlStream.listen((data) {
      // Handle booking control events (time confirmation, deposit invoice, etc.)
      // These might need to update the chat bubble or trigger other UI updates
      final eventType = data['type'] as String?;
      if (eventType == 'deposit_invoice' || eventType == 'time_confirmed') {
        ref.read(chatBubbleProvider.notifier).updateFromNewMessage(data);
      }
      // Handle onboarding messages
      if (eventType == 'onboarding_message') {
        final content = data['content'] as String?;
        if (content != null) {
          ref
              .read(chatBubbleProvider.notifier)
              .updateFromOnboarding(content, true);
        }
      }
    });

    // Check for existing onboarding messages
    _checkOnboardingMessages();
  }

  void _onIncomingNotification(Map<String, dynamic> data) {
    // Dedupe popups — socket and FCM can both deliver the same notification
    final id = (data['id'] ?? data['_id'])?.toString() ?? '';
    if (id.isNotEmpty) {
      if (_recentPopupIds.contains(id)) return;
      _recentPopupIds.add(id);
      if (_recentPopupIds.length > 50) {
        _recentPopupIds.remove(_recentPopupIds.first);
      }
    }
    if (!mounted) return;
    ref.read(notificationCountProvider.notifier).refresh();
    _showNotificationAlert(data);
  }

  void _showNotificationAlert(Map<String, dynamic> data) {
    // This widget sits above the Navigator (MaterialApp.router builder), so
    // its own context can't show dialogs — use the router's navigator context.
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) return;

    final title = data['title']?.toString() ?? 'Notification';
    final body = data['body']?.toString() ?? '';
    final type = data['type']?.toString() ?? '';
    final isChat = type.contains('chat') || type.contains('message');
    final payload = data['payload'];
    final payloadMap = payload is Map ? payload : const {};
    final bookingId =
        payloadMap['bookingId']?.toString() ?? data['bookingId']?.toString();
    final reelId = payloadMap['reelId']?.toString();
    final notificationId = (data['id'] ?? data['_id'])?.toString() ?? '';

    showDialog(
      context: navContext,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.notifications_active,
                color: GlayaColors.vibrantPink, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        content: Text(body, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Dismiss'),
          ),
          if (reelId != null && reelId.isNotEmpty)
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                if (notificationId.isNotEmpty) {
                  try {
                    await ApiService.dio
                        .put('/notifications/$notificationId/read');
                  } catch (_) {}
                }
                if (!mounted || !navContext.mounted) return;
                ref.read(notificationCountProvider.notifier).refresh();
                try {
                  final res = await ApiService.dio.get('/reels/$reelId');
                  final reel =
                      Reel.fromJson(res.data['data'] as Map<String, dynamic>);
                  if (!navContext.mounted) return;
                  if (reel.isPhoto) {
                    final url = ConfigService().replaceLocalhost(reel.videoUrl);
                    showDialog(
                      context: navContext,
                      builder: (ctx) => Dialog(
                        backgroundColor: Color(0xFF000000),
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
                                      size: 64),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 24,
                              right: 16,
                              child: IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    Navigator.of(navContext).push(MaterialPageRoute(
                      builder: (_) =>
                          ReelScreen(reels: [reel], initialIndex: 0),
                    ));
                  }
                } catch (_) {}
              },
              child: const Text('View'),
            )
          else if (bookingId != null && bookingId.isNotEmpty)
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                if (notificationId.isNotEmpty) {
                  try {
                    await ApiService.dio
                        .put('/notifications/$notificationId/read');
                  } catch (_) {}
                }
                if (!mounted || !navContext.mounted) return;
                ref.read(notificationCountProvider.notifier).refresh();
                if (isChat) {
                  // Restore a dismissed chat bubble for chat notifications
                  final notifier = ref.read(chatBubbleProvider.notifier);
                  notifier.undismiss();
                  ApiService.dio.get('/chats/list').then((resp) {
                    final rooms = (resp.data['data'] as List)
                        .cast<Map<String, dynamic>>();
                    notifier.updateFromChatList(rooms);
                  }).catchError((_) {});
                  showBookingChatDialog(navContext, bookingId);
                } else {
                  navContext.push('/bookings/$bookingId');
                }
              },
              child: const Text('View'),
            ),
        ],
      ),
    );
  }

  Future<void> _checkOnboardingMessages() async {
    try {
      await ref.read(onboardingProvider.notifier).loadMessages();
      final onboardingState = ref.read(onboardingProvider);
      if (onboardingState.hasUnreadMessages &&
          onboardingState.messages.isNotEmpty) {
        final lastMessage = onboardingState.messages.last;
        ref
            .read(chatBubbleProvider.notifier)
            .updateFromOnboarding(lastMessage.content, true);
      }
    } catch (e) {
      // Silently fail if onboarding check fails
    }
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Handle deep-link from a tapped push notification
    final pendingRoute = pendingNotificationRoute;
    final pendingBookingId = pendingNotificationBookingId;
    if (pendingRoute != null && widget.user != null) {
      pendingNotificationRoute = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          ref.read(routerProvider).push(pendingRoute);
        } catch (_) {}
      });
    } else if (pendingBookingId != null && widget.user != null) {
      pendingNotificationBookingId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final navContext = rootNavigatorKey.currentContext;
          if (navContext != null) {
            showBookingChatDialog(navContext, pendingBookingId);
          }
        } catch (_) {}
      });
    }

    if (widget.user == null) return widget.child;

    final isDesktop = ResponsiveHelper.isDesktop(context);
    if (isDesktop) return widget.child;

    return Stack(
      children: [
        widget.child,
        const Positioned.fill(child: FloatingChatBubble()),
      ],
    );
  }
}
