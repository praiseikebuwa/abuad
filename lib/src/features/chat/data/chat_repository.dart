import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/chat_channel.dart';
import '../domain/chat_message.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(FirebaseFirestore.instance, FirebaseAuth.instance);
});

class ChatRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ChatRepository(this._firestore, this._auth);

  String? get currentUserId => _auth.currentUser?.uid;

  // Stream list of channels where current user is a member
  Stream<List<ChatChannel>> watchChannels() {
    final uid = currentUserId;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection('channels')
        .where('memberIds', arrayContains: uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return ChatChannel.fromMap(doc.id, doc.data());
          }).toList();
        });
  }

  // Stream messages for a specific channel
  Stream<List<ChatMessage>> watchMessages(String channelId) {
    return _firestore
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return ChatMessage.fromMap(doc.id, doc.data());
          }).toList();
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

    final messageId = const Uuid().v4();
    final timestamp = DateTime.now();

    final message = ChatMessage(
      id: messageId,
      senderId: uid,
      content: content,
      type: type,
      timestamp: timestamp,
      imageUrl: imageUrl,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      readBy: [uid],
    );

    // Batch write: Add message AND update channel lastMessage
    final batch = _firestore.batch();

    final channelRef = _firestore.collection('channels').doc(channelId);
    final messageRef = channelRef.collection('messages').doc(messageId);

    batch.set(messageRef, message.toMap());
    batch.update(channelRef, {
      'lastMessage': message.toMap(),
      'lastMessageTime': timestamp.millisecondsSinceEpoch,
      'typingUsers.$uid': false,
    });

    await batch.commit();
  }

  // Start a new chat (or get existing)
  Future<String> createOrGetChannel(String otherUserId) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not logged in');

    // Sort member IDs for consistent querying
    final members = [uid, otherUserId]..sort();

    // Check if a channel already exists with these members
    final existingChannels = await _firestore
        .collection('channels')
        .where('memberIds', isEqualTo: members)
        .limit(1)
        .get();

    if (existingChannels.docs.isNotEmpty) {
      // Return existing channel
      return existingChannels.docs.first.id;
    }

    // Fetch user info for both members
    final memberNames = <String, String>{};
    final memberAvatars = <String, String?>{};

    for (final memberId in members) {
      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(memberId)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          memberNames[memberId] = data['displayName'] ?? 'Student';
          memberAvatars[memberId] = data['avatarUrl'];
        } else {
          memberNames[memberId] = 'Student';
          memberAvatars[memberId] = null;
        }
      } catch (e) {
        memberNames[memberId] = 'Student';
        memberAvatars[memberId] = null;
      }
    }

    // Create new channel
    final channelId = const Uuid().v4();
    final channel = ChatChannel(
      id: channelId,
      memberIds: members,
      lastMessage: {},
      lastMessageTime: DateTime.now(),
      memberNames: memberNames,
      memberAvatars: memberAvatars,
    );

    await _firestore.collection('channels').doc(channelId).set(channel.toMap());

    return channelId;
  }

  // Get user display info (for chat list)
  Future<Map<String, String>> getUserInfo(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        return {
          'name': data['displayName'] ?? 'Student',
          'handle': data['handle'] ?? '@student',
        };
      }
    } catch (e) {
      // Ignore errors, return default
    }
    return {'name': 'Student', 'handle': '@student'};
  }

  // Set typing status
  Future<void> setTypingStatus(String channelId, bool isTyping) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _firestore.collection('channels').doc(channelId).update({
      'typingUsers.$uid': isTyping,
    });
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String channelId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final messagesSnapshot = await _firestore
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .where('senderId', isNotEqualTo: uid)
        .get();

    final batch = _firestore.batch();
    for (final doc in messagesSnapshot.docs) {
      final message = ChatMessage.fromMap(doc.id, doc.data());
      if (!message.readBy.contains(uid)) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([uid]),
        });
      }
    }

    await batch.commit();
  }

  // Get channel by ID
  Future<ChatChannel?> getChannel(String channelId) async {
    try {
      final doc = await _firestore.collection('channels').doc(channelId).get();
      if (doc.exists) {
        return ChatChannel.fromMap(doc.id, doc.data()!);
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }
}
