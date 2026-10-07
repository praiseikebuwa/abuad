import '../services/api_client.dart';

class AppConfig {
  /// Base URL for backend API
  static String get apiBaseUrl => ApiClient.baseUrl;

  /// Enable AI Content Moderation via Backend Cloudflare Workers AI
  static const bool enableAiModeration = true;

  /// Whether to block posts entirely or just flag them
  static const bool blockFlaggedPosts = false;

  /// Cloudflare Workers AI Model used on backend
  static const String cloudflareAiModel = '@cf/meta/llama-3-8b-instruct';
}
