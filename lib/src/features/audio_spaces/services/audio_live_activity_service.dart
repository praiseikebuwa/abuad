import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/url_scheme_data.dart';

final audioLiveActivityServiceProvider = Provider<AudioLiveActivityService>((ref) {
  final service = AudioLiveActivityService();
  service.init();
  return service;
});

class AudioLiveActivityService {
  final LiveActivities _liveActivities = LiveActivities();
  bool _isInitialized = false;
  String? _currentActivityId;
  StreamSubscription? _urlSchemeSub;

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  Future<void> init() async {
    if (!_isSupportedPlatform || _isInitialized) return;
    try {
      await _liveActivities.init(
        appGroupId: 'group.com.abuad.life',
        urlScheme: 'abuadlife',
      );
      _isInitialized = true;
      debugPrint('[AudioLiveActivity] Initialized successfully');
    } catch (e) {
      debugPrint('[AudioLiveActivity] Init warning: $e');
    }
  }

  /// Start or update a Live Activity on Dynamic Island & Lock Screen for an ongoing Space
  Future<String?> startSpaceActivity({
    required String roomId,
    required String title,
    required String hostName,
    required String category,
    int participantCount = 1,
    bool isHost = false,
    bool isMuted = false,
  }) async {
    if (!_isSupportedPlatform) return null;
    try {
      await init();
      final activityData = <String, dynamic>{
        'type': 'active_space',
        'roomId': roomId,
        'title': title,
        'hostName': hostName,
        'category': category,
        'participantCount': participantCount,
        'isHost': isHost,
        'isMuted': isMuted,
        'status': 'LIVE',
        'startedAt': DateTime.now().millisecondsSinceEpoch,
        'deepLink': 'abuadlife://audio-space/$roomId',
      };

      if (_currentActivityId != null) {
        await _liveActivities.updateActivity(_currentActivityId!, activityData);
        return _currentActivityId;
      }

      final activityId = await _liveActivities.createActivity(
        'space_$roomId',
        activityData,
      );
      _currentActivityId = activityId ?? 'space_$roomId';
      debugPrint('[AudioLiveActivity] Started Space activity: $_currentActivityId');
      return _currentActivityId;
    } catch (e) {
      debugPrint('[AudioLiveActivity] Error starting space activity: $e');
      return null;
    }
  }

  /// Push a Live Activity invite notification to tagged users / group members
  Future<String?> showInvitationActivity({
    required String roomId,
    required String title,
    required String hostName,
    required String category,
    required String inviterName,
  }) async {
    if (!_isSupportedPlatform) return null;
    try {
      await init();
      final activityData = <String, dynamic>{
        'type': 'invitation',
        'roomId': roomId,
        'title': title,
        'hostName': hostName,
        'category': category,
        'inviterName': inviterName,
        'status': 'INVITED',
        'deepLink': 'abuadlife://audio-space/$roomId',
        'actionJoin': 'abuadlife://audio-space/$roomId/join',
        'actionDismiss': 'abuadlife://audio-space/$roomId/dismiss',
      };

      final activityId = await _liveActivities.createActivity(
        'invite_$roomId',
        activityData,
      );
      debugPrint('[AudioLiveActivity] Created Invitation activity: $activityId');
      return activityId;
    } catch (e) {
      debugPrint('[AudioLiveActivity] Error starting invitation activity: $e');
      return null;
    }
  }

  /// Update the live activity when listeners join, leave, or mic status changes
  Future<void> updateSpaceActivity({
    required String roomId,
    required int participantCount,
    bool isMuted = false,
    String? currentSpeakerName,
  }) async {
    if (!_isSupportedPlatform) return;
    try {
      if (_currentActivityId == null) return;
      final updatePayload = <String, dynamic>{
        'participantCount': participantCount,
        'isMuted': isMuted,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      if (currentSpeakerName != null) {
        updatePayload['currentSpeaker'] = currentSpeakerName;
      }
      await _liveActivities.updateActivity(_currentActivityId!, updatePayload);
    } catch (e) {
      debugPrint('[AudioLiveActivity] Error updating space activity: $e');
    }
  }

  /// End and remove the Live Activity when leaving or ending the space
  Future<void> endSpaceActivity([String? roomId]) async {
    if (!_isSupportedPlatform) return;
    try {
      final idToEnd = roomId != null ? 'space_$roomId' : _currentActivityId;
      if (idToEnd != null) {
        await _liveActivities.endActivity(idToEnd);
      } else {
        await _liveActivities.endAllActivities();
      }
      if (idToEnd == _currentActivityId) {
        _currentActivityId = null;
      }
      debugPrint('[AudioLiveActivity] Ended activity: $idToEnd');
    } catch (e) {
      debugPrint('[AudioLiveActivity] Error ending activity: $e');
    }
  }

  /// Listen to deep links from Dynamic Island or Lock Screen taps
  Stream<UrlSchemeData> get urlSchemeStream =>
      _isSupportedPlatform ? _liveActivities.urlSchemeStream() : const Stream.empty();

  void dispose() {
    _urlSchemeSub?.cancel();
  }
}
