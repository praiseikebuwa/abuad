enum ReportType { post, comment, story, user, message }

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
  final String reporterName;
  final String reporterHandle;
  final String? reporterAvatar;
  final Map<String, dynamic>? targetPreview;

  Report({
    required this.id,
    required this.reporterId,
    required this.targetId,
    required this.type,
    required this.reason,
    this.details,
    required this.createdAt,
    this.status = 'PENDING',
    this.reporterName = 'Student',
    this.reporterHandle = '',
    this.reporterAvatar,
    this.targetPreview,
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

    final reporterObj = map['reporter'] as Map<String, dynamic>?;
    final targetTypeStr = (map['targetType'] ?? map['type'] ?? 'post').toString().toLowerCase();
    final reasonStr = (map['reason'] ?? '').toString();

    // Parse reason
    ReportReason parsedReason = ReportReason.other;
    for (var r in ReportReason.values) {
      if (reasonStr.toLowerCase().contains(r.name.toLowerCase())) {
        parsedReason = r;
        break;
      }
    }

    return Report(
      id: map['id']?.toString() ?? '',
      reporterId: map['reporter_id'] ?? map['reporterId'] ?? '',
      targetId: map['target_id'] ?? map['targetId'] ?? '',
      type: ReportType.values.firstWhere(
        (e) => e.name == targetTypeStr,
        orElse: () => ReportType.post,
      ),
      reason: parsedReason,
      details: map['details'] ?? reasonStr,
      createdAt: parseTime(map['created_at'] ?? map['createdAt']),
      status: (map['status'] ?? 'PENDING').toString().toUpperCase(),
      reporterName: reporterObj?['fullName'] ?? 'Anonymous Student',
      reporterHandle: reporterObj?['username'] ?? '',
      reporterAvatar: reporterObj?['avatarUrl'],
      targetPreview: map['targetPreview'] is Map<String, dynamic>
          ? map['targetPreview'] as Map<String, dynamic>
          : null,
    );
  }
}
