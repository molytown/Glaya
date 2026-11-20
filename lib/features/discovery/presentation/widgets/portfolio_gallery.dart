import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/colors.dart';
import '../../../../shared/services/config_service.dart';
import '../../../home/presentation/widgets/just_finished_section.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';

class Album {
  final String id;
  final String title;
  final String? coverUrl;
  final int mediaCount;
  final List<GalleryMediaItem> mediaItems;

  Album({
    required this.id,
    required this.title,
    this.coverUrl,
    required this.mediaCount,
    required this.mediaItems,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    final configService = ConfigService();
    final media = json['media'] as List<dynamic>?;
    // Try coverMedia first, then fall back to first media item
    String? rawCoverUrl = json['coverMedia']?['mediaUrl'] as String?;
    if (rawCoverUrl == null && media != null && media.isNotEmpty) {
      rawCoverUrl =
          (media.first as Map<String, dynamic>?)?['mediaUrl'] as String?;
    }
    // Transform relative URLs to absolute URLs
    final coverUrl = rawCoverUrl != null
        ? configService.replaceLocalhost(rawCoverUrl)
        : null;

    // Parse media items
    final mediaItems = media
            ?.map(
              (item) => GalleryMediaItem.fromJson(item as Map<String, dynamic>),
            )
            .toList() ??
        [];

    return Album(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled',
      coverUrl: coverUrl,
      mediaCount: media?.length ?? 0,
      mediaItems: mediaItems,
    );
  }
}

class PortfolioGallery extends ConsumerWidget {
  final List<dynamic>? portfolioUrls;
  final String professionalId;

  const PortfolioGallery({
    super.key,
    this.portfolioUrls,
    required this.professionalId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull;
    final isOwnProfile = user?.role == 'professional' || user?.role == 'both';

    // Try to parse as albums first
    List<Album> albums = [];
    if (portfolioUrls != null && portfolioUrls!.isNotEmpty) {
      // Check if the data is in album format
      final firstItem = portfolioUrls![0];
      if (firstItem is Map<String, dynamic> && firstItem.containsKey('id')) {
        albums = portfolioUrls!
            .map((json) => Album.fromJson(json as Map<String, dynamic>))
            .toList();
        // Filter out albums with no media (URLs are already transformed in fromJson)
        albums = albums
            .where((album) => album.mediaCount > 0 && album.coverUrl != null)
            .toList();

        // Limit to 8 albums
        if (albums.length > 8) {
          albums = albums.sublist(0, 8);
        }
        print('PortfolioGallery: Parsed ${albums.length} albums with media');
      } else if (firstItem is String) {
        // Handle simple URL strings
        final configService = ConfigService();
        albums = portfolioUrls!.map((url) {
          final urlString = url as String;
          final normalizedUrl = configService.replaceLocalhost(urlString);
          return Album(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: 'Portfolio',
            coverUrl: normalizedUrl,
            mediaCount: 1,
            mediaItems: [
              GalleryMediaItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                mediaUrl: normalizedUrl,
                mediaType: 'image',
                thumbnailUrl: normalizedUrl,
              ),
            ],
          );
        }).toList();

        // Limit to 8 items
        if (albums.length > 8) {
          albums = albums.sublist(0, 8);
        }
        print(
          'PortfolioGallery: Parsed ${albums.length} simple URL portfolio items',
        );
      } else {
        print(
          'PortfolioGallery: Data is not in album format, firstItem: $firstItem',
        );
      }
    } else {
      print('PortfolioGallery: portfolioUrls is null or empty');
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Portfolio',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          if (albums.isEmpty)
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: const Center(
                child: Text(
                  'No portfolio images',
                  style: TextStyle(fontSize: 14, color: Color(0xFF000000)),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: albums.length,
              itemBuilder: (_, i) {
                final album = albums[i];
                return GestureDetector(
                  onTap: () {
                    if (album.mediaItems.isNotEmpty) {
                      _showGalleryViewer(context, album);
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (album.coverUrl != null)
                          CachedNetworkImage(
                            imageUrl: album.coverUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: GlayaColors.berry.withValues(alpha: 0.1),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: GlayaColors.berry.withValues(alpha: 0.1),
                            ),
                          )
                        else
                          Container(
                            color: GlayaColors.berry.withValues(alpha: 0.1),
                            child: const Icon(
                              Icons.photo_library,
                              color: GlayaColors.berry,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (albums.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    // Navigate to full portfolio view
                    context.push('/professional/$professionalId/portfolio');
                  },
                  child: const Text(
                    'See More',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: GlayaColors.berry,
                    ),
                  ),
                ),
              ),
            ),
          if (isOwnProfile && albums.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/portfolio'),
                  icon: const Icon(Icons.update, size: 20),
                  label: const Text('Update Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlayaColors.berry,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showGalleryViewer(BuildContext context, Album album) {
    showDialog(
      context: context,
      barrierColor: Color(0xFF000000).withValues(alpha: 0.9),
      builder: (context) => GalleryImageViewer(
        mediaItems: album.mediaItems,
        professionalId: professionalId,
        initialIndex: 0,
      ),
    );
  }
}
