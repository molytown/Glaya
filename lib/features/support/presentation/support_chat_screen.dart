import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/notification_websocket_service.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../auth/presentation/providers/auth_notifier.dart';

class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({super.key});

  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _notificationService = NotificationWebSocketService.instance;
  List<Map<String, dynamic>> _messages = [];
  String? _userId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final userId = await StorageService.getUserId();
    _userId = userId;
    if (userId != null) {
      _notificationService.connect(userId);
      _notificationService.notificationStream.listen(_onNewMessage);
      _notificationService.professionalMessageStream.listen(_onNewMessage);
      await _loadMessages();
    }
  }

  Future<void> _loadMessages() async {
    try {
      final response = await ApiService.dio.get('/support-chat/messages');
      setState(() {
        _messages =
            (response.data['data'] as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      print('Error loading support messages: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onNewMessage(Map<String, dynamic> data) {
    setState(() {
      _messages.add(data);
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _userId == null) return;

    setState(() {
      _messageController.clear();
      _messages.add({
        'content': content,
        'senderId': _userId,
        'createdAt': DateTime.now().toIso8601String(),
        'isOwn': true,
      });
    });

    try {
      await ApiService.dio.post(
        '/support-chat/message',
        data: {'content': content},
      );
    } catch (e) {
      print('Error sending support message: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to send message')));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Chat'),
        backgroundColor: GlayaColors.berry,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.support_agent,
                              size: 64,
                              color: GlayaColors.berry,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF000000),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Start a conversation with our support team',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFFAAAAAA),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isOwn = message['senderId'] == _userId;
                          return _MessageBubble(
                            message: message,
                            isOwn: isOwn,
                            userName: isOwn ? user?.name : 'Support Team',
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF000000).withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
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
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: GlayaColors.berry,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isOwn;
  final String? userName;

  const _MessageBubble({
    required this.message,
    required this.isOwn,
    this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final content = message['content'] as String? ?? '';
    final createdAt = message['createdAt'] as String?;

    String timeStr = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt);
        timeStr = DateFormat('h:mm a').format(dt);
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isOwn && userName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                userName!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF000000),
                ),
              ),
            ),
          Row(
            mainAxisAlignment:
                isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isOwn ? GlayaColors.berry : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: 14,
                        color: isOwn ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 10,
                        color: isOwn ? Colors.white70 : const Color(0xFF000000),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
