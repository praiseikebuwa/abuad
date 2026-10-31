import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

class LiveKitAudioService {
  Room? _room;
  EventsListener<RoomEvent>? _listener;

  Room? get room => _room;
  bool get isConnected => _room?.connectionState == ConnectionState.connected;

  final _speakersController = StreamController<List<String>>.broadcast();
  Stream<List<String>> get activeSpeakersStream => _speakersController.stream;

  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  Stream<ConnectionState> get connectionStateStream => _connectionStateController.stream;

  final _micStateController = StreamController<bool>.broadcast();
  Stream<bool> get micStateStream => _micStateController.stream;

  bool _isMicEnabled = false;
  bool get isMicEnabled => _isMicEnabled;

  List<String> _activeSpeakerIds = [];
  List<String> get activeSpeakerIds => _activeSpeakerIds;

  Future<void> connect({
    required String url,
    required String token,
    required bool canPublish,
  }) async {
    try {
      await disconnect();

      debugPrint('🎙️ [LiveKit] Connecting to $url...');

      final roomOptions = RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioCaptureOptions: const AudioCaptureOptions(
          autoGainControl: true,
          echoCancellation: true,
          noiseSuppression: true,
        ),
      );

      final room = Room(roomOptions: roomOptions);
      _room = room;

      _listener = room.createListener();

      _listener!
        ..on<RoomConnectedEvent>((event) {
          debugPrint('🎙️ [LiveKit] Connected to room: ${room.name}');
          _connectionStateController.add(ConnectionState.connected);
        })
        ..on<RoomDisconnectedEvent>((event) {
          debugPrint('🎙️ [LiveKit] Disconnected from room: ${event.reason}');
          _connectionStateController.add(ConnectionState.disconnected);
          _speakersController.add([]);
          _activeSpeakerIds = [];
        })
        ..on<ActiveSpeakersChangedEvent>((event) {
          final speakerIds = event.speakers.map((s) => s.identity).toList();
          _activeSpeakerIds = speakerIds;
          _speakersController.add(speakerIds);
        })
        ..on<TrackMutedEvent>((event) {
          if (event.participant == room.localParticipant) {
            _isMicEnabled = false;
            _micStateController.add(false);
          }
        })
        ..on<TrackUnmutedEvent>((event) {
          if (event.participant == room.localParticipant) {
            _isMicEnabled = true;
            _micStateController.add(true);
          }
        });

      await room.connect(url, token);

      if (canPublish) {
        // Initially keep microphone unmuted if speaker, or let user unmute explicitly
        // Default to muted on entry to avoid hot mic feedback
        await setMicrophoneEnabled(false);
      } else {
        _isMicEnabled = false;
        _micStateController.add(false);
      }

      _connectionStateController.add(ConnectionState.connected);
    } catch (e) {
      debugPrint('❌ [LiveKit] Connection failed: $e');
      await disconnect();
      rethrow;
    }
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    try {
      if (_room == null || _room?.localParticipant == null) return;
      await _room!.localParticipant!.setMicrophoneEnabled(enabled);
      _isMicEnabled = enabled;
      _micStateController.add(enabled);
      debugPrint('🎙️ [LiveKit] Microphone enabled = $enabled');
    } catch (e) {
      debugPrint('❌ [LiveKit] Set microphone error: $e');
      rethrow;
    }
  }

  Future<void> toggleMicrophone() async {
    await setMicrophoneEnabled(!_isMicEnabled);
  }

  Future<void> disconnect() async {
    try {
      _listener?.dispose();
      _listener = null;

      if (_room != null) {
        debugPrint('🎙️ [LiveKit] Disconnecting room...');
        await _room!.disconnect();
        await _room!.dispose();
        _room = null;
      }

      _isMicEnabled = false;
      _activeSpeakerIds = [];
      _speakersController.add([]);
      _micStateController.add(false);
      _connectionStateController.add(ConnectionState.disconnected);
    } catch (e) {
      debugPrint('⚠️ [LiveKit] Error during disconnect: $e');
      _room = null;
    }
  }

  void dispose() {
    disconnect();
    _speakersController.close();
    _connectionStateController.close();
    _micStateController.close();
  }
}

