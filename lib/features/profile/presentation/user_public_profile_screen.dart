import 'package:flutter/material.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/config_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../reels/data/models/reel_model.dart';
import '../../reels/data/repositories/reel_repository.dart';
import '../../reels/presentation/reel_screen.dart';

/// Public view of another user's profile (opened from reel "View Profile").
class UserPublicProfileScreen extends StatefulWidget {
  final String userId;
  const UserPublicProfileScreen({super.key, required this.userId});

  @override
  State<UserPublicProfileScreen> createState() =>
      _UserPublicProfileScreenState();
}

class _UserPublicProfileScreenState extends State<UserPublicProfileScreen> {
  Map<String, dynamic>? _user;
  List<Reel> _reels = [];
  List<Reel> _photos = [];
  bool _isLoading = true;
  final ReelRepository _reelRepository = ReelRepository();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userRes = await ApiService.dio.get('/users/${widget.userId}');
      final reels = await _reelRepository.getReelsByUser(widget.userId);
      final userData = userRes.data['data'] as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _user = userData;
          _reels = reels.where((r) => !r.isPhoto).toList();
          _photos = reels.where((r) => r.isPhoto).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? get _photoUrl {
    final raw = _user?['photoUrl']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return ConfigService().replaceLocalhost(raw);
  }

  String get _displayName => _user?['name']?.toString() ?? 'User';

  double? get _glayaScore {
    final v = _user?['glayaScore'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlayaColors.pinkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: GlayaColors.textPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                // Hero
                Row(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: GlayaColors.berry,
                      backgroundImage:
                          _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                      child: _photoUrl == null
                          ? Text(
                              _displayName.isNotEmpty
                                  ? _displayName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 32,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _displayName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: GlayaColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_glayaScore != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF8E1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFFFFD54F)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star,
                                          size: 13,
                                          color: Color(0xFFF59E0B)),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Glaya ${_glayaScore!.toStringAsFixed(1)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFB8860B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Member since ${_memberSince()}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF000000),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_reels.isNotEmpty) ...[
                  _sectionLabel('REELS'),
                  _grid(_reels, isPhoto: false),
                  const SizedBox(height: 20),
                ],
                if (_photos.isNotEmpty) ...[
                  _sectionLabel('PHOTOS'),
                  _grid(_photos, isPhoto: true),
                ],
                if (_reels.isEmpty && _photos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(
                      child: Text(
                        'No reels or photos yet',
                        style: TextStyle(color: Color(0xFF000000)),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _memberSince() {
    try {
      final raw = _user?['createdAt'] ?? _user?['created_at'];
      if (raw != null) {
        return DateTime.parse(raw.toString()).year.toString();
      }
    } catch (_) {}
    return DateTime.now().year.toString();
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Color(0xFF000000),
          ),
        ),
      );

  Widget _grid(List<Reel> items, {required bool isPhoto}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final reel = items[i];
        final url = ConfigService().replaceLocalhost(reel.videoUrl);
        return GestureDetector(
          onTap: () => _open(reel, items),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: const Color(0xFF1A1A2E),
              child: isPhoto
                  ? Image.network(url, fit: BoxFit.cover)
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF4A154B), Color(0xFF2D1B4E)],
                            ),
                          ),
                          padding: const EdgeInsets.all(8),
                          alignment: Alignment.bottomLeft,
                          child: reel.title != null
                              ? Text(
                                  reel.title!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const Center(
                          child: Icon(Icons.play_circle_fill,
                              color: Colors.white70, size: 36),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  void _open(Reel reel, List<Reel> list) {
    if (reel.isPhoto) {
      final url = ConfigService().replaceLocalhost(reel.videoUrl);
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Color(0xFF000000),
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              InteractiveViewer(
                child: Center(child: Image.network(url, fit: BoxFit.contain)),
              ),
              Positioned(
                top: 24,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final index = list.indexWhere((r) => r.id == reel.id);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReelScreen(
            reels: list,
            initialIndex: index < 0 ? 0 : index,
          ),
        ),
      );
    }
  }
}
