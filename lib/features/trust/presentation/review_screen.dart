import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/text_styles.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const ReviewScreen({super.key, required this.bookingId});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  int _rating = 5;
  int _punctualityScore = 5;
  final _commentController = TextEditingController();
  String? _revieweeId;
  bool _isLoading = false;
  bool _isLoadingBooking = true;
  String? _bookingStatus;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadBooking() async {
    try {
      print('[REVIEW] Loading booking: ${widget.bookingId}');
      final response = await ApiService.dio.get('/bookings/${widget.bookingId}');
      final data = response.data['data'] as Map<String, dynamic>;
      print('[REVIEW] Booking data: $data');
      // reviewee is the professional's USER id (not the professional entity id)
      final proUser = data['professional']?['user'] as Map<String, dynamic>?;
      setState(() {
        _revieweeId = (proUser?['id'] ?? data['professionalId']) as String?;
        _bookingStatus = data['status'] as String?;
        _isLoadingBooking = false;
      });
      print('[REVIEW] Booking status: $_bookingStatus, revieweeId: $_revieweeId');
    } catch (e) {
      print('[REVIEW] Failed to load booking: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load booking: ${e.toString()}';
          _isLoadingBooking = false;
        });
      }
    }
  }

  Future<void> _submitReview() async {
    if (_revieweeId == null) return;

    // Check if booking is completed
    if (_bookingStatus != 'completed') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reviews can only be submitted after the service is completed'),
            backgroundColor: GlayaColors.error,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService.dio.post('/reviews', data: {
        'bookingId': widget.bookingId,
        'revieweeId': _revieweeId,
        'rating': _rating,
        'comment': _commentController.text,
        'punctualityScore': _punctualityScore,
      });
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Review failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave a Review')),
      body: _isLoadingBooking
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Show booking status
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _bookingStatus == 'completed'
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _bookingStatus == 'completed'
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _bookingStatus == 'completed'
                                  ? Icons.check_circle
                                  : Icons.info,
                              color: _bookingStatus == 'completed'
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _bookingStatus == 'completed'
                                    ? 'Booking completed - you can leave a review'
                                    : 'Booking status: ${_bookingStatus ?? 'unknown'} - reviews can only be submitted after service completion',
                                style: TextStyle(
                                  color: _bookingStatus == 'completed'
                                      ? Colors.green.shade800
                                      : Colors.orange.shade800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Overall Rating', style: GlayaTextStyles.titleLarge()),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return IconButton(
                            icon: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 40,
                            ),
                            onPressed: () => setState(() => _rating = index + 1),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      Text('Punctuality', style: GlayaTextStyles.titleLarge()),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return IconButton(
                            icon: Icon(
                              index < _punctualityScore
                                  ? Icons.timer
                                  : Icons.timer_outlined,
                              color: GlayaColors.berry,
                              size: 32,
                            ),
                            onPressed: () =>
                                setState(() => _punctualityScore = index + 1),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _commentController,
                        style: const TextStyle(color: Colors.black),
                        decoration: const InputDecoration(
                          labelText: 'Comment',
                          hintText: 'Share your experience...',
                          hintStyle: TextStyle(color: Colors.grey),
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submitReview,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Submit Review'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
