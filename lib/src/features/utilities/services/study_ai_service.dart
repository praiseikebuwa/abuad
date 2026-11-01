import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';

class StudyExplanation {
  final String courseCode;
  final String topic;
  final String summary;
  final String detailedNotes;
  final List<String> keyTakeaways;
  final List<String> examTips;

  const StudyExplanation({
    required this.courseCode,
    required this.topic,
    required this.summary,
    required this.detailedNotes,
    required this.keyTakeaways,
    required this.examTips,
  });

  factory StudyExplanation.fromJson(Map<String, dynamic> json) {
    return StudyExplanation(
      courseCode: json['courseCode'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      detailedNotes: json['detailedNotes'] as String? ?? '',
      keyTakeaways: (json['keyTakeaways'] as List?)?.map((e) => e.toString()).toList() ?? [],
      examTips: (json['examTips'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class StudyQuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const StudyQuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory StudyQuizQuestion.fromJson(Map<String, dynamic> json) {
    return StudyQuizQuestion(
      id: json['id'] as String? ?? '',
      question: json['question'] as String? ?? '',
      options: (json['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
      correctIndex: json['correctIndex'] as int? ?? 0,
      explanation: json['explanation'] as String? ?? '',
    );
  }
}

class AudioLectureSession {
  final String title;
  final String courseCode;
  final String topic;
  final String spokenScript;
  final List<String> bulletPoints;
  final List<String> suggestedQuestions;
  final int estimatedDurationSeconds;

  const AudioLectureSession({
    required this.title,
    required this.courseCode,
    required this.topic,
    required this.spokenScript,
    required this.bulletPoints,
    required this.suggestedQuestions,
    required this.estimatedDurationSeconds,
  });

  factory AudioLectureSession.fromJson(Map<String, dynamic> json) {
    return AudioLectureSession(
      title: json['title'] as String? ?? '',
      courseCode: json['courseCode'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      spokenScript: json['spokenScript'] as String? ?? '',
      bulletPoints: (json['bulletPoints'] as List?)?.map((e) => e.toString()).toList() ?? [],
      suggestedQuestions: (json['suggestedQuestions'] as List?)?.map((e) => e.toString()).toList() ?? [],
      estimatedDurationSeconds: json['estimatedDurationSeconds'] as int? ?? 180,
    );
  }
}

class StudyAiService {
  Future<StudyExplanation> explainTopic({
    required String courseCode,
    required String topic,
    String? level,
    String? faculty,
    String depth = 'detailed',
  }) async {
    final res = await ApiClient.post('/study-ai/explain', {
      'courseCode': courseCode,
      'topic': topic,
      'level': level,
      'faculty': faculty,
      'depth': depth,
    });

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final json = jsonDecode(res.body);
      final rawData = json['data'];
      return StudyExplanation.fromJson(rawData is Map ? Map<String, dynamic>.from(rawData) : <String, dynamic>{});
    }
    throw Exception('Failed to generate study explanation (${res.statusCode}): ${res.body}');
  }

  Future<List<StudyQuizQuestion>> generateQuiz({
    required String courseCode,
    required String topic,
    int count = 4,
  }) async {
    final res = await ApiClient.post('/study-ai/quiz', {
      'courseCode': courseCode,
      'topic': topic,
      'count': count,
    });

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final json = jsonDecode(res.body);
      final list = json['data'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((item) => StudyQuizQuestion.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    throw Exception('Failed to generate quiz (${res.statusCode}): ${res.body}');
  }

  Future<AudioLectureSession> generateAudioLecture({
    required String courseCode,
    required String topic,
    int durationMinutes = 3,
    String style = 'conversational_tutor',
  }) async {
    final res = await ApiClient.post('/study-ai/audio-lecture', {
      'courseCode': courseCode,
      'topic': topic,
      'durationMinutes': durationMinutes,
      'style': style,
    });

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final json = jsonDecode(res.body);
      final rawData = json['data'];
      return AudioLectureSession.fromJson(rawData is Map ? Map<String, dynamic>.from(rawData) : <String, dynamic>{});
    }
    throw Exception('Failed to generate audio lecture (${res.statusCode}): ${res.body}');
  }
}

final studyAiServiceProvider = Provider<StudyAiService>((ref) => StudyAiService());
