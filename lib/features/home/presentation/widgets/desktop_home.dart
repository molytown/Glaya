import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/providers/location_provider.dart';
import '../../../../shared/services/config_service.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../discovery/data/professional_model.dart';
import '../../../discovery/presentation/discovery_provider.dart';
import '../../../reels/data/models/reel_model.dart';
import '../../../reels/presentation/widgets/reels_widget.dart';
import '../../controller/home_controller.dart';
import '../widgets/billboard.dart';
import '../widgets/category_professionals_carousel.dart';
import '../widgets/exclusive_offers.dart';
import '../widgets/hero_banner.dart';
import '../widgets/how_it_works.dart';
import '../widgets/just_finished_section.dart';
import '../widgets/loading_home.dart';
import '../widgets/photo_reels_widget.dart';
import '../widgets/professional_card.dart';
import '../widgets/home_utils.dart';
import '../../../../shared/widgets/verification_badge.dart';

// React index.css design tokens
const Color _pink = Color(0xFFE91E8C);
const Color _pinkBg = Color(0xFFFFF0F5);
const Color _pinkLight = Color(0xFFFCE4EC);
const Color _textDark = Color(0xFF1A1A2E);
const Color _textGray = Color(0xFF6B7280);
const Color _textLight = Color(0xFF9CA3AF);
const Color _offWhite = Color(0xFFF9FAFB);
const Color _border = Color(0xFFE5E7EB);
const double _radius = 12;

BoxDecoration _cardDeco({double radius = _radius}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _border),
      boxShadow: const [
        BoxShadow(
            color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1)),
      ],
    );

/// Desktop home body — mirrors React `HomePage.jsx` desktop layout:
///   home-top        : Sidebar | Hero + CatBar | Featured + Pro Banner
///   home-content-row: Top Rated | Glam Reels
///   category-row    : Glam Photos (span 2) | App Download
///   category-row    : Just Finished | Popular Services | Home Service Pros
///   category-row    : Top Makeup | Top Hair | Top Nails
///   home-bottom-row : How It Works | Reviews | Exclusive Offers
///   trust-bar
class DesktopHomeBody extends ConsumerWidget {
  final List<Reel> reels;
  final bool isLoadingReels;

