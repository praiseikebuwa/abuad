import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportType { post, comment, story, user }

enum ReportReason {
  spam,
  harassment,
  inappropriateContent,
  hateSpeech,
  misinformation,
  other,
}

class Report {
  final String id;
  final String reporterId;
  final String targetId;
  final ReportType type;
  final ReportReason reason;
  final String? details;
  final DateTime createdAt;
  final String status; // 'pending', 'reviewed', 'resolved'

  Report({
    required this.id,
    required this.reporterId,
    required this.targetId,
    required this.type,
    required this.reason,
    this.details,
    required this.createdAt,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reporter_id': reporterId,
      'target_id': targetId,
      'type': type.name,
      'reason': reason.name,
      'details': details,
      'created_at': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }

  factory Report.fromMap(Map<String, dynamic> map) {
    return Report(
      id: map['id'] ?? '',
      reporterId: map['reporter_id'] ?? '',
      targetId: map['target_id'] ?? '',
      type: ReportType.values.byName(map['type'] ?? 'post'),
      reason: ReportReason.values.byName(map['reason'] ?? 'other'),
      details: map['details'],
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'pending',
    );
  }
}
