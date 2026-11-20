import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';

class CallScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const CallScreen({super.key, required this.bookingId});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  bool _isLoading = true;
  String? _error;
  String? _callId;
  String? _channelName;
  String? _otherName;
  bool _muted = false;
  bool _speakerOn = true;
  int _secondsElapsed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initCall();
  }

  Future<void> _initCall() async {
    try {
      final response = await ApiService.dio.post('/calls/initiate', data: {
        'bookingId': widget.bookingId,
      });
      final data = response.data['data'] as Map<String, dynamic>;
      setState(() {
        _callId = data['callId'] as String?;
        _channelName = data['channelName'] as String?;
        _otherName = data['otherName'] as String? ?? 'Connecting...';
        _isLoading = false;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _secondsElapsed++);
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to start call: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _endCall() async {
    _timer?.cancel();
    try {
      if (_callId != null) {
        await ApiService.dio.post('/calls/end', data: {
          'callId': _callId,
          'durationSecs': _secondsElapsed,
        });
      }
    } catch (_) {}
    if (mounted) context.pop();
  }

  String get _elapsed {
    final m = (_secondsElapsed ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsElapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text('Connecting...',
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(_error!,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                  onPressed: () => context.pop(), child: const Text('Go Back')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            // Avatar
            CircleAvatar(
              radius: 56,
              backgroundColor: GlayaColors.berry.withValues(alpha: 0.3),
              child: Text(
                (_otherName ?? '?')[0].toUpperCase(),
                style: const TextStyle(
                    fontSize: 40,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            Text(_otherName ?? '',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_elapsed,
                style: const TextStyle(color: Colors.white60, fontSize: 18)),
            if (_channelName != null) ...[
              const SizedBox(height: 4),
              Text('Channel: $_channelName',
                  style: const TextStyle(color: Colors.white38, fontSize: 12))
            ],
            const Spacer(),
            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControl(
                  icon: _muted ? Icons.mic_off : Icons.mic,
                  label: _muted ? 'Unmute' : 'Mute',
                  color: _muted ? Colors.red : Colors.white24,
                  onTap: () => setState(() => _muted = !_muted),
                ),
                // End call button
                GestureDetector(
                  onTap: _endCall,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.call_end,
                        color: Colors.white, size: 32),
                  ),
                ),
                _buildControl(
                  icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
                  label: _speakerOn ? 'Speaker' : 'Earpiece',
                  color: _speakerOn ? GlayaColors.berry : Colors.white24,
                  onTap: () => setState(() => _speakerOn = !_speakerOn),
                ),
              ],
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildControl(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}
