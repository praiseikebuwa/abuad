import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/chat_channel.dart';
import '../domain/chat_message.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(Supabase.instance.client);
});

class ChatRepository {
  final SupabaseClient _supabase;

  ChatRepository(this._supabase);

  String? get currentUserId => _supabase.auth.currentUser?.id;

  // Stream list of channels where current user is a member
  Stream<List<ChatChannel>> watchChannels() {
    final uid = currentUserId;
    if (uid == null) return Stream.value([]);

    // 1. Get channel IDs for user
    // We can do a join: channels!inner(channel_members!inner(user_id))
    // Filter: channel_members.user_id = uid.
    // Also select all members from channel to build the channel object.

    return _supabase
        .from('channels')
        .select(
          '*, channel_members!inner(user_id), members:channel_members(user_id, profiles(display_name, avatar_url))',
        )
        .eq('channel_members.user_id', uid)
        .order('last_message_time', ascending: false)
        .asStream()
        .map((data) {
          return data.map((map) {
            // We need to map 'members' to the structure expected by fromMap
            // The query returns 'members' as List of {user_id, profiles: {...}}
            // Rename 'members' to 'channel_members' if needed or adjust logic.
            // Our fromMap expects 'channel_members'.
            final validMap = Map<String, dynamic>.from(map);
            validMap['channel_members'] = map['members']; // Remap alias
            return ChatChannel.fromMap(validMap, currentUserId: uid);
          }).toList();
        });
  }

  // Stream messages for a specific channel
  Stream<List<ChatMessage>> watchMessages(String channelId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('channel_id', channelId)
        .order('created_at', ascending: false)
        .map((data) {
          return data.map((map) => ChatMessage.fromMap(map)).toList();
        });
  }

  // Send a message
  Future<void> sendMessage(
    String channelId,
    String content, {
    String type = 'text',
    String? imageUrl,
    double? imageWidth,
    double? imageHeight,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Insert message
    final msgData = {
      'channel_id': channelId,
      'sender_id': uid,
      'content': content,
      'type': type,
      'created_at': timestamp,
      'image_url': imageUrl,
      'image_width': imageWidth,
      'image_height': imageHeight,
      'read_by': [uid],
    };

    final res = await _supabase
        .from('messages')
        .insert(msgData)
        .select()
        .single();

    // Update channel last_message
    await _supabase
        .from('channels')
        .update({
          'last_message': res, // Store full message object
          'last_message_time': timestamp,
        })
        .eq('id', channelId);
  }

  // Start a new chat (or get existing)
  Future<String> createOrGetChannel(String otherUserId) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not logged in');

    // Create a new direct channel
    // TODO: Implement unique constraint on direct chats in DB to prevent duplicates

    final channelRes = await _supabase
        .from('channels')
        .insert({
          'type': 'direct',
          'last_message_time': DateTime.now().millisecondsSinceEpoch,
        })
        .select()
        .single();

    final channelId = channelRes['id'];

    // Add members
    await _supabase.from('channel_members').insert([
      {'channel_id': channelId, 'user_id': uid},
      {'channel_id': channelId, 'user_id': otherUserId},
    ]);

    return channelId;
  }

  // Get user display info (for chat list)
  Future<Map<String, String>> getUserInfo(String userId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select('display_name, handle')
          .eq('id', userId)
          .single();

      return {
        'name': data['display_name'] ?? 'Student',
        'handle': data['handle'] ?? '@student',
      };
    } catch (e) {
      // Ignore errors
    }
    return {'name': 'Student', 'handle': '@student'};
  }

  // Set typing status - Logic moved to Realtime Presence in UI
  Future<void> setTypingStatus(String channelId, bool isTyping) async {
    // No-op for DB. Use channel.on('presence', ...) in UI.
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String channelId) async {
    final uid = currentUserId;
    if (uid == null) return;

    // Ideally use RPC. 'mark_channel_read(channel_id)'
    try {
      await _supabase.rpc('mark_channel_read', params: {'c_id': channelId});
    } catch (_) {
      // Ignored
    }
  }

  // Get channel by ID
  Future<ChatChannel?> getChannel(String channelId) async {
    try {
      final data = await _supabase
          .from('channels')
          .select(
            '*, members:channel_members(user_id, profiles(display_name, avatar_url))',
          )
          .eq('id', channelId)
          .single();

      final validMap = Map<String, dynamic>.from(data);
      validMap['channel_members'] = data['members'];

      return ChatChannel.fromMap(validMap, currentUserId: currentUserId);
    } catch (e) {
      // Ignore
    }
    return null;
  }
}
