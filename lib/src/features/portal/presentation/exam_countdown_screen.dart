import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class ExamCountdownScreen extends StatefulWidget {
  const ExamCountdownScreen({super.key});

  @override
  State<ExamCountdownScreen> createState() => _ExamCountdownScreenState();
}

class _ExamCountdownScreenState extends State<ExamCountdownScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Countdown Events (ABUAD Academic Calendar defaults)
  late List<_ExamEvent> _events;

  // Pomodoro Timer State
  int _pomodoroSeconds = 25 * 60;
  bool _isPomodoroRunning = false;
  Timer? _pomodoroTimer;
  int _completedSessions = 4;
  String _currentMode = 'Focus'; // Focus, Short Break, Long Break

  // Study Checklist
  final List<_StudyTask> _tasks = [
    _StudyTask(course: 'GST 111', topic: 'Revise 2021-2023 Past Questions (Concord & Idioms)', isDone: true),
    _StudyTask(course: 'GST 111', topic: 'Practice Reading Comprehension Speed Drills', isDone: true),
    _StudyTask(course: 'GST 112', topic: 'Memorize Socratic & Cartesian Philosophical tenets', isDone: false),
    _StudyTask(course: 'MTH 101', topic: 'Calculus: Derivatives and limits practice set', isDone: false),
    _StudyTask(course: 'ENG 201', topic: 'Material Science Module 2 summary notes', isDone: false),
    _StudyTask(course: 'GST 211', topic: 'Conflict Resolution: Mediation vs Arbitration frameworks', isDone: true),
  ];

  final TextEditingController _taskController = TextEditingController();
  final String _selectedCourseForTask = 'GST 111';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final now = DateTime.now();
    _events = [
      _ExamEvent(
        title: 'GST 111 & 112 CBT Mock Exams',
        courseCode: 'GST CBT',
        targetDate: now.add(const Duration(days: 8, hours: 14)),
        venue: 'Talent Discovery Centre (TDC) CBT Hall',
        color: const Color(0xFF8B5CF6),
      ),
      _ExamEvent(
        title: 'Mid-Semester Continuous Assessments',
        courseCode: 'CA Tests',
        targetDate: now.add(const Duration(days: 21, hours: 9)),
        venue: 'Respective College Lecture Theatres',
        color: const Color(0xFF3B82F6),
      ),
      _ExamEvent(
        title: 'First Semester Final Examinations',
        courseCode: 'Finals',
        targetDate: now.add(const Duration(days: 44, hours: 8)),
        venue: 'University Examination Centres',
        color: const Color(0xFFEF4444),
      ),
    ];
  }

  @override
  void dispose() {
    _pomodoroTimer?.cancel();
    _tabController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  void _togglePomodoro() {
    HapticFeedback.mediumImpact();
    if (_isPomodoroRunning) {
      _pomodoroTimer?.cancel();
      setState(() => _isPomodoroRunning = false);
    } else {
      setState(() => _isPomodoroRunning = true);
      _pomodoroTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_pomodoroSeconds > 0) {
          setState(() => _pomodoroSeconds--);
        } else {
          _pomodoroTimer?.cancel();
          HapticFeedback.heavyImpact();
          setState(() {
            _isPomodoroRunning = false;
            if (_currentMode == 'Focus') {
              _completedSessions++;
              _setPomodoroMode('Short Break');
            } else {
              _setPomodoroMode('Focus');
            }
          });
        }
      });
    }
  }

  void _resetPomodoro() {
    HapticFeedback.lightImpact();
    _pomodoroTimer?.cancel();
    setState(() {
      _isPomodoroRunning = false;
      _pomodoroSeconds = _currentMode == 'Focus'
          ? 25 * 60
          : (_currentMode == 'Short Break' ? 5 * 60 : 15 * 60);
    });
  }

  void _setPomodoroMode(String mode) {
    HapticFeedback.selectionClick();
    _pomodoroTimer?.cancel();
    setState(() {
      _currentMode = mode;
      _isPomodoroRunning = false;
      if (mode == 'Focus') {
        _pomodoroSeconds = 25 * 60;
      } else if (mode == 'Short Break') {
        _pomodoroSeconds = 5 * 60;
      } else {
        _pomodoroSeconds = 15 * 60;
      }
    });
  }

  String _formatTimer(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _addNewTask() {
    final text = _taskController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _tasks.insert(0, _StudyTask(course: _selectedCourseForTask, topic: text, isDone: false));
      _taskController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Exam & Study Hub',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF8B5CF6),
          indicatorWeight: 3,
          labelColor: isDark ? Colors.white : Colors.black,
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.timer_rounded, size: 20), text: 'Countdown'),
            Tab(icon: Icon(Icons.hourglass_top_rounded, size: 20), text: 'Pomodoro'),
            Tab(icon: Icon(Icons.checklist_rounded, size: 20), text: 'Checklist'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCountdownTab(isDark),
          _buildPomodoroTab(isDark),
          _buildChecklistTab(isDark),
        ],
      ),
    );
  }

  // ── Tab 1: Exam Countdowns ────────────────────────────────────────────────

  Widget _buildCountdownTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Hero Next Exam Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'NEXT EXAM',
                      style: GoogleFonts.robotoMono(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Icon(Icons.school_rounded, color: Colors.white, size: 22),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _events.first.title,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: Colors.white70, size: 15),
                  const SizedBox(width: 4),
                  Text(
                    _events.first.venue,
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildDigitalCountdownBox(_events.first.targetDate),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Upcoming Assessments & Exams',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ..._events.skip(1).map((event) => _buildEventCard(event, isDark)),
      ],
    );
  }

  Widget _buildDigitalCountdownBox(DateTime target) {
    final diff = target.difference(DateTime.now());
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final mins = diff.inMinutes % 60;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildTimeBox(days.toString().padLeft(2, '0'), 'DAYS'),
        _buildTimeColon(),
        _buildTimeBox(hours.toString().padLeft(2, '0'), 'HOURS'),
        _buildTimeColon(),
        _buildTimeBox(mins.toString().padLeft(2, '0'), 'MINS'),
      ],
    );
  }

  Widget _buildTimeBox(String val, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            val,
            style: GoogleFonts.robotoMono(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildTimeColon() {
    return const Text(
      ':',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
    );
  }

  Widget _buildEventCard(_ExamEvent event, bool isDark) {
    final diff = event.targetDate.difference(DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: event.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '${diff.inDays}d',
                style: GoogleFonts.robotoMono(
                  color: event.color,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.venue,
                  style: GoogleFonts.inter(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Pomodoro Study Timer ──────────────────────────────────────────

  Widget _buildPomodoroTab(bool isDark) {
    final totalSecondsInMode = _currentMode == 'Focus'
        ? 25 * 60
        : (_currentMode == 'Short Break' ? 5 * 60 : 15 * 60);
    final progress = 1.0 - (_pomodoroSeconds / totalSecondsInMode);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Mode Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ['Focus', 'Short Break', 'Long Break'].map((mode) {
              final isSelected = _currentMode == mode;
              return GestureDetector(
                onTap: () => _setPomodoroMode(mode),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF8B5CF6)
                        : (isDark ? Colors.black : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    mode,
                    style: GoogleFonts.outfit(
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 36),

          // Big Circular Timer
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTimer(_pomodoroSeconds),
                    style: GoogleFonts.robotoMono(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currentMode.toUpperCase(),
                    style: GoogleFonts.robotoMono(
                      color: const Color(0xFF8B5CF6),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 36),

          // Controls: Play/Pause, Reset
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 32,
                icon: const Icon(Icons.refresh_rounded),
                color: isDark ? Colors.white54 : Colors.black45,
                onPressed: _resetPomodoro,
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: _togglePomodoro,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                    ),
                  ),
                  child: Icon(
                    _isPomodoroRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: Colors.amberAccent, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$_completedSessions',
                      style: GoogleFonts.robotoMono(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Streak info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates_rounded, color: AppColors.secondaryTeal, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pomodoro tip: Study for 25 minutes completely distraction-free, then take a quick 5-minute break.',
                    style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 3: Study Checklist ────────────────────────────────────────────────

  Widget _buildChecklistTab(bool isDark) {
    final completedCount = _tasks.where((t) => t.isDone).length;
    final totalCount = _tasks.length;
    final percent = totalCount == 0 ? 0.0 : completedCount / totalCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Progress Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Study Goal Progress',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    '$completedCount of $totalCount completed',
                    style: GoogleFonts.robotoMono(fontSize: 12, color: const Color(0xFF8B5CF6), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: percent,
                  minHeight: 8,
                  backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Add task input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _taskController,
                style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: 'Add revision topic...',
                  hintStyle: GoogleFonts.inter(color: Colors.white38),
                  filled: true,
                  fillColor: isDark ? Colors.black : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  ),
                ),
                onSubmitted: (_) => _addNewTask(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onPressed: _addNewTask,
              child: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 18),

        ..._tasks.map((task) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: CheckboxListTile(
                value: task.isDone,
                activeColor: const Color(0xFF8B5CF6),
                title: Text(
                  task.topic,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                    color: task.isDone
                        ? (isDark ? Colors.white38 : Colors.black38)
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                subtitle: Text(
                  task.course,
                  style: GoogleFonts.robotoMono(fontSize: 11, color: const Color(0xFF8B5CF6), fontWeight: FontWeight.bold),
                ),
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  setState(() => task.isDone = val ?? false);
                },
              ),
            )),
      ],
    );
  }
}

class _ExamEvent {
  final String title;
  final String courseCode;
  final DateTime targetDate;
  final String venue;
  final Color color;

  _ExamEvent({
    required this.title,
    required this.courseCode,
    required this.targetDate,
    required this.venue,
    required this.color,
  });
}

class _StudyTask {
  final String course;
  final String topic;
  bool isDone;

  _StudyTask({required this.course, required this.topic, required this.isDone});
}
