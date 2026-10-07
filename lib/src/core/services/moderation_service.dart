import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import 'api_client.dart';

/// Service for handling AI-driven content moderation using Cloudflare Workers AI via Backend.
class ModerationService {
  /// Checks if the given text is safe for public viewing.
  /// Returns `true` if safe, `false` if it violates a policy.
  static Future<bool> isContentSafe(String text) async {
    if (text.trim().isEmpty) return true;

    if (!AppConfig.enableAiModeration) {
      debugPrint('ModerationService: AI moderation disabled in config.');
      return true;
    }

    try {
      final response = await ApiClient.post('/ai/moderate', {
        'text': text,
        'model': AppConfig.cloudflareAiModel,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final isSafe = data['safe'] as bool? ?? true;
          if (!isSafe) {
            final reason = data['reason'] ?? 'Policy violation detected';
            debugPrint('Content Flagged by Cloudflare AI: $reason');
          }
          return isSafe;
        }
      }

      debugPrint(
        'Moderation API status: ${response.statusCode} - ${response.body}',
      );
      return true; // Fail safe
    } catch (e) {
      debugPrint('ModerationService Exception: $e');
      return true; // Fail safe
    }
  }

  /// Checks if the given media (image or video URL) is safe for public viewing.
  /// Returns `true` if safe, `false` if it violates policy.
  static Future<bool> isMediaSafe(String mediaUrl, {String mediaType = 'image'}) async {
    if (mediaUrl.trim().isEmpty) return true;

    if (!AppConfig.enableAiModeration) {
      debugPrint('ModerationService: AI moderation disabled in config.');
      return true;
    }

    try {
      final response = await ApiClient.post('/ai/moderate-image', {
        'imageUrl': mediaUrl,
        'mediaType': mediaType,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final isSafe = data['safe'] as bool? ?? true;
          if (!isSafe) {
            final reason = data['reason'] ?? 'Inappropriate media content detected';
            debugPrint('Media Content Flagged by Cloudflare AI: $reason');
          }
          return isSafe;
        }
      }
      return true; // Fail safe
    } catch (e) {
      debugPrint('ModerationService Media Exception: $e');
      return true; // Fail safe
    }
  }
}
