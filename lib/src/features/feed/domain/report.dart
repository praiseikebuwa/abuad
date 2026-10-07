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
  final String status;

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
      'created_at': createdAt.toIso8601String(),
      'status': status,
    };
  }

  factory Report.fromMap(Map<String, dynamic> map) {
    DateTime parseTime(dynamic raw) {
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    return Report(
      id: map['id'] ?? '',
      reporterId: map['reporter_id'] ?? map['reporterId'] ?? '',
      targetId: map['target_id'] ?? map['targetId'] ?? '',
      type: ReportType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ReportType.post,
      ),
      reason: ReportReason.values.firstWhere(
        (e) => e.name == map['reason'],
        orElse: () => ReportReason.other,
      ),
      details: map['details'],
      createdAt: parseTime(map['created_at'] ?? map['createdAt']),
      status: map['status'] ?? 'pending',
    );
  }
}
