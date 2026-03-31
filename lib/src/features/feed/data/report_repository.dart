import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../domain/report.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(FirebaseFirestore.instance);
});

class ReportRepository {
  final FirebaseFirestore _firestore;

  ReportRepository(this._firestore);

  String? get currentUserId => auth.FirebaseAuth.instance.currentUser?.uid;

  Future<void> submitReport(Report report) async {
    final reportId = _firestore.collection('reports').doc().id;
    final reportWithId = Report(
      id: reportId,
      reporterId: report.reporterId,
      targetId: report.targetId,
      type: report.type,
      reason: report.reason,
      details: report.details,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('reports')
        .doc(reportId)
        .set(reportWithId.toMap());
  }

  Future<void> reportPost({
    required String postId,
    required ReportReason reason,
    String? details,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not logged in');

    await submitReport(
      Report(
        id: '', // Generated in submitReport
        reporterId: uid,
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
    final uid = currentUserId;
    if (uid == null) throw Exception('Not logged in');

    await submitReport(
      Report(
        id: '',
        reporterId: uid,
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
    final uid = currentUserId;
    if (uid == null) throw Exception('Not logged in');

    await submitReport(
      Report(
        id: '',
        reporterId: uid,
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
    final uid = currentUserId;
    if (uid == null) throw Exception('Not logged in');

    await submitReport(
      Report(
        id: '',
        reporterId: uid,
        targetId: userId,
        type: ReportType.user,
        reason: reason,
        details: details,
        createdAt: DateTime.now(),
      ),
    );
  }

  Stream<List<Report>> watchPendingReports() {
    return _firestore
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Report.fromMap(doc.data())).toList(),
        );
  }

  Future<void> updateReportStatus(String reportId, String status) async {
    await _firestore.collection('reports').doc(reportId).update({
      'status': status,
    });
  }

  Future<void> resolveReport(String reportId) async {
    await updateReportStatus(reportId, 'resolved');
  }
}
