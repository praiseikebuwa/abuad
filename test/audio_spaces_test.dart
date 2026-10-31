import 'package:flutter_test/flutter_test.dart';
import 'package:abuad/src/features/audio_spaces/domain/audio_room.dart';
import 'package:abuad/src/features/audio_spaces/presentation/controllers/audio_room_controller.dart';

void main() {
  group('Campus Live Audio Spaces Models & Domain Tests', () {
    test('AudioRoomUser parses correctly from json map', () {
      final json = {
        'id': 'user_1',
        'username': 'praise_abuad',
        'fullName': 'Praise Tech',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'department': 'Computer Engineering',
        'level': '500',
        'isVerified': true,
        'verificationType': 'GOLD',
      };

      final user = AudioRoomUser.fromJson(json);
      expect(user.id, 'user_1');
      expect(user.username, 'praise_abuad');
      expect(user.fullName, 'Praise Tech');
      expect(user.avatarUrl, 'https://example.com/avatar.jpg');
      expect(user.department, 'Computer Engineering');
      expect(user.level, '500');
      expect(user.isVerified, true);
      expect(user.verificationType, 'GOLD');
    });

    test('AudioParticipant role permissions and flags work accurately', () {
      final hostUser = const AudioRoomUser(
        id: 'host_1',
        username: 'prof_john',
        fullName: 'Prof. John',
      );

      final hostParticipant = AudioParticipant(
        id: 'p_1',
        roomId: 'room_1',
        userId: 'host_1',
        role: 'HOST',
        isMuted: false,
        joinedAt: DateTime.now(),
        user: hostUser,
      );

      expect(hostParticipant.isHost, true);
      expect(hostParticipant.isSpeaker, true);
      expect(hostParticipant.isListener, false);

      final listenerParticipant = AudioParticipant(
        id: 'p_2',
        roomId: 'room_1',
        userId: 'user_2',
        role: 'LISTENER',
        isMuted: true,
        joinedAt: DateTime.now(),
        user: const AudioRoomUser(
          id: 'user_2',
          username: 'student_mary',
          fullName: 'Mary Student',
        ),
      );

      expect(listenerParticipant.isHost, false);
      expect(listenerParticipant.isSpeaker, false);
      expect(listenerParticipant.isListener, true);
    });

    test('AudioRoom parses complete room data with nested participants and requests', () {
      final rawRoom = {
        'id': 'space_101',
        'hostId': 'user_host',
        'title': 'MTH 102 — Integration Tutorial & Exam Prep',
        'description': 'Solving past questions and live integration tricks together',
        'category': 'ACADEMIC',
        'visibility': 'PUBLIC',
        'speakersPermission': 'HOST_APPROVED',
        'status': 'LIVE',
        'isRecording': true,
        'isChatEnabled': true,
        'createdAt': '2026-10-31T12:00:00Z',
        'host': {
          'id': 'user_host',
          'username': 'tutor_praise',
          'fullName': 'Praise Tutor',
        },
        'participants': [
          {
            'id': 'part_1',
            'roomId': 'space_101',
            'userId': 'user_host',
            'role': 'HOST',
            'isMuted': false,
            'user': {
              'id': 'user_host',
              'username': 'tutor_praise',
              'fullName': 'Praise Tutor',
            },
          },
          {
            'id': 'part_2',
            'roomId': 'space_101',
            'userId': 'student_1',
            'role': 'LISTENER',
            'isMuted': true,
            'user': {
              'id': 'student_1',
              'username': 'david',
              'fullName': 'David O.',
            },
          },
        ],
        '_count': {
          'participants': 24,
          'requests': 3,
        },
      };

      final room = AudioRoom.fromJson(rawRoom);
      expect(room.id, 'space_101');
      expect(room.title, 'MTH 102 — Integration Tutorial & Exam Prep');
      expect(room.category, 'ACADEMIC');
      expect(room.isLive, true);
      expect(room.isRecording, true);
      expect(room.totalParticipants, 24);
      expect(room.speakers.length, 1);
      expect(room.listeners.length, 1);
    });

    test('ActiveAudioRoomState state transitions and copyWith operate properly', () {
      const initialState = ActiveAudioRoomState();
      expect(initialState.hasActiveRoom, false);
      expect(initialState.isConnected, false);
      expect(initialState.isSpeaker, false);

      final connectedState = initialState.copyWith(
        role: 'HOST',
        isConnected: true,
        isMuted: false,
      );

      expect(connectedState.isHost, true);
      expect(connectedState.isSpeaker, true);
      expect(connectedState.isMuted, false);
      expect(connectedState.isConnected, true);
    });
  });
}

