import 'package:flutter/material.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../utils/responsive_helper.dart';

/// Opens the booking chat as a popup dialog instead of a full screen.
/// On desktop, positions in bottom-right corner. On mobile/tablet, centered.
Future<void> showBookingChatDialog(BuildContext context, String bookingId) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close chat',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) =>
        BookingChatDialog(bookingId: bookingId),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: ResponsiveHelper.isDesktop(context)
              ? const Offset(0.2, 0.2)
              : const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

class BookingChatDialog extends StatelessWidget {
  final String bookingId;

  const BookingChatDialog({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final screen = MediaQuery.of(context).size;

    if (isDesktop) {
      // Bottom-right positioned dialog on desktop
      return Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 450,
              height: screen.height * 0.7,
              constraints: const BoxConstraints(
                minWidth: 350,
                maxWidth: 500,
                minHeight: 400,
                maxHeight: 700,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
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
                  onClose: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Centered dialog on mobile/tablet
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: screen.height * 0.82,
          child: ChatScreen(
            bookingId: bookingId,
            embedded: true,
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}
