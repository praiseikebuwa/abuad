import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:abuad/src/features/audio_spaces/domain/audio_room.dart';
import 'package:abuad/src/features/audio_spaces/presentation/widgets/live_space_preview_sheet.dart';
import 'package:abuad/src/core/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Live Notifications Configuration Tests', () {
    test('NotificationService exposes correct channel definitions', () {
      expect(NotificationService.channelId, 'abuad_alerts_v2');
      expect(NotificationService.liveSpaceChannelId, 'abuad_live_space_v1');
      expect(NotificationService.liveSpaceNotificationId, 99991);
    });
  });

  group('Live Space Preview Sheet Widget Tests', () {
    final mockRoom = AudioRoom(
      id: 'space_999',
      hostId: 'host_123',
      title: 'ABUAD Developers & AI Hackers Live Space',
      description: 'Discussing modern Flutter agents, real-time live activities, and mobile architectures.',
      category: 'ACADEMIC',
      status: 'LIVE',
      createdAt: DateTime.now(),
      totalParticipants: 42,
      host: const AudioRoomUser(
        id: 'host_123',
        username: 'tech_lead',
        fullName: 'Lead Engineer',
        avatarUrl: null,
      ),
    );

    testWidgets('LiveSpacePreviewSheet renders title, host, listeners, and Join Space button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LiveSpacePreviewSheet(room: mockRoom),
            ),
          ),
        ),
      );

      // Verify Space Title is rendered
      expect(find.text('ABUAD Developers & AI Hackers Live Space'), findsOneWidget);

      // Verify LIVE badge is displayed
      expect(find.text('LIVE SPACE'), findsOneWidget);

      // Verify Host info is displayed
      expect(find.text('Lead Engineer'), findsOneWidget);
      expect(find.text('@tech_lead'), findsOneWidget);

      // Verify Participant count is displayed
      expect(find.text('42'), findsOneWidget);

      // Verify "Join Space" prominent action button is present
      expect(find.text('Join Space'), findsOneWidget);

      // Verify Cancel button is present
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('LiveSpacePreviewSheet for scheduled space displays Set Reminder button',
        (WidgetTester tester) async {
      final scheduledRoom = mockRoom.copyWith(status: 'SCHEDULED');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LiveSpacePreviewSheet(room: scheduledRoom),
            ),
          ),
        ),
      );

      expect(find.text('📅 SCHEDULED'), findsOneWidget);
      expect(find.text('Set Reminder'), findsOneWidget);
    });
  });
}
