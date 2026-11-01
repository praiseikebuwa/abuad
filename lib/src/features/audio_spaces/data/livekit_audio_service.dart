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

  String? _currentUrl;
  String? _currentToken;
  bool _isConnecting = false;

  Future<void> connect({
    required String url,
    required String token,
    required bool canPublish,
    bool autoEnableMic = false,
  }) async {
    // If we are already connected to the same room with the same token, do not reconnect
    if (_room != null && isConnected && _currentToken == token && _currentUrl == url) {
      debugPrint('🎙️ [LiveKit] Already connected to room with current token. Updating mic/publish permissions.');
      if (canPublish && autoEnableMic) {
        await setMicrophoneEnabled(true);
      } else if (!canPublish) {
        await setMicrophoneEnabled(false);
      }
      return;
    }

    if (_isConnecting && _currentToken == token) {
      debugPrint('🎙️ [LiveKit] Connection already in progress with this token. Skipping redundant connect.');
      return;
    }

    _isConnecting = true;

    try {
      await disconnect();

      _currentUrl = url;
      _currentToken = token;

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
          final speakerIds = event.speakers
              .map((s) => s.identity)
              .where((id) => id.isNotEmpty)
              .toList();
          _activeSpeakerIds = speakerIds;
          _speakersController.add(speakerIds);
        })
        ..on<AudioPlaybackStatusChanged>((event) async {
          if (!room.canPlaybackAudio) {
            debugPrint('⚠️ [LiveKit] Audio autoplay blocked. Attempting startAudio...');
            try {
              await room.startAudio();
            } catch (_) {}
          }
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

      // Route audio to speakerphone on mobile
      if (!kIsWeb) {
        try {
          await AudioManager.instance.setSpeakerOutputPreferred(true);
        } catch (he) {
          debugPrint('⚠️ [LiveKit] setSpeakerOutputPreferred warning: $he');
        }
      }

      // Unlock HTML5 Web Audio / AudioContext
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
      _currentUrl = null;
      _currentToken = null;
      await disconnect();
      rethrow;
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> startAudio() async {
    final r = _room;
    if (r != null) {
      try {
        await r.startAudio();
      } catch (e) {
        debugPrint('⚠️ [LiveKit] startAudio error: $e');
      }
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
    _currentToken = null;
    _currentUrl = null;
    _isConnecting = false;

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
