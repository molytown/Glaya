import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/services/notchpay_service.dart';
import '../../../shared/services/api_service.dart';

class NotchPayPaymentWidget extends ConsumerStatefulWidget {
  final double amount;
  final String currency;
  final String bookingId;
  final Function(bool) onPaymentComplete;

  const NotchPayPaymentWidget({
    super.key,
    required this.amount,
    required this.currency,
    required this.bookingId,
    required this.onPaymentComplete,
  });

  @override
  ConsumerState<NotchPayPaymentWidget> createState() =>
      _NotchPayPaymentWidgetState();
}

class _NotchPayPaymentWidgetState
    extends ConsumerState<NotchPayPaymentWidget> {
  bool _isLoading = false;
  bool _isCheckingAvailability = true;
  bool _isAvailable = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final available = await NotchPayService.isAvailable();
    setState(() {
      _isCheckingAvailability = false;
      _isAvailable = available;
    });
  }

  Future<void> _initiatePayment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _getUserInfo();
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User information not available';
        });
        return;
      }

      final reference = 'booking_${widget.bookingId}_${DateTime.now().millisecondsSinceEpoch}';
      
      final result = await NotchPayService.initiatePayment(
        amount: widget.amount,
        currency: widget.currency,
        email: user['email'] ?? '',
        phone: user['phone'] ?? '',
        name: user['name'] ?? '',
        reference: reference,
        description: 'Payment for booking ${widget.bookingId}',
      );

      if (result != null && result['authorizationUrl'] != null) {
        // Open the payment URL
        final url = Uri.parse(result['authorizationUrl']);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          
          // Start polling for payment status
          _pollPaymentStatus(reference);
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Could not open payment page';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to initiate payment';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Payment initiation failed: $e';
      });
    }
  }

  Future<void> _pollPaymentStatus(String reference) async {
    int attempts = 0;
    const maxAttempts = 30; // 5 minutes with 10-second intervals

    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 10));
      
      final result = await NotchPayService.verifyPayment(reference);
      if (result != null) {
        final status = result['status'] as String?;
        
        if (status == 'complete') {
          widget.onPaymentComplete(true);
          setState(() {
            _isLoading = false;
          });
          return;
        } else if (status == 'failed' || status == 'canceled') {
          widget.onPaymentComplete(false);
          setState(() {
            _isLoading = false;
            _errorMessage = 'Payment failed or was canceled';
          });
          return;
        }
      }
      
      attempts++;
    }

    // Timeout
    widget.onPaymentComplete(false);
    setState(() {
      _isLoading = false;
      _errorMessage = 'Payment verification timeout';
    });
  }

  Future<Map<String, dynamic>?> _getUserInfo() async {
    try {
      final response = await ApiService.dio.get('/users/me');
      return response.data['data'];
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAvailability) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!_isAvailable) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(
                Icons.payment,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'NotchPay Not Available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'This payment method is currently not available. Please try another payment method.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/logo.png', // Replace with NotchPay logo
                  width: 48,
                  height: 48,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.payment, size: 48);
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pay with NotchPay',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Amount: ${widget.currency} ${widget.amount.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _initiatePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Pay Now',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Secure payment powered by NotchPay',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
