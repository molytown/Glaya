import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';
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
      final queryParams = <String, dynamic>{'limit': _pageSize, 'offset': 0, ...zoneQueryParams(locationState)};

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
    final mediaItems = (gallery['media'] as List<dynamic>?)
            ?.map((item) => GalleryMediaItem(
                  id: item['id'] as String,
                  mediaUrl: item['mediaUrl'] as String,
                  mediaType: item['mediaType'] as String? ?? 'photo',
                  thumbnailUrl: item['thumbnailUrl'] as String?,
                ))
            .toList() ??
        [];

    final professionalId = gallery['professional']?['id'] as String?;

    if (mediaItems.isNotEmpty && professionalId != null) {
      showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.9),
        builder: (context) => GalleryImageViewer(
          mediaItems: mediaItems,
          professionalId: professionalId,
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
