import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

class OnboardingMessage {
  final String id;
  final String content;
  final String senderType; // 'system' or 'user'
  final DateTime createdAt;
  final bool isRead;

  OnboardingMessage({
    required this.id,
    required this.content,
    required this.senderType,
    required this.createdAt,
    this.isRead = false,
  });

  factory OnboardingMessage.fromJson(Map<String, dynamic> json) {
    return OnboardingMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      senderType: json['senderType'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'senderType': senderType,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  OnboardingMessage copyWith({
    String? id,
    String? content,
    String? senderType,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return OnboardingMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      senderType: senderType ?? this.senderType,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

class OnboardingState {
  final List<OnboardingMessage> messages;
  final bool isLoading;
  final String? error;
  final bool hasUnreadMessages;
  final bool isActive;

  OnboardingState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.hasUnreadMessages = false,
    this.isActive = false,
  });

  OnboardingState copyWith({
    List<OnboardingMessage>? messages,
    bool? isLoading,
    String? error,
    bool? hasUnreadMessages,
    bool? isActive,
  }) {
    return OnboardingState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasUnreadMessages: hasUnreadMessages ?? this.hasUnreadMessages,
      isActive: isActive ?? this.isActive,
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(OnboardingState());

  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final messages = await ApiService.getOnboardingMessages();
      final hasUnread = messages.any((m) => !(m['isRead'] as bool? ?? false) && (m['senderType'] as String?) == 'system');
      state = state.copyWith(
        messages: messages.map((m) => OnboardingMessage.fromJson(m)).toList(),
        isLoading: false,
        hasUnreadMessages: hasUnread,
        isActive: messages.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> sendReply(String reply) async {
    try {
      await ApiService.sendOnboardingReply(reply);
      // Reload messages after sending reply
      await loadMessages();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> markAsRead() async {
    try {
      await ApiService.markOnboardingAsRead();
      final updatedMessages = state.messages.map((m) {
        if (m.senderType == 'system' && !m.isRead) {
          return m.copyWith(isRead: true);
        }
        return m;
      }).toList();
      state = state.copyWith(
        messages: updatedMessages,
        hasUnreadMessages: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void addSystemMessage(String content) {
    final newMessage = OnboardingMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      senderType: 'system',
      createdAt: DateTime.now(),
      isRead: false,
    );
    state = state.copyWith(
      messages: [...state.messages, newMessage],
      hasUnreadMessages: true,
      isActive: true,
    );
  }

  void reset() {
    state = OnboardingState();
  }
}

final onboardingProvider = StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier();
});
