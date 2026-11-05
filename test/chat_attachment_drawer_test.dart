import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Chat Attachment Features & Formats Tests', () {
    test('Format document file sizes correctly', () {
      String formatFileSize(int bytes) {
        if (bytes < 1024) return '$bytes B';
        if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }

      expect(formatFileSize(512), '512 B');
      expect(formatFileSize(2048), '2.0 KB');
      expect(formatFileSize(5 * 1024 * 1024), '5.0 MB');
    });

    test('Contact payload serialization and deserialization', () {
      final payload = jsonEncode({
        'name': 'Damilola Adebayo',
        'handle': 'dami_ade',
        'uid': 'user_12345',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'department': 'Computer Engineering',
        'phoneNumber': '+2348012345678',
      });

      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      expect(decoded['name'], 'Damilola Adebayo');
      expect(decoded['handle'], 'dami_ade');
      expect(decoded['uid'], 'user_12345');
      expect(decoded['department'], 'Computer Engineering');
      expect(decoded['phoneNumber'], '+2348012345678');
    });

    test('Poll payload serialization and options vote count', () {
      final poll = jsonEncode({
        'question': 'When should we study for COE312?',
        'options': [
          {'text': 'Today 6 PM', 'votes': 3, 'voters': ['u1', 'u2', 'u3']},
          {'text': 'Tomorrow 10 AM', 'votes': 5, 'voters': ['u4', 'u5', 'u6', 'u7', 'u8']},
          {'text': 'Saturday', 'votes': 0, 'voters': []},
        ],
      });

      final decoded = jsonDecode(poll) as Map<String, dynamic>;
      expect(decoded['question'], 'When should we study for COE312?');
      final options = (decoded['options'] as List).cast<Map<String, dynamic>>();
      expect(options.length, 3);
      final totalVotes = options.fold<int>(0, (sum, o) => sum + (o['votes'] as int));
      expect(totalVotes, 8);
    });

    test('Document message payload parsing with filename and size', () {
      const content = '📄 Document: Course_Syllabus_2026.pdf|2.4 MB';
      final raw = content.replaceFirst('📄 Document:', '').trim();
      final parts = raw.split('|');
      expect(parts[0], 'Course_Syllabus_2026.pdf');
      expect(parts[1], '2.4 MB');
    });
  });
}
