import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/discovery/presentation/discovery_provider.dart';
import '../../shared/utils/responsive_helper.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _zoomController;
  bool _navigated = false;
  late String _selectedImage;
  Offset? _dragStart;

  final List<String> _splashImages = [
    'assets/splash_image.jpg',
    'assets/splash_1.jpg',
    'assets/splash_2.jpg',
    'assets/splash_3.jpg',
    'assets/splash_4.jpg',
    'assets/splash_5.jpg',
    'assets/splash_6.jpg',
    'assets/splash_7.jpg',
    'assets/splash_8.jpg',
    'assets/splash_9.jpg',
    'assets/splash_10.jpg',
  ];

  @override
  void initState() {
    super.initState();
    // Default: randomly select a splash image for mobile/desktop
    _selectedImage = _splashImages[math.Random().nextInt(_splashImages.length)];
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);
    _navigateWhenReady();
    // Preload home screen providers in background
    _preloadHomeData();
    // Auto-navigate after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && !_navigated) {
        _navigated = true;
        _goHome();
      }
    });
  }

  void _preloadHomeData() {
    // Trigger home screen providers to fetch data in background
    ref.read(professionalsProvider(null).future);
    ref.read(homeCategoriesProvider.future);
    ref.read(activePromotionsProvider.future);
    ref.read(topRatedProfessionalsProvider.future);
  }

  Future<void> _navigateWhenReady() async {
    // Wait for auth state to leave the initial loading state (cached read),
    // capped so a stuck provider can't hold the splash forever.
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (mounted && DateTime.now().isBefore(deadline)) {
      final auth = ref.read(authNotifierProvider);
      if (auth is AsyncData) break;
      await Future.delayed(const Duration(milliseconds: 50));
    }
    // Don't auto-navigate here - let the 10s timer handle it
  }

  void _maybeNavigate() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _goHome();
  }

  Future<void> _goHome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('splash_shown', true);
    if (mounted) {
      // Navigate through GoRouter — an imperative Navigator.pushReplacement
      // leaves an unmanaged route on the stack that resurfaces later and
      // bounces the user back to HomePage from other screens.
      context.go('/');
    }
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragStart = details.globalPosition;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragStart == null || _navigated) return;
    final velocity = details.velocity.pixelsPerSecond;
    // Swipe left (negative velocity) triggers navigation
    if (velocity.dx < -300) {
      _navigated = true;
      _goHome();
    }
    _dragStart = null;
  }

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use tablet-specific splash image on tablet/iPad
    final displayImage = ResponsiveHelper.isTablet(context)
        ? 'assets/splash_tablet.jpg'
        : _selectedImage;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: GestureDetector(
        onTap: () {
          if (!_navigated) {
            _navigated = true;
            _goHome();
          }
        },
        onHorizontalDragStart: _onHorizontalDragStart,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _zoomController,
              builder: (context, child) {
                final scale = 1.0 + (_zoomController.value * 0.1);
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: Image.asset(
                displayImage,
                fit: BoxFit.cover,
              ),
            ),
            // Only show overlays on mobile/desktop (tablet image has branding built in)
            if (!ResponsiveHelper.isTablet(context)) ...[
              Positioned(
                top: 16,
                right: 16,
                child: Image.asset(
                  'assets/logo.png',
                  width: 80,
                  height: 80,
                ),
              ),
              const Positioned(
                bottom: 32,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FIND',
                      style: TextStyle(
                        fontFamily: 'Rained Personal',
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        shadows: [
                          Shadow(
                            color: Color(0xFF000000),
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'AND BOOK',
                      style: TextStyle(
                        fontFamily: 'Rained Personal',
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        shadows: [
                          Shadow(
                            color: Color(0xFF000000),
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'PROS NEAR YOUR',
                      style: TextStyle(
                        fontFamily: 'Rained Personal',
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        shadows: [
                          Shadow(
                            color: Color(0xFF000000),
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Swipe hint indicator
              Positioned(
                bottom: 120,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _zoomController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_zoomController.value * 20, 0),
                        child: child,
                      );
                    },
                    child: Icon(
                      Icons.swipe_left,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 32,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
