import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/services/api_client.dart';
import '../domain/audio_room.dart';

class AudioRoomRepository {
  const AudioRoomRepository();

  Future<List<AudioRoom>> getRooms({String? category, String? status}) async {
    final queryParams = <String, String>{};
    if (category != null && category.isNotEmpty && category != 'ALL') {
      queryParams['category'] = category;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final queryString = queryParams.isNotEmpty
        ? '?${Uri(queryParameters: queryParams).query}'
        : '';

    final res = await ApiClient.get('/audio-rooms$queryString');
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final json = jsonDecode(res.body);
      final list = json['data'] as List? ?? [];
      return list.map((item) => AudioRoom.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load audio rooms (${res.statusCode}): ${res.body}');
  }

  Future<Map<String, dynamic>> createRoom({
    required String title,
    String? description,
    String category = 'ACADEMIC',
    String visibility = 'PUBLIC',
    String speakersPermission = 'HOST_APPROVED',
    bool isRecording = false,
    bool isChatEnabled = true,
    DateTime? scheduledAt,
    List<String> taggedGroupIds = const [],
    List<String> taggedUserIds = const [],
    List<String> tags = const [],
  }) async {
    final body = {
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      'category': category,
      'visibility': visibility,
      'speakersPermission': speakersPermission,
      'isRecording': isRecording,
      'isChatEnabled': isChatEnabled,
      if (scheduledAt != null) 'scheduledAt': scheduledAt.toIso8601String(),
      if (taggedGroupIds.isNotEmpty) 'taggedGroupIds': taggedGroupIds,
      if (taggedUserIds.isNotEmpty) 'taggedUserIds': taggedUserIds,
      if (tags.isNotEmpty) 'tags': tags,
    };

    final res = await ApiClient.post('/audio-rooms', body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final json = jsonDecode(res.body);
      final data = json['data'] as Map<String, dynamic>;
      final room = AudioRoom.fromJson(data['room'] as Map<String, dynamic>);
      final token = data['token'] as String?;
      final role = data['role'] as String? ?? 'HOST';
      return {
        'room': room,
        'token': token,
        'role': role,
      };
    }
    throw Exception('Failed to create room (${res.statusCode}): ${res.body}');
  }

  Future<AudioRoom> getRoomDetails(String roomId) async {
    final res = await ApiClient.get('/audio-rooms/$roomId');
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final json = jsonDecode(res.body);
      return AudioRoom.fromJson(json['data'] as Map<String, dynamic>);
    }
    throw Exception('Failed to load room details (${res.statusCode})');
  }

  Future<Map<String, dynamic>> joinRoom(String roomId, {String role = 'LISTENER'}) async {
    final res = await ApiClient.post('/audio-rooms/$roomId/join', {'role': role});
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final json = jsonDecode(res.body);
      final data = json['data'] as Map<String, dynamic>;
      return {
        'token': data['token'] as String,
        'role': data['role'] as String? ?? 'LISTENER',
        'participant': AudioParticipant.fromJson(data['participant'] as Map<String, dynamic>),
      };
    }
    throw Exception('Failed to join audio room (${res.statusCode}): ${res.body}');
  }

  Future<void> leaveRoom(String roomId) async {
    try {
      await ApiClient.post('/audio-rooms/$roomId/leave', {});
    } catch (e) {
      debugPrint('[AudioRoomRepo] Leave room non-fatal error: $e');
    }
  }

  Future<void> raiseHand(String roomId) async {
    final res = await ApiClient.post('/audio-rooms/$roomId/raise-hand', {});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to raise hand: ${res.body}');
    }
  }

  Future<void> lowerHand(String roomId, {String? targetUserId}) async {
    final body = <String, dynamic>{};
    if (targetUserId != null) body['targetUserId'] = targetUserId;
    final res = await ApiClient.post('/audio-rooms/$roomId/lower-hand', body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to lower hand: ${res.body}');
    }
  }

  Future<void> moderate(
    String roomId, {
    required String targetUserId,
    required String action,
  }) async {
    final res = await ApiClient.post('/audio-rooms/$roomId/moderate', {
      'targetUserId': targetUserId,
      'action': action,
    });
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to perform moderation: ${res.body}');
    }
  }

  Future<List<AudioRoomMessageItem>> getMessages(String roomId) async {
    final res = await ApiClient.get('/audio-rooms/$roomId/messages');
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final json = jsonDecode(res.body);
      final list = json['data'] as List? ?? [];
      return list.map((item) => AudioRoomMessageItem.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<AudioRoomMessageItem> sendMessage(String roomId, String message) async {
    final res = await ApiClient.post('/audio-rooms/$roomId/messages', {'message': message});
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final json = jsonDecode(res.body);
      return AudioRoomMessageItem.fromJson(json['data'] as Map<String, dynamic>);
    }
    throw Exception('Failed to send message: ${res.body}');
  }

  Future<void> endRoom(String roomId) async {
    final res = await ApiClient.post('/audio-rooms/$roomId/end', {});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to end room: ${res.body}');
    }
  }
}