  const DesktopHomeBody({
    super.key,
    required this.reels,
    required this.isLoadingReels,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // React .home-page padding: 16px 150px (>1200px) / 16px 40px (1024–1200)
        final pad = w > 1200 ? 150.0 : 40.0;
        final cw = w - pad * 2;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, 16, pad, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopRow(context, ref, w, cw),
              const SizedBox(height: 20),
              _buildContentRow(context, ref, w, cw),
              const SizedBox(height: 20),
              _buildGlamRow(context, cw),
              const SizedBox(height: 20),
              _buildProsRow(context, ref, cw),
              const SizedBox(height: 20),
              _buildCategoryRow(context, cw),
              const SizedBox(height: 20),
              _buildBottomRow(context, ref, w, cw),
              const SizedBox(height: 20),
              const _TrustBar(),
            ],
          ),
        );
      },
    );
  }

  // ── SECTION 1: Sidebar | Hero + CatBar | Featured + Banner ──────────────
  Widget _buildTopRow(
      BuildContext context, WidgetRef ref, double w, double cw) {
    // React .home-top grid: 260px 1fr 320px (>1400)
    //   ≤1400: 300px 1fr 380px · ≤1200: 240px 1fr 300px · ≤1024: right hidden
    final sideW = w > 1400 ? 260.0 : (w > 1200 ? 300.0 : 240.0);
    final rightW = w > 1400 ? 320.0 : (w > 1200 ? 380.0 : 300.0);
    final showRight = w > 1024;

    const heroH = 424.0;
    const catH = 110.0;
    const centerGap = 12.0;
    final topH = heroH + centerGap + catH;

    final heroAsync = ref.watch(heroSlidesProvider);

    return SizedBox(
      height: topH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: sideW, child: const HomeBillboard()),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                heroAsync.when(
                  data: (slides) =>
                      HomeHeroBanner(slides: slides, height: heroH),
                  loading: () => const HomeLoadingPlaceholder(height: heroH),
                  error: (_, __) =>
                      const HomeHeroBanner(slides: [], height: heroH),
                ),
                const SizedBox(height: centerGap),
                const _CatBar(),
              ],
            ),
          ),
          if (showRight) ...[
            const SizedBox(width: 16),
            SizedBox(
              width: rightW,
              child: const _RightColumn(),
            ),
          ],
        ],
      ),
    );
  }

  // ── SECTION 2: Top Rated | Glam Reels ───────────────────────────────────
  Widget _buildContentRow(
      BuildContext context, WidgetRef ref, double w, double cw) {
    final topRatedAsync = ref.watch(topRatedProfessionalsProvider);
    // React .home-content-row: 503px 1fr (gap 75px)
    final colW = w > 1350 ? 503.0 : (cw * 0.45).clamp(360.0, 503.0);
    final gap = w > 1350 ? 75.0 : 32.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: colW,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                title: 'Top Rated Professionals',
                route: '/search',
              ),
              topRatedAsync.when(
                data: (pros) => pros.isEmpty
                    ? const SizedBox.shrink()
                    : TopRatedProfessionalsCarousel(
                        professionals: pros,
                        visibleCount: 3,
                        cardAspectRatio: 9 / 16,
                      ),
                loading: () => const HomeLoadingPlaceholder(height: 280),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: isLoadingReels
              ? const HomeLoadingPlaceholder(height: 200)
              : LayoutBuilder(
                  builder: (context, rc) {
                    // 6 reel cards visible, side-scrollable; card keeps the
                    // 120:200 aspect ratio via ReelsWidget.cardWidth.
                    final cardW = (rc.maxWidth / 6 - 12).clamp(90.0, 220.0);
                    return ReelsWidget(
                      reels: reels,
                      cardWidth: cardW,
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── SECTION 2A: Glam Photos (span 2) | App Download ──────────────────────
  Widget _buildGlamRow(BuildContext context, double cw) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(flex: 2, child: PhotoReelsWidget()),
        const SizedBox(width: 20),
        const Expanded(flex: 1, child: ExclusiveOffersSection()),
      ],
    );
  }

  // ── SECTION 2B: Just Finished | Popular Services | Home Service Pros ────
  Widget _buildProsRow(BuildContext context, WidgetRef ref, double cw) {
    final popularServicesAsync = ref.watch(popularServicesProvider);
    final lat = ref.watch(locationProvider).hasLocation
        ? ref.watch(locationProvider).lat!
        : 3.848;
    final lng = ref.watch(locationProvider).hasLocation
        ? ref.watch(locationProvider).lng!
        : 11.502;
    final homeServiceAsync =
        ref.watch(homeServiceProfessionalsProvider((lat: lat, lng: lng)));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(child: JustFinishedSection()),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                title: 'Popular Services',
                route: '/book',
              ),
              popularServicesAsync.when(
                data: (items) => _ServicesColumn(items: items),
                loading: () => const HomeLoadingPlaceholder(height: 300),
                error: (_, __) => const _ServicesColumn(items: []),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                title: 'Home Service Pros',
                route: '/search',
              ),
              homeServiceAsync.when(
                data: (pros) => pros.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          for (final pro in pros.take(3))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ProListRow(
                                professional: pro,
                                large: true,
                                bookLabel: 'Book Now',
                              ),
                            ),
                        ],
                      ),
                loading: () => const HomeLoadingPlaceholder(height: 300),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── SECTION 2C: Top Makeup | Top Hair | Top Nails ────────────────────────
  Widget _buildCategoryRow(BuildContext context, double cw) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _CategoryColumn(
            title: 'Top Makeup Artists',
            categoryName: 'Makeup',
            serviceId: 'makeup',
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _CategoryColumn(
            title: 'Top Hair Stylists',
            categoryName: 'Hair',
            serviceId: 'hair',
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _CategoryColumn(
            title: 'Top Manicure & Pedicure Artists',
            categoryName: 'Nails',
            serviceId: 'nails',
          ),
        ),
      ],
    );
  }

  // ── SECTION 3: How It Works | Reviews | Recommended For You ──────────────
  Widget _buildBottomRow(
      BuildContext context, WidgetRef ref, double w, double cw) {
    // React .home-bottom-row: 1fr 450px 462px (≤1200: 1fr 280px 240px)
    final col2W = w > 1350 ? 450.0 : 280.0;
    final col3W = w > 1350 ? 462.0 : 240.0;
    final recommendedAsync = ref.watch(recommendedProfessionalsProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(child: HowItWorksSection()),
        const SizedBox(width: 20),
        SizedBox(width: col2W, child: const _ReviewsSection()),
        const SizedBox(width: 20),
        SizedBox(
          width: col3W,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                title: 'Recommended For You',
                route: '/search',
              ),
              recommendedAsync.when(
                data: (pros) => pros.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          for (final pro in pros.take(4))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ProListRow(
                                professional: pro,
                                bookLabel: 'Book',
                              ),
                            ),
                        ],
                      ),
                loading: () => const HomeLoadingPlaceholder(height: 300),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Shared section header (React .section-header > .section-title + .view-all)
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? route;

  const _SectionHeader({
    required this.title,
    this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textDark,
              letterSpacing: -0.1,
            ),
          ),
          if (route != null)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => context.push(route!),
                child: const Row(
                  children: [
                    Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _pink,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 13, color: _pink),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Category icon bar — React CAT_ICONS + .cat-bar ────────────────────────
class _CatBar extends ConsumerWidget {
  const _CatBar();

  static const _items = [
    ('Hair', Icons.content_cut, Color(0xFFFCE4EC)),
    ('Nails', Icons.star_outline, Color(0xFFEDE7F6)),
    ('Skincare', Icons.auto_awesome_outlined, Color(0xFFE0F2F1)),
    ('Makeup', Icons.emoji_emotions_outlined, Color(0xFFFFF8E1)),
    ('Spa & Body', Icons.fitness_center_outlined, Color(0xFFE8F5E9)),
    ('Barbers', Icons.person_outline, Color(0xFFE3F2FD)),
    ('Brows & Lashes', Icons.visibility_outlined, Color(0xFFF3E5F5)),
    ('More', Icons.chevron_right, Color(0xFFF5F5F5)),
  ];

  void _select(
      BuildContext context, WidgetRef ref, String label, String? current) {
    if (label == 'More') {
      ref.read(selectedCategoryProvider.notifier).state = null;
      return;
    }
    final isActive = current == label;
    ref.read(selectedCategoryProvider.notifier).state = isActive ? null : label;
    if (!isActive) {
      context.push('/search?category=${Uri.encodeComponent(label)}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoryProvider);

    return Container(
      height: 110,
      decoration: _cardDeco(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          for (final item in _items)
            Expanded(
              child: _CatBarItem(
                label: item.$1,
                icon: item.$2,
                bg: item.$3,
                isActive: selected == item.$1,
                onTap: () => _select(context, ref, item.$1, selected),
              ),
            ),
        ],
      ),
    );
  }
}

class _CatBarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final bool isActive;
  final VoidCallback onTap;

  const _CatBarItem({
    required this.label,
    required this.icon,
    required this.bg,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? _pinkBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: _pink),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? _pink : _textDark,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Right column — Featured pros + Become-a-Pro / Premium banner ──────────
class _RightColumn extends ConsumerWidget {
  const _RightColumn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final recommendedAsync = ref.watch(recommendedProfessionalsProvider);
    final topRatedAsync = ref.watch(topRatedProfessionalsProvider);

    // React: featuredPros.slice(0,3) else topRated slice(0,3)
    final featured = recommendedAsync.valueOrNull;
    final pros = (featured != null && featured.isNotEmpty)
        ? featured.take(3).toList()
        : (topRatedAsync.valueOrNull ?? []).take(3).toList();

    final isPro = user?.role == 'professional' || user?.role == 'both';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Featured section card
          Container(
            decoration: _cardDeco(),
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Featured',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => context.push('/search'),
                        child: const Row(
                          children: [
                            Text(
                              'View all',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _pink,
                              ),
                            ),
                            Icon(Icons.chevron_right, size: 13, color: _pink),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (pros.isEmpty)
                  recommendedAsync.isLoading || topRatedAsync.isLoading
                      ? const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : const SizedBox(height: 8)
                else
                  for (final pro in pros)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ProListRow(
                        professional: pro,
                        bookLabel: 'Book',
                      ),
                    ),
              ],
            ),
          ),
          // Become a Professional / Glaya Premium banner
          if (!isPro) const _BecomeProBanner() else const _PremiumBanner(),
        ],
      ),
    );
  }
}

