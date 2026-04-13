import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import '../domain/chat_channel.dart';
import '../domain/chat_message.dart';
import '../../../core/utils/profanity_filter.dart';
import '../../../core/services/notification_service.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(FirebaseFirestore.instance, FirebaseDatabase.instance);
});

final unreadChatCountProvider = StreamProvider<int>((ref) {
  final chatRepo = ref.watch(chatRepositoryProvider);
  return chatRepo.watchChannels().map((channels) {
    int total = 0;
    final uid = chatRepo.currentUserId;
    if (uid == null) return 0;

    for (final channel in channels) {
      total += channel.unreadCounts[uid] ?? 0;
    }
    return total;
  });
});

final chatChannelsProvider = StreamProvider<List<ChatChannel>>((ref) {
  return ref.watch(chatRepositoryProvider).watchChannels();
});

class ChatRepository {
  final FirebaseFirestore _firestore;
  final FirebaseDatabase _rtdb;

  ChatRepository(this._firestore, this._rtdb);

  String? get currentUserId => auth.FirebaseAuth.instance.currentUser?.uid;

  // Stream list of channels where current user is a member
  Stream<List<ChatChannel>> watchChannels() {
    final uid = currentUserId;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection('channels')
        .where('member_ids', arrayContains: uid)
        .orderBy('last_message_time', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatChannel.fromMap(doc.data()))
              .toList(),
        );
  }

  // Stream a single channel by ID
  Stream<ChatChannel?> watchChannel(String channelId) {
    return _firestore
        .collection('channels')
        .doc(channelId)
        .snapshots()
        .map((doc) => doc.exists ? ChatChannel.fromMap(doc.data()!) : null);
  }

  // Stream messages for a specific channel
  Stream<List<ChatMessage>> watchMessages(String channelId) {
    return _firestore
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessage.fromMap(doc.data()))
              .toList(),
        );
  }

  // Send a message
  Future<void> sendMessage(
    String channelId,
    String content, {
    String type = 'text',
    String? imageUrl,
    double? imageWidth,
    double? imageHeight,
    double? latitude,
    double? longitude,
    bool isSnap = false,
    String? replyToId,
    String? replyToContent,
    String? replyToSenderId,
    List<String>? mentions,
    String? audioUrl,
    int? duration,
    String? sharedPostId,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    final messageId = _firestore
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .doc()
        .id;
    final now = DateTime.now();

    final maskedContent = ProfanityFilter.maskProfanity(content);

    final msgData = {
      'id': messageId,
      'sender_id': uid,
      'content': maskedContent,
      'type': type,
      'created_at': Timestamp.fromDate(now),
      'read_by': [uid],
      'image_url': ?imageUrl,
      'image_width': ?imageWidth,
      'image_height': ?imageHeight,
      'latitude': ?latitude,
      'longitude': ?longitude,
      if (isSnap) 'is_snap': true,
      'reply_to_id': ?replyToId,
      'reply_to_content': ?replyToContent,
      'reply_to_sender_id': ?replyToSenderId,
      'reactions': {},
      'mentions': ?mentions,
      'audio_url': ?audioUrl,
      'duration': ?duration,
      'shared_post_id': ?sharedPostId,
    };

    final channelRef = _firestore.collection('channels').doc(channelId);

    await _firestore.runTransaction((transaction) async {
      final channelDoc = await transaction.get(channelRef);
      if (!channelDoc.exists) return;

      final channelData = channelDoc.data()!;
      if (channelData['type'] == 'direct') {
        final memberIds = List<String>.from(channelData['member_ids']);
        final otherId = memberIds.firstWhere(
          (id) => id != uid,
          orElse: () => '',
        );

        if (otherId.isNotEmpty) {
          // Check if either user has blocked the other
          final blockedByMe = await _firestore
              .collection('users')
              .doc(uid)
              .collection('blocked_users')
              .doc(otherId)
              .get();
          final blockedByThem = await _firestore
              .collection('users')
              .doc(otherId)
              .collection('blocked_users')
              .doc(uid)
              .get();

          if (blockedByMe.exists || blockedByThem.exists) {
            throw Exception('Cannot send message: User is blocked');
          }
        }
      }
      final lastSnapTimeMap =
          channelData['last_snap_time'] as Map<String, dynamic>? ?? {};
      int streakCount = channelData['streak_count'] ?? 0;
      DateTime? streakExpiry = (channelData['streak_expiry'] as Timestamp?)
          ?.toDate();

      // Streak Logic (Only for direct chats)
      if (isSnap && channelData['type'] == 'direct') {
        final memberIds = List<String>.from(channelData['member_ids']);
        final otherId = memberIds.firstWhere(
          (id) => id != uid,
          orElse: () => '',
        );

        if (otherId.isNotEmpty) {
          final myLastSnap = (lastSnapTimeMap[uid] as Timestamp?)?.toDate();
          final theirLastSnap = (lastSnapTimeMap[otherId] as Timestamp?)
              ?.toDate();

          // 1. Lazy Expiration: Check if streak was already dead
          if (streakCount > 0 && streakExpiry != null && now.isAfter(streakExpiry)) {
            streakCount = 0;
            streakExpiry = null;
          }

          // 2. Update my last snap time
          lastSnapTimeMap[uid] = Timestamp.fromDate(now);

          // 3. Bi-directional Increment Logic
          if (theirLastSnap != null) {
            final hoursSinceTheirLastSnap = now.difference(theirLastSnap).inHours;
            
            // If they snapped within the last 24 hours (maintenance window)
            if (hoursSinceTheirLastSnap < 24) {
              if (streakCount == 0) {
                // Initial creation: Both have snapped within 24h of each other
                streakCount = 1;
              } else {
                // Increment: Only if I haven't already incremented in this "turn" (approx 12-24h)
                // This prevents spam-incrementing from one user
                final hoursSinceMyLastSnap = myLastSnap != null 
                    ? now.difference(myLastSnap).inHours 
                    : 100;
                
                if (hoursSinceMyLastSnap >= 12) {
                  streakCount++;
                }
              }
              // Reset expiry to 48 hours to be lenient (user: "one or two days")
              // This gives the other person plenty of time to respond without losing it
              streakExpiry = now.add(const Duration(hours: 48));
            } else {
              // They haven't snapped in > 24h. Streak isn't necessarily dead yet (if we are within 48h expiry),
              // but we don't increment it.
            }
          } else {
            // First ever snap in this channel, or they never snapped
            // Just set expiry for them to respond
            streakExpiry = now.add(const Duration(hours: 48));
          }
        }
      }

      // 1. Add message
      transaction.set(
        _firestore
            .collection('channels')
            .doc(channelId)
            .collection('messages')
            .doc(messageId),
        msgData,
      );

      // 2. Update channel
      transaction.update(channelRef, {
        'last_message': msgData,
        'last_message_time': Timestamp.fromDate(now),
        if (isSnap) 'last_snap_time': lastSnapTimeMap,
        if (isSnap) 'streak_count': streakCount,
        if (isSnap && streakExpiry != null)
          'streak_expiry': Timestamp.fromDate(streakExpiry),
        // Increment unread count for other members
        for (final memberId in List<String>.from(channelData['member_ids']))
          if (memberId != uid)
            'unread_counts.$memberId': FieldValue.increment(1),
      });

      // 3. Handle Streak Notifications
      if (isSnap && streakExpiry != null && channelData['type'] == 'direct') {
        // Cancel any pending warning and schedule a new one
        await NotificationService().cancelStreakWarning(channelId);
        await NotificationService().scheduleStreakWarning(
          channelId: channelId,
          otherUserName: (channelData['member_names'] as Map)[uid] ?? 'Your friend',
          expiryTime: streakExpiry,
        );
      }
    });

    // 3. Send Notification to other members
    try {
      final channelDoc = await channelRef.get();
      final channelData = channelDoc.data()!;
      final memberIds = List<String>.from(channelData['member_ids']);
      final memberNames = Map<String, String>.from(channelData['member_names']);
      final senderName = memberNames[uid] ?? 'ABUAD Nest User';

      for (final recipientId in memberIds) {
        if (recipientId != uid) {
          // Send push notification via cloud architecture (modeled here)
          await _firestore.collection('notifications').add({
            'user_id': recipientId,
            'title': channelData['type'] == 'group'
                ? '${channelData['display_name']} - $senderName'
                : senderName,
            'body': type == 'image' ? '📸 Sent a snap' : content,
            'type': 'chat',
            'data': {'id': channelId},
            'created_at': FieldValue.serverTimestamp(),
            'is_read': false,
          });
        }
      }
    } catch (e) {
      debugPrint('Error sending message notification: $e');
    }
  }

  // Start a new chat (or get existing)
  Future<String> createOrGetChannel(
    String otherUserId, {
    required String otherUserName,
    String? otherUserAvatar,
    required String currentUserName,
    String? currentUserAvatar,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not logged in');
    if (otherUserId.isEmpty) throw ArgumentError('otherUserId cannot be empty');

    // 1. Check for deterministic channel ID first (new format)
    final List<String> sortedIds = [uid, otherUserId]..sort();
    final deterministicId = 'direct_${sortedIds[0]}_${sortedIds[1]}';
    final deterministicDoc = await _firestore
        .collection('channels')
        .doc(deterministicId)
        .get();

    if (deterministicDoc.exists) {
      return deterministicDoc.id;
    }

    // 2. Fallback: Search for existing random-ID channels (backward compatibility)
    final existing = await _firestore
        .collection('channels')
        .where('type', isEqualTo: 'direct')
        .where('member_ids', arrayContains: uid)
        .get();

    for (final doc in existing.docs) {
      final memberIds = List<String>.from(doc.data()['member_ids']);
      if (memberIds.contains(otherUserId)) {
        return doc.id;
      }
    }

    // 3. Create new with deterministic ID
    final now = DateTime.now();

    // Fetch verification info
    final otherUserDoc = await _firestore
        .collection('users')
        .doc(otherUserId)
        .get();
    final otherUserType = otherUserDoc.data()?['verification_type'] ?? 'none';

    final currentUserDoc = await _firestore.collection('users').doc(uid).get();
    final currentUserType =
        currentUserDoc.data()?['verification_type'] ?? 'none';

    final channelData = {
      'id': deterministicId,
      'type': 'direct',
      'member_ids': [uid, otherUserId],
      'member_names': {uid: currentUserName, otherUserId: otherUserName},
      'member_avatars': {uid: currentUserAvatar, otherUserId: otherUserAvatar},
      'verification_types': {uid: currentUserType, otherUserId: otherUserType},
      'last_message_time': Timestamp.fromDate(now),
      'last_message': {},
      'unread_counts': {uid: 0, otherUserId: 0},
    };

    await _firestore
        .collection('channels')
        .doc(deterministicId)
        .set(channelData);
    return deterministicId;
  }

  // Create a new group chat
  Future<String> createGroupChannel({
    required String name,
    String? avatarUrl,
    required List<String> memberIds,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not logged in');

    final channelId = _firestore.collection('channels').doc().id;
    final now = DateTime.now();

    final allMemberIds = {uid, ...memberIds}.toList();

    // Fetch info for all members
    final Map<String, String> memberNames = {};
    final Map<String, String?> memberAvatars = {};
    final Map<String, String> verificationTypes = {};
    final Map<String, int> unreadCounts = {};

    for (final id in allMemberIds) {
      final userDoc = await _firestore.collection('users').doc(id).get();
      final userData = userDoc.data();
      if (userData != null) {
        memberNames[id] = userData['display_name'] ?? 'Student';
        memberAvatars[id] = userData['avatar_url'];
        verificationTypes[id] = userData['verification_type'] ?? 'none';
        unreadCounts[id] = 0;
      }
    }

    final channelData = {
      'id': channelId,
      'type': 'group',
      'display_name': name,
      'display_avatar_url': avatarUrl,
      'created_by': uid,
      'admin_ids': [uid],
      'restrict_info_updates': false,
      'restrict_messaging': false,
      'member_ids': allMemberIds,
      'member_names': memberNames,
      'member_avatars': memberAvatars,
      'verification_types': verificationTypes,
      'last_message_time': Timestamp.fromDate(now),
      'last_message': {},
      'unread_counts': unreadCounts,
    };

    await _firestore.collection('channels').doc(channelId).set(channelData);
    return channelId;
  }

  // Reactions logic
  Future<void> addReaction(
    String channelId,
    String messageId,
    String emoji,
  ) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _firestore
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .doc(messageId)
        .update({'reactions.$uid': emoji});
  }

  Future<void> removeReaction(String channelId, String messageId) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _firestore
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .doc(messageId)
        .update({'reactions.$uid': FieldValue.delete()});
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String channelId) async {
    final uid = currentUserId;
    if (uid == null) return;

    // In Firestore, we would typically update unread counts or mark specific messages
    // Simplified for MVP: reset unread count for current user
    await _firestore.collection('channels').doc(channelId).update({
      'unread_counts.$uid': 0,
    });
  }

  Future<void> markAllAsRead() async {
    final uid = currentUserId;
    if (uid == null) return;

    final batch = _firestore.batch();
    final channels = await _firestore
        .collection('channels')
        .where('member_ids', arrayContains: uid)
        .get();

    for (final doc in channels.docs) {
      final data = doc.data();
      final counts = Map<String, dynamic>.from(data['unread_counts'] ?? {});
      if ((counts[uid] ?? 0) > 0) {
        batch.update(doc.reference, {
          'unread_counts.$uid': 0,
        });
      }
    }

    await batch.commit();
  }

  // Typing logic using Realtime Database
  Future<void> setTypingStatus(String channelId, bool isTyping) async {
    final uid = currentUserId;
    if (uid == null) return;

    final ref = _rtdb.ref('channels/$channelId/typing/$uid');
    if (isTyping) {
      await ref.set(true);
      await ref.onDisconnect().remove();
    } else {
      await ref.remove();
    }
  }

  Stream<Map<String, bool>> watchTypingStatus(String channelId) {
    return _rtdb.ref('channels/$channelId/typing').onValue.map((event) {
      final Map<dynamic, dynamic>? data =
          event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return {};
      return data.map((key, value) => MapEntry(key.toString(), value as bool));
    });
  }

  // Get channel by ID
  Future<ChatChannel?> getChannel(String channelId) async {
    try {
      final doc = await _firestore.collection('channels').doc(channelId).get();
      if (!doc.exists) return null;
      return ChatChannel.fromMap(doc.data()!);
    } catch (e) {
      return null;
    }
  }

  Future<void> leaveGroup(String channelId) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _firestore.collection('channels').doc(channelId).update({
      'member_ids': FieldValue.arrayRemove([uid]),
      'member_names.$uid': FieldValue.delete(),
      'member_avatars.$uid': FieldValue.delete(),
      'verification_types.$uid': FieldValue.delete(),
      'unread_counts.$uid': FieldValue.delete(),
    });

    // Also remove from RTDB typing status
    await _rtdb.ref('channels/$channelId/typing/$uid').remove();
  }

  Future<void> toggleAdminStatus(String channelId, String userId) async {
    final channel = await getChannel(channelId);
    if (channel == null) return;

    final admins = List<String>.from(channel.adminIds);
    if (admins.contains(userId)) {
      admins.remove(userId);
    } else {
      admins.add(userId);
    }

    await _firestore.collection('channels').doc(channelId).update({
      'admin_ids': admins,
    });
  }

  Future<void> updateGroupSettings(
    String channelId, {
    bool? restrictInfoUpdates,
    bool? restrictMessaging,
  }) async {
    final Map<String, dynamic> updates = {};
    if (restrictInfoUpdates != null) {
      updates['restrict_info_updates'] = restrictInfoUpdates;
    }
    if (restrictMessaging != null) {
      updates['restrict_messaging'] = restrictMessaging;
    }

    if (updates.isNotEmpty) {
      await _firestore.collection('channels').doc(channelId).update(updates);
    }
  }

  Future<void> removeMember(String channelId, String userId) async {
    await _firestore.collection('channels').doc(channelId).update({
      'member_ids': FieldValue.arrayRemove([userId]),
      'member_names.$userId': FieldValue.delete(),
      'member_avatars.$userId': FieldValue.delete(),
      'verification_types.$userId': FieldValue.delete(),
      'unread_counts.$userId': FieldValue.delete(),
      'admin_ids': FieldValue.arrayRemove([userId]),
    });

    // Also remove from RTDB typing status
    await _rtdb.ref('channels/$channelId/typing/$userId').remove();
  }

  Future<void> updateChannelInfo(
    String channelId, {
    String? name,
    String? avatarUrl,
  }) async {
    final Map<String, dynamic> updates = {};
    if (name != null) updates['display_name'] = name;
    if (avatarUrl != null) updates['display_avatar_url'] = avatarUrl;

    if (updates.isNotEmpty) {
      await _firestore.collection('channels').doc(channelId).update(updates);
    }
  }

  Future<void> deleteMessage(
    String channelId,
    String messageId, {
    bool forEveryone = false,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    if (forEveryone) {
      await _firestore
          .collection('channels')
          .doc(channelId)
          .collection('messages')
          .doc(messageId)
          .update({'is_deleted': true, 'content': 'This message was deleted'});
    } else {
      // Delete just for me (hide it)
      await _firestore
          .collection('channels')
          .doc(channelId)
          .collection('messages')
          .doc(messageId)
          .update({
            'hidden_for': FieldValue.arrayUnion([uid]),
          });
    }
  }

  Future<void> togglePinMessage(
    String channelId,
    String messageId,
    bool pin,
  ) async {
    await _firestore
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .doc(messageId)
        .update({'is_pinned': pin});
  }

  Future<void> toggleSaveMessage(String channelId, String messageId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final msgRef = _firestore
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .doc(messageId);

    final doc = await msgRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final savedBy = List<String>.from(data['saved_by'] ?? []);

    if (savedBy.contains(uid)) {
      savedBy.remove(uid);
    } else {
      savedBy.add(uid);
    }

    await msgRef.update({'saved_by': savedBy});
  }

  Future<void> forwardMessage(
    String targetChannelId,
    ChatMessage originalMessage,
  ) async {
    final uid = currentUserId;
    if (uid == null) return;

    await sendMessage(
      targetChannelId,
      originalMessage.content,
      type: originalMessage.type,
      imageUrl: originalMessage.imageUrl,
      imageWidth: originalMessage.imageWidth,
      imageHeight: originalMessage.imageHeight,
      latitude: originalMessage.latitude,
      longitude: originalMessage.longitude,
      audioUrl: originalMessage.audioUrl,
      duration: originalMessage.duration,
    );
    
    // We could add 'forwardedFrom' logic here if needed by updating the newly sent message
  }

  Future<void> viewSnap(String channelId, String messageId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final msgRef = _firestore
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .doc(messageId);

    final doc = await msgRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    if (data['is_snap'] == true && data['sender_id'] != uid) {
      // Mark as read or delete? Snapchat deletes/hides.
      // We'll mark as read by me, and the UI will hide it if already read.
      await msgRef.update({
        'read_by': FieldValue.arrayUnion([uid]),
      });
    }
  }

  Future<void> editMessage(
    String channelId,
    String messageId,
    String newContent,
  ) async {
    final uid = currentUserId;
    if (uid == null) return;

    final maskedContent = ProfanityFilter.maskProfanity(newContent);
    await _firestore
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .doc(messageId)
        .update({'content': maskedContent, 'is_edited': true});
  }

  Future<void> togglePinChannel(String channelId, bool pin) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _firestore.collection('channels').doc(channelId).update({
      'pinned_by': pin
          ? FieldValue.arrayUnion([uid])
          : FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> toggleArchiveChannel(String channelId, bool archive) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _firestore.collection('channels').doc(channelId).update({
      'archived_by': archive
          ? FieldValue.arrayUnion([uid])
          : FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> toggleReaction(
    String channelId,
    String messageId,
    String emoji,
  ) async {
    final uid = currentUserId;
    if (uid == null) return;

    final msgRef = _firestore
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .doc(messageId);

    final doc = await msgRef.get();
    if (!doc.exists) return;

    final message = ChatMessage.fromMap(doc.data()!);
    final reactions = Map<String, String>.from(message.reactions);

    if (reactions[uid] == emoji) {
      reactions.remove(uid);
    } else {
      reactions[uid] = emoji;
    }

    await msgRef.update({'reactions': reactions});
  }
}
