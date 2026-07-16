import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;

  WebSocketService._internal();

  WebSocketChannel? _channel;
  final ValueNotifier<String?> dbChangeEvent = ValueNotifier<String?>(null);

  void connect() {
    if (_channel != null) return;

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('wss://api.oksigen24medis.com'),
      );

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            if (data['event'] == 'db_change') {
              final String? path = data['payload']?['url'];
              // Trigger update notification
              dbChangeEvent.value = path;
              // Reset so future identical changes still trigger notifications
              dbChangeEvent.value = null;
            }
          } catch (e) {
            debugPrint('Error parsing WebSocket message: $e');
          }
        },
        onError: (err) {
          debugPrint('WebSocket error: $err');
          _reconnect();
        },
        onDone: () {
          debugPrint('WebSocket closed');
          _reconnect();
        },
      );
    } catch (e) {
      debugPrint('Failed to connect to WebSocket: $e');
      _reconnect();
    }
  }

  void _reconnect() {
    _channel = null;
    Future.delayed(const Duration(seconds: 5), () {
      connect();
    });
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
