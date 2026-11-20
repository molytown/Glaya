import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/screens/phone_input_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/signup_selection_screen.dart';
import '../../features/auth/presentation/screens/customer_signup_screen.dart';
import '../../features/auth/presentation/screens/professional_signup_screen.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/screens/pick_map_screen.dart';
import '../../features/location/presentation/guest_location_picker_screen.dart';
import '../../features/discovery/presentation/professional_profile_screen.dart';
import '../../features/discovery/presentation/stylist_profile_page.dart';
import '../../features/booking/presentation/booking_flow_screen.dart';
import '../../features/booking/presentation/booking_detail_screen.dart';
import '../../features/booking/presentation/bookings_list_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/calls/presentation/call_screen.dart';
import '../../features/payments/presentation/payment_screen.dart';
import '../../features/payments/presentation/wallet_screen.dart';
import '../../features/trust/presentation/review_screen.dart';
import '../../features/trust/presentation/reviews_list_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/professional/presentation/service_management_screen.dart';
import '../../features/professional/presentation/availability_screen.dart';
import '../../features/professional/presentation/professional_onboarding_screen.dart';
import '../../features/professional/presentation/professional_dashboard_screen.dart';
import '../../features/professional/presentation/promotions_screen.dart';
import '../../features/professional/presentation/coupons_screen.dart';
import '../../features/professional/presentation/refer_customers_screen.dart';
import '../../features/professional/presentation/boost_profile_screen.dart';
import '../../features/professional/presentation/boost_analytics_screen.dart';
import '../../features/professional/presentation/portfolio_screen.dart';
import '../../features/professional/presentation/subscription_screen.dart';
import '../../features/discovery/presentation/service_portfolio_page.dart';
import '../../features/discovery/presentation/category_professionals_page.dart';
import '../../features/discovery/presentation/all_galleries_page.dart';
import '../../features/discovery/presentation/nearby_professionals_map_page.dart';
import '../../features/discovery/presentation/widgets/portfolio_viewer.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/admin_professionals_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/user_public_profile_screen.dart';
import '../../features/profile/presentation/cms_page_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/loyalty/presentation/loyalty_screen.dart';
import '../../features/premium/presentation/premium_screen.dart';
import '../widgets/desktop_shell.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/home/presentation/pages/popular_services_page.dart';
import '../../features/discovery/presentation/pro_services_page.dart';
import '../../features/search/presentation/home_service_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/onboarding/presentation/onboarding_chat_screen.dart';
import '../../features/support/presentation/support_chat_screen.dart';
import '../../features/support/presentation/gigi_chat_screen.dart';
import '../../ui/screens/home_glaya2.dart';
import '../../ui/screens/discover_glaya2.dart';
import '../widgets/splash_screen.dart';

bool _matchesRoute(String routePattern, String path) {
  if (!routePattern.contains(':')) {
    return routePattern == path;
  }

  final patternParts = routePattern.split('/');
  final pathParts = path.split('/');

  if (patternParts.length != pathParts.length) {
    return false;
  }

  for (int i = 0; i < patternParts.length; i++) {
    if (patternParts[i].startsWith(':')) {
      continue; // Parameter matches anything
    }
    if (patternParts[i] != pathParts[i]) {
      return false;
    }
  }

  return true;
}

