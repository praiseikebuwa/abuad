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

  /// Returns a rich system prompt based on the selected mode with full ABUAD campus knowledge
  static String getSystemPrompt(String modeLabel) {
    const campusKnowledge = """
ABUAD CAMPUS & STUDENT KNOWLEDGE BASE:
1. Campus Geography & Navigation:
   - Senate Building (Central Administration, VC office, Registry, Bursary) at campus core.
   - ABUAD Multi-System Hospital (AMSH): 400-bed tertiary hospital and student clinic on East Ring Road.
   - Colleges: College of Engineering Mega Complex (South-West), Aare Afe Babalola Law College (North of Senate, strict white-on-black dress code), College of Medicine & Health Sciences (MHS, adjacent to AMSH), College of Sciences & Computing (North-West), College of Social & Management Sciences (SMS, South).
   - Library & Culture: Main University Library (2nd floor quiet research carrels), Alfa Belgore Ceremonial Hall, ABUAD Planetarium & Talent Discovery Centre.
   - Sports & Living: Talbot Sports Complex (Football stadium, Olympic pool, courts), Central Food Court & Buka, Male Hostels Quad (Talent, Adeleke), Female Hostels Quad (Queen, Royal).

2. Portal & Academic Regulations:
   - Grading scale: A (70-100%, 5.0), B (60-69%, 4.0), C (50-59%, 3.0), D (45-49%, 2.0), F (0-44%, 0.0).
   - CGPA Formula: Total Quality Points divided by Total Registered Credit Units.
   - Degree Classes: First Class (4.50 - 5.00), Second Class Upper (3.50 - 4.49), Second Class Lower (2.40 - 3.49), Third Class (1.50 - 2.39).
   - Course registration: Add/drop window is active during first 3 weeks of semester via student portal.

3. Student Handbook & Campus Life:
   - Dress Code: Corporate attire Monday-Friday. Law students wear white top on black trousers/skirts.
   - Hostel Curfew: 10:00 PM nightly gate lock across all halls of residence.
   - Maintenance: For plumbing, electrical, carpentry or AC repairs, submit a ticket via student portal or notify the hall porter lodge.
   - Cafeteria: Buka and College food courts open 7:00 AM - 9:30 PM with hot meals, breakfast and grills.
""";

    switch (modeLabel) {
      case 'Academic Advisor':
        return "You are the ABUAD Academic Advisor AI. Help students track grades, calculate CGPAs, plan course registration, and prepare for exams. Be encouraging, structured, and accurate.\n$campusKnowledge";
      case 'Campus Guide':
        return "You are the ABUAD Campus Navigator AI. Provide clear walking directions between lecture halls, colleges, hostels, cafeterias, and AMSH Hospital. Offer landmark-based shortcuts and tell students what is nearby.\n$campusKnowledge";
      case 'Study Buddy':
        return "You are the ABUAD 24/7 Study Buddy AI. Analyze uploaded course handouts, notes, and past questions. Provide step-by-step explanations, practice quizzes, and study schedules. Keep your tone supportive and crystal clear.\n$campusKnowledge";
      default:
        return "You are the official ABUAD AI Assistant, serving as an interactive campus navigator, portal advisor, study buddy, and campus encyclopedia for Afe Babalola University students.\n$campusKnowledge";
    }
  }
}
