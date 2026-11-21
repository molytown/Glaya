import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../features/auth/presentation/providers/auth_notifier.dart';
import '../../../features/booking/presentation/bookings_list_screen.dart';
import '../../../features/discovery/presentation/stylist_profile_page.dart';
import '../../../features/loyalty/presentation/loyalty_screen.dart';
import '../../../features/payments/presentation/wallet_screen.dart';
import '../../../features/profile/presentation/profile_screen.dart';
import '../../../features/professional/presentation/portfolio_screen.dart';
import '../../../features/professional/presentation/professional_dashboard_screen.dart';
import '../../../features/professional/presentation/service_management_screen.dart';
import '../../../features/settings/presentation/settings_screen.dart';
import '../../../shared/providers/location_provider.dart';
import '../../../shared/providers/notification_provider.dart';
import '../../../shared/providers/chat_bubble_provider.dart';
import '../widgets/location_dialog.dart';
import 'page_slide_out.dart';

/// React `.navbar` replica — 73px white bar with logo, nav links, location,
/// pill search, currency/language selects, Book Now, messages, notifications
/// and the user menu / sign-in button.
class DesktopHeader extends ConsumerWidget {
  final bool showNotificationDropdown;
  final bool showMessagesDropdown;
  final VoidCallback onNotificationToggle;
  final VoidCallback onMessagesToggle;
  final VoidCallback onLoginTap;

  const DesktopHeader({
    super.key,
    required this.showNotificationDropdown,
    required this.showMessagesDropdown,
    required this.onNotificationToggle,
    required this.onMessagesToggle,
    required this.onLoginTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _HeaderContent(
      showNotificationDropdown: showNotificationDropdown,
      showMessagesDropdown: showMessagesDropdown,
      onNotificationToggle: onNotificationToggle,
      onMessagesToggle: onMessagesToggle,
      onLoginTap: onLoginTap,
    );
  }
}

class _HeaderContent extends ConsumerStatefulWidget {
  final bool showNotificationDropdown;
  final bool showMessagesDropdown;
  final VoidCallback onNotificationToggle;
  final VoidCallback onMessagesToggle;
  final VoidCallback onLoginTap;

  const _HeaderContent({
    required this.showNotificationDropdown,
    required this.showMessagesDropdown,
    required this.onNotificationToggle,
    required this.onMessagesToggle,
    required this.onLoginTap,
  });

