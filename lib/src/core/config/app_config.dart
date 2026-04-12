class AppConfig {
  /// OpenAI API Key for content moderation. 
  /// In a production app, this should be stored securely (e.g., Environment Variables or Secrets Manager).
  static const String openAiApiKey = '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';
  
  /// Base URL for OpenAI API
  static const String openAiBaseUrl = 'https://api.openai.com/v1';

  /// Whether to block posts entirely or just flag them
  static const bool blockFlaggedPosts = false;
}
