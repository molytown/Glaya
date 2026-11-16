import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/config_service.dart';
import '../services/api_service.dart';
import '../providers/chat_bubble_provider.dart';
import '../router/app_router.dart';
import 'booking_chat_dialog.dart';
import '../theme/colors.dart';

class FloatingChatBubble extends ConsumerStatefulWidget {
  const FloatingChatBubble({super.key});

  @override
  ConsumerState<FloatingChatBubble> createState() => _FloatingChatBubbleState();
}

class _FloatingChatBubbleState extends ConsumerState<FloatingChatBubble> 
    with SingleTickerProviderStateMixin {
  static const double _bubbleSize = 64;
  late AnimationController _popupController;
  late Animation<double> _popupAnimation;
  Offset? _position;
  bool _dragging = false;
  bool _overTrash = false;
  
  @override
  void initState() {
    super.initState();
    _popupController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _popupAnimation = CurvedAnimation(
      parent: _popupController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _popupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bubbleState = ref.watch(chatBubbleProvider);

    // Handle popup animation
    if (bubbleState.showPopup && !_popupController.isCompleted) {
      _popupController.forward();
    } else if (!bubbleState.showPopup && _popupController.isCompleted) {
      _popupController.reverse();
    }

    if (!bubbleState.isVisible || bubbleState.dismissed) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final position = _position ?? _defaultPosition(size);
        return Stack(
          children: [
            // Trash drop zone — only visible while dragging
            if (_dragging)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(child: _buildTrashZone()),
              ),
            // Main bubble (draggable)
            Positioned(
              left: position.dx,
              top: position.dy,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: () => _handleTap(ref, bubbleState.latestBookingId),
                    onPanStart: (_) => setState(() {
                      _dragging = true;
                      _overTrash = false;
                    }),
                    onPanUpdate: (details) => _onPanUpdate(details, size),
                    onPanEnd: (_) => _onPanEnd(),
                    onPanCancel: () => setState(() {
                      _dragging = false;
                      _overTrash = false;
                    }),
                    child: Opacity(
                      opacity: _dragging ? 0.85 : 1.0,
                      child: _buildBubble(bubbleState),
                    ),
                  ),
                  // Popup notification banner
                  if (bubbleState.showPopup && bubbleState.popupMessage != null)
                    Positioned(
                      right: 75,
                      bottom: 50,
                      child: AnimatedBuilder(
                        animation: _popupAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _popupAnimation.value,
                            child: Opacity(
                              opacity: _popupAnimation.value,
                              child: _buildPopupBanner(bubbleState),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Offset _defaultPosition(Size size) {
    // Matches the original fixed spot: right 16, bottom 100
    return Offset(
      size.width - 16 - _bubbleSize,
      size.height - 100 - _bubbleSize,
    );
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    final current = _position ?? _defaultPosition(size);
    final next = current + details.delta;
    final clamped = Offset(
      next.dx.clamp(0.0, size.width - _bubbleSize),
      next.dy.clamp(0.0, size.height - _bubbleSize),
    );
    setState(() {
      _position = clamped;
      _overTrash = _isOverTrash(clamped, size);
    });
  }

  void _onPanEnd() {
    final wasOverTrash = _overTrash;
    setState(() {
      _dragging = false;
      _overTrash = false;
    });
    if (wasOverTrash) {
      ref.read(chatBubbleProvider.notifier).dismiss();
    }
  }

  bool _isOverTrash(Offset position, Size size) {
    final bubbleCenter = position + const Offset(_bubbleSize / 2, _bubbleSize / 2);
    final trashCenter = Offset(size.width / 2, size.height - 62);
    return (bubbleCenter - trashCenter).distance < 70;
  }

  Widget _buildTrashZone() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: _overTrash ? Colors.red : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: _overTrash ? Colors.red : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.close,
            color: _overTrash ? Colors.white : Colors.red,
            size: 36,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Remove',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBubble(ChatBubbleState bubbleState) {
    return Container(
      width: _bubbleSize,
      height: _bubbleSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: GlayaColors.berry.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Profile photo or Glaya logo
          CircleAvatar(
            radius: 32,
            backgroundColor: GlayaColors.berry.withValues(alpha: 0.1),
            backgroundImage: _getBubbleImage(bubbleState),
            child: _getBubbleIcon(bubbleState),
          ),
          // Unread count badge
          if (bubbleState.unreadCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: GlayaColors.vibrantPink,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  bubbleState.unreadCount > 9 ? '9+' : bubbleState.unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPopupBanner(ChatBubbleState state) {
    return GestureDetector(
      onTap: () {
        ref.read(chatBubbleProvider.notifier).dismissPopup();
        _handleTap(ref, state.latestBookingId!);
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sender avatar
            CircleAvatar(
              radius: 16,
              backgroundColor: GlayaColors.berry.withValues(alpha: 0.1),
              backgroundImage: _getBubbleImage(state),
              child: _getBubbleIcon(state),
            ),
            const SizedBox(width: 8),
            // Message preview
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.latestSenderName ?? 'Admin',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: GlayaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    state.popupMessage ?? '',
                    style: const TextStyle(
                      fontSize: 11,
                      color: GlayaColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Dismiss button
            GestureDetector(
              onTap: () => ref.read(chatBubbleProvider.notifier).dismissPopup(),
              child: const Icon(Icons.close, size: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider? _getBubbleImage(ChatBubbleState state) {
    // Use Glaya logo for admin/support/system, otherwise use sender's photo
    if (state.senderType == 'admin' || state.senderType == 'support' || state.senderType == 'system') {
      return const AssetImage('assets/logo.png');
    }
    
    if (state.latestSenderPhoto != null && state.latestSenderPhoto!.isNotEmpty) {
      return NetworkImage(ConfigService().replaceLocalhost(state.latestSenderPhoto!));
    }
    
    return null;
  }

  Widget? _getBubbleIcon(ChatBubbleState state) {
    // Show icon if no image available
    if (state.latestSenderPhoto == null || state.latestSenderPhoto!.isEmpty) {
      if (state.senderType == 'admin' || state.senderType == 'support' || state.senderType == 'system') {
        return Image.asset('assets/logo.png', fit: BoxFit.cover);
      }
      
      return Text(
        (state.latestSenderName ?? '?')[0].toUpperCase(),
        style: const TextStyle(
          color: GlayaColors.berry,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      );
    }
    
    return null;
  }

  void _handleTap(WidgetRef ref, String? bookingId) {
    final bubbleState = ref.read(chatBubbleProvider);

    // Mark as read when opening chat — persist server-side so the count
    // doesn't come back on the chat list / next app start.
    if (bookingId != null) {
      ApiService.dio.put('/chat/$bookingId/read').then((_) async {
        try {
          final resp = await ApiService.dio.get('/chats/list');
          final rooms =
              (resp.data['data'] as List).cast<Map<String, dynamic>>();
          ref.read(chatBubbleProvider.notifier).updateFromChatList(rooms);
        } catch (_) {}
      }).catchError((_) {});
    }
    ref.read(chatBubbleProvider.notifier).markAsRead();
    
    // This widget lives in MaterialApp.router's `builder`, above the
    // Navigator — use the router's navigator context for navigation.
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) return;

    // Navigate to onboarding chat if there are onboarding messages
    if (bubbleState.hasOnboardingMessages) {
      navContext.push('/onboarding');
    } else if (bookingId != null) {
      // Navigate to chat screen
      showBookingChatDialog(navContext, bookingId);
    }
  }
}