  @override
  ConsumerState<_HeaderContent> createState() => _HeaderContentState();
}

class _HeaderContentState extends ConsumerState<_HeaderContent> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _currency = 'XAF';
  String _language = 'en';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _currency = prefs.getString('preferredCurrency') ?? 'XAF';
      _language = prefs.getString('preferredLanguage') ?? 'en';
    });
  }

  Future<void> _savePref(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  void _submitSearch() {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    context.push('/search?q=${Uri.encodeComponent(q)}');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final locationState = ref.watch(locationProvider);
    final notifCount = ref.watch(notificationCountProvider);
    final msgCount = ref.watch(chatBubbleProvider.select((s) => s.unreadCount));
    // Extract neighborhood name from location state
    String locationLabel;
    if (locationState.locationName != null &&
        locationState.locationName!.isNotEmpty) {
      final parts = locationState.locationName!.split(',');
      locationLabel =
          parts.length > 1 ? parts[0].trim() : locationState.locationName!;
    } else {
      locationLabel = 'Detecting location…';
    }
    final path = GoRouterState.of(context).uri.path;

    return Container(
      height: 73,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final pad = w > 1400 ? 50.0 : (w > 1200 ? 40.0 : 32.0);
          final isLoggedIn = user != null;
          final showLinks = w >= (isLoggedIn ? 1600 : 1420);
          final showSelectors = w >= (isLoggedIn ? 1800 : 1560);
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                SizedBox(
                  width: 48,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => context.go('/'),
                      child: Image.asset(
                        'assets/logo.png',
                        height: 40,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Nav links
                if (showLinks) ...[
                  for (final link in _navLinks)
                    _NavLink(
                      label: link.$1,
                      route: link.$2,
                      hasDropdown: link.$3,
                      isActive: link.$1 == 'Home'
                          ? path == '/'
                          : path.startsWith(link.$2),
                    ),
                ],
                // Location
                _LocationButton(label: locationLabel),
                const SizedBox(width: 8),
                // Search
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 150, maxWidth: 280),
                  child: _NavbarSearch(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onSubmitted: _submitSearch,
                  ),
                ),
                if (showSelectors) ...[
                  const SizedBox(width: 12),
                  _IconDropdown(
                    icon: Icons.public,
                    label: _currency,
                    tooltip: 'Currency',
                    items: _currencies,
                    selected: _currency,
                    onSelected: (v) {
                      _savePref('preferredCurrency', v);
                      setState(() => _currency = v);
                    },
                  ),
                  const SizedBox(width: 4),
                  _IconDropdown(
                    icon: Icons.translate,
                    label: _language.toUpperCase(),
                    tooltip: 'Language',
                    items: _languages,
                    selected: _language,
                    onSelected: (v) {
                      _savePref('preferredLanguage', v);
                      setState(() => _language = v);
                    },
                  ),
                ],
                // Support chat
                if (user?.role == 'professional' || user?.role == 'both') ...[
                  const SizedBox(width: 4),
                  _IconButton(
                    icon: Icons.headset_outlined,
                    tooltip: 'Support Chat',
                    onTap: () => context.push('/support/chat'),
                  ),
                ],
                // Book Now
                if (user != null &&
                    user.role != 'professional' &&
                    user.role != 'both') ...[
                  const SizedBox(width: 8),
                  _BookNowButton(onTap: () => context.push('/book')),
                ],
                if (user != null) ...[
                  const SizedBox(width: 8),
                  _MessagesIconButton(
                    badge: msgCount,
                    showDropdown: widget.showMessagesDropdown,
                    onTap: widget.onMessagesToggle,
                  ),
                  const SizedBox(width: 4),
                  _NotificationIconButton(
                    badge: notifCount,
                    showDropdown: widget.showNotificationDropdown,
                    onTap: widget.onNotificationToggle,
                  ),
                ],
                const SizedBox(width: 8),
                _UserMenu(
                  user: user,
                  onLogout: () async {
                    await ref.read(authNotifierProvider.notifier).logout();
                    if (mounted) context.go('/');
                  },
                  onLoginTap: widget.onLoginTap,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Mirrors React NAV_LINKS
  static const _navLinks = [
    ('Home', '/', false),
    ('Services', '/services/popular', true),
    ('Professionals', '/search', false),
    ('Salons', '/search', false),
    ('Offers', '/loyalty', false),
    ('Magazine', '/theme2/discover', false),
  ];

  // Mirrors React LOCAL_CURRENCIES
  static const _currencies = [
    ('NGN', 'Nigerian Naira'),
    ('USD', 'US Dollar'),
    ('EUR', 'Euro'),
    ('GBP', 'British Pound'),
    ('ZAR', 'South African Rand'),
    ('GHS', 'Ghanaian Cedi'),
    ('KES', 'Kenyan Shilling'),
    ('CAD', 'Canadian Dollar'),
    ('AUD', 'Australian Dollar'),
    ('JPY', 'Japanese Yen'),
    ('CNY', 'Chinese Yuan'),
    ('INR', 'Indian Rupee'),
    ('BRL', 'Brazilian Real'),
    ('MXN', 'Mexican Peso'),
    ('SAR', 'Saudi Riyal'),
    ('AED', 'UAE Dirham'),
    ('EGP', 'Egyptian Pound'),
    ('MAD', 'Moroccan Dirham'),
    ('TZS', 'Tanzanian Shilling'),
    ('UGX', 'Ugandan Shilling'),
    ('ETB', 'Ethiopian Birr'),
    ('XOF', 'West African CFA Franc'),
    ('XAF', 'Central African CFA Franc'),
    ('CDF', 'Congolese Franc'),
    ('RWF', 'Rwandan Franc'),
    ('CHF', 'Swiss Franc'),
    ('SEK', 'Swedish Krona'),
    ('NOK', 'Norwegian Krone'),
    ('DKK', 'Danish Krone'),
    ('PLN', 'Polish Zloty'),
    ('TRY', 'Turkish Lira'),
    ('RUB', 'Russian Ruble'),
    ('KRW', 'South Korean Won'),
    ('SGD', 'Singapore Dollar'),
    ('HKD', 'Hong Kong Dollar'),
    ('THB', 'Thai Baht'),
    ('IDR', 'Indonesian Rupiah'),
    ('MYR', 'Malaysian Ringgit'),
    ('PHP', 'Philippine Peso'),
    ('VND', 'Vietnamese Dong'),
    ('PKR', 'Pakistani Rupee'),
    ('BDT', 'Bangladeshi Taka'),
    ('LKR', 'Sri Lankan Rupee'),
    ('NPR', 'Nepalese Rupee'),
  ];

  // Mirrors React LOCAL_LANGUAGES
  static const _languages = [
    ('en', 'English'),
    ('fr', 'Français'),
    ('es', 'Español'),
    ('pt', 'Português'),
    ('de', 'Deutsch'),
    ('it', 'Italiano'),
    ('ar', 'العربية'),
    ('zh', '中文'),
    ('ja', '日本語'),
    ('ko', '한국어'),
    ('ru', 'Русский'),
    ('hi', 'हिन्दी'),
    ('bn', 'বাংলা'),
    ('ur', 'اردو'),
    ('tr', 'Türkçe'),
    ('nl', 'Nederlands'),
    ('pl', 'Polski'),
    ('sv', 'Svenska'),
    ('da', 'Dansk'),
    ('no', 'Norsk'),
    ('fi', 'Suomi'),
    ('el', 'Ελληνικά'),
    ('he', 'עברית'),
    ('th', 'ไทย'),
    ('id', 'Bahasa Indonesia'),
    ('ms', 'Bahasa Melayu'),
    ('vi', 'Tiếng Việt'),
    ('sw', 'Kiswahili'),
    ('am', 'አማርኛ'),
    ('ha', 'Hausa'),
    ('yo', 'Yorùbá'),
    ('ig', 'Igbo'),
  ];
}

class _NavLink extends StatelessWidget {
  final String label;
  final String route;
  final bool hasDropdown;
  final bool isActive;

  const _NavLink({
    required this.label,
    required this.route,
    required this.hasDropdown,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (hasDropdown) {
            _showServicesMenu(context);
          } else {
            context.go(route);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive
                      ? const Color(0xFFE91E8C)
                      : const Color(0xFF9CA3AF),
                ),
              ),
              if (hasDropdown)
                const Icon(Icons.keyboard_arrow_down,
                    size: 14, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }

  void _showServicesMenu(BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final global = box.localToGlobal(Offset.zero, ancestor: overlay);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
            global.dx, global.dy + box.size.height, box.size.width, 0),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(
            value: '/services/popular', child: Text('Popular Services')),
        PopupMenuItem(value: '/services', child: Text('All Services')),
        PopupMenuItem(value: '/home-service', child: Text('Home Service')),
        PopupMenuItem(value: '/search', child: Text('Find Professionals')),
      ],
    ).then((value) {
      if (value != null && context.mounted) context.go(value);
    });
  }
}

class _LocationButton extends ConsumerWidget {
  final String label;
  const _LocationButton({required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showLocationDialog(context, ref),
        child: Row(
          children: [
            const Icon(Icons.location_on, size: 14, color: Color(0xFFE91E8C)),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down,
                size: 14, color: Color(0xFF1A1A2E)),
          ],
        ),
      ),
    );
  }

  void _showLocationDialog(BuildContext context, WidgetRef ref) {
    final locationState = ref.read(locationProvider);
    final initialLocation =
        locationState.lat != null && locationState.lng != null
            ? LatLng(locationState.lat!, locationState.lng!)
            : null;
    showDialog(
      context: context,
      builder: (dialogContext) => LocationDialog(
        initialLocation: initialLocation,
        initialAddress: locationState.locationName,
        onConfirm: (latLng, address) {
          ref.read(locationProvider.notifier).setLocation(
                latLng.latitude,
                latLng.longitude,
              );
        },
      ),
    );
  }
}

