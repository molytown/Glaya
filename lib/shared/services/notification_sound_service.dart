import 'package:audioplayers/audioplayers.dart';

/// Plays Glaya notification sounds (same files as the React app).
class NotificationSoundService {
  NotificationSoundService._();
  static final NotificationSoundService instance = NotificationSoundService._();

  final AudioPlayer _player = AudioPlayer();

  static const String _notificationProfessional =
      'audio/new-notification-professional.mp3';
  static const String _notificationAdmin =
      'audio/new-notification-admin.mp3';
  static const String _messageReceivedProfessional =
      'audio/message-received-professional.mp3';
  static const String _messageReceivedAdmin =
      'audio/message-received-admin.mp3';

  /// Plays the new-notification sound for the current user role.
  /// Mirrors React's notificationHandler.playNotificationSound:
  /// professionals get the "professional" chime, everyone else the "admin" one.
  Future<void> playNotification({required bool isProfessional}) async {
    await _play(isProfessional ? _notificationProfessional : _notificationAdmin);
  }

  /// Plays the chat-message-received sound.
  Future<void> playMessageReceived({required bool isProfessional}) async {
    await _play(
        isProfessional ? _messageReceivedProfessional : _messageReceivedAdmin);
  }

  Future<void> _play(String asset) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(asset));
    } catch (_) {
      // Sound playback is best-effort — never crash on audio errors
    }
  }
}
