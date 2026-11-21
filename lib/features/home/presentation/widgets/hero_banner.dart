import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/services/config_service.dart';

/// React HeroCarousel replica — src/components/HeroCarousel.jsx + .css
class HomeHeroBanner extends StatefulWidget {
  final List<Map<String, dynamic>> slides;

  /// Fixed height override — React desktop .hero is a fixed 424px tall,
  /// full-width banner. When null the banner keeps React's 16/9 ratio.
  final double? height;

  const HomeHeroBanner({super.key, required this.slides, this.height});

  @override
  State<HomeHeroBanner> createState() => _HomeHeroBannerState();
}

class _HomeHeroBannerState extends State<HomeHeroBanner> {
  final _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  // Mirrors React FALLBACK_SLIDES. ctaLink values are mapped to routes
  // that exist in the Flutter router ('/professionals' and '/offers'
  // have no Flutter equivalent → '/search').
  static const _fallbackSlides = [
    {
      'id': '1',
      'badgeText': 'Glow Up ✨',
      'title': 'Your Beauty,',
      'titlePink': 'Your Way.',
      'subtitle': 'Book trusted beauty professionals\nnear you in minutes.',
      'ctaText': 'Book Now',
      'ctaLink': '/search',
      'bgColor': '#1A0A2E',
      'imageUrl':
          'https://images.unsplash.com/photo-1560066984-138dadb4c035?w=1200&h=600&fit=crop',
    },
    {
      'id': '2',
      'badgeText': 'New ✨',
      'title': 'Top Rated',
      'titlePink': 'Professionals.',
      'subtitle': 'Verified experts ready to serve\nyou at home or in salon.',
      'ctaText': 'Find a Pro',
      'ctaLink': '/search',
      'bgColor': '#0D1B2A',
      'imageUrl':
          'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=1200&h=600&fit=crop',
    },
    {
      'id': '3',
      'badgeText': 'Limited 🎁',
      'title': 'Exclusive',
      'titlePink': 'Offers Inside.',
      'subtitle': 'Get up to 20% off your first\nbooking this week.',
      'ctaText': 'View Offers',
      'ctaLink': '/search',
      'bgColor': '#1C0A1A',
      'imageUrl':
          'https://images.unsplash.com/photo-1487412947147-5cebf100ffc2?w=1200&h=600&fit=crop',
    },
  ];

  List<Map<String, dynamic>> get _items =>
      widget.slides.isEmpty ? _fallbackSlides : widget.slides;

  @override
  void initState() {
    super.initState();
    // React: setInterval(next, 5000)
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _nextSlide());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _nextSlide() {
    if (!mounted || !_pageController.hasClients) return;
    final count = _items.length;
    final next = (_currentPage + 1) % count;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _items.length;

    final pageView = PageView.builder(
      controller: _pageController,
      itemCount: count,
      onPageChanged: (index) => setState(() => _currentPage = index),
      itemBuilder: (_, index) {
        return _HeroSlide(
          slide: _items[index],
          currentIndex: _currentPage,
          totalSlides: count,
          onPageChanged: (i) {
            if (_pageController.hasClients) {
              _pageController.animateToPage(
                i,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            }
          },
        );
      },
    );

    // Desktop: fixed-height full-width banner (React .hero = 424px).
    // Mobile/tablet: React @media (max-width:768px) uses aspect-ratio 16/9
    // with 16px side inset.
    final content = widget.height != null
        ? SizedBox(
            height: widget.height,
            width: double.infinity,
            child: pageView,
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AspectRatio(aspectRatio: 16 / 9, child: pageView),
          );

    return content
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.05, end: 0);
  }
}

class _HeroSlide extends StatelessWidget {
  final Map<String, dynamic> slide;
  final int currentIndex;
  final int totalSlides;
  final Function(int) onPageChanged;

  const _HeroSlide({
    required this.slide,
    required this.currentIndex,
    required this.totalSlides,
    required this.onPageChanged,
  });

