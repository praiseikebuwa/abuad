import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  // TODO: Replace with your actual Gemini API Key from https://aistudio.google.com/
  static const String _apiKey = '';

  late final GenerativeModel _model;
  late final ChatSession _chatSession;

  AiService() {
    _model = GenerativeModel(model: 'gemini-pro', apiKey: _apiKey);
    _chatSession = _model.startChat();
  }

  /// Streams the chat response from Gemini
  Stream<String> streamChat(String message) async* {
    try {
      final response = _chatSession.sendMessageStream(Content.text(message));

      await for (final chunk in response) {
        if (chunk.text != null) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      yield "Error: Unable to connect to AI. Please check your API key and internet connection.";
    }
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
