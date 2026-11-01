import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../audio_spaces/data/audio_room_repository.dart';
import '../../audio_spaces/domain/audio_room.dart';
import '../../audio_spaces/presentation/controllers/audio_room_controller.dart';

class StudyLoungeRepository {
  final AudioRoomRepository _audioRoomRepository;

  StudyLoungeRepository(this._audioRoomRepository);

  Future<List<AudioRoom>> getLiveStudyLounges() async {
    return _audioRoomRepository.getRooms(
      category: 'ACADEMIC',
      status: 'LIVE',
    );
  }

  Future<List<AudioRoom>> getScheduledStudySessions() async {
    return _audioRoomRepository.getRooms(
      category: 'ACADEMIC',
      status: 'SCHEDULED',
    );
  }

  Future<AudioRoom> createStudyLounge({
    required String title,
    String? description,
    required String courseCode,
    String? faculty,
    DateTime? scheduledAt,
    List<String> tags = const [],
  }) async {
    final finalTags = <String>[
      if (courseCode.isNotEmpty) courseCode.toUpperCase(),
      if (faculty != null && faculty.isNotEmpty) faculty,
      ...tags,
    ];

    final result = await _audioRoomRepository.createRoom(
      title: title,
      description: description,
      category: 'ACADEMIC',
      scheduledAt: scheduledAt,
      tags: finalTags,
    );

    return result['room'] as AudioRoom;
  }
}

final studyLoungeRepositoryProvider = Provider<StudyLoungeRepository>((ref) {
  final audioRepo = ref.watch(audioRoomRepositoryProvider);
  return StudyLoungeRepository(audioRepo);
});

final liveStudyLoungesProvider = FutureProvider.autoDispose<List<AudioRoom>>((ref) async {
  final repo = ref.watch(studyLoungeRepositoryProvider);
  return repo.getLiveStudyLounges();
});

final scheduledStudySessionsProvider = FutureProvider.autoDispose<List<AudioRoom>>((ref) async {
  final repo = ref.watch(studyLoungeRepositoryProvider);
  return repo.getScheduledStudySessions();
});
