import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/config_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../reels/data/repositories/reel_repository.dart';
import '../../reels/data/models/reel_model.dart';
import '../../reels/presentation/widgets/reels_widget.dart';
import '../data/professional_model.dart';
import '../presentation/discovery_provider.dart';
import 'widgets/salon_profile_header.dart';
import 'widgets/trust_banner.dart';
import 'widgets/trust_score_card.dart';
import 'widgets/services_section.dart';
import 'widgets/availability_card.dart';
import 'widgets/portfolio_gallery.dart';
import 'widgets/team_section.dart';
import 'widgets/reviews_section.dart';
import 'widgets/about_section.dart';
import 'widgets/location_map_card.dart';
import 'widgets/policies_section.dart';
import 'widgets/similar_professionals_carousel.dart';
import 'widgets/bottom_sticky_booking_bar.dart';

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
    final displayName = professional.businessName ?? professional.name;
    final configService = ConfigService();
    String? coverUrl = professional.photoUrl != null
        ? configService.replaceLocalhost(professional.photoUrl!)
        : null;

    // Extract cover URL from the most recently updated gallery that has media.
    // Backend returns portfolioGalleries newest-first, but we re-sort defensively
    // and skip albums without a usable cover so the profile photo remains the fallback.
    if (professional.portfolioUrls != null &&
        professional.portfolioUrls!.isNotEmpty) {
      final galleries =
          professional.portfolioUrls!.whereType<Map<String, dynamic>>().toList()
            ..sort((a, b) {
              final aTime = DateTime.tryParse(
                    (a['updatedAt'] ?? a['createdAt'])?.toString() ?? '',
                  ) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final bTime = DateTime.tryParse(
                    (b['updatedAt'] ?? b['createdAt'])?.toString() ?? '',
                  ) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              return bTime.compareTo(aTime);
            });

      for (final gallery in galleries) {
        final media = (gallery['media'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList();
        if (media == null || media.isEmpty) continue;

        final coverMedia = gallery['coverMedia'];
        final coverMediaMap =
            coverMedia is Map<String, dynamic> ? coverMedia : null;
        final coverItem = media.firstWhere(
          (m) => m['mediaType'] == 'image',
          orElse: () => media.first,
        );

        final rawCoverUrl = coverMediaMap?['thumbnailUrl'] as String? ??
            coverMediaMap?['mediaUrl'] as String? ??
            coverItem['thumbnailUrl'] as String? ??
            coverItem['mediaUrl'] as String?;
        if (rawCoverUrl != null && rawCoverUrl.isNotEmpty) {
          coverUrl = configService.replaceLocalhost(rawCoverUrl);
          break;
        }
      }
    }

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 240,
              pinned: true,
              floating: false,
              backgroundColor: GlayaColors.berry,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    _isFavorited ? Icons.favorite : Icons.favorite_border,
                    color: Colors.white,
                  ),
                  onPressed: () => _toggleFavorite(professional.id),
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () {},
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: coverUrl ?? '',
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: GlayaColors.berry),
                      errorWidget: (_, __, ___) =>
                          Container(color: GlayaColors.berry),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            GlayaColors.berry.withValues(alpha: 0.3),
                            GlayaColors.berry.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SalonProfileHeader(professional: professional),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: TrustBanner(
                trustScore: professional.trustScore,
                totalBookings: professional.totalBookings,
                avgRating: professional.avgRating ?? 0.0,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: TrustScoreCard(
                trustScore: professional.trustScore,
                totalBookings: professional.totalBookings,
                avgRating: professional.avgRating ?? 0.0,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: ServicesSection(professional: professional),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: AvailabilityCard(availability: professional.availability),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: PortfolioGallery(
                portfolioUrls: professional.portfolioUrls,
                professionalId: professional.id,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: _isLoadingReels
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child:
                            CircularProgressIndicator(color: GlayaColors.berry),
                      ),
                    )
                  : _reels.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ReelsWidget(reels: _reels),
                        )
                      : const SizedBox.shrink(),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: TeamSection(professional: professional)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: ReviewsSection(professional: professional),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: AboutSection(professional: professional)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: LocationMapCard(professional: professional),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: PoliciesSection(professional: professional),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: SimilarProfessionalsCarousel(
                category: professional.category,
                excludeId: professional.id,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: BottomStickyBookingBar(professional: professional),
        ),
      ],
    );
  }
}
