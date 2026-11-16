import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/api_constants.dart';

class WebSocketService {
  io.Socket? _socket;
  final _messageController = StreamController<dynamic>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _newBookingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _adminMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _bookingControlController =
      StreamController<Map<String, dynamic>>.broadcast();
  final Set<String> _joinedRooms = {};
  final _professionalMessageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<dynamic> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Map<String, dynamic>> get newBookingStream =>
      _newBookingController.stream;
  Stream<Map<String, dynamic>> get adminMessageStream =>
      _adminMessageController.stream;
  Stream<Map<String, dynamic>> get bookingControlStream =>
      _bookingControlController.stream;
  Stream<Map<String, dynamic>> get professionalMessageStream =>
      _professionalMessageController.stream;

  void connect() {
    if (_socket != null) return;

    _socket = io.io(ApiConstants.socketUrl, <String, dynamic>{
      'transports': ['websocket', 'polling'],
      'autoConnect': true,
    });

    _socket!.on('message:receive', (data) {
      _messageController.add(data);
    });

    _socket!.on('typing:start', (data) {
      _typingController.add({'typing': true, 'userId': data['userId']});
    });

    _socket!.on('typing:stop', (data) {
      _typingController.add({'typing': false, 'userId': data['userId']});
    });

    _socket!.on('booking:created', (data) {
      _newBookingController.add(data as Map<String, dynamic>);
    });

    _socket!.on('booking_update', (data) {
      _bookingControlController.add(data as Map<String, dynamic>);
    });

    _socket!.on('admin:message', (data) {
      _adminMessageController.add(data as Map<String, dynamic>);
    });

    _socket!.on('booking:time_confirmed', (data) {
      _bookingControlController.add(data as Map<String, dynamic>);
    });

    _socket!.on('booking:deposit_invoice', (data) {
      _bookingControlController.add(data as Map<String, dynamic>);
    });

    _socket!.on('booking:deposit_paid', (data) {
      _bookingControlController.add(data as Map<String, dynamic>);
    });

    _socket!.on('booking:confirmed', (data) {
      _bookingControlController.add(data as Map<String, dynamic>);
    });

    _socket!.on('onboarding:message', (data) {
      _bookingControlController.add(data as Map<String, dynamic>);
    });

    _socket!.on('booking:terms_proposed', (data) {
      _bookingControlController.add(data as Map<String, dynamic>);
    });

    _socket!.on('booking:balance_due', (data) {
      _bookingControlController.add(data as Map<String, dynamic>);
    });

    _socket!.on('booking:cod_ready', (data) {
      _bookingControlController.add(data as Map<String, dynamic>);
    });

    _socket!.on('booking:payment_confirmed', (data) {
      _bookingControlController.add(data as Map<String, dynamic>);
    });

    // Socket.IO rooms are lost on reconnect — re-join all rooms on (re)connect
    _socket!.on('connect', (_) {
      for (final room in _joinedRooms) {
        _socket?.emit('join-room', room);
      }
    });

    _socket!.on('professional:message', (data) {
      _professionalMessageController.add(data as Map<String, dynamic>);
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void joinRoom(String bookingId) {
    _joinedRooms.add(bookingId);
    _socket?.emit('join-room', bookingId);
  }

  void leaveRoom(String bookingId) {
    _joinedRooms.remove(bookingId);
    _socket?.emit('leave-room', bookingId);
  }

  void sendMessage(
    String bookingId,
    String senderId,
    String content,
    String type,
  ) {
    _socket?.emit('message:send', {
      'bookingId': bookingId,
      'senderId': senderId,
      'content': content,
      'type': type,
    });
  }

  void sendTypingStart(String bookingId, String userId) {
    _socket?.emit('typing:start', {'bookingId': bookingId, 'userId': userId});
  }

  void sendTypingStop(String bookingId, String userId) {
    _socket?.emit('typing:stop', {'bookingId': bookingId, 'userId': userId});
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _newBookingController.close();
    _adminMessageController.close();
    _bookingControlController.close();
    _professionalMessageController.close();
  }

  void joinSupportRoom(String userId) {
    _socket?.emit('join', {'room': 'support:$userId'});
  }
}
