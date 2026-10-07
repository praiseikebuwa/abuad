import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AcademicRepository {
  String? get currentUserId => null;

  Future<void> saveGPAResult({
    required String semester,
    required double gpa,
    required List<Map<String, dynamic>> courses,
  }) async {}

  Stream<List<Map<String, dynamic>>> watchResults() async* {
    yield [];
  }

  Future<void> deleteResult(String resultId) async {}
}

final academicRepositoryProvider = Provider<AcademicRepository>((ref) {
  return AcademicRepository();
});

final resultsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(academicRepositoryProvider).watchResults();
});
