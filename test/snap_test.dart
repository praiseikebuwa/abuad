import 'package:flutter_test/flutter_test.dart';
import 'package:abuad/src/features/chat/domain/chat_message.dart';

void main() {
  group('ChatMessage Snap Ephemeral Domain Logic', () {
    test('Unviewed direct snap initializes correctly', () {
      final msg = ChatMessage(
        id: 'msg_1',
        senderId: 'user_alice',
        content: '📸 Snap',
        type: 'snap',
        timestamp: DateTime.now(),
        isSnap: true,
        snapViews: {},
        snapDuration: 10,
        snapMediaType: 'image',
      );

      expect(msg.isSnap, isTrue);
      expect(msg.getViewCountFor('user_bob'), equals(0));
      expect(msg.canReplay('user_bob'), isFalse);
      expect(msg.isSnapExpiredFor('user_bob'), isFalse);
      expect(msg.isSavedBy('user_bob'), isFalse);
    });

    test('First view allows single replay and is not expired', () {
      final msg = ChatMessage(
        id: 'msg_2',
        senderId: 'user_alice',
        content: '📸 Snap',
        type: 'snap',
        timestamp: DateTime.now(),
        isSnap: true,
        snapViews: {'user_bob': 1},
        snapDuration: 10,
        snapMediaType: 'image',
      );

      expect(msg.getViewCountFor('user_bob'), equals(1));
      expect(msg.canReplay('user_bob'), isTrue);
      expect(msg.isSnapExpiredFor('user_bob'), isFalse);
    });

    test('Second view permanently expires the snap for that user', () {
      final msg = ChatMessage(
        id: 'msg_3',
        senderId: 'user_alice',
        content: '📸 Snap',
        type: 'snap',
        timestamp: DateTime.now(),
        isSnap: true,
        snapViews: {'user_bob': 2},
        snapDuration: 10,
        snapMediaType: 'image',
      );

      expect(msg.getViewCountFor('user_bob'), equals(2));
      expect(msg.canReplay('user_bob'), isFalse);
      expect(msg.isSnapExpiredFor('user_bob'), isTrue);
    });

    test('Saved in chat overrides expiration', () {
      final msg = ChatMessage(
        id: 'msg_4',
        senderId: 'user_alice',
        content: '📸 Snap',
        type: 'snap',
        timestamp: DateTime.now(),
        isSnap: true,
        snapViews: {'user_bob': 2},
        savedBy: ['user_bob'],
      );

      expect(msg.isSavedBy('user_bob'), isTrue);
      expect(msg.isSnapExpiredFor('user_bob'), isFalse);
      expect(msg.canReplay('user_bob'), isTrue);
    });

    test('Video snap parity detection', () {
      final photoSnap = ChatMessage(
        id: 'msg_5',
        senderId: 'user_alice',
        content: '📸 Snap',
        type: 'snap',
        timestamp: DateTime.now(),
        isSnap: true,
        snapMediaType: 'image',
      );

      final videoSnap = ChatMessage(
        id: 'msg_6',
        senderId: 'user_alice',
        content: '🎥 Video Snap',
        type: 'snap',
        timestamp: DateTime.now(),
        isSnap: true,
        snapMediaType: 'video',
      );

      expect(photoSnap.isVideoSnap, isFalse);
      expect(videoSnap.isVideoSnap, isTrue);
    });

    test('Serialization and deserialization preserve snap metadata', () {
      final original = ChatMessage(
        id: 'msg_7',
        senderId: 'user_alice',
        content: '📸 Snap',
        type: 'snap',
        timestamp: DateTime(2026, 10, 17, 21, 0),
        isSnap: true,
        snapViews: {'user_bob': 1},
        snapDuration: 10,
        snapMediaType: 'image',
        savedBy: ['user_bob'],
      );

      final map = original.toMap();
      final parsed = ChatMessage.fromMap(map);

      expect(parsed.id, equals(original.id));
      expect(parsed.isSnap, isTrue);
      expect(parsed.snapViews['user_bob'], equals(1));
      expect(parsed.snapDuration, equals(10));
      expect(parsed.snapMediaType, equals('image'));
      expect(parsed.savedBy, contains('user_bob'));
    });
  });
}
