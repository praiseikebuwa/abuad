import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/api_client.dart';
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

  ChatRepository([this._ref, dynamic _]);

  String? get currentUserId => _ref?.read(authRepositoryProvider).currentUserId;

  Stream<List<ChatChannel>> watchChannels() {
    _fetchChannels();
    _channelsTimer ??= Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchChannels();
    });
    return _channelsController.stream;
  }

  Future<void> _fetchChannels() async {
    try {
      final response = await ApiClient.get('/chat/channels');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final channels = (data['data'] as List)
              .map((x) => ChatChannel.fromMap(x))
              .toList();
          if (!_channelsController.isClosed) {
            _channelsController.add(channels);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching chat channels: $e');
    }
  }

  Stream<ChatChannel?> watchChannel(String channelId) {
    if (!_channelControllers.containsKey(channelId) || _channelControllers[channelId]!.isClosed) {
      _channelControllers[channelId] = StreamController<ChatChannel?>.broadcast();
    }
    _fetchChannel(channelId);
    return _channelControllers[channelId]!.stream;
  }

  Future<ChatChannel?> getChannel(String channelId) async {
    try {
      final cleanId = channelId.startsWith('channel_') ? channelId.substring(8) : channelId;
      
      // Try direct lookup
      var response = await ApiClient.get('/chat/channels/$channelId');
      if (response.statusCode != 200 && cleanId != channelId) {
        response = await ApiClient.get('/chat/channels/$cleanId');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return ChatChannel.fromMap(data['data']);
        }
      }

      // If it's a direct user ID, find/create direct DM
      final directRes = await ApiClient.post('/chat/direct', {
        'targetUserId': cleanId,
      });
      if (directRes.statusCode == 200 || directRes.statusCode == 201) {
        final directData = jsonDecode(directRes.body);
        if (directData['success'] == true && directData['data'] != null) {
          return ChatChannel.fromMap(directData['data']);
        }
      }
    } catch (e) {
      debugPrint('Error getChannel: $e');
    }
    return null;
  }

  Future<void> _fetchChannel(String channelId) async {
    try {
      final channel = await getChannel(channelId);
      if (channel != null && _channelControllers.containsKey(channelId) && !_channelControllers[channelId]!.isClosed) {
        _channelControllers[channelId]!.add(channel);
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
    _messageTimers[channelId] = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      _fetchMessages(channelId);
    });

    return _messageControllers[channelId]!.stream;
  }

  Future<void> _fetchMessages(String channelId) async {
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

          if (_messageControllers.containsKey(channelId) && !_messageControllers[channelId]!.isClosed) {
            _messageControllers[channelId]!.add(messages);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching messages for $channelId: $e');
    }
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
      final res = await ApiClient.post('/chat/send', {
        'channelId': channelId,
        'receiverId': receiverId,
        'text': content,
        'mediaUrl': mediaUrl ?? imageUrl ?? audioUrl,
        'type': type,
      });

      if (res.statusCode == 200 || res.statusCode == 201) {
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
    _fetchChannels();
  }

  Future<void> markAllAsRead() async {
    _fetchChannels();
  }

  Future<void> markMessagesAsRead(String channelId) async {
    _fetchMessages(channelId);
  }

  Future<void> setTypingStatus(String channelId, bool isTyping) async {}

  Future<void> togglePinChannel(String channelId, [dynamic arg2]) async {
    try {
      await ApiClient.post('/chat/channels/$channelId/pin', {});
      _fetchChannels();
    } catch (e) {
      debugPrint('Error toggling pin: $e');
    }
  }

  Future<void> toggleArchiveChannel(String channelId, [dynamic arg2]) async {
    _fetchChannels();
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

  Future<void> viewSnap(dynamic arg1, [dynamic arg2]) async {}
  Future<void> toggleSaveMessage(dynamic arg1, [dynamic arg2]) async {}

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

  Stream<Map<String, bool>> watchTypingStatus(String channelId) async* {
    yield {};
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

  Future<void> toggleAdminStatus(String channelId, String userId) async {}
  Future<void> removeMember(String channelId, String userId) async {}
  Future<void> updateGroupSettings(String channelId, {bool? restrictInfoUpdates, bool? restrictMessaging, Map<String, dynamic>? settings}) async {}
  Future<void> leaveGroup(String channelId) async {
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
