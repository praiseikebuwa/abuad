import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'api_client.dart';
import 'notification_service.dart';

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
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  final _configUpdatedController = StreamController<Map<String, dynamic>>.broadcast();

  // Audio Spaces Realtime Streams
  final _audioRoomReactionController = StreamController<Map<String, dynamic>>.broadcast();
  final _audioRoomMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _audioRoomHandRaisedController = StreamController<Map<String, dynamic>>.broadcast();
  final _audioRoomHandLoweredController = StreamController<Map<String, dynamic>>.broadcast();
  final _audioRoomParticipantJoinedController = StreamController<Map<String, dynamic>>.broadcast();
  final _audioRoomParticipantLeftController = StreamController<Map<String, dynamic>>.broadcast();
  final _audioRoomParticipantUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _audioRoomEndedController = StreamController<Map<String, dynamic>>.broadcast();
  final _audioRoomRolePromotedController = StreamController<Map<String, dynamic>>.broadcast();
  final _audioRoomRoleDemotedController = StreamController<Map<String, dynamic>>.broadcast();
  final _audioRoomForceMutedController = StreamController<Map<String, dynamic>>.broadcast();
  final _audioRoomKickedController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onMessageUpdated => _messageUpdatedController.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted => _messageDeletedController.stream;
  Stream<Map<String, dynamic>> get onMessagesRead => _messagesReadController.stream;
  Stream<Map<String, dynamic>> get onChannelUpdated => _channelUpdatedController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onPresence => _presenceController.stream;
  Stream<Map<String, dynamic>> get onSnapSaved => _snapSavedController.stream;
  Stream<Map<String, dynamic>> get onNotification => _notificationController.stream;
  Stream<Map<String, dynamic>> get onConfigUpdated => _configUpdatedController.stream;

  Stream<Map<String, dynamic>> get onAudioRoomReaction => _audioRoomReactionController.stream;
  Stream<Map<String, dynamic>> get onAudioRoomMessage => _audioRoomMessageController.stream;
  Stream<Map<String, dynamic>> get onAudioRoomHandRaised => _audioRoomHandRaisedController.stream;
  Stream<Map<String, dynamic>> get onAudioRoomHandLowered => _audioRoomHandLoweredController.stream;
  Stream<Map<String, dynamic>> get onAudioRoomParticipantJoined => _audioRoomParticipantJoinedController.stream;
  Stream<Map<String, dynamic>> get onAudioRoomParticipantLeft => _audioRoomParticipantLeftController.stream;
  Stream<Map<String, dynamic>> get onAudioRoomParticipantUpdated => _audioRoomParticipantUpdatedController.stream;
  Stream<Map<String, dynamic>> get onAudioRoomEnded => _audioRoomEndedController.stream;
  Stream<Map<String, dynamic>> get onAudioRoomRolePromoted => _audioRoomRolePromotedController.stream;
  Stream<Map<String, dynamic>> get onAudioRoomRoleDemoted => _audioRoomRoleDemotedController.stream;
  Stream<Map<String, dynamic>> get onAudioRoomForceMuted => _audioRoomForceMutedController.stream;
  Stream<Map<String, dynamic>> get onAudioRoomKicked => _audioRoomKickedController.stream;

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
          .setTransports(['polling', 'websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setTimeout(10000)
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
        final map = Map<String, dynamic>.from(data);
        _newMessageController.add(map);

        try {
          final msg = map['message'] is Map ? Map<String, dynamic>.from(map['message']) : map;
          final sender = msg['sender'] is Map ? Map<String, dynamic>.from(msg['sender']) : {};
          final senderName = sender['fullName'] ?? sender['name'] ?? sender['username'] ?? 'New Message';
          final content = msg['content']?.toString() ?? 'Sent a message';
          final channelId = map['channelId']?.toString();

          NotificationService().showLocalNotification(
            title: senderName.toString(),
            body: content,
            payload: channelId,
            type: 'chat',
          );
        } catch (_) {}
      }
    });

    _socket!.on('notification:new', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        _notificationController.add(map);
        final title = map['title']?.toString() ?? 'New Notification';
        final body = map['body']?.toString() ?? '';
        final type = map['type']?.toString() ?? 'system';
        NotificationService().showLocalNotification(
          title: title,
          body: body,
          type: type,
        );
      }
    });

    _socket!.on('broadcast:new', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final title = map['title']?.toString() ?? 'Campus Broadcast';
        final body = map['body']?.toString() ?? '';
        final type = map['type']?.toString() ?? 'urgent';
        NotificationService().showLocalNotification(
          title: '📢 $title',
          body: body,
          type: type,
        );
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

    _socket!.on('config:updated', (data) {
      if (data is Map) {
        _configUpdatedController.add(Map<String, dynamic>.from(data));
      }
    });

    // Audio Room Spaces listeners
    _socket!.on('audio_room:reaction', (data) {
      if (data is Map) _audioRoomReactionController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('audio_room:message', (data) {
      if (data is Map) _audioRoomMessageController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('audio_room:hand_raised', (data) {
      if (data is Map) _audioRoomHandRaisedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('audio_room:hand_lowered', (data) {
      if (data is Map) _audioRoomHandLoweredController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('audio_room:participant_joined', (data) {
      if (data is Map) _audioRoomParticipantJoinedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('audio_room:participant_left', (data) {
      if (data is Map) _audioRoomParticipantLeftController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('audio_room:participant_updated', (data) {
      if (data is Map) _audioRoomParticipantUpdatedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('audio_room:ended', (data) {
      if (data is Map) _audioRoomEndedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('audio_room:role_promoted', (data) {
      if (data is Map) _audioRoomRolePromotedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('audio_room:role_demoted', (data) {
      if (data is Map) _audioRoomRoleDemotedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('audio_room:force_muted', (data) {
      if (data is Map) _audioRoomForceMutedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('audio_room:kicked', (data) {
      if (data is Map) _audioRoomKickedController.add(Map<String, dynamic>.from(data));
    });
  }

  void joinAudioRoom(String roomId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('audio_room:join', {'roomId': roomId});
    }
  }

  void leaveAudioRoom(String roomId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('audio_room:leave', {'roomId': roomId});
    }
  }

  void sendAudioRoomReaction(String roomId, String emoji) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('audio_room:reaction', {'roomId': roomId, 'emoji': emoji});
    }
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
