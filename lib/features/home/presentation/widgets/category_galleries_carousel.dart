import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../shared/services/api_service.dart';
import '../../../../shared/providers/location_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/services/config_service.dart';
import 'just_finished_section.dart';

class CategoryGalleriesCarousel extends ConsumerStatefulWidget {
  final String categoryName;
  final String serviceId;

  const CategoryGalleriesCarousel({
    super.key,
    required this.categoryName,
    required this.serviceId,
  });

  @override
  ConsumerState<CategoryGalleriesCarousel> createState() =>
      _CategoryGalleriesCarouselState();
}

class _CategoryGalleriesCarouselState
    extends ConsumerState<CategoryGalleriesCarousel> {
  List<Map<String, dynamic>> _galleries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGalleries();
  }

  Future<void> _loadGalleries() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final locationState = ref.read(locationProvider);
      final queryParams = <String, dynamic>{'page': 1, 'limit': 4};

      if (locationState.hasLocation) {
        queryParams['lat'] = locationState.lat;
        queryParams['lng'] = locationState.lng;
        queryParams['radius'] = 50;
      }

      final response = await ApiService.dio.get(
        '/professionals/portfolio/galleries/service/${widget.serviceId}',
        queryParameters: queryParams,
      );

      if (mounted) {
        setState(() {
          _galleries =
              (response.data['data'] as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showGalleryViewer(Map<String, dynamic> gallery) {
    final configService = ConfigService();
    final mediaItems = (gallery['media'] as List<dynamic>?)?.map((item) {
          String normalizedMediaUrl =
              item['mediaUrl']?.toString() ?? '';
          if (normalizedMediaUrl.isNotEmpty && !normalizedMediaUrl.startsWith('http')) {
            normalizedMediaUrl =
                '${configService.socketUrl}$normalizedMediaUrl';
          }

          String? normalizedThumbnailUrl = item['thumbnailUrl']?.toString();
          if (normalizedThumbnailUrl != null &&
              normalizedThumbnailUrl.isNotEmpty) {
            if (!normalizedThumbnailUrl.startsWith('http')) {
              normalizedThumbnailUrl =
                  '${configService.socketUrl}$normalizedThumbnailUrl';
            }
          }

          return GalleryMediaItem(
            id: item['id']?.toString() ?? '',
            mediaUrl: normalizedMediaUrl,
            mediaType: item['mediaType']?.toString() ?? 'photo',
            thumbnailUrl: normalizedThumbnailUrl,
          );
        }).toList() ??
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
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_galleries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _galleries.length,
            itemBuilder: (context, index) {
              final configService = ConfigService();
              final gallery = _galleries[index];
              final coverMedia = gallery['coverMedia'] as Map<String, dynamic>?;
              final mediaUrl = coverMedia?['mediaUrl'] as String? ?? '';

              // Normalize media URL
              String normalizedMediaUrl = mediaUrl;
              if (normalizedMediaUrl.isNotEmpty) {
                if (!normalizedMediaUrl.startsWith('http')) {
                  normalizedMediaUrl =
                      '${configService.socketUrl}$normalizedMediaUrl';
                }
              }

              final mediaType = coverMedia?['mediaType'] as String? ?? 'photo';
              final thumbnailUrl = coverMedia?['thumbnailUrl'] as String?;

              // Normalize thumbnail URL
              String? normalizedThumbnailUrl = thumbnailUrl;
              if (normalizedThumbnailUrl != null &&
                  normalizedThumbnailUrl.isNotEmpty) {
                if (!normalizedThumbnailUrl.startsWith('http')) {
                  normalizedThumbnailUrl =
                      '${configService.socketUrl}$normalizedThumbnailUrl';
                }
              }

              final mediaCount = gallery['mediaCount'] as int? ?? 0;
              final professionalName =
                  gallery['professional']?['name'] as String? ?? 'Professional';

              return GestureDetector(
                onTap: () => _showGalleryViewer(gallery),
                child: Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Media
                        mediaType == 'video' && normalizedThumbnailUrl?.isNotEmpty == true
                            ? CachedNetworkImage(
                                imageUrl: normalizedThumbnailUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.play_circle_outline,
                                    size: 48,
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image),
                                ),
                              )
                            : normalizedMediaUrl.isNotEmpty
                                ? CachedNetworkImage(
                                imageUrl: normalizedMediaUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    Container(color: Colors.grey[300]),
                                errorWidget: (_, __, ___) => Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image),
                                ),
                              )
                            : Container(color: Colors.grey[300]),
                        // Video indicator
                        if (mediaType == 'video')
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        // Professional name overlay
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                            child: Text(
                              professionalName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
