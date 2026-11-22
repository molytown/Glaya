import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/providers/location_provider.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/config_service.dart';
import '../../../../shared/widgets/bottom_nav.dart';
import '../../../../shared/widgets/content_actions.dart';
import '../../auth/presentation/providers/auth_notifier.dart';
import '../../profile/presentation/wallet_dialog.dart';

class StylistProfilePage extends ConsumerStatefulWidget {
  const StylistProfilePage({super.key});

  @override
  ConsumerState<StylistProfilePage> createState() => _StylistProfilePageState();
}

class _StylistProfilePageState extends ConsumerState<StylistProfilePage> {
  int selectedTab = 0;
  Map<String, dynamic>? _professionalData;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;

  final Color primaryColor = const Color(0xFFD6006E);
  final Color lightPink = const Color(0xFFF8BBD0);
  final Color backgroundColor = const Color(0xFFFCFAFB);
  final Color textColor = const Color(0xFF17202A);
  final Color secondaryText = const Color(0xFF68727D);

  final List<String> tabs = [
    'Overview',
    'Services',
    'Gallery',
    'Reviews',
    'Location',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfessionalData();
  }

  Future<dynamic> _getJson(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await ApiService.dio.get(path, queryParameters: query);
      return res.data?['data'];
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadProfessionalData() async {
    try {
      final results = await Future.wait([
        _getJson('/professionals/me'),
        _getJson('/professionals/me/dashboard'),
        _getJson('/professionals/me/analytics', query: {'period': 'month'}),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Map<String, dynamic>?;
        _professionalData = results[1] as Map<String, dynamic>?;
        _analytics = results[2] as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading professional data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Data helpers ──────────────────────────────────────────────

  Map<String, dynamic> get _pro =>
      _professionalData?['professional'] as Map<String, dynamic>? ?? {};

  Map<String, dynamic> get _profileUser =>
      _profile?['user'] as Map<String, dynamic>? ?? {};

  String _resolveMediaUrl(dynamic url) {
    if (url == null) return '';
    final str = url.toString();
    if (str.isEmpty) return '';
    if (str.startsWith('http')) return ConfigService().replaceLocalhost(str);
    return '${ConfigService().socketUrl}$str';
  }

  String _formatPrice(dynamic price) {
    final currency = ref.read(locationProvider).currency ??
        _pro['currency']?.toString() ??
        'XAF';
    final value = num.tryParse(price?.toString() ?? '') ?? 0;
    final symbol = switch (currency.toUpperCase()) {
      'USD' => '\$',
      'EUR' => '€',
      'GBP' => '£',
      'NGN' => '₦',
      'XAF' => 'FCFA ',
      'GHS' => 'GH₵ ',
      'KES' => 'KSh ',
      'ZAR' => 'R ',
      'INR' => '₹',
      'CAD' => 'C\$',
      'AUD' => 'A\$',
      'JPY' || 'CNY' => '¥',
      'BRL' => 'R\$',
      'MXN' => 'MX\$',
      _ => '$currency ',
    };
    final formatted = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
    return '$symbol$formatted';
  }

  String _formatDuration(dynamic mins) {
    final m = (mins is num ? mins : num.tryParse(mins?.toString() ?? '')) ?? 0;
    final h = m ~/ 60;
    final rem = m % 60;
    if (h == 0) return '${rem.toInt()}m';
    return rem == 0 ? '${h}h' : '${h}h ${rem.toInt()}m';
  }

  String _formatTime(dynamic time) {
    final str = time?.toString() ?? '';
    if (str.contains(':')) {
      final parts = str.split(':');
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$hour12:${minute.toString().padLeft(2, '0')} $period';
    }
    return str;
  }

  List<Map<String, dynamic>> get _reviews {
    final raw = (_analytics?['recentReviews'] as List<dynamic>?) ??
        (_profile?['reviews'] as List<dynamic>?) ??
        const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<String> get _galleryImageUrls {
    final urls = <String>[];
    final galleries = (_profile?['portfolioGalleries'] as List<dynamic>?) ?? [];
    for (final g in galleries) {
      if (g is! Map) continue;
      void addMedia(dynamic media) {
        if (media is! Map) return;
        for (final key in ['mediaUrl', 'thumbnailUrl', 'url']) {
          final u = _resolveMediaUrl(media[key]);
          if (u.isNotEmpty) {
            urls.add(u);
            return;
          }
        }
      }

      addMedia(g['coverMedia']);
      final media = g['media'] as List<dynamic>?;
      if (media != null) {
        for (final m in media) {
          addMedia(m);
        }
      }
    }
    if (urls.isEmpty) {
      final portfolio = (_profile?['portfolioUrls'] as List<dynamic>?) ??
          (_pro['portfolioUrls'] as List<dynamic>?) ??
          const [];
      for (final u in portfolio) {
        final resolved = _resolveMediaUrl(u);
        if (resolved.isNotEmpty) urls.add(resolved);
      }
    }
    return urls;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _buildScrollView();
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: isDesktop
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: content,
                  ),
                ),
              )
            : content,
      ),
      bottomNavigationBar: GlayaBottomNav(
        currentIndex: 4,
        userRole: user?.role,
      ),
    );
  }

  Widget _buildScrollView() {
    return RefreshIndicator(
      onRefresh: _loadProfessionalData,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeroSection()),

          SliverToBoxAdapter(child: _buildProfileHeader()),

          SliverToBoxAdapter(child: _buildStats()),

          SliverToBoxAdapter(child: _buildTabs()),

          SliverToBoxAdapter(child: _buildTabContent()),

          // Space for bottom action bar
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // HERO
  // ------------------------------------------------------------

  Widget _buildHeroSection() {
    final galleryUrls = _galleryImageUrls;
    final userPhoto = _resolveMediaUrl(_profileUser['photoUrl']);
    final imageUrl = galleryUrls.isNotEmpty
        ? galleryUrls.first
        : userPhoto.isNotEmpty
            ? userPhoto
            : 'https://images.unsplash.com/photo-1595476108010-b4d1f102b1b1?auto=format&fit=crop&w=1200&q=85';

    return SizedBox(
      height: 235,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(color: const Color(0xFFE9D9DD));
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF000000).withValues(alpha: .20),
                    Color(0xFF000000).withValues(alpha: .05),
                    Color(0xFF000000).withValues(alpha: .30),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 18,
              left: 18,
              child: _circleButton(
                Icons.arrow_back_ios_new_rounded,
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
            ),
            Positioned(
              top: 18,
              right: 72,
              child: _circleButton(Icons.share_rounded, onTap: () {}),
            ),
            Positioned(
              top: 18,
              right: 18,
              child: _circleButton(Icons.favorite_border_rounded, onTap: () {}),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // PROFILE HEADER
  // ------------------------------------------------------------

  Widget _buildProfileHeader() {
    final profile = _profile ?? {};
    final pro = _pro;
    final category = profile['category'] as Map<String, dynamic>?;
    final serviceCategories = profile['serviceCategories'];
    final categoryName =
        (category?['name'] ?? category?['title'])?.toString() ??
            (serviceCategories is List && serviceCategories.isNotEmpty
                ? serviceCategories
                    .map((c) => c is Map ? (c['name'] ?? c['title']) : c)
                    .where((c) => c != null)
                    .join(', ')
                : null) ??
            'Professional';
    final businessName = (profile['businessName'] ??
            profile['user']?['name'] ??
            pro['name'] ??
            'Professional')
        .toString();
    final city = profile['city']?.toString() ?? '';
    final state = profile['state']?.toString() ?? '';
    final neighborhood = profile['neighborhood']?.toString() ?? '';
    final address = profile['businessAddress']?.toString() ?? '';
    final parts = [
      if (neighborhood.isNotEmpty) neighborhood,
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
    ];
    final locationText = parts.isNotEmpty
        ? parts.join(', ')
        : address.isNotEmpty
            ? address
            : 'Location not set';
    final isVerified =
        (profile['verificationStatus'] ?? pro['verificationStatus']) ==
            'approved';
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final proUserId = (profile['userId'] ?? profile['user']?['id'])?.toString();
    final isOwner = user?.id != null && user!.id == proUserId;

    return Transform.translate(
      offset: const Offset(0, -35),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF000000).withValues(alpha: .04),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfilePhoto(),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 42),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (isVerified) _verifiedBadge(),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$categoryName  •  Professional',
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              locationText,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _topRatedBadge(),
                const Spacer(),
                if (isOwner) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/settings'),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit Profile',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => WalletDialog.show(context),
                      icon: const Icon(Icons.account_balance_wallet_outlined,
                          size: 16),
                      label: const Text('Wallet',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ),
                ] else
                  ElevatedButton.icon(
                    onPressed: () {
                      _showBookingMessage();
                    },
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: const Text('Book Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePhoto() {
    final photoUrl = _profileUser['photoUrl'] ??
        _profile?['photoUrl'] ??
        ref.read(authNotifierProvider).valueOrNull?.photoUrl;
    final imageUrl = _resolveMediaUrl(photoUrl).isNotEmpty
        ? _resolveMediaUrl(photoUrl)
        : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=500&q=85';

    return Container(
      margin: const EdgeInsets.only(top: 0),
      width: 105,
      height: 105,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 5),
        image: DecorationImage(
          image: NetworkImage(imageUrl),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
              color: Color(0xFF000000).withValues(alpha: .15), blurRadius: 10),
        ],
      ),
      child: Align(
        alignment: Alignment.bottomRight,
        child: _verifiedBadge(size: 26),
      ),
    );
  }

  Widget _verifiedBadge({double size = 22}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFD6006E),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(Icons.check, color: Colors.white, size: size * .62),
    );
  }

  Widget _topRatedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: lightPink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, size: 18, color: Color(0xFFE5A91C)),
          const SizedBox(width: 5),
          Text(
            'Top Rated',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // STATS
  // ------------------------------------------------------------

  Widget _buildStats() {
    final pro = _pro;
    final profile = _profile ?? {};
    final avgRating = num.tryParse(
                (pro['avgRating'] ?? profile['avgRating'])?.toString() ?? '')
            ?.toStringAsFixed(1) ??
        '0.0';
    final totalReviews =
        ((pro['totalReviews'] ?? profile['totalReviews']) as num?)?.toInt() ??
            0;
    final totalBookings =
        ((pro['totalBookings'] ?? profile['totalBookings']) as num?)?.toInt() ??
            0;
    final trustScore =
        ((pro['trustScore'] ?? profile['trustScore']) as num?)?.toInt() ?? 0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      child: Row(
        children: [
          Expanded(
            child: _statItem(
              icon: Icons.star_rounded,
              iconColor: const Color(0xFFE6A91C),
              title: avgRating,
              subtitle: '$totalReviews reviews',
            ),
          ),
          _divider(),
          Expanded(
            child: _statItem(
              icon: Icons.calendar_month_outlined,
              iconColor: textColor,
              title: totalBookings.toString(),
              subtitle: 'Bookings',
            ),
          ),
          _divider(),
          Expanded(
            child: _statItem(
              icon: Icons.verified_user_outlined,
              iconColor: textColor,
              title: trustScore.toString(),
              subtitle: 'Trust Score',
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 21),
            if (title.isNotEmpty) ...[
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: secondaryText,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 40, color: const Color(0xFFE9E9E9));
  }

  // ------------------------------------------------------------
  // TABS
  // ------------------------------------------------------------

  Widget _buildTabs() {
    return Container(
      height: 72,
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / tabs.length;
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: tabs.length,
            itemBuilder: (context, index) {
              final selected = selectedTab == index;

              final icons = [
                Icons.person_outline_rounded,
                Icons.content_cut_rounded,
                Icons.photo_library_outlined,
                Icons.star_border_rounded,
                Icons.location_on_outlined,
              ];

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedTab = index;
                  });
                },
                child: Container(
                  width: tabWidth,
                  padding: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected ? primaryColor : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icons[index],
                        size: 21,
                        color: selected ? primaryColor : secondaryText,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        tabs[index],
                        style: TextStyle(
                          color: selected ? primaryColor : textColor,
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // TAB CONTENT
  // ------------------------------------------------------------

  Widget _buildTabContent() {
    switch (selectedTab) {
      case 1:
        return _buildServices();
      case 2:
        return _buildGallery();
      case 3:
        return _buildReviews();
      case 4:
        return _buildLocation();
      default:
        return _buildOverview();
    }
  }

  // ------------------------------------------------------------
  // OVERVIEW
  // ------------------------------------------------------------

  Widget _buildOverview() {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final proUserId =
        (_profile?['userId'] ?? _profile?['user']?['id'])?.toString();
    final isOwner = user?.id != null && user!.id == proUserId;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAboutCard(),
          const SizedBox(height: 14),
          _buildOpeningHours(),
          const SizedBox(height: 14),
          _buildCustomerReviews(),
          if (isOwner) ...[
            const SizedBox(height: 14),
            _buildEditProfileSection(),
            const SizedBox(height: 14),
            _buildSettingsSection(),
          ],
          const SizedBox(height: 14),
          _buildSupportSection(),
          if (isOwner) ...[
            const SizedBox(height: 14),
            _buildLogoutButton(),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // ABOUT
  // ------------------------------------------------------------

  Widget _buildAboutCard() {
    final profile = _profile ?? {};
    final bio = profile['bio'] as String? ?? profile['about'] as String? ?? '';

    final user = ref.watch(authNotifierProvider).valueOrNull;
    final proUserId = (profile['userId'] ?? profile['user']?['id'])?.toString();
    final isOwner = user?.id != null && user!.id == proUserId;

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle(Icons.person_outline_rounded, 'About Me'),
              if (isOwner)
                GestureDetector(
                  onTap: () => _showBioEditor(bio),
                  child: Text(
                    'Edit',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bio.isNotEmpty
                ? bio
                : (isOwner
                    ? 'No bio yet — tap Edit to introduce yourself.'
                    : 'This professional hasn\'t added a bio yet.'),
            style: TextStyle(
              color: bio.isEmpty ? secondaryText : textColor,
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBioEditor(String currentBio) async {
    final controller = TextEditingController(text: currentBio);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit About Me'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                maxLines: 5,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText:
                      'Tell customers about yourself, your experience, and what makes you unique...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value != null && value.length > 1000) {
                    return 'Bio must be less than 1000 characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _saveBio(controller.text);
    }
  }

  Future<void> _saveBio(String bio) async {
    try {
      await ApiService.dio.put('/professionals/me', data: {'bio': bio});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bio updated successfully'),
            backgroundColor: primaryColor,
          ),
        );
        setState(() {
          _loadProfessionalData();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update bio: $e'),
            backgroundColor: primaryColor,
          ),
        );
      }
    }
  }

  // ------------------------------------------------------------
  // OPENING HOURS
  // ------------------------------------------------------------

  Widget _buildOpeningHours() {
    // Backend dayOfWeek follows JS getDay(): 0=Sunday ... 6=Saturday.
    // Display order: Monday..Sunday.
    const displayOrder = [1, 2, 3, 4, 5, 6, 0];
    const dayNames = {
      0: 'Sunday',
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
    };
    final availability =
        (_profile?['availability'] as List<dynamic>?) ?? const [];

    final hours = displayOrder.map((day) {
      final slots = availability.where((a) {
        if (a is! Map) return false;
        final d = (a['dayOfWeek'] ?? a['day_of_week']) as num?;
        final blocked = a['isBlocked'] ?? a['is_blocked'];
        return d?.toInt() == day && blocked != true;
      }).toList();
      if (slots.isEmpty) return [dayNames[day]!, 'Closed'];
      final ranges = slots.map((s) {
        final s_ = s as Map;
        final start = _formatTime(s_['startTime'] ?? s_['start_time']);
        final end = _formatTime(s_['endTime'] ?? s_['end_time']);
        return start.isEmpty || end.isEmpty ? 'Open' : '$start – $end';
      }).toList();
      return [dayNames[day]!, ranges.join(', ')];
    }).toList();

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionTitle(
                  Icons.access_time_rounded,
                  'Opening Hours',
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  _showCalendar();
                },
                icon: Icon(
                  Icons.calendar_month_outlined,
                  color: primaryColor,
                  size: 17,
                ),
                label: Text(
                  'View Calendar',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...hours.map((item) => _openingHourRow(day: item[0], hours: item[1])),
        ],
      ),
    );
  }

  Widget _openingHourRow({required String day, required String hours}) {
    final closed = hours == 'Closed';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEDEDED), width: .7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              day,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            hours,
            style: TextStyle(
              color: closed ? secondaryText : textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // CUSTOMER REVIEWS
  // ------------------------------------------------------------

  Widget _buildCustomerReviews() {
    final reviews = _reviews;
    final pro = _pro;
    final profile = _profile ?? {};
    final avgRating = num.tryParse(
            (pro['avgRating'] ?? profile['avgRating'])?.toString() ?? '') ??
        0;
    final totalReviews =
        ((pro['totalReviews'] ?? profile['totalReviews']) as num?)?.toInt() ??
            reviews.length;
    final ratingDisplay = avgRating == avgRating.roundToDouble()
        ? avgRating.toInt().toString()
        : avgRating.toStringAsFixed(1);
    final filledStars = avgRating.round().clamp(0, 5);
    final fiveStarCount = reviews
        .where((r) => ((r['rating'] ?? r['stars']) as num? ?? 0) >= 5)
        .length;
    final latestReview = reviews.isNotEmpty ? reviews.first : null;

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionTitle(Icons.star_rounded, 'Customer Reviews'),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    selectedTab = 3;
                  });
                },
                child: Row(
                  children: [
                    Text(
                      'See All ($totalReviews)',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: primaryColor),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        ratingDisplay,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 31,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: List.generate(
                          5,
                          (index) => Icon(
                            index < filledStars
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: const Color(0xFFE7A91C),
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Based on $totalReviews reviews',
                    style: TextStyle(color: secondaryText, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(width: 22),
              Container(width: 1, height: 65, color: const Color(0xFFE6E6E6)),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _reviewMetric(
                      Icons.reviews_outlined,
                      'Total Reviews',
                      '$totalReviews',
                    ),
                    _reviewMetric(
                      Icons.star_rounded,
                      'Avg Rating',
                      ratingDisplay,
                    ),
                    _reviewMetric(
                      Icons.thumb_up_alt_outlined,
                      '5-Star Reviews',
                      '$fiveStarCount',
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (latestReview != null) ...[
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 12),
            _reviewItem(
              name: _reviewerName(latestReview),
              date: _reviewDate(latestReview),
              text: _reviewText(latestReview),
              imageUrl: _reviewImage(latestReview),
              rating: _reviewRating(latestReview),
              reviewId: latestReview['id']?.toString(),
              reviewerId: _reviewerId(latestReview),
            ),
          ],
        ],
      ),
    );
  }

  String _reviewerName(Map<String, dynamic> r) {
    final n = r['reviewer_name'] ??
        r['reviewerName'] ??
        r['reviewer']?['name'] ??
        r['user']?['name'];
    return n?.toString() ?? 'Customer';
  }

  String _reviewDate(Map<String, dynamic> r) {
    final raw = r['created_at'] ?? r['createdAt'];
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 30) return '${diff.inDays} days ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
    return '${(diff.inDays / 365).floor()} years ago';
  }

  int _reviewRating(Map<String, dynamic> r) =>
      ((r['rating'] ?? r['stars']) as num?)?.toInt() ?? 5;

  String? _reviewerId(Map<String, dynamic> r) => (r['reviewer_id'] ??
          r['reviewerId'] ??
          r['reviewer']?['id'] ??
          r['user']?['id'])
      ?.toString();

  String _reviewText(Map<String, dynamic> r) =>
      (r['comment'] ?? r['review'] ?? r['text'] ?? '').toString();

  String _reviewImage(Map<String, dynamic> r) =>
      _resolveMediaUrl(r['reviewer_photo_url'] ??
          r['reviewer']?['photoUrl'] ??
          r['user']?['photoUrl']);

  Widget _reviewMetric(IconData icon, String title, String percentage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(icon, size: 15, color: primaryColor),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: textColor, fontSize: 10),
            ),
          ),
          Text(
            percentage,
            style: TextStyle(
              color: secondaryText,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewItem({
    required String name,
    required String date,
    required String text,
    required String imageUrl,
    int rating = 5,
    String? reviewId,
    String? reviewerId,
  }) {
    final clampedRating = rating.clamp(0, 5);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: lightPink,
          backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
          child: imageUrl.isEmpty
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (reviewId != null && reviewerId != null)
                    GestureDetector(
                      onTap: () => ContentActions.show(
                        context,
                        targetType: 'review',
                        targetId: reviewId,
                        reportedUserId: reviewerId,
                        displayName: name,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.more_vert,
                            size: 18, color: secondaryText),
                      ),
                    ),
                  Text(
                    date,
                    style: TextStyle(color: secondaryText, fontSize: 9),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < clampedRating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: const Color(0xFFE7A91C),
                    size: 13,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                text,
                style: TextStyle(color: textColor, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // FULL REVIEWS TAB
  // ------------------------------------------------------------

  Widget _buildReviews() {
    final reviews = _reviews;
    final pro = _pro;
    final profile = _profile ?? {};
    final avgRating = num.tryParse(
            (pro['avgRating'] ?? profile['avgRating'])?.toString() ?? '') ??
        0;
    final totalReviews =
        ((pro['totalReviews'] ?? profile['totalReviews']) as num?)?.toInt() ??
            reviews.length;
    final ratingDisplay = avgRating == avgRating.roundToDouble()
        ? avgRating.toInt().toString()
        : avgRating.toStringAsFixed(1);
    final filledStars = avgRating.round().clamp(0, 5);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _sectionCard(
            child: Column(
              children: [
                Text(
                  ratingDisplay,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 45,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < filledStars
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: const Color(0xFFE7A91C),
                      size: 23,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$totalReviews customer reviews',
                  style: TextStyle(color: secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (reviews.isEmpty)
            _sectionCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No reviews yet',
                    style: TextStyle(color: secondaryText, fontSize: 13),
                  ),
                ),
              ),
            )
          else
            _sectionCard(
              child: Column(
                children: [
                  for (var i = 0; i < reviews.length; i++) ...[
                    if (i > 0) const Divider(height: 30),
                    _reviewItem(
                      name: _reviewerName(reviews[i]),
                      date: _reviewDate(reviews[i]),
                      text: _reviewText(reviews[i]),
                      imageUrl: _reviewImage(reviews[i]),
                      rating: _reviewRating(reviews[i]),
                      reviewId: reviews[i]['id']?.toString(),
                      reviewerId: _reviewerId(reviews[i]),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SERVICES
  // ------------------------------------------------------------

  Widget _buildServices() {
    final services = ((_profile?['services'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .where((s) => s['isActive'] != false)
        .toList();

    if (services.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _sectionCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No services listed yet',
                style: TextStyle(color: secondaryText, fontSize: 13),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final s in services)
            _serviceCard(
              title: (s['name'] ?? 'Service').toString(),
              duration:
                  _formatDuration(s['durationMins'] ?? s['duration_mins']),
              price: _formatPrice(s['price']),
            ),
        ],
      ),
    );
  }

  Widget _serviceCard({
    required String title,
    required String duration,
    required String price,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: lightPink,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.content_cut_rounded, color: primaryColor),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  duration,
                  style: TextStyle(color: secondaryText, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: TextStyle(
              color: primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // GALLERY
  // ------------------------------------------------------------

  Widget _buildGallery() {
    final images = _galleryImageUrls;

    if (images.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _sectionCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No portfolio photos yet',
                style: TextStyle(color: secondaryText, fontSize: 13),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: images.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (_, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.network(
              images[index],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: lightPink),
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // LOCATION
  // ------------------------------------------------------------

  Widget _buildLocation() {
    final profile = _profile ?? {};
    final name = (profile['businessName'] ??
            profile['user']?['name'] ??
            _pro['name'] ??
            'Professional')
        .toString();
    final addressParts = [
      profile['neighborhood'],
      profile['city'],
      profile['state'],
      profile['country'],
    ].map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    final businessAddress = profile['businessAddress']?.toString() ?? '';
    final locationText = addressParts.isNotEmpty
        ? addressParts.join(', ')
        : businessAddress.isNotEmpty
            ? businessAddress
            : 'Address not set';
    final location = profile['location'];
    final hasCoords =
        location is Map && location['lat'] != null && location['lng'] != null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: _sectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(Icons.location_on_outlined, 'Location'),
            const SizedBox(height: 15),
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE4E0DC),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xFFD6006E),
                      size: 48,
                    ),
                    if (hasCoords)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${location['lat']}, ${location['lng']}',
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              name,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              locationText,
              style: TextStyle(color: secondaryText, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // COMMON COMPONENTS
  // ------------------------------------------------------------

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: child,
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFF0E8EC)),
      boxShadow: [
        BoxShadow(
          color: Color(0xFF000000).withValues(alpha: .025),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 22),
        const SizedBox(width: 9),
        Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _circleButton(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // ------------------------------------------------------------
  // SETTINGS/PROFILE SECTIONS
  // ------------------------------------------------------------

  Widget _buildEditProfileSection() {
    return _sectionCard(
      child: InkWell(
        onTap: () => context.push('/settings'),
        borderRadius: BorderRadius.circular(10),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                size: 20,
                color: Color(0xFF555555),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Edit Profile',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: Color(0xFFCCCCCC),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    final user = ref.read(authNotifierProvider).valueOrNull;
    final items = [
      (Icons.phone_outlined, 'Phone Number', null, user?.phone ?? '—'),
      (Icons.lock_outline, 'Two-Factor Authentication', '/settings', null),
      (Icons.devices_outlined, 'Devices', '/settings', null),
      (Icons.language_outlined, 'Language', '/settings', null),
      (
        Icons.privacy_tip_outlined,
        'Privacy Settings',
        '/cms/privacy-policy',
        null
      ),
    ];
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.settings_outlined, 'Settings'),
          const SizedBox(height: 8),
          ...items.map(
            (t) => InkWell(
              onTap: t.$3 != null ? () => context.push(t.$3!) : null,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
                child: Row(
                  children: [
                    Icon(t.$1, size: 20, color: const Color(0xFF555555)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t.$2,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    if (t.$4 != null)
                      Text(
                        t.$4!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF000000),
                        ),
                      ),
                    if (t.$3 != null)
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Color(0xFFCCCCCC),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection() {
    final items = [
      (Icons.help_outline, 'Help Centre', '/cms/support', null),
      (Icons.chat_bubble_outline, 'Contact Support', null, null),
      (Icons.report_problem_outlined, 'Report Issue', '/cms/support', null),
      (Icons.menu_book_outlined, 'FAQs', '/cms/support', null),
    ];
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.support_agent_outlined, 'Support'),
          const SizedBox(height: 8),
          ...items.map(
            (t) => InkWell(
              onTap: t.$2 == 'Contact Support'
                  ? () => _openSupportChat()
                  : (t.$3 != null ? () => context.push(t.$3!) : null),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
                child: Row(
                  children: [
                    Icon(t.$1, size: 20, color: const Color(0xFF555555)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t.$2,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    if (t.$4 != null)
                      Text(
                        t.$4!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF000000),
                        ),
                      ),
                    if (t.$3 != null && t.$2 != 'Contact Support')
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Color(0xFFCCCCCC),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openSupportChat() {
    context.push('/support-chat');
  }

  Widget _buildLogoutButton() {
    return _sectionCard(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout, size: 18),
          label: const Text(
            'LOG OUT',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  void _logout() {
    ref.read(authNotifierProvider.notifier).logout();
    context.go('/login');
  }

  // ------------------------------------------------------------
  // DIALOGS
  // ------------------------------------------------------------

  void _showBookingMessage() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 5, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Book ${(_profile?['businessName'] ?? _profile?['user']?['name'] ?? _pro['name'] ?? 'Professional')}',
                style: TextStyle(
                  color: textColor,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a service to continue with your booking.',
                style: TextStyle(color: secondaryText, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCalendar() {
    showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now(),
    );
  }
}
