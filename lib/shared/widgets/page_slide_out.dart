import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';

/// Opens any page content as a right-side slide-out panel instead of
/// navigating to a full page. Desktop: ~760px panel; mobile: full width.
Future<void> showPageSlideOut(
  BuildContext context, {
  required String title,
  required Widget child,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close $title',
    barrierColor: Color(0xFF000000).withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) =>
        PageSlideOut(title: title, child: child),
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

class PageSlideOut extends StatelessWidget {
  final String title;
  final Widget child;

  const PageSlideOut({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: isDesktop ? 780.0 : double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0xFF000000),
                blurRadius: 30,
                offset: Offset(-8, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              _SlideOutHeader(title: title),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideOutHeader extends StatelessWidget {
  final String title;

  const _SlideOutHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
