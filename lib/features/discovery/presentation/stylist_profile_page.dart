import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/config_service.dart';
import '../../../../shared/widgets/bottom_nav.dart';
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

  Future<void> _loadProfessionalData() async {
    try {
      final response = await ApiService.dio.get('/professionals/me/dashboard');
      setState(() {
        _professionalData = response.data['data'] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading professional data: $e');
      setState(() => _isLoading = false);
    }
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
    final pro =
        _professionalData?['professional'] as Map<String, dynamic>? ?? {};
    final portfolioUrls = (pro['portfolioUrls'] as List<dynamic>?) ?? [];
    // Filter out null values from portfolioUrls
    final validUrls = portfolioUrls.whereType<String>().toList();
    final coverImage = validUrls.isNotEmpty ? validUrls[0] : null;
    final configService = ConfigService();
    final imageUrl = coverImage != null
        ? (coverImage.startsWith('http')
            ? configService.replaceLocalhost(coverImage)
            : '${configService.socketUrl}$coverImage')
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
    final pro =
        _professionalData?['professional'] as Map<String, dynamic>? ?? {};
    final businessName = pro['businessName'] as String? ?? 'Professional';
    final category = pro['category'] as String? ?? 'Professional';
    final city = pro['city'] as String? ?? 'Unknown';
    final state = pro['state'] as String? ?? '';
    final locationText = city.isNotEmpty ? '$city, $state' : 'Location not set';
    final isVerified = pro['verificationStatus'] == 'approved';
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final isOwner = user?.id != null && user!.id == pro['userId']?.toString();

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
                          '$category  •  Professional',
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
    final user = ref.read(authNotifierProvider).valueOrNull;
    final photoUrl = user?.photoUrl;
    final configService = ConfigService();
    final imageUrl = photoUrl != null
        ? configService.replaceLocalhost(photoUrl)
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
    final pro =
        _professionalData?['professional'] as Map<String, dynamic>? ?? {};
    final avgRating =
        num.tryParse(pro['avgRating']?.toString() ?? '')?.toStringAsFixed(1) ??
            '0.0';
    final totalReviews = (pro['totalReviews'] as num?)?.toInt() ?? 0;
    final totalBookings = (pro['totalBookings'] as num?)?.toInt() ?? 0;
    final trustScore = (pro['trustScore'] as num?)?.toInt() ?? 0;

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
    final pro =
        _professionalData?['professional'] as Map<String, dynamic>? ?? {};
    final isOwner = user?.id != null && user!.id == pro['userId']?.toString();
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
    final pro =
        _professionalData?['professional'] as Map<String, dynamic>? ?? {};
    final bio = pro['bio'] as String? ??
        pro['about'] as String? ??
        "Hi! I'm a professional passionate about providing excellent service. "
            "My goal is to give you a personalized experience and results you'll love.";

    final user = ref.watch(authNotifierProvider).valueOrNull;
    final isOwner = user?.id != null && user!.id == pro['userId']?.toString();

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
            bio,
            style: TextStyle(color: textColor, fontSize: 14, height: 1.55),
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
    final hours = [
      ['Monday', '9:00 AM – 6:00 PM'],
      ['Tuesday', '9:00 AM – 6:00 PM'],
      ['Wednesday', '9:00 AM – 6:00 PM'],
      ['Thursday', '9:00 AM – 6:00 PM'],
      ['Friday', '9:00 AM – 7:00 PM'],
      ['Saturday', '9:00 AM – 5:00 PM'],
      ['Sunday', 'Closed'],
    ];

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
                      'See All (124)',
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
                        '4.8',
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
                          (index) => const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFE7A91C),
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Based on 124 reviews',
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
                      Icons.sentiment_satisfied_alt_outlined,
                      'Great service',
                      '96%',
                    ),
                    _reviewMetric(
                      Icons.favorite_border_rounded,
                      'Professional',
                      '94%',
                    ),
                    _reviewMetric(
                      Icons.thumb_up_alt_outlined,
                      'Highly recommend',
                      '92%',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 12),
          _reviewItem(
            name: 'Jessica M.',
            date: '2 days ago',
            text: 'Alicia did an amazing job with my braids! '
                'She was professional, kind and took her time. '
                'I\'ll definitely be booking again.',
            imageUrl:
                'https://images.unsplash.com/photo-1494790108377-be9c29b29330'
                '?auto=format&fit=crop&w=200&q=80',
          ),
        ],
      ),
    );
  }

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
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(radius: 21, backgroundImage: NetworkImage(imageUrl)),
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
                  (index) => const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFE7A91C),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _sectionCard(
            child: Column(
              children: [
                Text(
                  '4.8',
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
                    (_) => const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFE7A91C),
                      size: 23,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '124 customer reviews',
                  style: TextStyle(color: secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionCard(
            child: Column(
              children: [
                _reviewItem(
                  name: 'Jessica M.',
                  date: '2 days ago',
                  text: 'Alicia did an amazing job with my braids! '
                      'She was professional and very kind.',
                  imageUrl:
                      'https://images.unsplash.com/photo-1494790108377-be9c29b29330'
                      '?auto=format&fit=crop&w=200&q=80',
                ),
                const Divider(height: 30),
                _reviewItem(
                  name: 'Maria T.',
                  date: '1 week ago',
                  text: 'Beautiful work and very professional. '
                      'The entire appointment was smooth.',
                  imageUrl:
                      'https://images.unsplash.com/photo-1544005313-94ddf0286df2'
                      '?auto=format&fit=crop&w=200&q=80',
                ),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _serviceCard(title: 'Box Braids', duration: '2h 30m', price: '\$120'),
          _serviceCard(
            title: 'Natural Hair Styling',
            duration: '1h 30m',
            price: '\$85',
          ),
          _serviceCard(title: 'Hair Coloring', duration: '2h', price: '\$150'),
          _serviceCard(title: 'Silk Press', duration: '1h 45m', price: '\$95'),
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
    final images = [
      'https://images.unsplash.com/photo-1605497788044-5a32c7078486',
      'https://images.unsplash.com/photo-1562322140-8baeececf3df',
      'https://images.unsplash.com/photo-1595950653106-6c9ebd614d3a',
      'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e',
    ];

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
            child: Image.network(images[index], fit: BoxFit.cover),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // LOCATION
  // ------------------------------------------------------------

  Widget _buildLocation() {
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
              child: const Center(
                child: Icon(
                  Icons.location_on,
                  color: Color(0xFFD6006E),
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Alicia B. Styles',
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Los Angeles, California',
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
                'Book Alicia B. Styles',
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
