import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/socket_service.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/chat_channel.dart';
import '../domain/chat_message.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref);
});

final unreadChatCountProvider = StreamProvider<int>((ref) {
  return Stream.value(0);
});

final chatChannelsProvider = StreamProvider<List<ChatChannel>>((ref) {
  return ref.watch(chatRepositoryProvider).watchChannels();
});

class ChatRepository {
  final Ref? _ref;
  final Map<String, StreamController<List<ChatMessage>>> _messageControllers = {};
  final Map<String, StreamController<ChatChannel?>> _channelControllers = {};
  final StreamController<List<ChatChannel>> _channelsController = StreamController<List<ChatChannel>>.broadcast();
  Timer? _channelsTimer;
  final Map<String, Timer> _messageTimers = {};
  bool _isFetchingChannels = false;
  final Set<String> _inFlightMessageFetches = {};
  final Map<String, Future<ChatChannel?>> _inFlightChannelRequests = {};
  final Map<String, DateTime> _negativeChannelCache = {};

  final Map<String, List<ChatMessage>> _cachedMessages = {};
  final Map<String, ChatChannel> _cachedChannels = {};
  List<ChatChannel> _channelsList = [];
  final Map<String, StreamController<Map<String, bool>>> _typingControllers = {};
  final Map<String, Map<String, bool>> _typingStatus = {};
  bool _socketInitialized = false;

  static const String _channelsCacheKey = 'cached_chat_channels_v2';

  List<ChatChannel> get channels => List.unmodifiable(_channelsList);

  ChatChannel? getCachedChannel(String channelId) {
    if (_cachedChannels.containsKey(channelId)) {
      return _cachedChannels[channelId];
    }
    final cleanId = channelId.startsWith('channel_') ? channelId.substring(8) : channelId;
    if (_cachedChannels.containsKey(cleanId)) {
      return _cachedChannels[cleanId];
    }
    if (_cachedChannels.containsKey('channel_$cleanId')) {
      return _cachedChannels['channel_$cleanId'];
    }
    for (final channel in _cachedChannels.values) {
      if (channel.id == channelId || channel.id == cleanId || channel.id == 'channel_$cleanId') {
        return channel;
      }
    }
    return null;
  }

  void _updateChannelCache(ChatChannel channel) {
    _cachedChannels[channel.id] = channel;
    final cleanId = channel.id.startsWith('channel_') ? channel.id.substring(8) : channel.id;
    _cachedChannels[cleanId] = channel;
    _cachedChannels['channel_$cleanId'] = channel;
  }

  ChatRepository([this._ref, dynamic _]) {
    _initSocketListeners();
    _loadChannelsFromDisk();
  }

