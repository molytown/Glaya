import 'package:flutter/material.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../router/app_router.dart';
import '../utils/responsive_helper.dart';

/// Non-modal floating chat panel for desktop/tablet.
///
/// Unlike [showBookingChatDialog] (a modal route), this inserts an
/// [OverlayEntry] above the app so the page behind stays interactive.
/// Only one chat can be open at a time — opening another booking swaps
/// the panel content.
class FloatingChatOverlay {
  FloatingChatOverlay._();

  static OverlayEntry? _entry;
  static String? _bookingId;

  static bool get isOpen => _entry != null;

  /// Shows [bookingId] in the floating panel. No-op if already open
  /// for the same booking.
  static void show(String bookingId) {
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    if (_entry != null) {
      if (_bookingId == bookingId) return;
      _bookingId = bookingId;
      _entry!.markNeedsBuild();
      return;
    }

    _bookingId = bookingId;
    _entry = OverlayEntry(
      builder: (_) => _FloatingChatPanel(bookingId: _bookingId!),
    );
    overlay.insert(_entry!);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
    _bookingId = null;
  }
}

class _FloatingChatPanel extends StatelessWidget {
  final String bookingId;

  const _FloatingChatPanel({required this.bookingId});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final screen = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Empty areas of the Stack don't hit-test, so taps pass through
        // to the page underneath — only the panel itself is interactive.
        Positioned(
          right: 24,
          bottom: 24,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: isDesktop ? 450 : 420,
              height: screen.height * (isDesktop ? 0.7 : 0.65),
              constraints: BoxConstraints(
                minWidth: isDesktop ? 350 : 320,
                maxWidth: isDesktop ? 500 : 460,
                minHeight: 380,
                maxHeight: isDesktop ? 700 : 640,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF000000).withValues(alpha: 0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ChatScreen(
                  bookingId: bookingId,
                  embedded: true,
                  onClose: FloatingChatOverlay.hide,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