// ── Compact horizontal pro row — React .pro-list-card ─────────────────────
class _ProListRow extends StatelessWidget {
  final ProfessionalModel professional;
  final bool large;
  final String bookLabel;

  const _ProListRow({
    required this.professional,
    this.large = false,
    this.bookLabel = 'Book',
  });

  @override
  Widget build(BuildContext context) {
    final pro = professional;
    final rating = pro.avgRating ?? professionalRating(pro.trustScore);
    final photoSize = large ? 84.0 : 56.0;
    final category = pro.categories.isNotEmpty
        ? pro.categories.take(2).join(' • ')
        : pro.category;
    final location = pro.displayArea ??
        (pro.distance != null
            ? '${pro.distance!.toStringAsFixed(1)} km away'
            : null);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push('/professional/${pro.id}'),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: large ? 12 : 8, vertical: large ? 10 : 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: photoSize,
                  height: photoSize,
                  child: (pro.photoUrl?.isNotEmpty ?? false)
                      ? CachedNetworkImage(
                          imageUrl:
                              ConfigService().replaceLocalhost(pro.photoUrl!),
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _photoPlaceholder(),
                        )
                      : _photoPlaceholder(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            pro.name.split(' ').first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        VerificationBadge(
                            subscriptionType: pro.subscriptionType),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: _textLight),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(
                          '★ ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        Text(
                          '${rating.toStringAsFixed(1)} (${pro.totalReviews})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        if (location != null) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.location_on,
                              size: 9, color: _textLight),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: _textLight),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => context.push('/professional/${pro.id}?book=1'),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _pink,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      bookLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 14, color: _textLight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoPlaceholder() => Container(
        color: _pinkLight,
        child: const Icon(Icons.person, size: 20, color: _pink),
      );
}

