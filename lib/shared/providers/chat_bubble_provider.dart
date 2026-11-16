import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatBubbleState {
  final bool isVisible;
  final String? latestBookingId;
  final String? latestSenderName;
  final String? latestSenderPhoto;
  final String? senderType; // 'user', 'professional', 'admin', 'support', 'system'
  final int unreadCount;
  final String? serviceName;
  final bool showPopup;
  final String? popupMessage;
  final DateTime? popupTimestamp;
  final bool hasOnboardingMessages;
  final String? onboardingLastMessage;
  final bool dismissed;

  const ChatBubbleState({
    this.isVisible = false,
    this.latestBookingId,
    this.latestSenderName,
    this.latestSenderPhoto,
    this.senderType,
    this.unreadCount = 0,
    this.serviceName,
    this.showPopup = false,
    this.popupMessage,
    this.popupTimestamp,
    this.hasOnboardingMessages = false,
    this.onboardingLastMessage,
    this.dismissed = false,
  });

  ChatBubbleState copyWith({
    bool? isVisible,
    String? latestBookingId,
    String? latestSenderName,
    String? latestSenderPhoto,
    String? senderType,
    int? unreadCount,
    String? serviceName,
    bool? showPopup,
    String? popupMessage,
    DateTime? popupTimestamp,
    bool? hasOnboardingMessages,
    String? onboardingLastMessage,
    bool? dismissed,
  }) {
    return ChatBubbleState(
      isVisible: isVisible ?? this.isVisible,
      latestBookingId: latestBookingId ?? this.latestBookingId,
      latestSenderName: latestSenderName ?? this.latestSenderName,
      latestSenderPhoto: latestSenderPhoto ?? this.latestSenderPhoto,
      senderType: senderType ?? this.senderType,
      unreadCount: unreadCount ?? this.unreadCount,
      serviceName: serviceName ?? this.serviceName,
      showPopup: showPopup ?? this.showPopup,
      popupMessage: popupMessage ?? this.popupMessage,
      popupTimestamp: popupTimestamp ?? this.popupTimestamp,
      hasOnboardingMessages: hasOnboardingMessages ?? this.hasOnboardingMessages,
      onboardingLastMessage: onboardingLastMessage ?? this.onboardingLastMessage,
      dismissed: dismissed ?? this.dismissed,
    );
  }
}

class ChatBubbleNotifier extends StateNotifier<ChatBubbleState> {
  ChatBubbleNotifier() : super(const ChatBubbleState());

  void updateFromChatList(List<Map<String, dynamic>> chatRooms) {
    if (chatRooms.isEmpty) {
      state = ChatBubbleState(isVisible: false, dismissed: state.dismissed);
      return;
    }

    // Find the most recent conversation based on last message timestamp
    final sortedRooms = List<Map<String, dynamic>>.from(chatRooms);
    sortedRooms.sort((a, b) {
      final aLast = a['lastMessage'] as Map<String, dynamic>?;
      final bLast = b['lastMessage'] as Map<String, dynamic>?;
      
      if (aLast == null && bLast == null) return 0;
      if (aLast == null) return 1;
      if (bLast == null) return -1;
      
      final aTime = DateTime.tryParse(aLast['created_at'] ?? '');
      final bTime = DateTime.tryParse(bLast['created_at'] ?? '');
      
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      
      return bTime.compareTo(aTime); // Most recent first
    });

    final latestRoom = sortedRooms.first;
    final otherUser = latestRoom['otherUser'] as Map<String, dynamic>?;
    final unreadCount = latestRoom['unreadCount'] as int? ?? 0;

    // Determine sender type - could be derived from user role or explicit field
    final senderType = otherUser?['role'] as String? ?? 'user';
    
    state = ChatBubbleState(
      isVisible: true,
      latestBookingId: latestRoom['bookingId'] as String?,
      latestSenderName: otherUser?['name'] as String?,
      latestSenderPhoto: otherUser?['photoUrl'] as String?,
      senderType: senderType,
      unreadCount: unreadCount,
      serviceName: latestRoom['serviceName'] as String?,
      dismissed: state.dismissed,
    );
  }

  void updateFromNewMessage(Map<String, dynamic> messageData) {
    final senderName = messageData['sender_name'] as String?;
    final senderPhoto = messageData['sender_photo'] as String?;
    final senderType = messageData['sender_type'] as String? ?? 'user';
    final bookingId = messageData['bookingId'] as String?;
    final serviceName = messageData['serviceName'] as String?;
    final messageContent = messageData['content'] as String?;

    // Show popup for admin/system messages
    final shouldShowPopup = (senderType == 'admin' || senderType == 'support' || senderType == 'system') && messageContent != null;

    state = state.copyWith(
      isVisible: true,
      latestBookingId: bookingId,
      latestSenderName: senderName,
      latestSenderPhoto: senderPhoto,
      senderType: senderType,
      unreadCount: state.unreadCount + 1,
      serviceName: serviceName,
      showPopup: shouldShowPopup,
      popupMessage: shouldShowPopup ? messageContent : null,
      popupTimestamp: shouldShowPopup ? DateTime.now() : null,
      dismissed: false,
    );
  }

  void updateFromNewBooking(Map<String, dynamic> bookingData) {
    final professionalName = bookingData['professionalName'] as String?;
    final professionalPhoto = bookingData['professionalPhoto'] as String?;
    final bookingId = bookingData['bookingId'] as String?;
    final serviceName = bookingData['serviceName'] as String?;

    state = ChatBubbleState(
      isVisible: true,
      latestBookingId: bookingId,
      latestSenderName: professionalName,
      latestSenderPhoto: professionalPhoto,
      senderType: 'professional',
      unreadCount: 1,
      serviceName: serviceName,
      dismissed: false,
    );
  }

  void markAsRead() {
    state = state.copyWith(unreadCount: 0);
  }

  void hide() {
    state = const ChatBubbleState(isVisible: false);
  }

  void dismissPopup() {
    state = state.copyWith(showPopup: false, popupMessage: null, popupTimestamp: null);
  }

  void updateFromOnboarding(String lastMessage, bool hasUnread) {
    state = state.copyWith(
      isVisible: true,
      senderType: 'system',
      latestSenderName: 'Glaya',
      latestSenderPhoto: null, // Will use Glaya logo
      hasOnboardingMessages: true,
      onboardingLastMessage: lastMessage,
      showPopup: hasUnread,
      popupMessage: hasUnread ? lastMessage : null,
      popupTimestamp: hasUnread ? DateTime.now() : null,
      unreadCount: hasUnread ? state.unreadCount + 1 : state.unreadCount,
      dismissed: false,
    );
  }

  void dismiss() {
    state = state.copyWith(
      dismissed: true,
      showPopup: false,
      popupMessage: null,
      popupTimestamp: null,
    );
  }

  void undismiss() {
    // Force visible even if a previous chat-list sync left isVisible
    // false — tapping a chat notification should always reveal the bubble.
    // Sender details are filled in by the follow-up /chats/list refresh.
    if (state.dismissed || !state.isVisible) {
      state = state.copyWith(dismissed: false, isVisible: true);
    }
  }
}

final chatBubbleProvider = StateNotifierProvider<ChatBubbleNotifier, ChatBubbleState>((ref) {
  return ChatBubbleNotifier();
});