/// Global navigator key — lets widgets placed above the Navigator in
/// MaterialApp.router's `builder` (e.g. FloatingChatBubble) obtain a
/// context that can show dialogs / push routes.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // NOTE: do NOT ref.watch(authNotifierProvider) here — every auth emission
  // would build a brand-new GoRouter, resetting the whole navigation stack
  // (visible as a flash/reset right after app start). Auth state is read
  // lazily inside redirect() instead.
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    // Removed refreshListenable to prevent router re-evaluation on auth state changes
    // Login screen will handle its own navigation after successful login
    redirect: (context, state) async {
      final authState = ProviderScope.containerOf(context).read(authNotifierProvider);
      final path = state.uri.path;
      print('[ROUTER] Redirect check for path: $path');

      // Never redirect auth routes (login, signup, otp, splash) anywhere
      final authRoutes = ['/login', '/signup-selection', '/signup/customer', '/signup/professional', '/otp-verify', '/splash'];
      if (authRoutes.contains(path)) {
        print('[ROUTER] On auth route, staying put');
        return null;
      }

      // While auth is still loading, stay put — don't redirect yet
      if (authState.isLoading) {
        print('[ROUTER] Auth still loading, staying on current page');
        return null;
      }

      final isLoggedIn = authState.valueOrNull != null;
      print('[ROUTER] Is logged in: $isLoggedIn');

      // Public routes that don't require authentication (guest users can access)
      final publicRoutes = [
        '/splash',
        '/login',
        '/signup-selection',
        '/signup/customer',
        '/signup/professional',
        '/',
        '/professional/:id',
        '/admin',
        '/cms/:slug',
        '/search',
        '/home-service',
        '/loyalty',
        '/premium',
        '/theme2/home',
        '/theme2/discover',
        '/location-picker',
        '/guest-location',
        '/services/popular',
        '/service-portfolio/:serviceId',
        '/category/:slug',
        '/all-galleries',
        '/nearby-professionals-map',
      ];
      final isPublicRoute = publicRoutes.any(
        (route) =>
            route == path ||
            (route.contains(':') && _matchesRoute(route, path)),
      );

      // Already logged in — don't show login page again
      if (isLoggedIn && path == '/login') {
        // If there's a return URL, navigate there
        final from = state.uri.queryParameters['from'];
        return from != null ? from : '/';
      }

      // Not logged in trying to access a protected route
      if (!isLoggedIn && !isPublicRoute) {
        // Special handling for booking routes - show login prompt
        if (path.startsWith('/book') || path.startsWith('/bookings')) {
          return '/login?from=${Uri.encodeComponent(path)}';
        }
        return '/login?from=${Uri.encodeComponent(path)}';
      }

      // Professional-only routes
      final professionalOnlyRoutes = [
        '/professional/dashboard',
        '/services',
        '/availability',
        '/portfolio',
        '/subscription',
        '/service-portfolio/:serviceId',
        '/all-galleries',
        '/boost',
        '/boost/analytics',
      ];
      final isProfessionalOnlyRoute = professionalOnlyRoutes.any(
        (route) =>
            route == path ||
            (route.contains(':') && _matchesRoute(route, path)),
      );

      if (isProfessionalOnlyRoute) {
        final user = authState.valueOrNull;
        if (user?.role != 'professional' && user?.role != 'both') {
          return '/'; // Redirect to home if not professional
        }
      }

      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => DesktopShell(
          child: child,
          path: state.uri.path,
        ),
        routes: [
          GoRoute(
            path: '/splash',
            builder: (context, state) => const SplashScreen(),
          ),
          GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/login',
        builder: (context, state) => const PhoneInputScreen(),
      ),
      GoRoute(
        path: '/signup-selection',
        builder: (context, state) => const SignupSelectionScreen(),
      ),
      GoRoute(
        path: '/signup/customer',
        builder: (context, state) => const CustomerSignupScreen(),
      ),
      GoRoute(
        path: '/signup/professional',
        builder: (context, state) => const ProfessionalSignupScreen(),
      ),
      GoRoute(
        path: '/otp-verify',
        builder: (context, state) {
          final phone = state.extra as String?;
          return OtpVerificationScreen(phone: phone ?? '');
        },
      ),
      GoRoute(
        path: '/professional/dashboard',
        builder: (context, state) => const ProfessionalDashboardScreen(),
      ),
      GoRoute(
        path: '/professional/:id',
        builder: (context, state) => ProfessionalProfileScreen(
          professionalId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/professional/:id/services',
        builder: (context, state) =>
            ProServicesPage(professionalId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/book/:professionalId',
        builder: (context, state) => BookingFlowScreen(
          professionalId: state.pathParameters['professionalId']!,
          initialServiceId: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/bookings',
        builder: (context, state) => const BookingsListScreen(),
      ),
      GoRoute(
        path: '/bookings/:id',
        builder: (context, state) =>
            BookingDetailScreen(bookingId: state.pathParameters['id']!),
      ),
      // /chat/list MUST be before /chat/:bookingId
      GoRoute(
        path: '/chat/list',
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chat/:bookingId',
        builder: (context, state) =>
            ChatScreen(bookingId: state.pathParameters['bookingId']!),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingChatScreen(),
      ),
      GoRoute(
        path: '/call/:bookingId',
        builder: (context, state) =>
            CallScreen(bookingId: state.pathParameters['bookingId']!),
      ),
      GoRoute(
        path: '/payment/:bookingId',
        builder: (context, state) =>
            PaymentScreen(bookingId: state.pathParameters['bookingId']!),
      ),
      GoRoute(
        path: '/wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/review/:bookingId',
        builder: (context, state) =>
            ReviewScreen(bookingId: state.pathParameters['bookingId']!),
      ),
      GoRoute(
        path: '/reviews',
        builder: (context, state) =>
            ReviewsListScreen(professionalId: state.extra as String?),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/support/chat',
        builder: (context, state) => const SupportChatScreen(),
      ),
      GoRoute(
        path: '/support/gigi',
        builder: (context, state) => const GigiChatScreen(),
      ),
      GoRoute(
        path: '/services',
        builder: (context, state) => const ServiceManagementScreen(),
      ),
      GoRoute(
        path: '/availability',
        builder: (context, state) => const AvailabilityScreen(),
      ),
      GoRoute(
        path: '/become-professional',
        builder: (context, state) => const ProfessionalOnboardingScreen(),
      ),
      GoRoute(
        path: '/promotions',
        builder: (context, state) => const PromotionsScreen(),
      ),
      GoRoute(
        path: '/coupons',
        builder: (context, state) => const CouponsScreen(),
      ),
      GoRoute(
        path: '/refer',
        builder: (context, state) => const ReferCustomersScreen(),
      ),
      GoRoute(
        path: '/boost',
        builder: (context, state) => const BoostProfileScreen(),
      ),
      GoRoute(
        path: '/boost/analytics',
        builder: (context, state) => const BoostAnalyticsScreen(),
      ),
      GoRoute(
        path: '/portfolio',
        builder: (context, state) => const PortfolioScreen(),
      ),
      GoRoute(
        path: '/subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/service-portfolio/:serviceId',
        builder: (context, state) =>
            ServicePortfolioPage(serviceId: state.pathParameters['serviceId']!),
      ),
      GoRoute(
        path: '/category/:slug',
        builder: (context, state) => CategoryProfessionalsPage(
          slug: state.pathParameters['slug']!,
          name: state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        path: '/all-galleries',
        builder: (context, state) => const AllGalleriesPage(),
      ),
      GoRoute(
        path: '/nearby-professionals-map',
        builder: (context, state) => const NearbyProfessionalsMapPage(),
      ),
      GoRoute(
        path: '/portfolio-viewer',
        builder: (context, state) =>
            PortfolioViewer(gallery: state.extra as Map<String, dynamic>),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/professionals',
        builder: (context, state) => const AdminProfessionalsScreen(),
      ),
      GoRoute(
        path: '/profile',
        redirect: (context, state) {
          // Professionals should see the new stylist profile page
          final container = ProviderScope.containerOf(context);
          final user = container.read(authNotifierProvider).valueOrNull;
          if (user?.role == 'professional' || user?.role == 'both') {
            return '/stylist-profile';
          }
          return null;
        },
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/stylist-profile',
        builder: (context, state) => const StylistProfilePage(),
      ),
      GoRoute(
        path: '/user/:id',
        builder: (context, state) => UserPublicProfileScreen(
          userId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/cms/:slug',
        builder: (context, state) =>
            CmsPageScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/book',
        builder: (context, state) => BookingFlowScreen(
          professionalId: state.uri.queryParameters['professionalId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/loyalty',
        builder: (context, state) => const LoyaltyScreen(),
      ),
      GoRoute(
        path: '/premium',
        builder: (context, state) => const PremiumScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) =>
            SearchScreen(initialQuery: state.uri.queryParameters['q']),
      ),
      GoRoute(
        path: '/services/popular',
        builder: (context, state) => const PopularServicesPage(),
      ),
      GoRoute(
        path: '/home-service',
        builder: (context, state) => const HomeServiceScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/theme2/home',
        builder: (context, state) => const HomeGlaya2(),
      ),
      GoRoute(
        path: '/theme2/discover',
        builder: (context, state) => const DiscoverGlaya2(),
      ),
      GoRoute(
        path: '/location-picker',
        builder: (context, state) => const PickMapScreen(
          fromSignUp: false,
          fromAddAddress: false,
          canRoute: false,
          route: null,
        ),
      ),
      GoRoute(
        path: '/guest-location',
        builder: (context, state) => const GuestLocationPickerScreen(),
      ),
        ],
      ),
    ],
  );
});

/// Bridges Riverpod auth state → GoRouter's [refreshListenable].
/// When [authNotifierProvider] emits a new value, GoRouter re-runs redirect.
class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier(Ref ref) {
    ref.listen<AsyncValue>(authNotifierProvider, (_, __) => notifyListeners());
  }
}
