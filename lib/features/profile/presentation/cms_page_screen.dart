import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/services/api_service.dart';

class CmsPageScreen extends ConsumerStatefulWidget {
  final String slug;

  const CmsPageScreen({super.key, required this.slug});

  @override
  ConsumerState<CmsPageScreen> createState() => _CmsPageScreenState();
}

class _CmsPageScreenState extends ConsumerState<CmsPageScreen> {
  static const Color pinkPrimary = Color(0xFFD6006E);
  static const Color darkBrown = Color(0xFF3E1C0E);
  static const Color white = Colors.white;

  Map<String, dynamic>? _pageData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPage();
  }

  Future<void> _fetchPage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = ApiService.dio;
      final response = await dio.get('/cms/${widget.slug}');
      if (response.data['success']) {
        setState(() {
          _pageData = response.data['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.data['error'] ?? 'Failed to load page';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: white,
      appBar: AppBar(
        backgroundColor: pinkPrimary,
        title: Text(
          _pageData?['title'] ?? 'Page',
          style: const TextStyle(color: white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: pinkPrimary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: darkBrown),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchPage,
                        style: ElevatedButton.styleFrom(backgroundColor: pinkPrimary),
                        child: const Text('Retry', style: TextStyle(color: white)),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_pageData != null) ...[
                        Text(
                          _pageData!['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: darkBrown,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._renderHtml(_pageData!['content'] ?? ''),
                        if (widget.slug == 'support') ...[
                          const SizedBox(height: 24),
                          const _ContactForm(),
                        ],
                      ],
                    ],
                  ),
                ),
    );
  }

  /// Convert stored HTML content into readable widgets (no html renderer dependency).
  List<Widget> _renderHtml(String html) {
    if (html.trim().isEmpty) return const [];
    // Normalize block-level tags into newlines
    var text = html
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</\s*(p|div|h[1-6]|li|ul|ol|tr|table|section|article)\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<\s*li[^>]*>', caseSensitive: false), '• ')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');

    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return lines.map((line) {
      final isHeading = line.startsWith('##') || RegExp(r'^\d+\.').hasMatch(line) || line.length < 60 && line == line.toUpperCase();
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          line,
          style: TextStyle(
            fontSize: isHeading ? 18 : 16,
            fontWeight: isHeading ? FontWeight.bold : FontWeight.normal,
            color: darkBrown,
            height: 1.5,
          ),
        ),
      );
    }).toList();
  }
}

class _ContactForm extends StatefulWidget {
  const _ContactForm();

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  static const Color pinkPrimary = Color(0xFFD6006E);
  static const Color darkBrown = Color(0xFF3E1C0E);

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _messageCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in your name, email and message.');
      return;
    }
    setState(() { _sending = true; _error = null; });
    try {
      await ApiService.dio.post('/support/contact', data: {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'subject': _subjectCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
      });
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to send. Please try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Message sent! Our support team will reply to your email.',
                style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Send us a message',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBrown)),
        const SizedBox(height: 12),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _subjectCtrl,
          decoration: const InputDecoration(labelText: 'Subject (optional)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _messageCtrl,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: _sending ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: pinkPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _sending
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Send Message', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
