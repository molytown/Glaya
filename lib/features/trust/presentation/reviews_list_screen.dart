import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';

class ReviewsListScreen extends ConsumerStatefulWidget {
  const ReviewsListScreen({super.key, this.professionalId});

  final String? professionalId;

  @override
  ConsumerState<ReviewsListScreen> createState() => _ReviewsListScreenState();
}

class _ReviewsListScreenState extends ConsumerState<ReviewsListScreen> {
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final endpoint = widget.professionalId != null
          ? '/reviews/professional/${widget.professionalId}'
          : '/reviews/me';
      final r = await ApiService.dio.get(endpoint);
      final list = (r.data['data'] as List? ?? []).cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _reviews = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F0F4),
      appBar: AppBar(
        backgroundColor: GlayaColors.berry,
        elevation: 0,
        title: const Text('My Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: GlayaColors.berry))
          : _reviews.isEmpty
              ? const Center(child: Text('No reviews yet', style: TextStyle(fontSize: 14, color: Color(0xFF888888))))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reviews.length,
                  itemBuilder: (_, i) {
                    final review = _reviews[i];
                    final rating = (review['rating'] as num?)?.toInt() ?? 0;
                    final comment = review['comment'] as String? ?? 'No comment';
                    final reviewerName = review['reviewer']?['name'] as String? ?? 'You';
                    String dateStr = '';
                    try {
                      final dt = DateTime.parse((review['createdAt'] ?? review['created_at']) as String);
                      dateStr = DateFormat('MMM d, y').format(dt.toLocal());
                    } catch (_) {}
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ...List.generate(5, (index) {
                                  return Icon(
                                    index < rating ? Icons.star : Icons.star_border,
                                    color: const Color(0xFFF59E0B),
                                    size: 18,
                                  );
                                }),
                                const Spacer(),
                                Text(dateStr, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(comment, style: const TextStyle(fontSize: 14, color: Color(0xFF333333))),
                            const SizedBox(height: 8),
                            Text('By $reviewerName', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
