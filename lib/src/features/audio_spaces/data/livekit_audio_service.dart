import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

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
    bool autoEnableMic = false,
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

      try {
        await room.startAudio();
      } catch (e) {
        debugPrint('⚠️ [LiveKit] startAudio non-fatal: $e');
      }

      if (canPublish && autoEnableMic) {
        await setMicrophoneEnabled(true);
      } else if (canPublish) {
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
      if (enabled && !kIsWeb) {
        try {
          final status = await Permission.microphone.request();
          if (!status.isGranted) {
            debugPrint('⚠️ [LiveKit] Microphone permission denied');
            _isMicEnabled = false;
            _micStateController.add(false);
            return;
          }
        } catch (pe) {
          debugPrint('⚠️ [LiveKit] Permission request check non-fatal: $pe');
        }
      }
      final participant = _room?.localParticipant;
      if (participant == null) {
        debugPrint('⚠️ [LiveKit] Cannot set mic: localParticipant is null');
        return;
      }
      await participant.setMicrophoneEnabled(enabled);
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
      final roomToClose = _room;
      _room = null;

      if (roomToClose != null) {
        debugPrint('🎙️ [LiveKit] Disconnecting room...');
        try {
          await roomToClose.disconnect();
        } catch (e) {
          debugPrint('⚠️ [LiveKit] Disconnect room error: $e');
        }
        try {
          await roomToClose.dispose();
        } catch (e) {
          debugPrint('⚠️ [LiveKit] Dispose room error: $e');
        }
      }

      try {
        _listener?.dispose();
      } catch (_) {}
      _listener = null;

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

