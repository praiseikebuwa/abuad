import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AttendanceTrackerScreen extends StatefulWidget {
  const AttendanceTrackerScreen({super.key});

  @override
  State<AttendanceTrackerScreen> createState() => _AttendanceTrackerScreenState();
}

class _AttendanceTrackerScreenState extends State<AttendanceTrackerScreen> {
  // Course attendance items
  final List<_AttendanceCourse> _courses = [
    _AttendanceCourse(
      code: 'GST 111',
      title: 'Use of English',
      attended: 14,
      totalHeld: 16,
      expectedTotal: 20,
    ),
    _AttendanceCourse(
      code: 'GST 112',
      title: 'Logic & Philosophy',
      attended: 12,
      totalHeld: 16,
      expectedTotal: 20,
    ),
    _AttendanceCourse(
      code: 'ENG 201',
      title: 'Engineering Mathematics',
      attended: 10,
      totalHeld: 15,
      expectedTotal: 20,
    ),
    _AttendanceCourse(
      code: 'MTH 101',
      title: 'Elementary Mathematics',
      attended: 15,
      totalHeld: 17,
      expectedTotal: 22,
    ),
    _AttendanceCourse(
      code: 'CHAPEL',
      title: 'Sunday Chapel Services',
      attended: 7,
      totalHeld: 8,
      expectedTotal: 12,
      isChapel: true,
    ),
  ];

  final TextEditingController _newCourseCode = TextEditingController();
  final TextEditingController _newCourseTitle = TextEditingController();

  @override
  void dispose() {
    _newCourseCode.dispose();
    _newCourseTitle.dispose();
    super.dispose();
  }

  void _markAttendance(int index, bool wasPresent) {
    HapticFeedback.lightImpact();
    setState(() {
      _courses[index].totalHeld++;
      if (wasPresent) {
        _courses[index].attended++;
      }
    });
  }

  void _showAddCourseDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text('Track New Course', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _newCourseCode,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Course Code (e.g. LAW 101)',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _newCourseTitle,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Course Title',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            onPressed: () {
              if (_newCourseCode.text.trim().isNotEmpty) {
                setState(() {
                  _courses.add(
                    _AttendanceCourse(
                      code: _newCourseCode.text.trim().toUpperCase(),
                      title: _newCourseTitle.text.trim().isEmpty ? 'Lecture Series' : _newCourseTitle.text.trim(),
                      attended: 0,
                      totalHeld: 0,
                      expectedTotal: 20,
                    ),
                  );
                });
                _newCourseCode.clear();
                _newCourseTitle.clear();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add Course', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check if any course is currently below 75%
    final atRiskCourses = _courses.where((c) => c.percentage < 75.0 && c.totalHeld > 0).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          '75% Attendance Tracker',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: _showAddCourseDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ABUAD 75% Rule Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: atRiskCourses.isNotEmpty
                    ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)]
                    : [const Color(0xFF10B981), const Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (atRiskCourses.isNotEmpty ? const Color(0xFFEF4444) : const Color(0xFF10B981))
                      .withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ABUAD EXAM ELIGIBILITY POLICY',
                        style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Icon(
                      atRiskCourses.isNotEmpty ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  atRiskCourses.isNotEmpty
                      ? '⚠️ Warning: ${atRiskCourses.length} Course${atRiskCourses.length == 1 ? '' : 's'} Below 75%'
                      : 'All Courses Safe for Exam Clearance! 🎉',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Students must maintain a minimum of 75% attendance in all registered courses and chapel services to sit for final semester examinations.',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Your Registered Courses & Chapel Attendance',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),

          ..._courses.asMap().entries.map((entry) {
            final idx = entry.key;
            final course = entry.value;
            return _buildCourseAttendanceTile(idx, course, isDark);
          }),
        ],
      ),
    );
  }

  Widget _buildCourseAttendanceTile(int idx, _AttendanceCourse course, bool isDark) {
    final pct = course.percentage;
    final isSafe = pct >= 75.0 || course.totalHeld == 0;
    final safeToMiss = course.safeToMissCount;
    final neededInRow = course.neededToRecoverCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSafe ? (isDark ? Colors.white10 : const Color(0xFFE2E8F0)) : Colors.redAccent.withValues(alpha: 0.6),
          width: isSafe ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (course.isChapel ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  course.code,
                  style: GoogleFonts.robotoMono(
                    fontWeight: FontWeight.bold,
                    color: course.isChapel ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  course.title,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: GoogleFonts.robotoMono(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: isSafe ? const Color(0xFF10B981) : Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: course.totalHeld == 0 ? 1.0 : (pct / 100),
              minHeight: 8,
              backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                isSafe ? const Color(0xFF10B981) : Colors.redAccent,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Counts and Insight Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${course.attended} attended / ${course.totalHeld} held',
                style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSafe
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isSafe
                      ? (safeToMiss > 0 ? 'Safe to miss: $safeToMiss' : 'Right at 75% threshold')
                      : '⚠️ Must attend next $neededInRow lectures!',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSafe ? const Color(0xFF10B981) : Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12),

          // Quick Mark Actions
          Row(
            children: [
              Text('Log lecture today:', style: GoogleFonts.inter(fontSize: 12, color: Colors.white38)),
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.check_rounded, size: 16, color: Color(0xFF10B981)),
                label: const Text('Present', style: TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF10B981)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _markAttendance(idx, true),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                label: const Text('Absent', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _markAttendance(idx, false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceCourse {
  final String code;
  final String title;
  int attended;
  int totalHeld;
  int expectedTotal;
  final bool isChapel;

  _AttendanceCourse({
    required this.code,
    required this.title,
    required this.attended,
    required this.totalHeld,
    required this.expectedTotal,
    this.isChapel = false,
  });

  double get percentage {
    if (totalHeld == 0) return 100.0;
    return (attended / totalHeld) * 100;
  }

  // How many more lectures student can safely miss and still remain >= 75%
  int get safeToMissCount {
    if (totalHeld == 0) return 3;
    int testHeld = totalHeld;
    int testAttended = attended;
    int safeMisses = 0;
    while ((testAttended / (testHeld + 1)) >= 0.75) {
      safeMisses++;
      testHeld++;
    }
    return safeMisses;
  }

  // How many consecutive lectures student must attend to reach >= 75%
  int get neededToRecoverCount {
    if (percentage >= 75.0) return 0;
    int testHeld = totalHeld;
    int testAttended = attended;
    int count = 0;
    while ((testAttended / testHeld) < 0.75 && count < 30) {
      testAttended++;
      testHeld++;
      count++;
    }
    return count;
  }
}
