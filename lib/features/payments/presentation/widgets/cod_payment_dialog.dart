import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';

/// Professional view: shows the 5-digit cash payment code the customer must
/// confirm. Pops with `true` if the code was refreshed.
class CodCodeDisplayDialog extends StatefulWidget {
  final String bookingId;

  const CodCodeDisplayDialog({super.key, required this.bookingId});

  @override
  State<CodCodeDisplayDialog> createState() => _CodCodeDisplayDialogState();
}

class _CodCodeDisplayDialogState extends State<CodCodeDisplayDialog> {
  bool _loading = true;
  bool _refreshing = false;
  String? _code;
  String? _expiresAt;
  double? _amount;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.dio.get('/bookings/${widget.bookingId}/cod');
      final data = res.data['data'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _code = data['code']?.toString();
          _expiresAt = data['expiresAt']?.toString();
          final amt = data['amount'];
          _amount = amt is num ? amt.toDouble() : double.tryParse('$amt');
          _loading = false;
        });
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['error'] ?? e.response!.data['message'])
                  ?.toString() ??
              'Failed to load code'
          : 'Failed to load code';
      if (mounted) {
        setState(() {
          _error = msg;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Cash Payment Code',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: GlayaColors.berry)),
            )
          : _error != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: GlayaColors.error, size: 36),
                    const SizedBox(height: 8),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Give this code to the customer — they enter it to confirm cash payment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF000000))),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        if (_code != null) {
                          Clipboard.setData(ClipboardData(text: _code!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied')),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          color: GlayaColors.blushPink,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: GlayaColors.berry, width: 1.5),
                        ),
                        child: Text(
                          _code ?? '—',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 8,
                            color: GlayaColors.berry,
                          ),
                        ),
                      ),
                    ),
                    if (_amount != null) ...[
                      const SizedBox(height: 10),
                      Text('Amount due: ${_amount!.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                    if (_expiresAt != null) ...[
                      const SizedBox(height: 4),
                      Text('Valid until ${_expiresAt!.replaceFirst('T', ' ').substring(0, 16)}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF000000))),
                    ],
                  ],
                ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close',
              style: TextStyle(color: Color(0xFF555555), fontWeight: FontWeight.w600)),
        ),
        if (_error == null)
          TextButton.icon(
            onPressed: _refreshing
                ? null
                : () {
                    setState(() => _refreshing = true);
                    _load().whenComplete(() {
                      if (mounted) setState(() => _refreshing = false);
                    });
                  },
            icon: _refreshing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
          ),
      ],
    );
  }
}

/// Customer view: enter the 5-digit code the professional gave them.
/// Pops with `true` when the code is verified (booking completed).
class CodCodeEntryDialog extends StatefulWidget {
  final String bookingId;

  const CodCodeEntryDialog({super.key, required this.bookingId});

  @override
  State<CodCodeEntryDialog> createState() => _CodCodeEntryDialogState();
}

class _CodCodeEntryDialogState extends State<CodCodeEntryDialog> {
  final _codeController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 5-digit code')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiService.dio
          .post('/bookings/${widget.bookingId}/cod/verify', data: {'code': code});
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['error'] ?? e.response!.data['message'])
                  ?.toString() ??
              'Verification failed'
          : 'Verification failed';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: GlayaColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Enter Payment Code',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Enter the 5-digit code your professional gave you to confirm your cash payment.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF000000)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 5,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 8),
            decoration: InputDecoration(
              counterText: '',
              hintText: '•••••',
              filled: true,
              fillColor: GlayaColors.blushPink,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: GlayaColors.berry),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: GlayaColors.berry),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel',
              style: TextStyle(color: Color(0xFF555555), fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _verify,
          style: ElevatedButton.styleFrom(
            backgroundColor: GlayaColors.berry,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Confirm Payment', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