class _NavbarSearch extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;

  const _NavbarSearch({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onSubmitted: (_) => onSubmitted(),
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF1A1A2E)),
              decoration: const InputDecoration(
                hintText: 'Search services, salons, professionals...',
                hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14),
                isDense: true,
              ),
            ),
          ),
          GestureDetector(
            onTap: onSubmitted,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: const BoxDecoration(
                color: Color(0xFFE91E8C),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: const Icon(Icons.search, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF1A1A2E)),
          ),
        ),
      ),
    );
  }
}

class _MessagesIconButton extends StatelessWidget {
  final int badge;
  final bool showDropdown;
  final VoidCallback onTap;

  const _MessagesIconButton({
    required this.badge,
    required this.showDropdown,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Messages',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: showDropdown
                        ? const Color(0xFFE91E8C)
                        : const Color(0xFFE5E7EB),
                    width: showDropdown ? 2 : 1,
                  ),
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: 20,
                  color: showDropdown
                      ? const Color(0xFFE91E8C)
                      : const Color(0xFF1A1A2E),
                ),
              ),
              if (badge > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE91E8C),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationIconButton extends StatelessWidget {
  final int badge;
  final bool showDropdown;
  final VoidCallback onTap;

  const _NotificationIconButton({
    required this.badge,
    required this.showDropdown,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Notifications',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: showDropdown
                        ? const Color(0xFFE91E8C)
                        : const Color(0xFFE5E7EB),
                    width: showDropdown ? 2 : 1,
                  ),
                ),
                child: Icon(
                  Icons.notifications_none,
                  size: 20,
                  color: showDropdown
                      ? const Color(0xFFE91E8C)
                      : const Color(0xFF1A1A2E),
                ),
              ),
              if (badge > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE91E8C),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookNowButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BookNowButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE91E8C),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Book Now',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconDropdown extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final List<(String, String)> items;
  final String selected;
  final void Function(String) onSelected;

  const _IconDropdown({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showDropdown(context),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF6B7280)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down,
                size: 14, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  void _showDropdown(BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final global = box.localToGlobal(Offset.zero, ancestor: overlay);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
            global.dx, global.dy + box.size.height, box.size.width, 0),
        Offset.zero & overlay.size,
      ),
      items: items
          .map((item) => PopupMenuItem(
                value: item.$1,
                child: Text(item.$2),
              ))
          .toList(),
    ).then((value) {
      if (value != null) onSelected(value);
    });
  }
}

