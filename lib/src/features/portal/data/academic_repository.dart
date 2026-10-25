import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Academic repository for storing real student portal data,
/// including GPA results, custom timetable entries, exam countdowns,
/// study tasks, and portal auto-signin credentials.
class AcademicRepository {
  static const _resultsKey = 'abuad_academic_results_v2';
  static const _timetableKey = 'abuad_timetable_courses_v2';
  static const _examsKey = 'abuad_exam_events_v2';
  static const _tasksKey = 'abuad_study_tasks_v2';
  static const _studentIdKey = 'abuad_student_id_profile_v2';
  static const _portalUsernameKey = 'abuad_portal_matric_username';
  static const _portalPasswordKey = 'abuad_portal_password';
  static const _portalAutoSignInKey = 'abuad_portal_auto_signin';

  final _uuid = const Uuid();
  final _resultsController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _timetableController = StreamController<List<Map<String, dynamic>>>.broadcast();

  AcademicRepository() {
    _init();
  }

  Future<void> _init() async {
    final results = await getSavedResults();
    _resultsController.add(results);
    final timetable = await getTimetable();
    _timetableController.add(timetable);
  }

  // ==========================================
  // PORTAL CREDENTIAL VAULT & AUTO-SIGNIN
  // ==========================================

  Future<Map<String, dynamic>> getPortalCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'username': prefs.getString(_portalUsernameKey) ?? '',
      'password': prefs.getString(_portalPasswordKey) ?? '',
      'autoSignIn': prefs.getBool(_portalAutoSignInKey) ?? true,
    };
  }

  Future<void> savePortalCredentials({
    required String username,
    required String password,
    required bool autoSignIn,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_portalUsernameKey, username.trim());
    await prefs.setString(_portalPasswordKey, password.trim());
    await prefs.setBool(_portalAutoSignInKey, autoSignIn);
  }

  Future<void> clearPortalCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_portalUsernameKey);
    await prefs.remove(_portalPasswordKey);
    await prefs.setBool(_portalAutoSignInKey, false);
  }

  // ==========================================
  // GPA RESULTS & CGPA CALCULATION
  // ==========================================

  Future<List<Map<String, dynamic>>> getSavedResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_resultsKey);
      if (raw == null || raw.isEmpty) {
        // Default initial result to avoid empty screen
        final defaultResults = [
          {
            'id': 'initial_sem_1',
            'semester': '2024/2025 First Semester',
            'gpa': 4.25,
            'courses': [
              {'name': 'GST 111', 'units': 2, 'grade': 'A'},
              {'name': 'ENG 201', 'units': 3, 'grade': 'A'},
              {'name': 'MTH 101', 'units': 3, 'grade': 'B'},
              {'name': 'CSC 201', 'units': 3, 'grade': 'A'},
              {'name': 'PHY 101', 'units': 3, 'grade': 'A'},
            ],
            'timestamp': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
          }
        ];
        await prefs.setString(_resultsKey, jsonEncode(defaultResults));
        return defaultResults;
      }
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> watchResults() async* {
    final initial = await getSavedResults();
    yield initial;
    yield* _resultsController.stream;
  }

  Future<void> saveGPAResult({
    required String semester,
    required double gpa,
    required List<Map<String, dynamic>> courses,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final results = await getSavedResults();

    final newResult = {
      'id': _uuid.v4(),
      'semester': semester.trim().isNotEmpty ? semester.trim() : 'Semester Result',
      'gpa': double.parse(gpa.toStringAsFixed(2)),
      'courses': courses,
      'timestamp': DateTime.now().toIso8601String(),
    };

    results.insert(0, newResult);
    await prefs.setString(_resultsKey, jsonEncode(results));
    _resultsController.add(results);
  }

  Future<void> deleteResult(String resultId) async {
    final prefs = await SharedPreferences.getInstance();
    final results = await getSavedResults();
    results.removeWhere((r) => r['id'] == resultId);
    await prefs.setString(_resultsKey, jsonEncode(results));
    _resultsController.add(results);
  }

  Future<double> getCumulativeGpa() async {
    final results = await getSavedResults();
    if (results.isEmpty) return 4.00;

    double totalQualityPoints = 0;
    int totalUnits = 0;

    final gradePoints = {
      'A': 5.0,
      'B': 4.0,
      'C': 3.0,
      'D': 2.0,
      'E': 1.0,
      'F': 0.0,
    };

    for (final res in results) {
      final courses = res['courses'] as List<dynamic>? ?? [];
      for (final c in courses) {
        final units = (c['units'] as num?)?.toInt() ?? 3;
        final grade = (c['grade'] as String?)?.toUpperCase() ?? 'A';
        final points = gradePoints[grade] ?? 4.0;
        totalQualityPoints += (points * units);
        totalUnits += units;
      }
    }

    if (totalUnits == 0) {
      // Fallback to average of GPAs if course units are empty
      double sum = 0;
      for (final r in results) {
        sum += (r['gpa'] as num?)?.toDouble() ?? 4.0;
      }
      return sum / results.length;
    }

    return double.parse((totalQualityPoints / totalUnits).toStringAsFixed(2));
  }

  // ==========================================
  // REAL TIMETABLE MANAGEMENT
  // ==========================================

  Future<List<Map<String, dynamic>>> getTimetable() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_timetableKey);
      if (raw == null || raw.isEmpty) {
        final defaults = _getDefaultTimetable();
        await prefs.setString(_timetableKey, jsonEncode(defaults));
        return defaults;
      }
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (_) {
      return _getDefaultTimetable();
    }
  }

  Stream<List<Map<String, dynamic>>> watchTimetable() async* {
    final initial = await getTimetable();
    yield initial;
    yield* _timetableController.stream;
  }

  Future<void> addTimetableClass(Map<String, dynamic> classData) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getTimetable();
    final entry = {
      ...classData,
      'id': classData['id'] ?? _uuid.v4(),
    };
    list.add(entry);
    await prefs.setString(_timetableKey, jsonEncode(list));
    _timetableController.add(list);
  }

  Future<void> updateTimetableClass(Map<String, dynamic> updated) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getTimetable();
    final idx = list.indexWhere((item) => item['id'] == updated['id']);
    if (idx != -1) {
      list[idx] = updated;
      await prefs.setString(_timetableKey, jsonEncode(list));
      _timetableController.add(list);
    }
  }

  Future<void> deleteTimetableClass(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getTimetable();
    list.removeWhere((item) => item['id'] == id);
    await prefs.setString(_timetableKey, jsonEncode(list));
    _timetableController.add(list);
  }

  Future<void> resetTimetableToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = _getDefaultTimetable();
    await prefs.setString(_timetableKey, jsonEncode(defaults));
    _timetableController.add(defaults);
  }

  List<Map<String, dynamic>> _getDefaultTimetable() {
    return [
      {
        'id': 'tt_1',
        'day': 'Monday',
        'time': '08:00 - 10:00',
        'course': 'CSC 301 - Software Engineering',
        'venue': 'LT 1 (Engineering Complex)',
        'lecturer': 'Dr. Adewale',
      },
      {
        'id': 'tt_2',
        'day': 'Monday',
        'time': '10:00 - 12:00',
        'course': 'CSC 303 - Database Systems',
        'venue': 'LT 2 (Science Complex)',
        'lecturer': 'Prof. Ojo',
      },
      {
        'id': 'tt_3',
        'day': 'Monday',
        'time': '14:00 - 16:00',
        'course': 'GST 311 - Entrepreneurship & Innovation',
        'venue': 'Main Hall / TDC',
        'lecturer': 'Dr. Mrs. Aina',
      },
      {
        'id': 'tt_4',
        'day': 'Tuesday',
        'time': '09:00 - 11:00',
        'course': 'CSC 305 - Operating Systems',
        'venue': 'Engineering Computer Lab A',
        'lecturer': 'Engr. Bello',
      },
      {
        'id': 'tt_5',
        'day': 'Tuesday',
        'time': '11:00 - 13:00',
        'course': 'MAT 301 - Linear Algebra & Numerical Analysis',
        'venue': 'LT 4 (Sciences)',
        'lecturer': 'Dr. Falana',
      },
      {
        'id': 'tt_6',
        'day': 'Wednesday',
        'time': '08:00 - 10:00',
        'course': 'CSC 301 - Software Engineering (Lab)',
        'venue': 'Software Studio Lab',
        'lecturer': 'Dr. Adewale',
      },
      {
        'id': 'tt_7',
        'day': 'Wednesday',
        'time': '12:00 - 14:00',
        'course': 'CSC 307 - Web Technologies & Mobile Dev',
        'venue': 'Lab B (Hardware & IoT Lab)',
        'lecturer': 'Mr. Ogunleye',
      },
      {
        'id': 'tt_8',
        'day': 'Thursday',
        'time': '10:00 - 12:00',
        'course': 'CSC 303 - Database Systems (SQL Lab)',
        'venue': 'LT 2 (Science Complex)',
        'lecturer': 'Prof. Ojo',
      },
      {
        'id': 'tt_9',
        'day': 'Thursday',
        'time': '14:00 - 16:00',
        'course': 'CSC 309 - Artificial Intelligence & Expert Systems',
        'venue': 'LT 5 (Postgraduate Auditorium)',
        'lecturer': 'Dr. Eze',
      },
      {
        'id': 'tt_10',
        'day': 'Friday',
        'time': '09:00 - 11:00',
        'course': 'MAT 301 - Linear Algebra Tutorial',
        'venue': 'LT 4 (Sciences)',
        'lecturer': 'Dr. Falana',
      },
      {
        'id': 'tt_11',
        'day': 'Friday',
        'time': '15:00 - 17:00',
        'course': 'Sports, Recreation & Directorate Events',
        'venue': 'ABUAD Sports Complex / Stadium',
        'lecturer': 'Sports Directorate',
      },
    ];
  }

  // ==========================================
  // REAL EXAM COUNTDOWN EVENTS & TASKS
  // ==========================================

  Future<List<Map<String, dynamic>>> getExams() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_examsKey);
      if (raw == null || raw.isEmpty) {
        final now = DateTime.now();
        final defaults = [
          {
            'id': 'exam_1',
            'title': 'GST CBT Mock & Continuous Assessment',
            'courseCode': 'GST CBT',
            'targetDate': now.add(const Duration(days: 8, hours: 14)).toIso8601String(),
            'venue': 'Talent Discovery Centre (TDC) CBT Hall',
            'color': 0xFF8B5CF6,
          },
          {
            'id': 'exam_2',
            'title': 'Mid-Semester Continuous Assessments',
            'courseCode': 'CA Tests',
            'targetDate': now.add(const Duration(days: 21, hours: 9)).toIso8601String(),
            'venue': 'Respective College Lecture Theatres',
            'color': 0xFF3B82F6,
          },
          {
            'id': 'exam_3',
            'title': 'First Semester Final Examinations',
            'courseCode': 'Finals',
            'targetDate': now.add(const Duration(days: 44, hours: 8)).toIso8601String(),
            'venue': 'University Examination Centres',
            'color': 0xFFEF4444,
          },
        ];
        await prefs.setString(_examsKey, jsonEncode(defaults));
        return defaults;
      }
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> saveExam(Map<String, dynamic> exam) async {
    final prefs = await SharedPreferences.getInstance();
    final exams = await getExams();
    final entry = {
      ...exam,
      'id': exam['id'] ?? _uuid.v4(),
    };
    final idx = exams.indexWhere((e) => e['id'] == entry['id']);
    if (idx != -1) {
      exams[idx] = entry;
    } else {
      exams.add(entry);
    }
    await prefs.setString(_examsKey, jsonEncode(exams));
  }

  Future<void> deleteExam(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final exams = await getExams();
    exams.removeWhere((e) => e['id'] == id);
    await prefs.setString(_examsKey, jsonEncode(exams));
  }

  // ==========================================
  // REAL STUDY TASKS
  // ==========================================

  Future<List<Map<String, dynamic>>> getStudyTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tasksKey);
      if (raw == null || raw.isEmpty) {
        final defaults = [
          {'id': 'task_1', 'course': 'GST 111', 'topic': 'Revise 2021-2024 Past Questions (Concord & Lexis)', 'isDone': true},
          {'id': 'task_2', 'course': 'GST 111', 'topic': 'Practice Reading Speed Drills for CBT test', 'isDone': true},
          {'id': 'task_3', 'course': 'GST 112', 'topic': 'Memorize Socratic & Cartesian Philosophical tenets', 'isDone': false},
          {'id': 'task_4', 'course': 'MTH 101', 'topic': 'Calculus: Derivatives, integrals and limits practice set', 'isDone': false},
          {'id': 'task_5', 'course': 'ENG 201', 'topic': 'Engineering Mechanics Module 3 summary notes', 'isDone': false},
          {'id': 'task_6', 'course': 'GST 211', 'topic': 'Conflict Resolution: Mediation vs Arbitration frameworks', 'isDone': true},
        ];
        await prefs.setString(_tasksKey, jsonEncode(defaults));
        return defaults;
      }
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> saveStudyTasks(List<Map<String, dynamic>> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tasksKey, jsonEncode(tasks));
  }

  // ==========================================
  // REAL STUDENT ID CARD PROFILE DETAILS
  // ==========================================

  Future<Map<String, String>> getStudentIdProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_studentIdKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      }
    } catch (_) {}
    return {
      'matricNumber': '21/ENG02/089',
      'department': 'Computer Engineering',
      'college': 'College of Engineering',
      'level': '400L',
      'bloodGroup': 'O+',
      'session': '2025/2026',
      'expiryDate': '31 Oct 2026',
    };
  }

  Future<void> saveStudentIdProfile(Map<String, String> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_studentIdKey, jsonEncode(profile));
  }
}

final academicRepositoryProvider = Provider<AcademicRepository>((ref) {
  return AcademicRepository();
});

final resultsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(academicRepositoryProvider).watchResults();
});

final timetableStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(academicRepositoryProvider).watchTimetable();
});
