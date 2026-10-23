import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'api_client.dart';

class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  socket_io.Socket? _socket;
  bool get isConnected => _socket?.connected ?? false;

  final _newMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageDeletedController = StreamController<Map<String, dynamic>>.broadcast();
  final _messagesReadController = StreamController<Map<String, dynamic>>.broadcast();
  final _channelUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceController = StreamController<Map<String, dynamic>>.broadcast();
  final _snapSavedController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onMessageUpdated => _messageUpdatedController.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted => _messageDeletedController.stream;
  Stream<Map<String, dynamic>> get onMessagesRead => _messagesReadController.stream;
  Stream<Map<String, dynamic>> get onChannelUpdated => _channelUpdatedController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onPresence => _presenceController.stream;
  Stream<Map<String, dynamic>> get onSnapSaved => _snapSavedController.stream;

  String _getSocketUrl() {
    try {
      final uri = Uri.parse(ApiClient.baseUrl);
      // Strip /api if present to target the socket server root
      final portPart = uri.hasPort ? ':${uri.port}' : '';
      return '${uri.scheme}://${uri.host}$portPart';
    } catch (_) {
      return 'https://api.abuadapp.com.ng';
    }
  }

  Future<void> connect() async {
    await ApiClient.ensureTokensLoaded();
    final token = ApiClient.accessToken;
    if (token == null || token.isEmpty) {
      debugPrint('⚡ SocketService: Cannot connect, access token is missing');
      return;
    }

    if (_socket != null && _socket!.connected) {
      debugPrint('⚡ SocketService: Already connected');
      return;
    }

    _socket?.dispose();

    final serverUrl = _getSocketUrl();
    debugPrint('⚡ SocketService: Connecting to $serverUrl ...');

    _socket = socket_io.io(
      serverUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setAuth({'token': token})
          .setQuery({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('⚡ SocketService: Connected successfully!');
    });

    _socket!.onDisconnect((_) {
      debugPrint('⚡ SocketService: Disconnected');
    });

    _socket!.onConnectError((err) {
      debugPrint('⚡ SocketService connection error: $err');
    });

    _socket!.on('message:new', (data) {
      if (data is Map) {
        _newMessageController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('message:updated', (data) {
      if (data is Map) {
        _messageUpdatedController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('message:deleted', (data) {
      if (data is Map) {
        _messageDeletedController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('messages:read', (data) {
      if (data is Map) {
        _messagesReadController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('channel:updated', (data) {
      if (data is Map) {
        _channelUpdatedController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('typing', (data) {
      if (data is Map) {
        _typingController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('presence', (data) {
      if (data is Map) {
        _presenceController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('snap:saved', (data) {
      if (data is Map) {
        _snapSavedController.add(Map<String, dynamic>.from(data));
      }
    });
  }

  void sendTyping(String channelId, bool isTyping) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('typing', {'channelId': channelId, 'isTyping': isTyping});
    }
  }

  void disconnect() {
    try {
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
    } catch (e) {
      debugPrint('⚡ SocketService error on disconnect: $e');
    }
  }
}
