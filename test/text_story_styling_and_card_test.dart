import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:abuad/src/features/stories/domain/story.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() {
  group('Text Story Domain & Deserialization Tests', () {
    test('Story.fromMap correctly parses background_color and text_color as int', () {
      final map = {
        'id': 'story_1',
        'author_id': 'user_1',
        'type': 'text',
        'content': 'Studying for finals at the central library! 📚',
        'background_color': 0xFFEF5350,
        'text_color': 0xFFFFFFFF,
        'font_family': 'Roboto',
        'text_align': 'center',
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
        'user_name': 'Daniel',
        'user_avatar': '',
      };

      final story = Story.fromMap(map);
      expect(story.type, 'text');
      expect(story.content, 'Studying for finals at the central library! 📚');
      expect(story.backgroundColor, 0xFFEF5350);
      expect(story.textColor, 0xFFFFFFFF);
      expect(story.fontFamily, 'Roboto');
      expect(story.textAlign, 'center');
    });

    test('Story.fromMap correctly parses hex string background colors', () {
      final map = {
        'id': 'story_2',
        'author_id': 'user_2',
        'type': 'text',
        'content': 'Campus cafeteria vibes 🍔',
        'background_color': '#00E5FF',
        'text_color': '#000000',
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      };

      final story = Story.fromMap(map);
      expect(story.backgroundColor, 0xFF00E5FF);
      expect(story.textColor, 0xFF000000);
    });

    test('Story.fromMap parses metadata packed inside linkUrl JSON', () {
      final linkUrlJson = '{"backgroundColor":4293874512,"textColor":4294967295,"fontFamily":"Serif","textAlign":"right","linkUrl":"https://abuad.edu.ng"}';
      final map = {
        'id': 'story_3',
        'author_id': 'user_3',
        'type': 'text',
        'content': 'Law college dinner tonight 🥂',
        'link_url': linkUrlJson,
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      };

      final story = Story.fromMap(map);
      expect(story.backgroundColor, 4293874512);
      expect(story.textColor, 4294967295);
      expect(story.fontFamily, 'Serif');
      expect(story.textAlign, 'right');
      expect(story.linkUrl, 'https://abuad.edu.ng');
    });

    test('Story.fromMap does not distort text content with URL formatting', () {
      final map = {
        'id': 'story_4',
        'author_id': 'user_4',
        'type': 'text',
        'content': 'Uploads will resume next week! Check out uploads/docs folder.',
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      };

      final story = Story.fromMap(map);
      expect(story.content, 'Uploads will resume next week! Check out uploads/docs folder.');
    });
  });
}
