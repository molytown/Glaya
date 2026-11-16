import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/onboarding_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/text_styles.dart';

class OnboardingChatScreen extends ConsumerStatefulWidget {
  const OnboardingChatScreen({super.key});

  @override
  ConsumerState<OnboardingChatScreen> createState() => _OnboardingChatScreenState();
}

class _OnboardingChatScreenState extends ConsumerState<OnboardingChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markAsRead();
  }

  Future<void> _loadMessages() async {
    await ref.read(onboardingProvider.notifier).loadMessages();
  }

  Future<void> _markAsRead() async {
    await ref.read(onboardingProvider.notifier).markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    ref.read(onboardingProvider.notifier).sendReply(message);
    _messageController.clear();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingProvider);

    // Auto-scroll when new messages arrive
    ref.listen(onboardingProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Glaya'),
        backgroundColor: GlayaColors.berry,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: onboardingState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : onboardingState.error != null
                    ? Center(
                        child: Text(
                          'Error: ${onboardingState.error}',
                          style: GlayaTextStyles.bodyMedium(color: Colors.red),
                        ),
                      )
                    : onboardingState.messages.isEmpty
                        ? Center(
                            child: Text(
                              'No messages yet',
                              style: GlayaTextStyles.bodyMedium(),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: onboardingState.messages.length,
                            itemBuilder: (context, index) {
                              final message = onboardingState.messages[index];
                              return _buildMessageBubble(message);
                            },
                          ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(OnboardingMessage message) {
    final isSystem = message.senderType == 'system';
    
    return Align(
      alignment: isSystem ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isSystem ? GlayaColors.divider : GlayaColors.berry,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSystem) ...[
              Row(
                children: [
                  Image.asset('assets/logo.png', width: 20, height: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Glaya',
                    style: GlayaTextStyles.bodySmall(
                      color: GlayaColors.textSecondary,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text(
              message.content,
              style: GlayaTextStyles.bodyMedium(
                color: isSystem ? GlayaColors.textPrimary : Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.createdAt),
              style: GlayaTextStyles.bodySmall(
                color: isSystem ? GlayaColors.textSecondary : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Quick reply button for "No One"
          OutlinedButton(
            onPressed: () {
              _messageController.text = 'No One';
              _sendMessage();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: GlayaColors.berry,
              side: const BorderSide(color: GlayaColors.berry),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('No One'),
          ),
          const SizedBox(height: 8),
          // Message input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type your reply...',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: GlayaColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: GlayaColors.berry),
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: GlayaColors.berry,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
