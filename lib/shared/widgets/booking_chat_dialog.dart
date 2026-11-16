import 'package:flutter/material.dart';
import '../../features/chat/presentation/chat_screen.dart';

/// Opens the booking chat as a popup dialog instead of a full screen.
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
          begin: const Offset(0, 0.15),
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
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
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
