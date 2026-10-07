import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../domain/report.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository();
});

class ReportRepository {
  ReportRepository([dynamic _]);

  String? get currentUserId => null;

  Future<void> submitReport(Report report) async {
    await ApiClient.post('/admin/reports', {
      'targetId': report.targetId,
      'targetType': report.type.name,
      'reason': report.reason.name,
      'details': report.details,
    });
  }

  Future<void> reportPost({
    required String postId,
    required ReportReason reason,
    String? details,
  }) async {
    await submitReport(
      Report(
        id: '',
        reporterId: '',
        targetId: postId,
        type: ReportType.post,
        reason: reason,
        details: details,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> reportComment({
    required String commentId,
    required ReportReason reason,
    String? details,
  }) async {
    await submitReport(
      Report(
        id: '',
        reporterId: '',
        targetId: commentId,
        type: ReportType.comment,
        reason: reason,
        details: details,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> reportStory({
    required String storyId,
    required ReportReason reason,
    String? details,
  }) async {
    await submitReport(
      Report(
        id: '',
        reporterId: '',
        targetId: storyId,
        type: ReportType.story,
        reason: reason,
        details: details,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> reportUser({
    required String userId,
    required ReportReason reason,
    String? details,
  }) async {
    await submitReport(
      Report(
        id: '',
        reporterId: '',
        targetId: userId,
        type: ReportType.user,
        reason: reason,
        details: details,
        createdAt: DateTime.now(),
      ),
    );
  }

  Stream<List<Report>> watchPendingReports() async* {
    try {
      final response = await ApiClient.get('/admin/reports');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          yield (data['data'] as List).map((x) => Report.fromMap(x)).toList();
          return;
        }
      }
    } catch (e) {}
    yield [];
  }

  Future<void> updateReportStatus(String reportId, String status) async {}
  Future<void> resolveReport(String reportId) async {}
}
