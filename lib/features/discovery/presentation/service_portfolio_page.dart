import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/providers/location_provider.dart';
import '../../home/presentation/widgets/just_finished_section.dart';
import 'widgets/portfolio_card.dart';

class ServicePortfolioPage extends ConsumerStatefulWidget {
  final String serviceId;

  const ServicePortfolioPage({super.key, required this.serviceId});

  @override
  ConsumerState<ServicePortfolioPage> createState() =>
      _ServicePortfolioPageState();
}

class _ServicePortfolioPageState extends ConsumerState<ServicePortfolioPage> {
  List<Map<String, dynamic>> _galleries = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  int _total = 0;
  final ScrollController _scrollController = ScrollController();

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
      final queryParams = <String, dynamic>{'page': 1, 'limit': 12};

      if (locationState.hasLocation) {
        queryParams['lat'] = locationState.lat;
        queryParams['lng'] = locationState.lng;
        queryParams['radius'] = 50;
      }

      print('Loading galleries for serviceId: ${widget.serviceId}');
      print('Query params: $queryParams');

      final response = await ApiService.dio.get(
        '/professionals/portfolio/galleries/service/${widget.serviceId}',
        queryParameters: queryParams,
      );

      print('Response: ${response.data}');

      setState(() {
        _galleries =
            (response.data['data'] as List).cast<Map<String, dynamic>>();
        _total = response.data['meta']['total'] as int;
        _currentPage = 1;
      });

      print('Loaded ${_galleries.length} galleries, total: $_total');
    } catch (e) {
      print('Error loading galleries: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load portfolios: ${e.toString()}')),
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
        'page': _currentPage + 1,
        'limit': 12
      };

      if (locationState.hasLocation) {
        queryParams['lat'] = locationState.lat;
        queryParams['lng'] = locationState.lng;
        queryParams['radius'] = 50;
      }

      final response = await ApiService.dio.get(
        '/professionals/portfolio/galleries/service/${widget.serviceId}',
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

  String _getServiceName(String serviceId) {
    switch (serviceId.toLowerCase()) {
      case 'hair':
        return 'Hair';
      case 'makeup':
        return 'Makeup';
      case 'nails':
        return 'Nails';
      case 'skincare':
        return 'Skincare';
      case 'massage':
        return 'Massage';
      default:
        return 'Portfolio';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getServiceName(widget.serviceId)),
        backgroundColor: GlayaColors.surface,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: GlayaColors.vibrantPink))
          : _galleries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No portfolios yet',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadGalleries,
                  color: GlayaColors.vibrantPink,
                  child: GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _galleries.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _galleries.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(
                                color: GlayaColors.vibrantPink),
                          ),
                        );
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
        barrierColor: Colors.black.withValues(alpha: 0.9),
        builder: (context) => GalleryImageViewer(
          mediaItems: mediaItems,
          professionalId: professionalId,
          initialIndex: 0,
        ),
      );
    }
  }
}
