import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/providers/location_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/widgets/bottom_nav.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../discovery/presentation/discovery_provider.dart';
import '../../controller/home_controller.dart';
import '../../models/category.dart';
import '../widgets/app_header.dart';
import '../widgets/categories.dart';
import '../widgets/exclusive_offers.dart';
import '../widgets/hero_banner.dart';
import '../widgets/home_sections.dart';
import '../widgets/loading_home.dart';
import '../widgets/location_bar.dart';
import '../widgets/premium_banner.dart';
import '../widgets/professional_card.dart';
import '../widgets/search_bar.dart';
import '../widgets/section_title.dart';
import '../widgets/why_customers_love_glaya.dart';
import '../widgets/just_finished_section.dart';
import '../widgets/nearby_professionals_map.dart';
import '../widgets/home_service_carousel.dart';
import '../widgets/category_galleries_carousel.dart';
import '../widgets/category_professionals_carousel.dart';
import '../../../location/presentation/guest_location_picker_screen.dart';
import '../../../reels/presentation/widgets/reels_widget.dart';
import '../../../reels/data/models/reel_model.dart';
import '../../../reels/data/repositories/reel_repository.dart';
import '../../../../shared/services/api_service.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _searchController = TextEditingController();
  double? _lastLat;
  double? _lastLng;
  String? _lastZoneId;
  final ReelRepository _reelRepository = ReelRepository();
  List<dynamic> _reels = [];
  bool _isLoadingReels = false;
  StreamSubscription<String>? _contentSub;
  Timer? _contentDebounce;

  @override
  void initState() {
    super.initState();
    // Delay the initial fetch to avoid modifying provider during build
    Future.microtask(() {
      final locationState = ref.read(locationProvider);
      final lat = locationState.hasLocation ? locationState.lat! : 3.848;
      final lng = locationState.hasLocation ? locationState.lng! : 11.502;
      _lastLat = lat;
      _lastLng = lng;
      ref.read(nearbyProfessionalsProvider.notifier).fetchNearby(lat, lng);
      _loadReels();
    });
    // When background revalidation writes fresh content to the cache, refresh
    // providers so new data appears without restarting the app.
    _contentSub = ApiService.onContentRefreshed.listen((_) {
      _contentDebounce?.cancel();
      _contentDebounce = Timer(const Duration(milliseconds: 800), _refreshFromCache);
    });
  }

  void _refreshFromCache() {
    if (!mounted) return;
    final providers = <Refreshable<dynamic>>[
      heroSlidesProvider,
      topRatedProfessionalsProvider,
      popularServicesProvider,
      customerReviewsProvider,
      trendingNowProvider,
      howItWorksProvider,
      exclusiveOffersProvider,
      premiumPlansProvider,
      recommendedProfessionalsProvider,
      professionalsProvider(null),
    ];
    for (final provider in providers) {
      // refresh (not invalidate) keeps the previous data visible while the
      // provider reloads — invalidate would flash loading placeholders.
      ref.refresh(provider);
    }
    final loc = ref.read(locationProvider);
    final lat = loc.hasLocation ? loc.lat! : 3.848;
    final lng = loc.hasLocation ? loc.lng! : 11.502;
    ref.read(nearbyProfessionalsProvider.notifier).fetchNearby(lat, lng);
    _loadReels();
  }

  Future<void> _loadReels() async {
    // Only show the loading placeholder when there's nothing to display —
    // otherwise keep the current reels visible while refreshing.
    if (_reels.isEmpty) setState(() => _isLoadingReels = true);
    try {
      final loc = ref.read(locationProvider);
      final reels =
          await _reelRepository.getReels(zoneParams: zoneQueryParams(loc));
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

  @override
  void dispose() {
    _contentDebounce?.cancel();
    _contentSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final user = ref.watch(authNotifierProvider).valueOrNull;

    final lat = locationState.hasLocation ? locationState.lat! : 3.848;
    final lng = locationState.hasLocation ? locationState.lng! : 11.502;

    // Trigger nearby professionals fetch when location changes (after build)
    if (_lastLat != lat || _lastLng != lng) {
      _lastLat = lat;
      _lastLng = lng;
      // Use Future.microtask to defer the provider modification
      Future.microtask(() {
        ref.read(nearbyProfessionalsProvider.notifier).fetchNearby(lat, lng);
      });
    }

    // Zone changed → reload zone-scoped reels for the new zone
    final zoneId = locationState.zoneId;
    if (_lastZoneId != zoneId) {
      _lastZoneId = zoneId;
      if (_lastZoneId != null) {
        Future.microtask(_loadReels);
      }
    }

    // Extract neighborhood/street name from full address
    String locationLabel;
    if (locationState.locationName != null &&
        locationState.locationName!.isNotEmpty) {
      final parts = locationState.locationName!.split(',');
      // Use first part (street/neighborhood) if available, otherwise full name
      locationLabel =
          parts.length > 1 ? parts[0].trim() : locationState.locationName!;
    } else {
      locationLabel =
          locationState.hasLocation ? 'Current location' : 'Douala, Cameroon';
    }

    // Show location prompt for guest users without location
    final shouldShowLocationPrompt = user == null && !locationState.hasLocation;

    final heroAsync = ref.watch(heroSlidesProvider);
    final topRatedAsync = ref.watch(topRatedProfessionalsProvider);
    final nearbyAsync = ref.watch(nearbyProfessionalsProvider);
    final homeServiceAsync =
        ref.watch(homeServiceProfessionalsProvider((lat: lat, lng: lng)));
    final popularServicesAsync = ref.watch(popularServicesProvider);
    final trendingNowAsync = ref.watch(trendingNowProvider);
    final recommendedAsync = ref.watch(recommendedProfessionalsProvider);
    final recentlyViewedAsync = ref.watch(recentlyViewedProvider);
    final upcomingAsync = ref.watch(upcomingBookingProvider);

    return Scaffold(
      backgroundColor: GlayaColors.background,
      body: SafeArea(
        child: Column(
          children: [
            HomeAppHeader(
                photoUrl: user?.photoUrl, locationLabel: locationLabel),
            HomeSearchBar(controller: _searchController),
            if (shouldShowLocationPrompt)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [GlayaColors.berry, GlayaColors.roseGold],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Set your location',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Find beauty professionals near you',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/guest-location'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Set',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                color: GlayaColors.berry,
                onRefresh: () => refreshHomeData(ref, lat: lat, lng: lng),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    SliverToBoxAdapter(
                      child: heroAsync.when(
                        data: (slides) => HomeHeroBanner(slides: slides),
                        loading: () =>
                            const HomeLoadingPlaceholder(height: 200),
                        error: (_, __) => const HomeHeroBanner(slides: []),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(
                      child: HomeCategories(
                        categories: HomeCategory.defaults,
                        selectedLabel: selectedCategory,
                        onSelected: (label) => ref
                            .read(selectedCategoryProvider.notifier)
                            .state = label,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(
                      child: _isLoadingReels
                          ? const HomeLoadingPlaceholder(height: 200)
                          : _reels.isNotEmpty
                              ? ReelsWidget(reels: _reels as List<Reel>)
                              : const SizedBox.shrink(),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 28)),
                    _section(
                      titleWidget: const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Top Rated ',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: GlayaColors.textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: 'Professionals',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: GlayaColors.accentPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                      onSeeAll: () => context.push('/search'),
                      child: topRatedAsync.when(
                        data: (pros) =>
                            TopRatedProfessionalsCarousel(professionals: pros),
                        loading: () =>
                            const HomeLoadingPlaceholder(height: 280),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                    const SliverToBoxAdapter(child: JustFinishedSection()),
                    _section(
                      title: 'Popular Services',
                      onSeeAll: () => context.push('/services/popular'),
                      child: popularServicesAsync.when(
                        data: (items) => PopularServicesRow(items: items),
                        loading: () =>
                            const HomeLoadingPlaceholder(height: 160),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                    _section(
                      title: 'Home Service Pros',
                      titleWidget: const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Home Service ',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: GlayaColors.textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: 'Pros',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      subtitle:
                          'They can come or send a stylist over to your home',
                      onSeeAll: () => context.push('/home-service'),
                      child: homeServiceAsync.when(
                        data: (pros) {
                          return pros.isEmpty
                              ? const SizedBox.shrink()
                              : HomeServiceCarousel(professionals: pros);
                        },
                        loading: () {
                          return const HomeLoadingPlaceholder(height: 200);
                        },
                        error: (error, stack) {
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    _section(
                      titleWidget: const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Makeup ',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: GlayaColors.textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: 'Artists',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: GlayaColors.accentPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                      onSeeAll: () => context.push('/service-portfolio/makeup'),
                      child: const CategoryProfessionalsCarousel(
                        categoryName: 'Makeup',
                        serviceId: 'makeup',
                      ),
                    ),
                    _section(
                      titleWidget: const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Hair ',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: GlayaColors.textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: 'Stylist',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: GlayaColors.vibrantPink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      onSeeAll: () => context.push('/service-portfolio/hair'),
                      child: const CategoryProfessionalsCarousel(
                        categoryName: 'Hair',
                        serviceId: 'hair',
                      ),
                    ),
                    _section(
                      titleWidget: const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Nails ',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: GlayaColors.textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: 'Artists',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: GlayaColors.accentPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                      onSeeAll: () => context.push('/service-portfolio/nails'),
                      child: const CategoryProfessionalsCarousel(
                        categoryName: 'Nails',
                        serviceId: 'nails',
                      ),
                    ),
                    const SliverToBoxAdapter(child: BecomeProfessionalBanner()),
                    const SliverToBoxAdapter(child: ReferLoyaltyRow()),
                    _section(
                      title: 'Recommended For You',
                      onSeeAll: () => context.push('/search'),
                      child: recommendedAsync.when(
                        data: (pros) =>
                            RecommendedProfessionalRow(professionals: pros),
                        loading: () =>
                            const HomeLoadingPlaceholder(height: 140),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                    _section(
                      title: 'Nearby Professionals',
                      onSeeAll: () => context.push('/nearby-professionals-map'),
                      child: nearbyAsync.when(
                        data: (pros) => pros.isEmpty
                            ? const SizedBox.shrink()
                            : _DeferredMap(
                                child: NearbyProfessionalsMap(professionals: pros)),
                        loading: () =>
                            const HomeLoadingPlaceholder(height: 180),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                    _section(
                      title: 'Trending Now',
                      showSeeAll: false,
                      child: trendingNowAsync.when(
                        data: (items) => TrendingNowRow(items: items),
                        loading: () =>
                            const HomeLoadingPlaceholder(height: 160),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    const SliverToBoxAdapter(child: ExclusiveOffersSection()),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    const SliverToBoxAdapter(
                        child: WhyCustomersLoveGlayaSection()),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(
                      child: upcomingAsync.when(
                        data: (booking) => booking == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 20, 16, 0),
                                child:
                                    UpcomingAppointmentCard(booking: booking),
                              ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: recentlyViewedAsync.when(
                        data: (list) => list.isEmpty
                            ? const SizedBox.shrink()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 20),
                                  HomeSectionTitle(
                                      title: 'Recently Viewed',
                                      showSeeAll: false),
                                  const SizedBox(height: 12),
                                  ProfessionalCardRow(professionals: list),
                                ],
                              ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 100),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          GlayaBottomNav(currentIndex: 0, userRole: user?.role),
    );
  }

  Widget _section({
    String title = '',
    Widget? titleWidget,
    String? subtitle,
    required Widget child,
    VoidCallback? onSeeAll,
    bool showSeeAll = true,
  }) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: HomeSectionTitle(
                title: title,
                titleWidget: titleWidget,
                subtitle: subtitle,
                onSeeAll: onSeeAll,
                showSeeAll: showSeeAll),
          ),
        ),
        SliverToBoxAdapter(child: child),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }
}

/// Defers mounting of heavy children (e.g. GoogleMap platform view) until
/// the first content frame has settled — avoids multi-second main-thread
/// jank during launch. Shows a same-size placeholder in the meantime.
class _DeferredMap extends StatefulWidget {
  final Widget child;

  const _DeferredMap({required this.child});

  @override
  State<_DeferredMap> createState() => _DeferredMapState();
}

class _DeferredMapState extends State<_DeferredMap> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _ready = true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _ready ? widget.child : const SizedBox(height: 200);
  }
}
