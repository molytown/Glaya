import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/colors.dart';
import '../../../../shared/services/config_service.dart';

class HomeHeroBanner extends StatefulWidget {
  final List<Map<String, dynamic>> slides;

  /// Fixed height override — React desktop .hero is a fixed 424px tall,
  /// full-width banner. When null the banner keeps its 16/8 aspect ratio.
  final double? height;

  const HomeHeroBanner({super.key, required this.slides, this.height});

  @override
  State<HomeHeroBanner> createState() => _HomeHeroBannerState();
}

class _HomeHeroBannerState extends State<HomeHeroBanner> {
  final _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  static const _fallback = {
    'title': 'Glow More,\nPay Less!',
    'subtitle': 'Get 20% OFF on your\nfirst booking',
    'badgeText': 'Special Offer',
    'ctaText': 'Book Now',
    'discountLabel': '20%\nOFF',
    'bgColor': '#FCE4EC',
    'imageUrl':
        'https://images.unsplash.com/photo-1560066984-138dadb4c035?w=800&h=400&fit=crop',
  };

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _nextSlide());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _nextSlide() {
    if (!mounted || !_pageController.hasClients) return;
    final count = widget.slides.isEmpty ? 1 : widget.slides.length;
    final next = (_currentPage + 1) % count;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.slides.isEmpty ? 1 : widget.slides.length;

    final pageView = PageView.builder(
      controller: _pageController,
      itemCount: count,
      onPageChanged: (index) => setState(() => _currentPage = index),
      itemBuilder: (_, index) {
        final slide = widget.slides.isEmpty ? _fallback : widget.slides[index];
        return _HeroSlide(
          slide: slide,
          currentIndex: _currentPage,
          totalSlides: count,
          onPageChanged: (index) {
            if (_pageController.hasClients) {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            }
          },
        );
      },
    );

    // Desktop: fixed-height full-width banner (React .hero = 424px).
    // Mobile/tablet: 16/8 aspect ratio with 16px side inset.
    final banner = widget.height != null
        ? SizedBox(
            height: widget.height,
            width: double.infinity,
            child: pageView,
          )
        : Padding(
            // 16px side inset matches the rest of the home content on all devices.
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AspectRatio(aspectRatio: 16 / 8, child: pageView),
          );

    return banner
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

  @override
  Widget build(BuildContext context) {
    final configService = ConfigService();
    final imageUrl = slide['imageUrl'] as String?;

    // Normalize image URL
    String normalizedImageUrl = imageUrl ?? '';
    if (normalizedImageUrl.isNotEmpty) {
      if (!normalizedImageUrl.startsWith('http')) {
        normalizedImageUrl = '${configService.socketUrl}$normalizedImageUrl';
      }
    }

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: GlayaColors.berry.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Full background image
            Positioned.fill(
              child: normalizedImageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: normalizedImageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          Container(color: GlayaColors.berry),
                    )
                  : Container(
                      color: GlayaColors.berry,
                      child: const Icon(
                        Icons.face_retouching_natural,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
            ),
            // Left-side gradient overlay (matching React design)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFF000000).withValues(alpha: 0.75),
                      Color(0xFF000000).withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            // Content overlay
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 16 : 32,
                  isMobile ? 12 : 24,
                  0,
                  isMobile ? 12 : 16,
                ),
                child: SizedBox(
                  width: isMobile ? null : 400,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Badge
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 6 : 8,
                            vertical: isMobile ? 1.5 : 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFD6006E).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFD6006E)
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            slide['badgeText'] as String? ?? 'Special Offer',
                            style: TextStyle(
                              fontSize: isMobile ? 9 : 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(height: isMobile ? 6 : 8),
                        // Title
                        Text(
                          slide['title'] as String? ?? 'Your Beauty,',
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          slide['titlePink'] as String? ?? 'Your Way.',
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 28,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFD6006E),
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: isMobile ? 4 : 6),
                        // Subtitle
                        Text(
                          slide['subtitle'] as String? ??
                              'Book trusted beauty professionals\nnear you in minutes.',
                          style: TextStyle(
                            fontSize: isMobile ? 10 : 12,
                            color: const Color(0xD2FFFFFF),
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: isMobile ? 10 : 14),
                        // CTA Button
                        GestureDetector(
                          onTap: () {
                            final serviceId = slide['serviceId'] as String?;
                            final professionalId =
                                slide['professionalId'] as String?;
                            final ctaLink = slide['ctaLink'] as String?;

                            print('[HERO] Button tapped');
                            print('[HERO] serviceId: $serviceId');
                            print('[HERO] professionalId: $professionalId');
                            print('[HERO] ctaLink: $ctaLink');

                            // If service is selected, navigate to booking with service pre-selected
                            if (serviceId != null && professionalId != null) {
                              print(
                                  '[HERO] Navigating to booking with service');
                              context.push('/book/$professionalId',
                                  extra: serviceId);
                            }
                            // If only professional is selected, navigate to professional profile
                            else if (professionalId != null) {
                              print(
                                  '[HERO] Navigating to professional profile');
                              context.push('/professional/$professionalId');
                            }
                            // Otherwise, use CTA Link as fallback if it's a valid path, otherwise go to search
                            else {
                              final fallbackPath =
                                  (ctaLink != null && ctaLink.startsWith('/'))
                                      ? ctaLink
                                      : '/search';
                              print('[HERO] Using CTA fallback: $fallbackPath');
                              context.push(fallbackPath);
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 14 : 18,
                              vertical: isMobile ? 6 : 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD6006E),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD6006E)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  slide['ctaText'] as String? ?? 'Book Now',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isMobile ? 11 : 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Navigation arrows
            Positioned(
              left: isMobile ? 12 : 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => onPageChanged(
                    (currentIndex - 1 + totalSlides) % totalSlides,
                  ),
                  child: Container(
                    width: isMobile ? 32 : 36,
                    height: isMobile ? 32 : 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: isMobile ? 18 : 20,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: isMobile ? 12 : 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => onPageChanged((currentIndex + 1) % totalSlides),
                  child: Container(
                    width: isMobile ? 32 : 36,
                    height: isMobile ? 32 : 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: isMobile ? 18 : 20,
                    ),
                  ),
                ),
              ),
            ),
            // Dots indicator
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
                          ? const Color(0xFFD6006E)
                          : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(
                        index == currentIndex ? 4 : 4,
                      ),
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
}
