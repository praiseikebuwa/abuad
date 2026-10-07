import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/api_client.dart';

class AiService {
  AiService();

  /// Streams/queries response from Cloudflare Workers AI via backend API
  Stream<String> streamChat(String message, {String? imageUrl, String? systemPrompt}) async* {
    try {
      final response = await ApiClient.post('/ai/query', {
        'prompt': message,
        'imageUrl': imageUrl,
        'systemPrompt': systemPrompt,
        'model': imageUrl != null
            ? '@cf/meta/llama-3.2-11b-vision-instruct'
            : AppConfig.cloudflareAiModel,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final resData = data['data'];
          String reply = '';

          if (resData is Map && resData['response'] != null) {
            reply = resData['response'].toString();
          } else if (resData is String) {
            reply = resData;
          }

          if (reply.trim().isEmpty || reply.trim() == '{}') {
            reply =
                "I'm your ABUAD AI Assistant. How can I help you with your studies or campus questions today?";
          }

          yield reply;
          return;
        } else if (data['error'] != null && data['error']['message'] != null) {
          yield "AI Assistant Error: ${data['error']['message']}";
          return;
        }
      }
      yield "Unable to connect to AI Assistant (${response.statusCode}). Please check your connection.";
    } catch (e) {
      debugPrint('AiService Exception: $e');
      yield "AI Service connection error. Please ensure backend server is active.";
    }
  }

  /// Returns a system prompt based on the selected mode
  static String getSystemPrompt(String modeLabel) {
    switch (modeLabel) {
      case 'Academic Advisor':
        return "You are an Academic Advisor at ABUAD (Afe Babalola University). Help students with course registration, CGPA calculations, and exam prep tips. Be formal but encouraging.";
      case 'Campus Guide':
        return "You are a Campus Guide at ABUAD. Provide detailed directions to locations like the Senate Building, Cafeteria, Talbot Stadium, and Colleges. Mention landmarks.";
      case 'Study Buddy':
        return "You are a friendly Study Buddy for ABUAD students. Explain complex topics clearly. Carefully distinguish between general academic subjects (e.g., mathematics, physics, biology, accounting) and computer programming based strictly on the user's prompt. Keep responses accurate, engaging, and clear.";
      default:
        return "You are a helpful AI Assistant for ABUAD students. Pay close attention to the user's domain (e.g., mathematics vs programming) and answer academic and campus questions accurately.";
    }
  }
}
