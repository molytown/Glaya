import 'package:glaya/features/reels/data/models/reel_model.dart';
import 'package:glaya/shared/services/api_service.dart';

class ReelRepository {
  // Feed order is upload date (newest first) — the reel player applies
  // priority scoring itself for the videos after the tapped one.
  List<Reel> _sortByUploadDate(List<Reel> reels) {
    return reels.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<Reel>> getReels({Map<String, dynamic>? zoneParams}) async {
    try {
      final response = await ApiService.dio.get('/reels', queryParameters: zoneParams);
      final data = response.data['data'] as List<dynamic>?;
      final reels = (data ?? []).map((json) => Reel.fromJson(json as Map<String, dynamic>)).toList();
      return _sortByUploadDate(reels);
    } catch (e) {
      print('Error fetching reels: $e');
      return [];
    }
  }

  Future<List<Reel>> getReelsByUser(String userId) async {
    try {
      final response = await ApiService.dio.get('/reels/user/$userId');
      final data = response.data['data'] as List<dynamic>?;
      return (data ?? [])
          .map((json) => Reel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching user reels: $e');
      return [];
    }
  }

  Future<List<Reel>> getReelsByProfessional(String professionalId, {Map<String, dynamic>? zoneParams}) async {
    try {
      final response = await ApiService.dio.get('/reels/professional/$professionalId', queryParameters: zoneParams);
      final data = response.data['data'] as List<dynamic>?;
      return (data ?? []).map((json) => Reel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error fetching professional reels: $e');
      return [];
    }
  }

  Future<List<Reel>> getRelatedReels(String categoryId, String professionalId, {Map<String, dynamic>? zoneParams}) async {
    try {
      final response = await ApiService.dio.get('/reels/related/$categoryId/$professionalId', queryParameters: zoneParams);
      final data = response.data['data'] as List<dynamic>?;
      return (data ?? []).map((json) => Reel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error fetching related reels: $e');
      return [];
    }
  }

  // Returns the server's updated view count, or null on failure.
  Future<int?> incrementView(String reelId) async {
    try {
      final response = await ApiService.dio.post('/reels/$reelId/view');
      final views = response.data?['data']?['views'];
      return views is int ? views : null;
    } catch (e) {
      print('Error incrementing view: $e');
      return null;
    }
  }

  Future<void> incrementShare(String reelId) async {
    try {
      await ApiService.dio.post('/reels/$reelId/share');
    } catch (e) {
      print('Error incrementing share: $e');
    }
  }

  Future<void> likeReel(String reelId) async {
    try {
      await ApiService.dio.post('/reels/$reelId/like');
    } catch (e) {
      print('Error liking reel: $e');
    }
  }

  Future<void> unlikeReel(String reelId) async {
    try {
      await ApiService.dio.post('/reels/$reelId/unlike');
    } catch (e) {
      print('Error unliking reel: $e');
    }
  }
}