// ── Become a Professional banner — React .become-prof-banner ──────────────
class _BecomeProBanner extends StatelessWidget {
  const _BecomeProBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE91E8C),
            Color(0xFFC2185B),
            Color(0xFF7209B7),
            Color(0xFFB5179E),
            Color(0xFFFF006E),
            Color(0xFF9C27B0),
          ],
        ),
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Become a Professional',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Join Glaya and grow your beauty business.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xE6FFFFFF),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => context.push('/become-professional'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Join Now',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE91E8C),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.person_outline, size: 60, color: Colors.white),
        ],
      ),
    );
  }
}

// ── Glaya Premium banner — React .subscription-banner (pro users) ─────────
class _PremiumBanner extends StatelessWidget {
  const _PremiumBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFD700),
            Color(0xFFFFC107),
            Color(0xFFFF8F00),
            Color(0xFFE65100),
          ],
        ),
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.4),
            blurRadius: 28,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Glaya Premium',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3E2723),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Get exclusive benefits and grow your business.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF5D4037)),
                ),
                const SizedBox(height: 16),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => context.push('/premium'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5D4037),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text(
                        'Upgrade Now',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.auto_awesome, size: 60, color: Color(0xFFFFF8E1)),
        ],
      ),
    );
  }
}

// ── Popular Services column — services-list + carousel ────────────────────
class _ServicesColumn extends ConsumerWidget {
  final List<Map<String, dynamic>> items;

