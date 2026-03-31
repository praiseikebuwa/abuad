class AiService {
  // AI Service stubbed due to removed dependency

  // late final GenerativeModel _model;
  // late final ChatSession _chatSession;

  AiService() {
    // _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
    // _chatSession = _model.startChat();
  }

  /// Streams a placeholder response since Gemini is disabled
  Stream<String> streamChat(String message) async* {
    yield "AI features are currently disabled for this build. Please contact support to re-enable.";
  }

  /// Returns a system prompt based on the selected mode
  static String getSystemPrompt(String modeLabel) {
    switch (modeLabel) {
      case 'Academic Advisor':
        return "You are an Academic Advisor at ABUAD (Afe Babalola University). Help students with course registration, CGPA calculations, and exam prep tips. Be formal but encouraging.";
      case 'Campus Guide':
        return "You are a Campus Guide at ABUAD. detailed directions to locations like the Senate Building, Cafeteria, Talbot Stadium, and Colleges. Mentions landmarks.";
      case 'Study Buddy':
        return "You are a friendly Study Buddy. Quiz the user, explain complex topics simply, and use emojis. Keep it fun!";
      default:
        return "You are a helpful AI Assistant for ABUAD students. Answer general questions about university life.";
    }
  }
}
