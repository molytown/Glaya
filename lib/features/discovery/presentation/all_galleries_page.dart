import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/config_service.dart';
import '../../../../shared/providers/location_provider.dart';
import '../../../../shared/services/location_service.dart';
import '../../home/presentation/widgets/just_finished_section.dart';
import 'widgets/portfolio_card.dart';

class AllGalleriesPage extends ConsumerStatefulWidget {
  const AllGalleriesPage({super.key});

  @override
  ConsumerState<AllGalleriesPage> createState() => _AllGalleriesPageState();
}

class _AllGalleriesPageState extends ConsumerState<AllGalleriesPage> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _galleries = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _total = 0;
  int _currentPage = 1;
  final int _pageSize = 12;

  @override
  void initState() {
    super.initState();
    _loadGalleries();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore && _galleries.length < _total) {
        _loadMoreGalleries();
      }
    }
  }

  Future<void> _loadGalleries() async {
    setState(() => _isLoading = true);
    try {
      final locationState = ref.read(locationProvider);
      final queryParams = <String, dynamic>{
        'limit': _pageSize,
        'offset': 0,
        ...zoneQueryParams(locationState)
      };

      if (locationState.hasLocation) {
        queryParams['lat'] = locationState.lat;
        queryParams['lng'] = locationState.lng;
        queryParams['radius'] = 50;
      } else {
        // Use default location from backend
        final defaultLocation = await LocationService.getDefaultLocation();
        if (defaultLocation != null) {
          queryParams['lat'] = defaultLocation.latitude;
          queryParams['lng'] = defaultLocation.longitude;
          queryParams['radius'] = 50;
        }
      }

      final response = await ApiService.dio.get(
        '/professionals/portfolio/recent',
        queryParameters: queryParams,
      );

      setState(() {
        _galleries =
            (response.data['data'] as List).cast<Map<String, dynamic>>();
        _total = response.data['meta']['total'] as int;
        _currentPage = 1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load galleries: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreGalleries() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final locationState = ref.read(locationProvider);
      final queryParams = <String, dynamic>{
        'limit': _pageSize,
        'offset': _currentPage * _pageSize,
        ...zoneQueryParams(locationState),
      };

      if (locationState.hasLocation) {
        queryParams['lat'] = locationState.lat;
        queryParams['lng'] = locationState.lng;
        queryParams['radius'] = 50;
      } else {
        // Use default location from backend
        final defaultLocation = await LocationService.getDefaultLocation();
        if (defaultLocation != null) {
          queryParams['lat'] = defaultLocation.latitude;
          queryParams['lng'] = defaultLocation.longitude;
          queryParams['radius'] = 50;
        }
      }

      final response = await ApiService.dio.get(
        '/professionals/portfolio/recent',
        queryParameters: queryParams,
      );

      setState(() {
        _galleries.addAll(
            (response.data['data'] as List).cast<Map<String, dynamic>>());
        _total = response.data['meta']['total'] as int;
        _currentPage++;
      });
    } catch (e) {
      // Silently fail for load more
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _viewGallery(Map<String, dynamic> gallery) {
    final configService = ConfigService();
    String normalizeUrl(String? url) {
      final u = url ?? '';
      if (u.isNotEmpty && !u.startsWith('http')) {
        return '${configService.socketUrl}$u';
      }
      return u;
    }

    var items = (gallery['media'] as List<dynamic>?)
            ?.map((item) => GalleryMediaItem(
                  id: item['id']?.toString() ?? '',
                  mediaUrl: normalizeUrl(item['mediaUrl']?.toString()),
                  mediaType: item['mediaType']?.toString() ?? 'photo',
                  thumbnailUrl: normalizeUrl(item['thumbnailUrl']?.toString()),
                ))
            .where((i) => i.mediaUrl.isNotEmpty)
            .toList() ??
        <GalleryMediaItem>[];

    // Albums can have a cover image but an empty media list — fall back to
    // the cover so single-image albums still open the viewer.
    if (items.isEmpty) {
      final cover = gallery['coverMedia'] as Map<String, dynamic>?;
      final coverUrl = normalizeUrl(cover?['mediaUrl']?.toString());
      if (coverUrl.isNotEmpty) {
        items = [
          GalleryMediaItem(
            id: gallery['id']?.toString() ?? '',
            mediaUrl: coverUrl,
            mediaType: cover?['mediaType']?.toString() ?? 'photo',
            thumbnailUrl: normalizeUrl(cover?['thumbnailUrl']?.toString()),
          ),
        ];
      }
    }

    final professionalId = gallery['professional']?['id']?.toString();

    if (items.isNotEmpty) {
      showDialog(
        context: context,
        barrierColor: Color(0xFF000000).withValues(alpha: 0.9),
        builder: (context) => GalleryImageViewer(
          mediaItems: items,
          professionalId: professionalId ?? '',
          initialIndex: 0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Galleries'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _galleries.isEmpty
              ? const Center(
                  child: Text(
                    'No galleries nearby',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadGalleries,
                  child: GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _galleries.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _galleries.length) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return PortfolioCard(
                        gallery: _galleries[index],
                        onTap: () => _viewGallery(_galleries[index]),
                      );
                    },
                  ),
                ),
    );
  }
}