  const _ServicesColumn({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = items.take(4).toList();
    if (services.isEmpty) return const SizedBox.shrink();

    // React desktop shows only .services-list — .services-carousel is
    // display:none above 768px, so no card grid here.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final svc in services) _ServiceRow(service: svc),
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final Map<String, dynamic> service;

  const _ServiceRow({required this.service});

  @override
  Widget build(BuildContext context) {
    final name = (service['name'] ?? service['title'] ?? 'Service').toString();
    final priceValue = service['price'] ?? service['priceFrom'];
    final currency = service['currency']?.toString() ?? 'XAF';
    final rating = service['rating'] ?? service['avgRating'];
    final reviewCount = service['reviewCount'] ?? service['reviewsCount'];
    final imageUrl = service['imageUrl']?.toString();
    final pro = service['professional'] as Map<String, dynamic>?;
    final proId = pro?['id']?.toString();

    void open() {
      if (proId != null && proId.isNotEmpty) {
        context.push('/professional/$proId');
      } else {
        context.push('/search?q=${Uri.encodeComponent(name)}');
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 70,
              height: 70,
              child: (imageUrl?.isNotEmpty ?? false)
                  ? CachedNetworkImage(
                      imageUrl: ConfigService().replaceLocalhost(imageUrl!),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _svcPlaceholder(),
                    )
                  : _svcPlaceholder(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  priceValue != null
                      ? '$currency ${priceValue is num ? priceValue.toStringAsFixed(0) : priceValue}+'
                      : '',
                  style: const TextStyle(fontSize: 12, color: _textGray),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Text(
                      '★ ',
                      style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B)),
                    ),
                    Text(
                      rating != null
                          ? (rating is num
                              ? rating.toStringAsFixed(1)
                              : rating.toString())
                          : '4.8',
                      style: const TextStyle(fontSize: 12, color: _textDark),
                    ),
                    if (reviewCount != null)
                      Text(
                        ' ($reviewCount)',
                        style: const TextStyle(fontSize: 12, color: _textLight),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: open,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: _pink,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Book',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _svcPlaceholder() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFCE4EC), Color(0xFFF8BBD0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Icon(Icons.content_cut, size: 16, color: _pink),
      );
}

// ── Category column — header + CategoryProfessionalsCarousel ──────────────
class _CategoryColumn extends StatelessWidget {
  final String title;
  final String categoryName;
  final String serviceId;

  const _CategoryColumn({
    required this.title,
    required this.categoryName,
    required this.serviceId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title, route: '/search'),
        CategoryProfessionalsCarousel(
          categoryName: categoryName,
          serviceId: serviceId,
        ),
      ],
    );
  }
}

// ── Reviews — React renderReviewsSection driven by customerReviewsProvider ─
class _ReviewsSection extends ConsumerStatefulWidget {
  const _ReviewsSection();

  @override
  ConsumerState<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends ConsumerState<_ReviewsSection> {
  int _index = 0;

  static const _fallback = [
    {
      'reviewerName': 'Adaeze N.',
      'rating': 5,
      'comment':
          "The best beauty app I've used! Found amazing professionals and the booking process is so easy.",
      'createdAt': '2 days ago',
    },
    {
      'reviewerName': 'Fatima K.',
      'rating': 5,
      'comment':
          'Booked a makeup artist in 5 minutes. She was professional and on time. Glaya is amazing!',
      'createdAt': '3 days ago',
    },
    {
      'reviewerName': 'Chioma B.',
      'rating': 5,
      'comment':
          'My nails look fantastic! Great service and very affordable. Will definitely book again.',
      'createdAt': '1 week ago',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(customerReviewsProvider);

    return reviewsAsync.when(
      data: (reviews) {
        final list = reviews.isNotEmpty
            ? reviews
            : _fallback.cast<Map<String, dynamic>>();
        final idx = _index % list.length;
        final rev = list[idx];
        final name = (rev['reviewerName'] ?? rev['name'] ?? 'User').toString();
        final rating = (rev['rating'] is num)
            ? (rev['rating'] as num).toInt()
            : int.tryParse('${rev['rating']}') ?? 5;
        final comment = (rev['comment'] ?? rev['review'] ?? '').toString();
        final createdAt =
            (rev['createdAt'] ?? rev['created_at'] ?? '').toString();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
                title: 'Why Customers Love Glaya', route: '/reviews'),
            Container(
              decoration: _cardDeco(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: _pink,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: _textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  Icons.star,
                                  size: 12,
                                  color: i < rating
                                      ? const Color(0xFFF59E0B)
                                      : _border,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (createdAt.isNotEmpty)
                        Text(
                          createdAt,
                          style:
                              const TextStyle(fontSize: 11, color: _textLight),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '"$comment"',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: _textGray,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ReviewNavButton(
                  icon: Icons.chevron_left,
                  onTap: () => setState(
                      () => _index = (_index - 1 + list.length) % list.length),
                ),
                Row(
                  children: List.generate(
                    list.length,
                    (i) => GestureDetector(
                      onTap: () => setState(() => _index = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: i == idx ? 20 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == idx ? _pink : _border,
                          borderRadius:
                              BorderRadius.circular(i == idx ? 4 : 3.5),
                        ),
                      ),
                    ),
                  ),
                ),
                _ReviewNavButton(
                  icon: Icons.chevron_right,
                  onTap: () =>
                      setState(() => _index = (_index + 1) % list.length),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader(
              title: 'Why Customers Love Glaya', route: '/reviews'),
          Container(
            decoration: _cardDeco(),
            padding: const EdgeInsets.all(16),
            height: 140,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _ReviewNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ReviewNavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _offWhite,
            shape: BoxShape.circle,
            border: Border.all(color: _border),
          ),
          child: Icon(icon, size: 14, color: _textGray),
        ),
      ),
    );
  }
}

// ── Trust bar — React TRUST + .trust-bar ──────────────────────────────────
class _TrustBar extends StatelessWidget {
  const _TrustBar();

  static const _items = [
    (
      Icons.verified_user_outlined,
      'Verified Professionals',
      'All pros are verified\n& reviewed'
    ),
    (Icons.credit_card, 'Secure Payments', 'Your payments are\n100% secure'),
    (Icons.access_time, 'On-time Guarantee', 'Punctuality\nis our priority'),
    (
      Icons.headset_mic_outlined,
      '24/7 Support',
      "We're here to help\nyou anytime"
    ),
    (Icons.lock_outline, 'Privacy First', 'Your data is safe\nwith us'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final item in _items)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _pinkBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item.$1, size: 18, color: _pink),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$2,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.$3,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _textGray,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
