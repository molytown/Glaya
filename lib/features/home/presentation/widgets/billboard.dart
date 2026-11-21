import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../discovery/presentation/discovery_provider.dart';

// React components/Billboard.jsx — admin-managed portrait banner carousel
// that replaces the old "Browse Categories" sidebar on desktop home.
class HomeBillboard extends ConsumerStatefulWidget {
  const HomeBillboard({super.key});

  @override
  ConsumerState<HomeBillboard> createState() => _HomeBillboardState();
}

class _HomeBillboardState extends ConsumerState<HomeBillboard> {
  static const _autoplay = Duration(seconds: 5);

  final _controller = PageController();
  Timer? _timer;
  int _index = 0;
  bool _paused = false;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _syncTimer(int count) {
    _timer?.cancel();
    if (count < 2 || _paused) return;
    _timer = Timer.periodic(_autoplay, (_) {
      if (!mounted || _controller.positions.isEmpty) return;
      final next = (_index + 1) % count;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  void _onPageChanged(int i) => setState(() => _index = i);

  void _go(int dir, int count) {
    if (count == 0) return;
    final next = (_index + dir + count) % count;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _openLink(Map<String, dynamic> slide) {
    final link = slide['ctaLink'] as String?;
    if (link == null || link.isEmpty) return;
    if (link.startsWith('http')) {
      launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    } else {
      context.push(link);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(billboardSlidesProvider);

    return async.when(
      loading: () => _card(child: const SizedBox.expand()),
      error: (_, __) => const SizedBox.shrink(),
      data: (slides) {
        if (slides.isEmpty) return const SizedBox.shrink();
        _syncTimer(slides.length);
        return MouseRegion(
          onEnter: (_) {
            _paused = true;
            _syncTimer(slides.length);
          },
          onExit: (_) {
            _paused = false;
            _syncTimer(slides.length);
          },
          child: _card(
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: slides.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, i) =>
                      _BillboardSlide(slide: slides[i], onCta: _openLink),
                ),
                if (slides.length > 1) ...[
                  _navButton(
                    icon: Icons.chevron_left,
                    alignment: Alignment.centerLeft,
                    onTap: () => _go(-1, slides.length),
                  ),
                  _navButton(
                    icon: Icons.chevron_right,
                    alignment: Alignment.centerRight,
                    onTap: () => _go(1, slides.length),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < slides.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: i == _index ? 14 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _index
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D1B4E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _navButton({
    required IconData icon,
    required Alignment alignment,
    required VoidCallback onTap,
  }) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: EdgeInsets.only(
          left: alignment == Alignment.centerLeft ? 8 : 0,
          right: alignment == Alignment.centerRight ? 8 : 0,
        ),
        child: Material(
          color: Colors.black.withValues(alpha: 0.45),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(icon, size: 16, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _BillboardSlide extends StatelessWidget {
  final Map<String, dynamic> slide;
  final void Function(Map<String, dynamic>) onCta;

  const _BillboardSlide({required this.slide, required this.onCta});

  @override
  Widget build(BuildContext context) {
    final mediaUrl = slide['mediaUrl'] as String?;
    final bgColor = slide['bgColor'] as String?;
    final badge = slide['badgeText'] as String?;
    final title = slide['title'] as String?;
    final subtitle = slide['subtitle'] as String?;
    final ctaText = slide['ctaText'] as String?;
    final hasLink = (slide['ctaLink'] as String?)?.isNotEmpty == true;

    return GestureDetector(
      onTap: hasLink ? () => onCta(slide) : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: _parseColor(bgColor)),
          if (mediaUrl != null && mediaUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: mediaUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (_, __) => const SizedBox.expand(),
              errorWidget: (_, __, ___) => const SizedBox.expand(),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xB3000000)],
                stops: [0.35, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (badge != null && badge.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xE5E91E8C),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                if (title != null && title.isNotEmpty)
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      shadows: [
                        Shadow(color: Color(0x66000000), blurRadius: 4)
                      ],
                    ),
                  ),
                if (subtitle != null && subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                if (ctaText != null && ctaText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: () => onCta(slide),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E8C),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66E91E8C),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          ctaText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF2D1B4E);
    final h = hex.replaceFirst('#', '');
    final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
    return v != null ? Color(v) : const Color(0xFF2D1B4E);
  }
}
