import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/config_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../auth/presentation/providers/auth_notifier.dart';
import '../../reels/data/repositories/reel_repository.dart';
import '../../reels/data/models/reel_model.dart';
import '../../reels/presentation/widgets/reels_widget.dart';
import '../data/professional_model.dart';
import '../presentation/discovery_provider.dart';
import 'widgets/opening_hours_display.dart';
import 'widgets/upcoming_appointment.dart';
import 'widgets/services_reviews_grid.dart';
import 'widgets/portfolio_gallery.dart';
import 'widgets/bottom_sticky_booking_bar.dart';
import 'widgets/similar_professionals_carousel.dart';
import 'widgets/location_map_card.dart';
import 'widgets/policies_section.dart';

class ProfessionalProfileScreen extends ConsumerStatefulWidget {
  final String professionalId;

  const ProfessionalProfileScreen({super.key, required this.professionalId});

  @override
  ConsumerState<ProfessionalProfileScreen> createState() =>
      _ProfessionalProfileScreenState();
}

class _ProfessionalProfileScreenState
    extends ConsumerState<ProfessionalProfileScreen> {
  bool _isFavorited = false;
  List<Reel> _reels = [];
  bool _isLoadingReels = false;
  final ReelRepository _reelRepository = ReelRepository();

  @override
  void initState() {
    super.initState();
    addToRecentlyViewed(widget.professionalId);
    _loadFavoriteStatus();
    _loadReels();
  }

  Future<void> _loadReels() async {
    setState(() => _isLoadingReels = true);
    try {
      final reels = await _reelRepository.getReelsByProfessional(
        widget.professionalId,
      );
      if (mounted) {
        setState(() => _reels = reels.where((r) => !r.isPhoto).toList());
      }
    } catch (e) {
      print('Error loading reels: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingReels = false);
      }
    }
  }

  Future<void> _loadFavoriteStatus() async {
    try {
      final resp = await ApiService.dio.get('/favorites');
      final list = resp.data['data'] as List<dynamic>;
      setState(() {
        _isFavorited = list.any(
          (f) =>
              (f as Map<String, dynamic>)['professional']?['id'] ==
              widget.professionalId,
        );
      });
    } catch (_) {}
  }

  Future<void> _toggleFavorite(String professionalId) async {
    try {
      if (_isFavorited) {
        await ApiService.dio.delete('/favorites/$professionalId');
      } else {
        await ApiService.dio.post(
          '/favorites',
          data: {'professionalId': professionalId},
        );
      }
      setState(() => _isFavorited = !_isFavorited);
    } catch (_) {}
  }

  void _shareProfile(ProfessionalModel professional) {
    final name = professional.businessName ?? professional.name;
    final url = 'https://glaya.space/professional/${professional.id}';
    Share.share('Check out $name on Glaya! $url');
  }

  @override
  Widget build(BuildContext context) {
    final professionalAsync = ref.watch(
      salonProfileProvider(widget.professionalId),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F0F4),
      body: professionalAsync.when(
        data: (professional) => _buildProfile(context, professional),
        loading: () => const Center(
          child: CircularProgressIndicator(color: GlayaColors.berry),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Error loading profile',
                style: TextStyle(fontSize: 16, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.refresh(salonProfileProvider(widget.professionalId)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlayaColors.berry,
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfile(BuildContext context, ProfessionalModel professional) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull;
    final isOwnProfile = user?.professionalId == professional.id;

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            // Header - matches React profile-header
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Row(
                        children: [
                          Icon(Icons.arrow_back, size: 20, color: Color(0xFF1A1A1A)),
                          SizedBox(width: 8),
                          Text(
                            'Back',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Header actions
                    _buildIconButton(
                      icon: _isFavorited ? Icons.favorite : Icons.favorite_border,
                      onPressed: () => _toggleFavorite(professional.id),
                    ),
                    const SizedBox(width: 8),
                    _buildIconButton(
                      icon: Icons.share,
                      onPressed: () => _shareProfile(professional),
                    ),
                  ],
                ),
              ),
            ),
            // Hero Section - matches React profile-hero
            SliverToBoxAdapter(
              child: _buildHeroSection(context, professional, isDesktop, isOwnProfile),
            ),
            // About Section
            SliverToBoxAdapter(
              child: _buildAboutSection(professional, isOwnProfile),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            // Quick Info Grid - UpcomingAppointment, OpeningHours, Reels
            SliverToBoxAdapter(
              child: _buildQuickInfoGrid(professional, isDesktop, isOwnProfile),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            // Services & Reviews 2-column grid
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ServicesReviewsGrid(professional: professional),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            // Portfolio Section
            SliverToBoxAdapter(
              child: _buildPortfolioSection(professional, isOwnProfile),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            // Location Map
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: LocationMapCard(professional: professional),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            // Policies
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: PoliciesSection(professional: professional),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            // Similar Professionals
            SliverToBoxAdapter(
              child: SimilarProfessionalsCarousel(
                category: professional.category,
                excludeId: professional.id,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
        // Bottom bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: BottomStickyBookingBar(professional: professional),
        ),
      ],
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onPressed}) {
    return Material(
      color: const Color(0xFFF5F5F5),
      shape: const CircleBorder(side: BorderSide(color: Color(0xFFEEEEEE))),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: const Color(0xFF1A1A1A)),
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, ProfessionalModel professional, bool isDesktop, bool isOwnProfile) {
    final configService = ConfigService();
    final photoUrl = professional.photoUrl != null
        ? configService.replaceLocalhost(professional.photoUrl!)
        : null;
    final firstName = professional.name.split(' ').first;
    final rating = professional.trustScore > 0 ? (professional.trustScore / 20).toStringAsFixed(1) : '0.0';
    final reviewCount = professional.totalReviews;
    final category = professional.categories.isNotEmpty
        ? professional.categories.join(', ')
        : professional.category;
    final location = professional.displayArea ?? 'Location not set';

    if (isDesktop) {
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFFFCE4EC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left side - photo and info
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  // Photo
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: photoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: photoUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => _buildPhotoPlaceholder(),
                              errorWidget: (_, __, ___) => _buildPhotoPlaceholder(),
                            )
                          : _buildPhotoPlaceholder(),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row with name and verification
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                firstName,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (professional.verificationStatus == 'approved') ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.verified, color: Color(0xFF10B981), size: 24),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
                        ),
                        const SizedBox(height: 8),
                        // Rating
                        Row(
                          children: [
                            const Icon(Icons.star, color: Color(0xFFF59E0B), size: 16),
                            const SizedBox(width: 4),
                            Text(rating, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                            const SizedBox(width: 4),
                            Text('($reviewCount reviews)', style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Location
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF666666)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(location, style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
                            ),
                            if (isOwnProfile)
                              IconButton(
                                icon: const Icon(Icons.edit, size: 12, color: GlayaColors.berry),
                                onPressed: () {},
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 32),
            // Right side - Trust Score
            Expanded(
              flex: 2,
              child: _buildTrustScoreCard(professional),
            ),
          ],
        ),
      );
    }

    // Mobile layout - stacked
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE4EC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Photo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _buildPhotoPlaceholder(),
                          errorWidget: (_, __, ___) => _buildPhotoPlaceholder(),
                        )
                      : _buildPhotoPlaceholder(),
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            firstName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (professional.verificationStatus == 'approved') ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: Color(0xFF10B981), size: 20),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(category, style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFF59E0B), size: 14),
                        const SizedBox(width: 4),
                        Text(rating, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                        const SizedBox(width: 4),
                        Text('($reviewCount)', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF666666)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(location, style: const TextStyle(fontSize: 12, color: Color(0xFF666666)), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTrustScoreCard(professional),
        ],
      ),
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      color: const Color(0xFFFCE4EC),
      child: const Center(
        child: Icon(Icons.check_circle, color: GlayaColors.berry, size: 48),
      ),
    );
  }

  Widget _buildTrustScoreCard(ProfessionalModel professional) {
    final rating = professional.trustScore > 0 ? (professional.trustScore / 20).toStringAsFixed(1) : '0.0';
    final totalReviews = professional.totalReviews;
    final trustScore = professional.trustScore;
    final totalBookings = professional.totalBookings;
    final yearsActive = professional.createdAt != null
        ? DateTime.now().year - professional.createdAt!.year
        : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          // Score badge
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: GlayaColors.berry.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('⭐', style: TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rating,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
                    ),
                    const Text('OUT OF 5', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF888888), letterSpacing: 0.5)),
                    Text('Based on $totalReviews reviews', style: const TextStyle(fontSize: 11, color: Color(0xFF666666))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats grid
          Row(
            children: [
              _buildStatItem('Trust Score', '$trustScore', Icons.access_time),
              _buildStatItem('Bookings', '$totalBookings', Icons.event_available),
              _buildStatItem('Reviews', '$totalReviews', Icons.star),
              _buildStatItem('Years', '$yearsActive', Icons.emoji_events),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: GlayaColors.berry),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
        ],
      ),
    );
  }

  Widget _buildAboutSection(ProfessionalModel professional, bool isOwnProfile) {
    final bio = professional.bio ?? '';
    final yearsActive = professional.createdAt != null
        ? DateTime.now().year - professional.createdAt!.year
        : 0;
    final rating = professional.trustScore > 0 ? (professional.trustScore / 20).toStringAsFixed(1) : '0.0';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
              ),
              if (isOwnProfile)
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.edit, size: 16, color: GlayaColors.berry),
                  label: const Text('Edit', style: TextStyle(color: GlayaColors.berry, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bio.isNotEmpty ? bio : 'No bio added yet.',
            style: const TextStyle(fontSize: 14, color: Color(0xFF666666), height: 1.6),
          ),
          const SizedBox(height: 20),
          // Stats grid
          Row(
            children: [
              _buildAboutStat('${professional.totalBookings}', 'Bookings'),
              _buildAboutStat('$yearsActive', 'Years Active'),
              _buildAboutStat(rating, 'Rating'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAboutStat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: GlayaColors.berry)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickInfoGrid(ProfessionalModel professional, bool isDesktop, bool isOwnProfile) {
    final widgets = <Widget>[
      UpcomingAppointment(professionalId: professional.id, isOwnProfile: isOwnProfile),
      OpeningHoursDisplay(professionalId: professional.id, isOwnProfile: isOwnProfile),
      _buildReelsCard(),
    ];

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: widgets[0]),
            const SizedBox(width: 12),
            Expanded(child: widgets[1]),
            const SizedBox(width: 12),
            Expanded(child: widgets[2]),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          widgets[0],
          const SizedBox(height: 12),
          widgets[1],
          const SizedBox(height: 12),
          widgets[2],
        ],
      ),
    );
  }

  Widget _buildReelsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reels', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 12),
          if (_isLoadingReels)
            const Center(child: CircularProgressIndicator(color: GlayaColors.berry))
          else if (_reels.isEmpty)
            const Text('No reels yet', style: TextStyle(fontSize: 13, color: Color(0xFF888888)))
          else
            SizedBox(
              height: 200,
              child: ReelsWidget(reels: _reels),
            ),
        ],
      ),
    );
  }

  Widget _buildPortfolioSection(ProfessionalModel professional, bool isOwnProfile) {
    final hasPortfolio = professional.portfolioUrls != null && professional.portfolioUrls!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Portfolio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
              ),
              if (isOwnProfile)
                TextButton.icon(
                  onPressed: () => context.push('/portfolio'),
                  icon: const Icon(Icons.edit, size: 16, color: GlayaColors.berry),
                  label: const Text('Manage', style: TextStyle(color: GlayaColors.berry, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasPortfolio)
            _buildEmptyState(Icons.image_outlined, 'No portfolio photos yet')
          else
            PortfolioGallery(
              portfolioUrls: professional.portfolioUrls,
              professionalId: professional.id,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 32, color: const Color(0xFFCCCCCC)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(fontSize: 14, color: Color(0xFF888888))),
        ],
      ),
    );
  }
}