  Future<void> _loadChannelsFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_channelsCacheKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          final loaded = decoded.map((m) => ChatChannel.fromMap(Map<String, dynamic>.from(m))).toList();
          for (final ch in loaded) {
            _updateChannelCache(ch);
          }
          _channelsList = loaded;
          _sortChannels(_channelsList);
          if (!_channelsController.isClosed) {
            _channelsController.add(List.from(_channelsList));
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading cached channels: $e');
    }
  }

  Future<void> _saveChannelsToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _channelsList.map((c) => c.toMap()).toList();
      await prefs.setString(_channelsCacheKey, jsonEncode(data));
    } catch (_) {}
  }

  void _sortChannels(List<ChatChannel> list) {
    final uid = currentUserId;
    list.sort((a, b) {
      final aPinned = a.pinnedBy.contains(uid);
      final bPinned = b.pinnedBy.contains(uid);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;

      // Real messages come before empty placeholders
      final aHasMsg = a.lastMessage.isNotEmpty && (a.lastMessage['content']?.toString().trim().isNotEmpty ?? false);
      final bHasMsg = b.lastMessage.isNotEmpty && (b.lastMessage['content']?.toString().trim().isNotEmpty ?? false);
      if (aHasMsg && !bHasMsg) return -1;
      if (!aHasMsg && bHasMsg) return 1;

      return b.lastMessageTime.compareTo(a.lastMessageTime);
    });
  }

  void _emitChannels() {
    _sortChannels(_channelsList);
    if (!_channelsController.isClosed) {
      _channelsController.add(List.from(_channelsList));
    }
    _saveChannelsToDisk();
  }

  void _handleIncomingRealtimeMessage(
    String channelId,
    ChatMessage newMsg,
    Map<String, dynamic> rawMsg,
  ) {
    final existingChannel = getCachedChannel(channelId);
    final uid = currentUserId;

    final senderInfo = rawMsg['sender'];
    final senderName = senderInfo is Map
        ? (senderInfo['fullName'] ?? senderInfo['name'] ?? senderInfo['username'])
        : null;

    final lastMsg = <String, dynamic>{
      'id': newMsg.id,
      'sender_id': newMsg.senderId,
      'senderId': newMsg.senderId,
      'sender_name': senderName,
      'content': newMsg.content,
      'text': newMsg.content,
      'type': newMsg.type,
      'timestamp': newMsg.timestamp.toIso8601String(),
      'created_at': newMsg.timestamp.toIso8601String(),
      'isSnap': newMsg.isSnap,
      'mediaUrl': newMsg.imageUrl ?? newMsg.audioUrl,
    };

    if (existingChannel != null) {
      final updatedUnread = Map<String, int>.from(existingChannel.unreadCounts);
      if (uid != null && newMsg.senderId != uid) {
        updatedUnread[uid] = (updatedUnread[uid] ?? 0) + 1;
      }

      final updatedChannel = existingChannel.copyWith(
        lastMessage: lastMsg,
        lastMessageTime: newMsg.timestamp,
        unreadCounts: updatedUnread,
      );

      _updateChannelCache(updatedChannel);

      final idx = _channelsList.indexWhere(
        (c) => c.id == existingChannel.id || c.id == channelId,
      );
      if (idx != -1) {
        _channelsList[idx] = updatedChannel;
      } else {
        _channelsList.add(updatedChannel);
      }
      _emitChannels();
    } else {
      _fetchChannels();
    }
  }

  void _initSocketListeners() {
    if (_socketInitialized) return;
    _socketInitialized = true;

    SocketService.instance.onNewMessage.listen((data) {
      final channelId = data['channelId']?.toString();
      final msgMap = data['message'];
      if (channelId != null && msgMap is Map) {
        final newMsg = ChatMessage.fromMap(Map<String, dynamic>.from(msgMap));
        final list = _cachedMessages.putIfAbsent(channelId, () => []);
        if (!list.any((m) => m.id == newMsg.id)) {
          list.add(newMsg);
          if (_messageControllers.containsKey(channelId) && !_messageControllers[channelId]!.isClosed) {
            _messageControllers[channelId]!.add(List.from(list));
          }
        }
        // INSTANT REALTIME TOP-OF-LIST UPDATE
        _handleIncomingRealtimeMessage(channelId, newMsg, Map<String, dynamic>.from(msgMap));
        _fetchChannels();
      }
    });

    SocketService.instance.onMessageUpdated.listen((data) {
      final msgMap = data['message'];
      final channelId = data['channelId']?.toString() ??
          (msgMap is Map ? (msgMap['channelId'] ?? msgMap['channel_id'])?.toString() : null);
      if (channelId != null && msgMap is Map) {
        final updatedMsg = ChatMessage.fromMap(Map<String, dynamic>.from(msgMap));
        final list = _cachedMessages[channelId];
        if (list != null) {
          final idx = list.indexWhere((m) => m.id == updatedMsg.id);
          if (idx != -1) {
            list[idx] = updatedMsg;
            if (_messageControllers.containsKey(channelId) && !_messageControllers[channelId]!.isClosed) {
              _messageControllers[channelId]!.add(List.from(list));
            }
          }
        }
      }
    });

    SocketService.instance.onSnapSaved.listen((data) {
      final channelId = data['channelId']?.toString();
      if (channelId != null) {
        _fetchMessages(channelId);
      }
    });

    SocketService.instance.onMessageDeleted.listen((data) {
      final channelId = data['channelId']?.toString();
      final messageId = data['messageId']?.toString();
      if (channelId != null && messageId != null) {
        final list = _cachedMessages[channelId];
        if (list != null) {
          final idx = list.indexWhere((m) => m.id == messageId);
          if (idx != -1) {
            list.removeAt(idx);
            if (_messageControllers.containsKey(channelId) && !_messageControllers[channelId]!.isClosed) {
              _messageControllers[channelId]!.add(List.from(list));
            }
          }
        }
      }
    });

    SocketService.instance.onMessagesRead.listen((data) {
      final channelId = data['channelId']?.toString();
      final readUserId = data['userId']?.toString();
      if (channelId != null && readUserId != null) {
        final list = _cachedMessages[channelId];
        if (list != null) {
          bool hasChange = false;
          for (var i = 0; i < list.length; i++) {
            final m = list[i];
            if (!m.readBy.contains(readUserId)) {
              final newReadBy = List<String>.from(m.readBy)..add(readUserId);
              list[i] = ChatMessage(
                id: m.id,
                senderId: m.senderId,
                content: m.content,
                type: m.type,
                timestamp: m.timestamp,
                isRead: true,
                readBy: newReadBy,
                imageUrl: m.imageUrl,
                imageWidth: m.imageWidth,
                imageHeight: m.imageHeight,
                audioUrl: m.audioUrl,
                duration: m.duration,
                latitude: m.latitude,
                longitude: m.longitude,
                replyToId: m.replyToId,
                replyToContent: m.replyToContent,
                replyToSenderId: m.replyToSenderId,
                reactions: m.reactions,
                mentions: m.mentions,
                isSnap: m.isSnap,
                isEdited: m.isEdited,
                isDeleted: m.isDeleted,
                isPinned: m.isPinned,
                savedBy: m.savedBy,
                forwardedFrom: m.forwardedFrom,
                sharedPostId: m.sharedPostId,
              );
              hasChange = true;
            }
          }
          if (hasChange && _messageControllers.containsKey(channelId) && !_messageControllers[channelId]!.isClosed) {
            _messageControllers[channelId]!.add(List.from(list));
          }
        }
      }
    });

    SocketService.instance.onChannelUpdated.listen((data) {
      _fetchChannels();
      final chId = data['channelId']?.toString();
      if (chId != null) {
        _fetchChannel(chId);
      }
    });

    SocketService.instance.onTyping.listen((data) {
      final channelId = data['channelId']?.toString();
      final typingUserId = data['userId']?.toString();
      final isTyping = data['isTyping'] == true;
      if (channelId != null && typingUserId != null) {
        _typingStatus.putIfAbsent(channelId, () => {})[typingUserId] = isTyping;
        if (_typingControllers.containsKey(channelId) && !_typingControllers[channelId]!.isClosed) {
          _typingControllers[channelId]!.add(Map.from(_typingStatus[channelId]!));
        }
      }
    });
  }

  String? get currentUserId => _ref?.read(authRepositoryProvider).currentUserId;

  Stream<List<ChatChannel>> watchChannels() {
    if (_channelsList.isNotEmpty) {
      scheduleMicrotask(() {
        if (!_channelsController.isClosed) {
          _channelsController.add(List.from(_channelsList));
        }
      });
    }
    _fetchChannels();
    _channelsTimer ??= Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchChannels();
    });
    return _channelsController.stream;
  }

  Future<void> _fetchChannels() async {
    if (_isFetchingChannels) return;
    _isFetchingChannels = true;
    try {
      final response = await ApiClient.get('/chat/channels').timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final channels = (data['data'] as List)
              .map((x) => ChatChannel.fromMap(x))
              .toList();
          for (final ch in channels) {
            _updateChannelCache(ch);
          }
          _channelsList = channels;
          _emitChannels();
          return;
        }
      }
      if (_cachedChannels.isNotEmpty) {
        _channelsList = _cachedChannels.values.toSet().toList();
        _emitChannels();
      }
    } catch (e) {
      debugPrint('Error fetching chat channels: $e');
      if (_cachedChannels.isNotEmpty) {
        _channelsList = _cachedChannels.values.toSet().toList();
        _emitChannels();
      }
    } finally {
      _isFetchingChannels = false;
    }
  }

  Stream<ChatChannel?> watchChannel(String channelId) {
    if (!_channelControllers.containsKey(channelId) || _channelControllers[channelId]!.isClosed) {
      _channelControllers[channelId] = StreamController<ChatChannel?>.broadcast();
    }
    final cached = getCachedChannel(channelId);
    if (cached != null) {
      scheduleMicrotask(() {
        if (_channelControllers.containsKey(channelId) && !_channelControllers[channelId]!.isClosed) {
          _channelControllers[channelId]!.add(cached);
        }
      });
    }
    _fetchChannel(channelId);
    return _channelControllers[channelId]!.stream;
  }

  Future<ChatChannel?> getChannel(String channelId, {bool forceRefresh = false}) async {
    final cached = getCachedChannel(channelId);
    if (!forceRefresh && cached != null) {
      return cached;
    }
    final lastFailed = _negativeChannelCache[channelId];
    if (!forceRefresh && lastFailed != null && DateTime.now().difference(lastFailed).inSeconds < 20) {
      return cached;
    }
    if (_inFlightChannelRequests.containsKey(channelId)) {
      return _inFlightChannelRequests[channelId];
    }

    final future = _fetchChannelInternal(channelId, cached);
    _inFlightChannelRequests[channelId] = future;
    try {
      return await future;
    } finally {
      _inFlightChannelRequests.remove(channelId);
    }
  }

  Future<ChatChannel?> _fetchChannelInternal(String channelId, ChatChannel? cached) async {
    try {
      final cleanId = channelId.startsWith('channel_') ? channelId.substring(8) : channelId;
      
      // Try direct lookup with timeout
      var response = await ApiClient.get('/chat/channels/$channelId')
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200 && cleanId != channelId) {
        response = await ApiClient.get('/chat/channels/$cleanId')
            .timeout(const Duration(seconds: 10));
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final channel = ChatChannel.fromMap(data['data']);
          _updateChannelCache(channel);
          _negativeChannelCache.remove(channelId);
          return channel;
        }
      }

      // If it's a direct user ID, find/create direct DM
      final directRes = await ApiClient.post('/chat/direct', {
        'targetUserId': cleanId,
      }).timeout(const Duration(seconds: 10));
      if (directRes.statusCode == 200 || directRes.statusCode == 201) {
        final directData = jsonDecode(directRes.body);
        if (directData['success'] == true && directData['data'] != null) {
          final channel = ChatChannel.fromMap(directData['data']);
          _updateChannelCache(channel);
          _negativeChannelCache.remove(channelId);
          return channel;
        }
      }
      _negativeChannelCache[channelId] = DateTime.now();
    } catch (e) {
      debugPrint('Error getChannel: $e');
      _negativeChannelCache[channelId] = DateTime.now();
    }
    return cached;
  }

  Future<void> _fetchChannel(String channelId) async {
    try {
      final channel = await getChannel(channelId);
      if (channel != null) {
        _updateChannelCache(channel);
        if (_channelControllers.containsKey(channelId) && !_channelControllers[channelId]!.isClosed) {
          _channelControllers[channelId]!.add(channel);
        }
      }
    } catch (e) {
      debugPrint('Error fetching channel $channelId: $e');
    }
  }

  Stream<List<ChatMessage>> watchMessages(String channelId) {
    if (!_messageControllers.containsKey(channelId) || _messageControllers[channelId]!.isClosed) {
      _messageControllers[channelId] = StreamController<List<ChatMessage>>.broadcast();
    }

    _fetchMessages(channelId);

    // Setup periodic polling for real-time messages & AI responses
    _messageTimers[channelId]?.cancel();
    _messageTimers[channelId] = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchMessages(channelId);
    });

    return _messageControllers[channelId]!.stream;
  }

  Future<void> _fetchMessages(String channelId) async {
    if (_inFlightMessageFetches.contains(channelId)) return;
    _inFlightMessageFetches.add(channelId);
    try {
      final response = await ApiClient.get('/chat/messages?channelId=$channelId');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          var messages = (data['data'] as List)
              .map((x) => ChatMessage.fromMap(x))
              .toList();

          // Check disappearing messages setting
          final prefs = await SharedPreferences.getInstance();
          final disappearing = prefs.getString('chat_disappearing_$channelId') ?? 'Off';
          if (disappearing != 'Off') {
            final now = DateTime.now();
            Duration? cutoff;
            if (disappearing == '24 Hours') cutoff = const Duration(hours: 24);
            if (disappearing == '7 Days') cutoff = const Duration(days: 7);
            if (disappearing == '90 Days') cutoff = const Duration(days: 90);
            if (cutoff != null) {
              final threshold = now.subtract(cutoff);
              messages = messages.where((m) => m.timestamp.isAfter(threshold)).toList();
            }
          }

          _cachedMessages[channelId] = messages;
          if (_messageControllers.containsKey(channelId) && !_messageControllers[channelId]!.isClosed) {
            _messageControllers[channelId]!.add(messages);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching messages for $channelId: $e');
    } finally {
      _inFlightMessageFetches.remove(channelId);
    }
  }

  List<ChatMessage> getCachedMessages(String channelId) {
    return _cachedMessages[channelId] ?? [];
  }

  Future<List<ChatMessage>> fetchMessagesOnce(String channelId) async {
    await _fetchMessages(channelId);
    return _cachedMessages[channelId] ?? [];
  }

  ChatMessage? getLatestUnreadSnap(String channelId, String? currentUserId) {
    final list = _cachedMessages[channelId];
    if (list == null || currentUserId == null) return null;
    for (final msg in list.reversed) {
      final isSnapMsg = msg.isSnap || msg.type == 'snap' || msg.content.contains('Snap');
      if (isSnapMsg && msg.senderId != currentUserId && !msg.isSnapExpiredFor(currentUserId)) {
        return msg;
      }
    }
    return null;
  }

  ({int unreadSnaps, int unreadMessages}) getUnreadBreakdown(String channelId, String? currentUserId) {
    final list = _cachedMessages[channelId];
    if (list == null || currentUserId == null) {
      return (unreadSnaps: 0, unreadMessages: 0);
    }
    int snaps = 0;
    int msgs = 0;
    for (final m in list) {
      if (m.senderId != currentUserId && !m.readBy.contains(currentUserId)) {
        if (m.isSnap && !m.isSnapExpiredFor(currentUserId)) {
          snaps++;
        } else {
          msgs++;
        }
      }
    }
    return (unreadSnaps: snaps, unreadMessages: msgs);
  }

  Future<String> createOrGetChannel(
    String otherUserId, {
    String? otherUserName,
    String? otherUserAvatar,
    String? currentUserName,
    String? currentUserAvatar,
  }) async {
    try {
      final res = await ApiClient.post('/chat/direct', {
        'targetUserId': otherUserId,
        'otherUserName': otherUserName,
        'otherUserAvatar': otherUserAvatar,
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        if (data['data'] != null && data['data']['id'] != null) {
          _fetchChannels();
          return data['data']['id'].toString();
        }
      }
    } catch (e) {
      debugPrint('Error creating direct channel: $e');
    }
    return 'channel_$otherUserId';
  }

  Future<void> sendMessage(
    String channelId,
    String content, {
    String type = 'text',
    String? receiverId,
    String? mediaUrl,
    String? imageUrl,
    String? audioUrl,
    int? duration,
    double? imageWidth,
    double? imageHeight,
    bool? isSnap,
    double? latitude,
    double? longitude,
    bool? forEveryone,
    String? replyToId,
    String? replyToContent,
    String? replyToSenderId,
    String? sharedPostId,
  }) async {
    try {
      final effectiveType = sharedPostId != null ? 'post' : type;
      final effectiveMediaUrl = mediaUrl ?? imageUrl ?? audioUrl ?? (sharedPostId != null ? 'post:$sharedPostId' : null);

      final clientMsgId = 'msg_${DateTime.now().microsecondsSinceEpoch}_${channelId.hashCode}';
      final payload = <String, dynamic>{
        'clientMsgId': clientMsgId,
        'channelId': channelId,
        'text': content,
        'mediaUrl': effectiveMediaUrl,
        'type': effectiveType,
      };
      if (receiverId != null) payload['receiverId'] = receiverId;
      if (sharedPostId != null) {
        payload['sharedPostId'] = sharedPostId;
        payload['shared_post_id'] = sharedPostId;
      }
      if (replyToId != null) payload['replyToId'] = replyToId;
      if (replyToContent != null) payload['replyToContent'] = replyToContent;
      if (replyToSenderId != null) payload['replyToSenderId'] = replyToSenderId;
      if (isSnap != null) payload['isSnap'] = isSnap;
      if (duration != null) payload['duration'] = duration;
      payload['mediaType'] = type;

      final res = await ApiClient.post('/chat/send', payload);

      if (res.statusCode == 200 || res.statusCode == 201) {
        // Optimistically update channel immediately
        final existing = getCachedChannel(channelId);
        if (existing != null) {
          final updated = existing.copyWith(
            lastMessage: {
              'content': content,
              'text': content,
              'type': effectiveType,
              'sender_id': currentUserId,
              'senderId': currentUserId,
              'timestamp': DateTime.now().toIso8601String(),
              'created_at': DateTime.now().toIso8601String(),
              'isSnap': isSnap ?? false,
              'mediaUrl': effectiveMediaUrl,
            },
            lastMessageTime: DateTime.now(),
          );
          _updateChannelCache(updated);
          final idx = _channelsList.indexWhere((c) => c.id == existing.id || c.id == channelId);
          if (idx != -1) {
            _channelsList[idx] = updated;
          } else {
            _channelsList.add(updated);
          }
          _emitChannels();
        }
        // Immediately refresh messages and channels
        _fetchMessages(channelId);
        _fetchChannels();
        _fetchChannel(channelId);
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  Future<void> markChannelAsRead(String channelId) async {
    final uid = currentUserId;
    final ch = getCachedChannel(channelId);
    if (ch != null && uid != null) {
      final updatedUnread = Map<String, int>.from(ch.unreadCounts);
      updatedUnread[uid] = 0;
      final updated = ch.copyWith(unreadCounts: updatedUnread);
      _updateChannelCache(updated);
      final idx = _channelsList.indexWhere((c) => c.id == ch.id || c.id == channelId);
      if (idx != -1) _channelsList[idx] = updated;
      _emitChannels();
    }
    try {
      final cleanId = channelId.startsWith('channel_') ? channelId.substring(8) : channelId;
      await ApiClient.post('/chat/channels/$cleanId/read', {});
      _fetchChannels();
    } catch (e) {
      debugPrint('Error marking channel as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    _fetchChannels();
  }

  Future<void> markMessagesAsRead(String channelId) async {
    try {
      final cleanId = channelId.startsWith('channel_') ? channelId.substring(8) : channelId;
      await ApiClient.post('/chat/channels/$cleanId/read', {});
    } catch (_) {}
    _fetchMessages(channelId);
  }

  Future<void> setTypingStatus(String channelId, bool isTyping) async {
    SocketService.instance.sendTyping(channelId, isTyping);
  }

  Future<void> togglePinChannel(String channelId, [dynamic arg2]) async {
    final uid = currentUserId;
    final ch = getCachedChannel(channelId);
    if (ch != null && uid != null) {
      final isPinned = ch.pinnedBy.contains(uid);
      final newPinnedBy = isPinned
          ? ch.pinnedBy.where((id) => id != uid).toList()
          : [...ch.pinnedBy, uid];
      final updated = ch.copyWith(pinnedBy: newPinnedBy);
      _updateChannelCache(updated);
      final idx = _channelsList.indexWhere((c) => c.id == ch.id || c.id == channelId);
      if (idx != -1) _channelsList[idx] = updated;
      _emitChannels();
    }
    try {
      final cleanId = channelId.startsWith('channel_') ? channelId.substring(8) : channelId;
      await ApiClient.post('/chat/channels/$cleanId/pin', {});
      _fetchChannels();
    } catch (e) {
      debugPrint('Error toggling pin: $e');
    }
  }

  Future<void> toggleArchiveChannel(String channelId, [dynamic arg2]) async {
    final uid = currentUserId;
    final ch = getCachedChannel(channelId);
    if (ch != null && uid != null) {
      final isArchived = ch.archivedBy.contains(uid);
      final newArchivedBy = isArchived
          ? ch.archivedBy.where((id) => id != uid).toList()
          : [...ch.archivedBy, uid];
      final updated = ch.copyWith(archivedBy: newArchivedBy);
      _updateChannelCache(updated);
      final idx = _channelsList.indexWhere((c) => c.id == ch.id || c.id == channelId);
      if (idx != -1) _channelsList[idx] = updated;
      _emitChannels();
    }
    try {
      final cleanId = channelId.startsWith('channel_') ? channelId.substring(8) : channelId;
      await ApiClient.post('/chat/channels/$cleanId/archive', {});
      _fetchChannels();
    } catch (e) {
      debugPrint('Error toggling archive: $e');
    }
  }

  Future<void> deleteChannel(String channelId) async {
    try {
      final cleanId = channelId.startsWith('channel_') ? channelId.substring(8) : channelId;
      await ApiClient.delete('/chat/channels/$cleanId');
      _fetchChannels();
    } catch (e) {
      debugPrint('Error deleting channel: $e');
    }
  }

  Future<void> editMessage(String channelId, String messageId, String newText) async {
    try {
      await ApiClient.patch('/chat/messages/$messageId', {'text': newText});
      _fetchMessages(channelId);
    } catch (e) {
      debugPrint('Error editing message: $e');
    }
  }

  Future<void> deleteMessage(String channelId, String messageId, {bool forEveryone = false}) async {
    try {
      await ApiClient.delete('/chat/messages/$messageId');
      _fetchMessages(channelId);
    } catch (e) {
      debugPrint('Error deleting message: $e');
    }
  }

  Future<void> viewSnap(String channelId, String messageId) async {
    try {
      await ApiClient.post('/chat/messages/$messageId/view-snap', {});
      _fetchMessages(channelId);
      _fetchChannels();
    } catch (e) {
      debugPrint('Error viewing snap: $e');
    }
  }

  Future<void> toggleSaveMessage(String channelId, String messageId) async {
    try {
      await ApiClient.post('/chat/messages/$messageId/save', {});
      _fetchMessages(channelId);
    } catch (e) {
      debugPrint('Error toggling save message: $e');
    }
  }

  Future<void> toggleReaction(String channelId, String messageId, [String? emoji]) async {
    try {
      await ApiClient.post('/chat/messages/$messageId/reaction', {'emoji': emoji ?? '❤️'});
      _fetchMessages(channelId);
    } catch (e) {
      debugPrint('Error toggling reaction: $e');
    }
  }

  Future<void> togglePinMessage(dynamic arg1, [dynamic arg2, dynamic arg3]) async {}
  Future<void> forwardMessage(dynamic arg1, dynamic arg2) async {}

  Stream<Map<String, bool>> watchTypingStatus(String channelId) {
    if (!_typingControllers.containsKey(channelId) || _typingControllers[channelId]!.isClosed) {
      _typingControllers[channelId] = StreamController<Map<String, bool>>.broadcast();
    }
    return _typingControllers[channelId]!.stream;
  }

  Future<String> createGroupChannel({
    required String name,
    required List<String> memberIds,
    String? avatarUrl,
  }) async {
    try {
      final res = await ApiClient.post('/chat/channels', {
        'name': name,
        'type': 'group',
        'isGroup': true,
        'memberIds': memberIds,
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        if (data['data'] != null && data['data']['id'] != null) {
          _fetchChannels();
          return data['data']['id'].toString();
        }
      }
    } catch (e) {
      debugPrint('Error creating group channel: $e');
    }
    return 'group_channel';
  }

  Future<void> updateChannelInfo(String channelId, {String? name, String? avatarUrl, Map<String, dynamic>? data}) async {
    try {
      final payload = <String, dynamic>{};
      if (name != null) payload['name'] = name;
      await ApiClient.patch('/chat/channels/$channelId', payload);
      _fetchChannel(channelId);
      _fetchChannels();
    } catch (e) {
      debugPrint('Error updating channel info: $e');
    }
  }

  Future<bool> addMembersToGroup(String channelId, List<String> userIds) async {
    try {
      final cleanId = channelId.startsWith('channel_') ? channelId.substring(8) : channelId;
      final res = await ApiClient.post('/chat/channels/$cleanId/members', {
        'userIds': userIds,
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        _fetchChannel(channelId);
        _fetchChannels();
        return true;
      }
    } catch (e) {
      debugPrint('Error adding members to group: $e');
    }
    return false;
  }

  Future<Map<String, dynamic>?> getGroupPublicInfo(String channelId) async {
    try {
      final cleanId = channelId.startsWith('channel_') ? channelId.substring(8) : channelId;
      final res = await ApiClient.get('/chat/channels/$cleanId/public-info');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['channel'] != null) {
          return Map<String, dynamic>.from(data['channel']);
        }
      }
    } catch (e) {
      debugPrint('Error getting group public info: $e');
    }
    return null;
  }

  Future<bool> joinGroup(String channelId) async {
    try {
      final cleanId = channelId.startsWith('channel_') ? channelId.substring(8) : channelId;
      final res = await ApiClient.post('/chat/channels/$cleanId/join', {});
      if (res.statusCode == 200 || res.statusCode == 201) {
        _fetchChannel(channelId);
        _fetchChannels();
        return true;
      }
    } catch (e) {
      debugPrint('Error joining group: $e');
    }
    return false;
  }

  Future<void> toggleAdminStatus(String channelId, String userId) async {}

  Future<bool> removeMember(String channelId, String userId) async {
    try {
      final cleanId = channelId.startsWith('channel_') ? channelId.substring(8) : channelId;
      final res = await ApiClient.delete('/chat/channels/$cleanId/members/$userId');
      if (res.statusCode == 200) {
        _fetchChannel(channelId);
        _fetchChannels();
        return true;
      }
    } catch (e) {
      debugPrint('Error removing member: $e');
    }
    return false;
  }

  Future<void> updateGroupWallpaper(String channelId, String wallpaperUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_wallpaper_$channelId', wallpaperUrl);
      final cleanId = channelId.startsWith('channel_') ? channelId.substring(8) : channelId;
      await ApiClient.post('/chat/channels/$cleanId/wallpaper', {
        'wallpaperUrl': wallpaperUrl,
      });
    } catch (e) {
      debugPrint('Error setting group wallpaper: $e');
    }
  }

  Future<void> updateGroupSettings(
    String channelId, {
    bool? restrictInfoUpdates,
    bool? restrictMessaging,
    Map<String, dynamic>? settings,
  }) async {
    try {
      final cleanId = channelId.startsWith('channel_') ? channelId.substring(8) : channelId;
      final payload = <String, dynamic>{};
      if (restrictInfoUpdates != null) payload['restrictInfoUpdates'] = restrictInfoUpdates;
      if (restrictMessaging != null) payload['restrictMessaging'] = restrictMessaging;
      if (settings != null) payload.addAll(settings);
      await ApiClient.patch('/chat/channels/$cleanId', payload);
      _fetchChannel(channelId);
      _fetchChannels();
    } catch (e) {
      debugPrint('Error updating group settings: $e');
    }
  }

  Future<void> leaveGroup(String channelId) async {
    final cleanId = channelId.startsWith('channel_') ? channelId.substring(8) : channelId;
    final currentUserId = _ref?.read(currentUserIdProvider);
    if (currentUserId != null) {
      await removeMember(cleanId, currentUserId);
    }
    _fetchChannels();
  }

  Future<void> clearChannelMessages(String channelId) async {
    try {
      final cleanId = channelId.startsWith('channel_') ? channelId.substring(8) : channelId;
      await ApiClient.delete('/chat/channels/$cleanId/messages');
    } catch (e) {
      debugPrint('Error clearing channel messages: $e');
    }
    if (_messageControllers.containsKey(channelId) && !_messageControllers[channelId]!.isClosed) {
      _messageControllers[channelId]!.add([]);
    }
  }

  Future<void> blockUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('blocked_user_$userId', true);
      await ApiClient.post('/users/$userId/block', {});
    } catch (e) {
      debugPrint('Error blocking user: $e');
    }
  }

  Future<void> unblockUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('blocked_user_$userId', false);
      await ApiClient.post('/users/$userId/unblock', {});
    } catch (e) {
      debugPrint('Error unblocking user: $e');
    }
  }

  Future<bool> isUserBlocked(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('blocked_user_$userId') ?? false;
    } catch (_) {
      return false;
    }
  }
}