  static const _pink = Color(0xFFE91E8C); // React --pink

  Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    return Color(int.tryParse(h, radix: 16) ?? 0xFF1A0A2E);
  }

  @override
  Widget build(BuildContext context) {
    final configService = ConfigService();
    final rawImageUrl = slide['imageUrl'] as String?;

    // Normalize image URL (API may return relative /uploads paths)
    String imageUrl = '';
    if (rawImageUrl != null && rawImageUrl.isNotEmpty) {
      imageUrl = rawImageUrl.startsWith('http')
          ? configService.replaceLocalhost(rawImageUrl)
          : '${configService.socketUrl}$rawImageUrl';
    }

    final bgColor = _parseHexColor(slide['bgColor'] as String?) ??
        const Color(0xFF1A0A2E); // React default hero bg

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      // React .hero: border-radius: var(--radius) = 12px, no shadow
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Background: image cover, or bgColor when no image
            // (React: style={{ background: slide.bgColor }} + <img> overlay)
            Positioned.fill(
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: bgColor),
                    )
                  : Container(color: bgColor),
            ),
            // Gradient overlay — React .hero-overlay
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xBF000000), // rgba(0,0,0,0.75)
                      Color(0x4D000000), // rgba(0,0,0,0.30)
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            // Content — React .hero is flex with align-items:center,
            // .hero-content max-width 460px padding 32px 40px
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 20 : 40,
                  isMobile ? 16 : 32,
                  isMobile ? 20 : 40,
                  isMobile ? 16 : 32,
                ),
                child: SizedBox(
                  width: isMobile ? 220 : 460,
                  child: _buildContent(context, isMobile),
                ),
              ),
            ),
            // Prev/Next nav — React .hero-nav
            _buildNavButton(
              isMobile: isMobile,
              isPrev: true,
              onTap: () => onPageChanged(
                (currentIndex - 1 + totalSlides) % totalSlides,
              ),
            ),
            _buildNavButton(
              isMobile: isMobile,
              isPrev: false,
              onTap: () => onPageChanged((currentIndex + 1) % totalSlides),
            ),
            // Dots — React .hero-dots / .hero-dot
            Positioned(
              bottom: 18,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  totalSlides,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: index == currentIndex ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index == currentIndex
                          ? _pink
                          : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isMobile) {
    final badgeText = slide['badgeText'] as String? ?? '';
    final title = slide['title'] as String? ?? '';
    final titlePink = slide['titlePink'] as String? ?? '';
    final subtitle = slide['subtitle'] as String? ?? '';
    final ctaText = slide['ctaText'] as String? ?? 'Book Now';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // .hero-badge — pill with pink tint border, backdrop blur in React
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 10,
            vertical: isMobile ? 2 : 3,
          ),
          decoration: BoxDecoration(
            color: _pink.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _pink.withValues(alpha: 0.5)),
          ),
          child: Text(
            badgeText,
            style: TextStyle(
              fontSize: isMobile ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: isMobile ? 8 : 12),
        // .hero-title — 36px desktop / 20px mobile, pink second line
        Text(
          title,
          style: TextStyle(
            fontSize: isMobile ? 20 : 36,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: isMobile ? 1.2 : 1.15,
          ),
        ),
        Text(
          titlePink,
          style: TextStyle(
            fontSize: isMobile ? 20 : 36,
            fontWeight: FontWeight.w800,
            color: _pink,
            height: isMobile ? 1.2 : 1.15,
          ),
        ),
        SizedBox(height: isMobile ? 6 : 10),
        // .hero-subtitle — white-space: pre-line (\n renders as break)
        Text(
          subtitle,
          style: TextStyle(
            fontSize: isMobile ? 11 : 13.5,
            color: Colors.white.withValues(alpha: 0.82),
            height: isMobile ? 1.4 : 1.6,
          ),
        ),
        SizedBox(height: isMobile ? 14 : 22),
        // .btn-pink.hero-cta — radius 24, pink shadow
        GestureDetector(
          onTap: () => _handleCtaTap(context),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 0 : 22,
              vertical: isMobile ? 6 : 10,
            ),
            decoration: BoxDecoration(
              color: _pink,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x66E91E8C), // rgba(233,30,140,0.4)
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    ctaText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 10 : 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward,
                  size: isMobile ? 12 : 16,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavButton({
    required bool isMobile,
    required bool isPrev,
    required VoidCallback onTap,
  }) {
    final size = isMobile ? 32.0 : 36.0;
    return Positioned(
      left: isPrev ? (isMobile ? 12 : 16) : null,
      right: isPrev ? null : (isMobile ? 12 : 16),
      top: 0,
      bottom: 0,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(
              isPrev ? Icons.chevron_left : Icons.chevron_right,
              color: Colors.white,
              size: isMobile ? 18 : 20,
            ),
          ),
        ),
      ),
    );
  }

  void _handleCtaTap(BuildContext context) {
    final serviceId = slide['serviceId'] as String?;
    final professionalId = slide['professionalId'] as String?;
    final ctaLink = slide['ctaLink'] as String?;

    if (serviceId != null && professionalId != null) {
      context.push('/book/$professionalId', extra: serviceId);
    } else if (professionalId != null) {
      context.push('/professional/$professionalId');
    } else {
      final fallbackPath =
          (ctaLink != null && ctaLink.startsWith('/')) ? ctaLink : '/search';
      context.push(fallbackPath);
    }
  }
}
