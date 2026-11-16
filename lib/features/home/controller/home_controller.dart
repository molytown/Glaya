import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../discovery/presentation/discovery_provider.dart';

final selectedCategoryProvider = StateProvider<String?>((ref) => null);

Future<void> refreshHomeData(WidgetRef ref, {required double lat, required double lng}) {
  // Fetch nearby professionals using the new notifier method
  ref.read(nearbyProfessionalsProvider.notifier).fetchNearby(lat, lng);
  
  return Future.wait([
    ref.refresh(heroSlidesProvider.future),
    ref.refresh(topRatedProfessionalsProvider.future),
    ref.refresh(popularServicesProvider.future),
    ref.refresh(customerReviewsProvider.future),
    ref.refresh(trendingNowProvider.future),
    ref.refresh(howItWorksProvider.future),
    ref.refresh(exclusiveOffersProvider.future),
    ref.refresh(premiumPlansProvider.future),
    ref.refresh(recommendedProfessionalsProvider.future),
    ref.refresh(recentlyViewedProvider.future),
    ref.refresh(upcomingBookingProvider.future),
  ]);
}
