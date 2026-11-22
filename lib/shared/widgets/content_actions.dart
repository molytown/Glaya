import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';

/// Bottom-sheet actions for user-generated content:
///   - Report content (recorded against the uploader; 10 distinct reporters
///     triggers a 30-day suspension server-side)
///   - Block user (hides that user's reels/profile content for 90 days)
///
/// Usage:
///   ContentActions.show(context,
///     targetType: 'reel',
///     targetId: reel.id,
///     reportedUserId: reel.user?.id,
///     displayName: 'Sara',
///   );
class ContentActions {
  static const _reasons = <String, String>{
    'spam': 'Spam or scam',
    'harassment': 'Harassment or bullying',
    'inappropriate': 'Inappropriate content',
    'fake': 'Fake or misleading',
    'other': 'Something else',
  };

  static Future<void> show(
    BuildContext context, {
    required String targetType,
    required String targetId,
    required String? reportedUserId,
    required String displayName,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ContentActionsSheet(
        targetType: targetType,
        targetId: targetId,
        reportedUserId: reportedUserId,
        displayName: displayName,
      ),
    );
  }
}

class _ContentActionsSheet extends ConsumerStatefulWidget {
  final String targetType;
  final String targetId;
  final String? reportedUserId;
  final String displayName;

  const _ContentActionsSheet({
    required this.targetType,
    required this.targetId,
    required this.reportedUserId,
    required this.displayName,
  });

  @override
  ConsumerState<_ContentActionsSheet> createState() =>
      _ContentActionsSheetState();
}

class _ContentActionsSheetState extends ConsumerState<_ContentActionsSheet> {
  bool _busy = false;

  String? get _myId => ref.read(authNotifierProvider).valueOrNull?.id;

  bool get _canModerate =>
      widget.reportedUserId != null && widget.reportedUserId != _myId;

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Future<void> _report() async {
    if (!_canModerate) return;
    // Reason picker
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Why are you reporting this?',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A))),
            ),
            ...ContentActions._reasons.entries.map(
              (e) => ListTile(
                title: Text(e.value,
                    style: const TextStyle(
                        fontSize: 15, color: Color(0xFF1A1A1A))),
                onTap: () => Navigator.pop(ctx, e.key),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;

    // Optional details
    final detailsCtrl = TextEditingController();
    final details = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add details (optional)'),
        content: TextField(
          controller: detailsCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Tell us more...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Skip')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, detailsCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: GlayaColors.berry,
                foregroundColor: Colors.white),
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );
    detailsCtrl.dispose();
    if (!mounted) return;

    setState(() => _busy = true);
    try {
      await ApiService.dio.post('/moderation/report', data: {
        'reportedUserId': widget.reportedUserId,
        'targetType': widget.targetType,
        'targetId': widget.targetId,
        'reason': reason,
        'details': (details != null && details.isNotEmpty) ? details : null,
      });
      if (mounted) Navigator.pop(context);
      _snack('Report submitted. Thank you for keeping Glaya safe.');
    } catch (e) {
      setState(() => _busy = false);
      _snack('Could not submit report: $e', error: true);
    }
  }

  Future<void> _block() async {
    if (!_canModerate) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block ${widget.displayName}?'),
        content: const Text(
          'You will no longer see content from this user for 90 days.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Block', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ApiService.dio.post('/moderation/block/${widget.reportedUserId}');
      if (mounted) Navigator.pop(context);
      _snack(
          'Blocked. You won\'t see ${widget.displayName}\'s content for 90 days.');
    } catch (e) {
      setState(() => _busy = false);
      _snack('Could not block user: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: GlayaColors.berry),
              )
            else ...[
              if (_canModerate) ...[
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.red),
                  title: const Text('Report content',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A))),
                  subtitle: const Text(
                      'Spam, harassment, inappropriate content',
                      style: TextStyle(fontSize: 12, color: Color(0xFF000000))),
                  onTap: _report,
                ),
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: Text('Block ${widget.displayName}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A))),
                  subtitle: const Text('Hide their content for 90 days',
                      style: TextStyle(fontSize: 12, color: Color(0xFF000000))),
                  onTap: _block,
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('This is your own content',
                      style: TextStyle(fontSize: 14, color: Color(0xFF000000))),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: GlayaColors.berry)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
