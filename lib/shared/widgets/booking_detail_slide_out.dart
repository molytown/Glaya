import 'package:flutter/material.dart';
import '../../features/booking/presentation/booking_detail_screen.dart';
import '../utils/responsive_helper.dart';

/// Opens booking details as a right-side slide-out panel instead of
/// navigating to the full booking details page.
Future<void> showBookingDetailSlideOut(BuildContext context, String bookingId) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close booking details',
    barrierColor: Color(0xFF000000).withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) =>
        BookingDetailSlideOut(bookingId: bookingId),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

class BookingDetailSlideOut extends StatelessWidget {
  final String bookingId;

  const BookingDetailSlideOut({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: isDesktop ? 560.0 : double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFFFCE4EC),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF000000),
                blurRadius: 30,
                offset: Offset(-8, 0),
              ),
            ],
          ),
          child: BookingDetailScreen(
            bookingId: bookingId,
            embedded: true,
          ),
        ),
      ),
    );
  }
}