class _UserMenu extends ConsumerWidget {
  final dynamic user;
  final VoidCallback onLogout;
  final VoidCallback onLoginTap;

  const _UserMenu({
    required this.user,
    required this.onLogout,
    required this.onLoginTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user == null) {
      return _LoginButton(onTap: onLoginTap);
    }
    final photoUrl = user.photoUrl as String?;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showUserMenu(context, ref),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: photoUrl != null
              ? ClipOval(
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.person, size: 18),
                  ),
                )
              : const Icon(Icons.person, size: 18, color: Color(0xFF6B7280)),
        ),
      ),
    );
  }

  void _showUserMenu(BuildContext context, WidgetRef ref) {
    final box = context.findRenderObject() as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final global = box.localToGlobal(Offset.zero, ancestor: overlay);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
            global.dx, global.dy + box.size.height, box.size.width, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        if (user.role == 'professional' || user.role == 'both')
          const PopupMenuItem(value: 'dashboard', child: Text('Dashboard')),
        const PopupMenuItem(value: 'profile', child: Text('Profile')),
        const PopupMenuItem(value: 'bookings', child: Text('Bookings')),
        if (user.role == 'professional' || user.role == 'both')
          const PopupMenuItem(value: 'services', child: Text('Services')),
        if (user.role == 'professional' || user.role == 'both')
          const PopupMenuItem(value: 'portfolio', child: Text('Portfolio')),
        if (user.role == 'professional' || user.role == 'both')
          const PopupMenuItem(value: 'analytics', child: Text('Analytics')),
        const PopupMenuItem(value: 'wallet', child: Text('Wallet')),
        const PopupMenuItem(value: 'rewards', child: Text('Rewards')),
        const PopupMenuItem(value: 'settings', child: Text('Settings')),
        const PopupMenuItem(value: 'logout', child: Text('Sign Out')),
      ],
    ).then((value) {
      if (value == null) return;
      if (value == 'logout') {
        onLogout();
      } else if (context.mounted) {
        _openSlideOut(context, value);
      }
    });
  }

  void _openSlideOut(BuildContext context, String key) {
    final isPro = user.role == 'professional' || user.role == 'both';
    switch (key) {
      case 'dashboard':
        showPageSlideOut(context,
            title: 'Dashboard', child: const ProfessionalDashboardScreen());
      case 'profile':
        showPageSlideOut(
          context,
          title: 'Profile',
          child: isPro ? const StylistProfilePage() : const ProfileScreen(),
        );
      case 'bookings':
        showPageSlideOut(context,
            title: 'Bookings', child: const BookingsListScreen());
      case 'services':
        showPageSlideOut(context,
            title: 'Services', child: const ServiceManagementScreen());
      case 'portfolio':
        showPageSlideOut(context,
            title: 'Portfolio', child: const PortfolioScreen());
      case 'analytics':
        showPageSlideOut(context,
            title: 'Analytics', child: const ProfessionalDashboardScreen());
      case 'wallet':
        showPageSlideOut(context, title: 'Wallet', child: const WalletScreen());
      case 'rewards':
        showPageSlideOut(context,
            title: 'Rewards', child: const LoyaltyScreen());
      case 'settings':
        showPageSlideOut(context,
            title: 'Settings', child: const SettingsScreen());
    }
  }
}

class _LoginButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LoginButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE91E8C),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'sign in / Join',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
