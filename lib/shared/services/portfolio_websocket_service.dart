import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'config_service.dart';

class PortfolioWebSocketService {
  static final PortfolioWebSocketService _instance = PortfolioWebSocketService._internal();
  factory PortfolioWebSocketService() => _instance;
  PortfolioWebSocketService._internal();

  IO.Socket? _socket;
  final StreamController<Map<String, dynamic>> _uploadController = StreamController<Map<String, dynamic>>.broadcast();
  bool _isConnected = false;

  Stream<Map<String, dynamic>> get uploadStream => _uploadController.stream;

  void connect() {
    if (_isConnected) return;

    try {
      _socket = IO.io(
        ConfigService().socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .build(),
      );

      _socket!.onConnect((_) {
        print('Portfolio WebSocket connected');
        _isConnected = true;
      });

      _socket!.onDisconnect((_) {
        print('Portfolio WebSocket disconnected');
        _isConnected = false;
      });

      _socket!.on('portfolio:new_upload', (data) {
        if (data is Map<String, dynamic>) {
          _uploadController.add(data);
        }
      });

      _socket!.onError((error) {
        print('Portfolio WebSocket error: $error');
      });
    } catch (e) {
      print('Failed to connect to Portfolio WebSocket: $e');
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _uploadController.close();
  }
}
