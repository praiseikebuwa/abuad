import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../domain/report.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository();
});

class ReportRepository {
  ReportRepository([dynamic _]);

  Future<bool> submitReport(Report report) async {
    try {
      final response = await ApiClient.post('/admin/reports', {
        'targetId': report.targetId,
        'targetType': report.type.name,
        'reason': report.reason.name,
        'details': report.details,
      });

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Error submitting report: $e');
      return false;
    }
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

  Future<void> reportMessage({
    required String messageId,
    required ReportReason reason,
    String? details,
  }) async {
    await submitReport(
      Report(
        id: '',
        reporterId: '',
        targetId: messageId,
        type: ReportType.message,
        reason: reason,
        details: details,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<List<Report>> fetchReports({
    String status = 'ALL',
    String targetType = 'ALL',
  }) async {
    try {
      final response = await ApiClient.get(
        '/admin/reports?status=$status&targetType=$targetType',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return (data['data'] as List)
              .map((x) => Report.fromMap(x as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching reports: $e');
    }
    return [];
  }

  Stream<List<Report>> watchPendingReports() async* {
    try {
      final reports = await fetchReports(status: 'PENDING');
      yield reports;
    } catch (_) {
      yield [];
    }
  }

  Future<bool> updateReportStatus(String reportId, String status) async {
    try {
      final response = await ApiClient.patch('/admin/reports/$reportId', {
        'status': status,
      });
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating report status: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> executeReportAction(
    String reportId,
    String action, {
    String? notes,
  }) async {
    try {
      final response = await ApiClient.post('/admin/reports/$reportId/action', {
        'action': action,
        if (notes != null) 'notes': notes,
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['success'] == true,
          'message': data['message'] ?? 'Action completed',
        };
      }
    } catch (e) {
      debugPrint('Error executing report action: $e');
    }
    return {'success': false, 'message': 'Failed to execute action'};
  }

  Future<Map<String, dynamic>?> getAdminMetrics() async {
    try {
      final response = await ApiClient.get('/admin/metrics');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is Map) {
          return Map<String, dynamic>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint('Error fetching admin metrics: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchAdminUsers({
    String? query,
    String? filter,
  }) async {
    try {
      String endpoint = '/admin/users?';
      if (query != null && query.isNotEmpty) {
        endpoint += 'q=${Uri.encodeComponent(query)}&';
      }
      if (filter != null && filter.isNotEmpty) {
        endpoint += 'filter=$filter&';
      }

      final response = await ApiClient.get(endpoint);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return (data['data'] as List)
              .map((x) => Map<String, dynamic>.from(x as Map))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching admin users: $e');
    }
    return [];
  }

  Future<bool> setUserBan(String userId, bool isBanned) async {
    try {
      final response = await ApiClient.post('/admin/users/$userId/ban', {
        'isBanned': isBanned,
      });
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error toggling ban: $e');
      return false;
    }
  }

  Future<bool> setUserVerification(
    String userId,
    bool isVerified, {
    String verificationType = 'BLUE',
  }) async {
    try {
      final response = await ApiClient.post('/admin/users/$userId/verify', {
        'isVerified': isVerified,
        'verificationType': verificationType,
      });
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error setting verification: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchUnmaskedConfessions() async {
    try {
      final response = await ApiClient.get('/admin/confessions');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return (data['data'] as List)
              .map((x) => Map<String, dynamic>.from(x as Map))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching confessions: $e');
    }
    return [];
  }

  Future<bool> deletePostAdmin(String postId) async {
    try {
      final response = await ApiClient.delete('/admin/posts/$postId');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting post: $e');
      return false;
    }
  }

  Future<bool> broadcastAnnouncement(String title, String body) async {
    try {
      final response = await ApiClient.post('/admin/broadcast', {
        'title': title,
        'body': body,
      });
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Error broadcasting: $e');
      return false;
    }
  }

  Future<bool> getAiPostingStatus() async {
    try {
      final response = await ApiClient.get('/admin/settings/ai-posting');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['enabled'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Error fetching AI posting status: $e');
      return false;
    }
  }

  Future<bool> setAiPostingStatus(bool enabled) async {
    try {
      final response = await ApiClient.post('/admin/settings/ai-posting', {
        'enabled': enabled,
      });
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating AI posting status: $e');
      return false;
    }
  }

  Future<int?> cleanAiFeedPosts() async {
    try {
      final response = await ApiClient.post('/admin/ai-posts/clean', {});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['count'] as int? ?? 0;
      }
      return null;
    } catch (e) {
      debugPrint('Error cleaning AI feed posts: $e');
      return null;
    }
  }
}
