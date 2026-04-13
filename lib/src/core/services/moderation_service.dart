import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Service for handling AI-driven content moderation using OpenAI Moderation API.
class ModerationService {
  /// Checks if the given text is safe for public viewing.
  /// Returns `true` if safe, `false` if it violates a policy.
  static Future<bool> isContentSafe(String text) async {
    if (text.trim().isEmpty) return true;

    // Skip if API key is not configured
    if (AppConfig.openAiApiKey == 'YOUR_OPENAI_API_KEY_HERE') {
      debugPrint(
        '⚠️ ModerationService: OpenAI API key not found. Skipping AI moderation.',
      );
      return true;
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.openAiBaseUrl}/moderations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConfig.openAiApiKey}',
        },
        body: jsonEncode({'input': text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List;

        if (results.isNotEmpty) {
          final isFlagged = results[0]['flagged'] as bool;

          if (isFlagged) {
            final categories = results[0]['categories'] as Map<String, dynamic>;
            final violated = categories.entries
                .where((e) => e.value == true)
                .map((e) => e.key)
                .toList();

            debugPrint('🚫 Content Flagged: $violated');
            return false;
          }
        }
        return true;
      } else {
        debugPrint(
          '❌ Moderation API Error: ${response.statusCode} - ${response.body}',
        );
        return true; // Fail safe
      }
    } catch (e) {
      debugPrint('❌ ModerationService Exception: $e');
      return true; // Fail safe
    }
  }
}
