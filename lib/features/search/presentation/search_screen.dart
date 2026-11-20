import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/config_service.dart';
import '../../../../shared/theme/colors.dart';

final searchResultsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, query) async {
  if (query.isEmpty) return {'professionals': [], 'services': []};
  final resp =
      await ApiService.dio.get('/search', queryParameters: {'q': query});
  return resp.data['data'] as Map<String, dynamic>;
});

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late TextEditingController _controller;
  String _query = '';
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery ?? '';
    _controller = TextEditingController(text: _query);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchResultsProvider(_query));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: GlayaColors.berry,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: _query.isEmpty,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          textInputAction: TextInputAction.search,
          onSubmitted: (q) => setState(() => _query = q.trim()),
          decoration: InputDecoration(
            hintText: 'Search professionals, services...',
            hintStyle: const TextStyle(color: Colors.white60),
            border: InputBorder.none,
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white70),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
          ),
          onChanged: (v) => setState(() {}),
        ),
      ),
      body: _query.isEmpty
          ? _buildEmptyState()
          : resultsAsync.when(
              data: (data) {
                final professionals =
                    (data['professionals'] as List<dynamic>?) ?? [];
                final services = (data['services'] as List<dynamic>?) ?? [];

                return Column(
                  children: [
                    Container(
                      color: Colors.grey[50],
                      child: Row(
                        children: [
                          _buildTabChip(
                              'Professionals (${professionals.length})', 0),
                          _buildTabChip('Services (${services.length})', 1),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _tab == 0
                          ? _buildProfessionalList(professionals)
                          : _buildServiceList(services),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Search failed: $e')),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('Search for professionals or services',
              style: TextStyle(color: Colors.grey, fontSize: 15)),
        ],
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

  Widget _buildProfessionalList(List<dynamic> professionals) {
    if (professionals.isEmpty) {
      return const Center(
          child: Text('No professionals found',
              style: TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: professionals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final p = professionals[i] as Map<String, dynamic>;
        final user = p['user'] as Map<String, dynamic>?;
        return GestureDetector(
          onTap: () => context.push('/professional/${p['id']}'),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: GlayaColors.berry.withValues(alpha: 0.15),
                  backgroundImage: user?['photoUrl'] != null
                      ? NetworkImage(ConfigService()
                          .replaceLocalhost(user!['photoUrl'] as String))
                      : null,
                  child: user?['photoUrl'] == null
                      ? Text((user?['name'] as String? ?? '?')[0].toUpperCase(),
                          style: const TextStyle(
                              color: GlayaColors.berry,
                              fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?['name'] as String? ?? 'Unknown',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(p['category'] as String? ?? '',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber[600]),
                          const SizedBox(width: 3),
                          Text(
                            ((p['avgRating'] as num?)?.toStringAsFixed(1) ??
                                '5.0'),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text('  •  ${p['totalReviews'] ?? 0} reviews',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        );
      },
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
                    color: Colors.black.withValues(alpha: 0.04),
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
                  child:
                      const Icon(Icons.content_cut, color: GlayaColors.berry),
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
}
