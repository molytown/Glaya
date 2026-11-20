import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/config_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../discovery/data/professional_model.dart';
import '../../discovery/presentation/discovery_provider.dart';
import '../../home/presentation/widgets/professional_card.dart';
import '../../../../shared/providers/location_provider.dart';

final homeServiceSearchProvider =
    FutureProvider.family<Map<String, dynamic>, ({double lat, double lng})>(
        (ref, location) async {
  final dio = ApiService.dio;

  // Fetch professionals with home service
  final professionalsResponse =
      await dio.get('/professionals', queryParameters: {
    'lat': location.lat,
    'lng': location.lng,
    'radiusKm': 50,
    'homeService': true,
    'limit': 50,
  });

  final professionals = (professionalsResponse.data['data'] as List<dynamic>)
      .map((e) => ProfessionalModel.fromJson(e as Map<String, dynamic>))
      .toList();

  // Group professionals by category
  final Map<String, List<ProfessionalModel>> groupedByCategory = {};
  for (final pro in professionals) {
    final category = pro.category ?? 'Other';
    if (!groupedByCategory.containsKey(category)) {
      groupedByCategory[category] = [];
    }
    groupedByCategory[category]!.add(pro);
  }

  // Fetch all services from home service professionals
  final servicesResponse = await dio.get('/services/public');
  final allServices = servicesResponse.data['data'] as List<dynamic>;

  // Filter services that belong to home service professionals
  final homeServiceProfessionalIds = professionals.map((p) => p.id).toSet();
  final services = (allServices)
      .where((s) => homeServiceProfessionalIds.contains(s['professionalId']))
      .toList();

  return {
    'professionals': professionals,
    'groupedByCategory': groupedByCategory,
    'services': services,
    'categories': groupedByCategory.keys.toList(),
  };
});

class HomeServiceScreen extends ConsumerStatefulWidget {
  const HomeServiceScreen({super.key});

  @override
  ConsumerState<HomeServiceScreen> createState() => _HomeServiceScreenState();
}

class _HomeServiceScreenState extends ConsumerState<HomeServiceScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final lat = locationState.hasLocation ? locationState.lat! : 3.848;
    final lng = locationState.hasLocation ? locationState.lng! : 11.502;

    final resultsAsync =
        ref.watch(homeServiceSearchProvider((lat: lat, lng: lng)));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: GlayaColors.berry,
        foregroundColor: Colors.white,
        title: const Text('Home Service'),
        elevation: 0,
      ),
      body: resultsAsync.when(
        data: (data) {
          final professionals =
              data['professionals'] as List<ProfessionalModel>? ?? [];
          final groupedByCategory = data['groupedByCategory']
                  as Map<String, List<ProfessionalModel>>? ??
              {};
          final services = data['services'] as List<dynamic>? ?? [];
          final categories = data['categories'] as List<String>? ?? [];

          return Column(
            children: [
              Container(
                color: Colors.grey[50],
                child: Row(
                  children: [
                    _buildTabChip('Professionals (${professionals.length})', 0),
                    _buildTabChip('Categories (${categories.length})', 1),
                    _buildTabChip('Services (${services.length})', 2),
                  ],
                ),
              ),
              Expanded(
                child: _tab == 0
                    ? _buildProfessionalList(professionals)
                    : _tab == 1
                        ? _buildCategoryList(groupedByCategory)
                        : _buildServiceList(services),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
      ),
    );
  }

  Widget _buildTabChip(String label, int index) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? GlayaColors.berry : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? GlayaColors.berry : Colors.grey,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalList(List<ProfessionalModel> professionals) {
    if (professionals.isEmpty) {
      return const Center(
          child: Text('No home service professionals found',
              style: TextStyle(color: Colors.grey)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: professionals.length,
      itemBuilder: (context, i) {
        final pro = professionals[i];
        return ProfessionalCard(
          professional: pro,
          rating: pro.avgRating ?? 0.0,
          priceLabel: '\$25+',
          distanceLabel: (pro.distance ?? 0) > 0
              ? '${(pro.distance ?? 0).toStringAsFixed(1)} km away'
              : 'Nearby',
        );
      },
    );
  }

  Widget _buildCategoryList(
      Map<String, List<ProfessionalModel>> groupedByCategory) {
    if (groupedByCategory.isEmpty) {
      return const Center(
          child: Text('No categories found',
              style: TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: groupedByCategory.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final category = groupedByCategory.keys.elementAt(i);
        final pros = groupedByCategory[category]!;
        return _buildCategoryCard(category, pros);
      },
    );
  }

  Widget _buildCategoryCard(
      String category, List<ProfessionalModel> professionals) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Color(0xFF000000).withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _formatCategory(category),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: GlayaColors.berry.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${professionals.length}',
                  style: const TextStyle(
                      color: GlayaColors.berry,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: professionals.length > 5 ? 5 : professionals.length,
              itemBuilder: (context, i) {
                final pro = professionals[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: GlayaColors.berry.withValues(alpha: 0.15),
                    backgroundImage: pro.photoUrl != null
                        ? NetworkImage(
                            ConfigService().replaceLocalhost(pro.photoUrl!))
                        : null,
                    child: pro.photoUrl == null
                        ? Text((pro.name ?? '?')[0].toUpperCase(),
                            style: const TextStyle(
                                color: GlayaColors.berry,
                                fontWeight: FontWeight.bold))
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceList(List<dynamic> services) {
    if (services.isEmpty) {
      return const Center(
          child:
              Text('No services found', style: TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: services.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final s = services[i] as Map<String, dynamic>;
        final pro = s['professional'] as Map<String, dynamic>?;
        final proUser = pro?['user'] as Map<String, dynamic>?;
        return GestureDetector(
          onTap: () {
            if (pro?['id'] != null) context.push('/professional/${pro!['id']}');
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                    color: Color(0xFF000000).withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: GlayaColors.berry.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.home, color: GlayaColors.berry),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['name'] as String? ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('by ${proUser?['name'] ?? 'Unknown'}',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text(
                        '${s['durationMins'] ?? 60} min  •  \$${(s['price'] as num?)?.toStringAsFixed(0) ?? '0'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${(s['price'] as num?)?.toStringAsFixed(0) ?? '0'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: GlayaColors.berry,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatCategory(String category) {
    // Capitalize first letter
    return category[0].toUpperCase() + category.substring(1);
  }
}
