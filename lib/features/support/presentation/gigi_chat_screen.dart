import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../auth/presentation/providers/auth_notifier.dart';

class _ChatMessage {
  final String role; // 'user' | 'assistant' | 'human'
  final String content;
  final bool escalated;
  final DateTime? time;

  const _ChatMessage({
    required this.role,
    required this.content,
    this.escalated = false,
    this.time,
  });
}

class GigiChatScreen extends ConsumerStatefulWidget {
  const GigiChatScreen({super.key});

  @override
  ConsumerState<GigiChatScreen> createState() => _GigiChatScreenState();
}

class _GigiChatScreenState extends ConsumerState<GigiChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  String _mode = 'ai'; // 'ai' | 'human'
  final List<_ChatMessage> _aiMessages = [];
  List<Map<String, dynamic>> _humanMessages = [];
  bool _aiSending = false;
  bool _humanSending = false;
  bool _humanLoading = false;
  bool _guestFieldsExpanded = false;

  @override
  void initState() {
    super.initState();
    _aiMessages.add(const _ChatMessage(
      role: 'assistant',
      content:
          "Hi! I'm Gigi, Glaya's support assistant. How can I help you today?",
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  // ---------- Gigi AI ----------
  Future<void> _sendAiMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _aiSending) return;
    _messageController.clear();
    setState(() {
      _aiSending = true;
      _aiMessages
          .add(_ChatMessage(role: 'user', content: text, time: DateTime.now()));
    });
    _scrollToBottom();

    try {
      final history = _aiMessages
          .where((m) => m.content.isNotEmpty)
          .map((m) => {
                'role': m.role == 'user' ? 'user' : 'assistant',
                'content': m.content
              })
          .toList();
      final user = ref.read(authNotifierProvider).valueOrNull;
      final isGuest = user == null;
      final response = await ApiService.dio.post('/support/ai/chat', data: {
        'message': text,
        'history': history,
        if (isGuest && _nameController.text.trim().isNotEmpty)
          'name': _nameController.text.trim(),
        if (isGuest && _emailController.text.trim().isNotEmpty)
          'email': _emailController.text.trim(),
      });
      final data = response.data?['data'] as Map<String, dynamic>? ?? {};
      setState(() {
        _aiMessages.add(_ChatMessage(
          role: 'assistant',
          content: (data['reply'] as String?)?.isNotEmpty == true
              ? data['reply'] as String
              : "Sorry, I didn't catch that — could you try again?",
          escalated: data['escalated'] == true,
          time: DateTime.now(),
        ));
      });
    } catch (e) {
      setState(() {
        _aiMessages.add(const _ChatMessage(
          role: 'assistant',
          content:
              "I'm having trouble connecting right now. Please try again in a moment.",
          escalated: true,
        ));
      });
    } finally {
      setState(() => _aiSending = false);
      _scrollToBottom();
    }
  }

  // ---------- Human support ----------
  Future<void> _loadHumanMessages() async {
    setState(() => _humanLoading = true);
    try {
      final response = await ApiService.dio.get('/support-chat/messages');
      setState(() {
        _humanMessages =
            (response.data['data'] as List).cast<Map<String, dynamic>>();
        _humanLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _humanLoading = false);
    }
  }

  Future<void> _sendHumanMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _humanSending) return;
    final user = ref.read(authNotifierProvider).valueOrNull;
    if (user == null) return;
    _messageController.clear();
    setState(() {
      _humanSending = true;
      _humanMessages.add({
        'content': text,
        'senderId': user.id,
        'createdAt': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();
    try {
      await ApiService.dio
          .post('/support-chat/message', data: {'content': text});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    } finally {
      setState(() => _humanSending = false);
    }
  }

  void _switchMode(String mode) {
    if (mode == _mode) return;
    final user = ref.read(authNotifierProvider).valueOrNull;
    if (mode == 'human' && user == null) return; // guests can't use human chat
    setState(() => _mode = mode);
    if (mode == 'human' && _humanMessages.isEmpty) {
      _loadHumanMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final isGuest = user == null;

    return Scaffold(
      backgroundColor: GlayaColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            if (_mode == 'ai')
              ClipOval(
                child: Image.asset(
                  'assets/gigi-avatar.jpg',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.smart_toy_outlined, size: 24),
                ),
              )
            else
              const Icon(Icons.support_agent_outlined, size: 24),
            const SizedBox(width: 10),
            Text(_mode == 'ai' ? 'Gigi · Glaya Support' : 'Human Support'),
          ],
        ),
        backgroundColor: GlayaColors.berry,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _modeButton('ai', 'Gigi (AI)', Icons.smart_toy_outlined),
                const SizedBox(width: 8),
                _modeButton('human', isGuest ? 'Human (sign in)' : 'Human',
                    Icons.support_agent_outlined,
                    enabled: !isGuest),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _mode == 'ai' ? _buildAiMessages() : _buildHumanMessages(),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _modeButton(String mode, String label, IconData icon,
      {bool enabled = true}) {
    final active = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: enabled ? () => _switchMode(mode) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? GlayaColors.berry : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? GlayaColors.berry : GlayaColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: active
                      ? Colors.white
                      : (enabled ? GlayaColors.textSecondary : Colors.grey)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? Colors.white
                      : (enabled ? GlayaColors.textSecondary : Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiMessages() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _aiMessages.length + (_aiSending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _aiMessages.length) {
          return _typingBubble();
        }
        final msg = _aiMessages[index];
        final isUser = msg.role == 'user';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  isUser ? 'You' : 'Gigi',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(maxWidth: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isUser ? GlayaColors.berry : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: isUser ? null : Border.all(color: GlayaColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: isUser ? Colors.white : GlayaColors.textPrimary,
                      ),
                    ),
                    if (msg.escalated)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'A support agent has been notified and will follow up.',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF059669),
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('h:mm a').format(msg.time ?? DateTime.now()),
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            isUser ? Colors.white70 : const Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _typingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text('Gigi',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF666666))),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GlayaColors.border),
            ),
            child: const SizedBox(
              width: 40,
              height: 14,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: GlayaColors.berry),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHumanMessages() {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    if (user == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Sign in to chat with a human support agent.',
            textAlign: TextAlign.center,
            style: TextStyle(color: GlayaColors.textSecondary),
          ),
        ),
      );
    }
    if (_humanLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_humanMessages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.support_agent, size: 64, color: GlayaColors.berry),
            SizedBox(height: 16),
            Text('No messages yet',
                style: TextStyle(fontSize: 16, color: Color(0xFF888888))),
            SizedBox(height: 8),
            Text('Start a conversation with our support team',
                style: TextStyle(fontSize: 14, color: Color(0xFFAAAAAA))),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _humanMessages.length,
      itemBuilder: (context, index) {
        final msg = _humanMessages[index];
        final isOwn = msg['senderId'] == user.id;
        return _HumanBubble(message: msg, isOwn: isOwn);
      },
    );
  }

  Widget _buildInputBar() {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final sending = _mode == 'ai' ? _aiSending : _humanSending;
    final humanBlocked = _mode == 'human' && user == null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Guest contact fields (AI mode only)
          if (_mode == 'ai' && user == null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(
                    () => _guestFieldsExpanded = !_guestFieldsExpanded),
                icon: const Icon(Icons.alternate_email, size: 16),
                label: Text(
                  _guestFieldsExpanded
                      ? 'Hide contact info'
                      : 'Leave email for follow-up',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            if (_guestFieldsExpanded)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'Name (optional)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'Email (optional)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: humanBlocked
                        ? 'Sign in to message support'
                        : (_mode == 'ai'
                            ? 'Ask Gigi anything...'
                            : 'Type a message...'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: GlayaColors.berry),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  enabled: !sending && !humanBlocked,
                  onSubmitted: (_) =>
                      _mode == 'ai' ? _sendAiMessage() : _sendHumanMessage(),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: const BoxDecoration(
                    color: GlayaColors.berry, shape: BoxShape.circle),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: sending || humanBlocked
                      ? null
                      : (_mode == 'ai' ? _sendAiMessage : _sendHumanMessage),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HumanBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isOwn;

  const _HumanBubble({required this.message, required this.isOwn});

  @override
  Widget build(BuildContext context) {
    final content = message['content'] as String? ?? '';
    final createdAt = message['createdAt'] as String?;
    String timeStr = '';
    if (createdAt != null) {
      try {
        timeStr = DateFormat('h:mm a').format(DateTime.parse(createdAt));
      } catch (_) {}
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isOwn)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text('Support Team',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF666666))),
            ),
          Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isOwn ? GlayaColors.berry : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(content,
                    style: TextStyle(
                        fontSize: 14,
                        color: isOwn ? Colors.white : const Color(0xFF1A1A1A))),
                const SizedBox(height: 4),
                Text(timeStr,
                    style: TextStyle(
                        fontSize: 10,
                        color:
                            isOwn ? Colors.white70 : const Color(0xFF888888))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
