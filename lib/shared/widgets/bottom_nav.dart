import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';
import 'portfolio_upload_dialog.dart';
import '../../features/reels/presentation/widgets/reel_upload_dialog.dart';

const Color _navPink = GlayaColors.vibrantPink;
const Color _navGray = Color(0xFF9E9E9E);

class GlayaBottomNav extends StatelessWidget {
  final int currentIndex;
  final String? userRole;

  const GlayaBottomNav({super.key, required this.currentIndex, this.userRole});

  bool get _isPro => userRole == 'professional' || userRole == 'both';
  bool get _isLoggedIn => userRole != null;

  @override
  Widget build(BuildContext context) {
    return _isPro
        ? _ProNav(currentIndex: currentIndex)
        : _CustomerNav(currentIndex: currentIndex, isLoggedIn: _isLoggedIn);
  }
}

// ── Customer Nav ─────────────────────────────────────────────────────────────
// 🏠 Home | 🔍 Discover | ➕ Book (FAB) | 💬 Messages | 👤 Profile

class _CustomerNav extends StatelessWidget {
  final int currentIndex;
  final bool isLoggedIn;
  const _CustomerNav({required this.currentIndex, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return _NavShell(
      children: [
        _NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            selected: currentIndex == 0,
            onTap: () => context.go('/')),
        _NavItem(
            icon: Icons.calendar_today,
            label: 'My Bookings',
            selected: currentIndex == 1,
            onTap: () => context.push('/bookings')),
        _FabItem(
            label: 'Book',
            onTap: () => isLoggedIn
                ? _showCustomerQuickAdd(context)
                : context.push('/book')),
        _NavItem(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Messages',
            selected: currentIndex == 3,
            onTap: () => context.push('/chat/list')),
        _NavItem(
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            selected: currentIndex == 4,
            onTap: () => context.push('/profile')),
      ],
    );
  }

  void _showCustomerQuickAdd(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerQuickAddSheet(parentContext: context),
    );
  }
}

// ── Customer Quick Add Sheet ──────────────────────────────────────────────────
class _CustomerQuickAddSheet extends StatelessWidget {
  /// Stable context from above the sheet — the sheet's own context is defunct
  /// after Navigator.pop, so dialogs must be opened with this instead.
  final BuildContext parentContext;
  const _CustomerQuickAddSheet({required this.parentContext});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.movie_outlined,
        'Upload Reel',
        () => ReelUploadDialog.openForCustomer(parentContext),
      ),
      (
        Icons.photo_library_outlined,
        'Upload Photo',
        () =>
            ReelUploadDialog.openForCustomer(parentContext, isPhoto: true),
      ),
      (
        Icons.calendar_today_outlined,
        'Book',
        () => context.push('/book'),
      ),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Quick Actions',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A))),
            ),
            const SizedBox(height: 16),
            ...items.map((t) => Material(
                  color: Colors.transparent,
                  child: ListTile(
                    onTap: () {
                      Navigator.pop(context);
                      t.$3();
                    },
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: _navPink.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(t.$1, color: _navPink, size: 20),
                    ),
                    title: Text(t.$2,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A))),
                    trailing:
                        const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
                    contentPadding: EdgeInsets.zero,
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ── Professional Nav ─────────────────────────────────────────────────────────
// � Home | 📅 My Bookings | ➕ New Post (FAB) | 📬 Inbox | � Dashboard

class _ProNav extends StatelessWidget {
  final int currentIndex;
  const _ProNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return _NavShell(
      children: [
        _NavItem(
            icon: Icons.home,
            label: 'Home',
            selected: currentIndex == 0,
            onTap: () => context.go('/')),
        _NavItem(
            icon: Icons.calendar_today,
            label: 'Bookings',
            selected: currentIndex == 1,
            onTap: () => context.push('/bookings')),
        _FabItem(label: 'Post', onTap: () => _showQuickAdd(context)),
        _NavItem(
            icon: Icons.mail_outline,
            label: 'Inbox',
            selected: currentIndex == 3,
            onTap: () => context.push('/chat/list')),
        _NavItem(
            icon: Icons.business,
            label: 'Dashboard',
            selected: currentIndex == 4,
            onTap: () => context.go('/professional/dashboard')),
      ],
    );
  }

  void _showQuickAdd(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickAddSheet(parentContext: context),
    );
  }
}

// ── Quick Add Sheet (Pro) ─────────────────────────────────────────────────────
class _QuickAddSheet extends StatelessWidget {
  /// Stable context from above the sheet — see _CustomerQuickAddSheet.
  final BuildContext parentContext;
  const _QuickAddSheet({required this.parentContext});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.movie_outlined,
        'Upload Reel',
        () => showDialog(
              context: parentContext,
              builder: (_) => const ReelUploadDialog(isProfessional: true),
            )
      ),
      (
        Icons.calendar_today_outlined,
        'New Booking',
        () => context.push('/bookings')
      ),
      (
        Icons.content_cut_outlined,
        'Add Service',
        () => context.push('/services')
      ),
      (
        Icons.schedule_outlined,
        'Set Availability',
        () => context.push('/availability')
      ),
      (
        Icons.photo_library_outlined,
        'Upload Portfolio',
        () => PortfolioUploadDialog.show(parentContext)
      ),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Quick Add',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A))),
            ),
            const SizedBox(height: 16),
            ...items.map((t) => Material(
                  color: Colors.transparent,
                  child: ListTile(
                    onTap: () {
                      Navigator.pop(context);
                      t.$3();
                    },
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: _navPink.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(t.$1, color: _navPink, size: 20),
                    ),
                    title: Text(t.$2,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A))),
                    trailing:
                        const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
                    contentPadding: EdgeInsets.zero,
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ── Shared primitives ─────────────────────────────────────────────────────────
class _NavShell extends StatelessWidget {
  final List<Widget> children;
  const _NavShell({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(height: 70, child: Row(children: children)),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected ? _navPink : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: _navPink.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Icon(icon,
                    size: 22, color: selected ? Colors.white : _navGray),
              ),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.normal,
                      color: selected ? _navPink : _navGray)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FabItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FabItem({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _navPink,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _navPink.withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _navPink)),
          ],
        ),
      ),
    );
  }
}
