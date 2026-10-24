import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class CbtPracticeScreen extends StatefulWidget {
  const CbtPracticeScreen({super.key});

  @override
  State<CbtPracticeScreen> createState() => _CbtPracticeScreenState();
}

class _CbtPracticeScreenState extends State<CbtPracticeScreen> {
  // Course selection
  final List<_CbtCourse> _courses = [
    _CbtCourse(
      code: 'GST 111',
      title: 'Use of English',
      description: 'Concord, Lexis, Reading Comprehension & Figures of Speech',
      icon: Icons.menu_book_rounded,
      color: const Color(0xFF8B5CF6),
      questionsCount: 10,
      durationMinutes: 10,
    ),
    _CbtCourse(
      code: 'GST 112',
      title: 'Logic, Philosophy & Human Existence',
      description: 'Deductive vs Inductive reasoning, Fallacies & Epistemology',
      icon: Icons.psychology_rounded,
      color: const Color(0xFF3B82F6),
      questionsCount: 10,
      durationMinutes: 10,
    ),
    _CbtCourse(
      code: 'GST 211',
      title: 'Peace & Conflict Studies',
      description: 'Conflict dynamics, mediation, peace treaties & security',
      icon: Icons.handshake_rounded,
      color: const Color(0xFF10B981),
      questionsCount: 10,
      durationMinutes: 10,
    ),
    _CbtCourse(
      code: 'MTH 101',
      title: 'Elementary Mathematics',
      description: 'Trigonometry, complex numbers, quadratic systems & calculus',
      icon: Icons.functions_rounded,
      color: const Color(0xFFF59E0B),
      questionsCount: 10,
      durationMinutes: 15,
    ),
    _CbtCourse(
      code: 'CHM 101',
      title: 'General Chemistry',
      description: 'Stoichiometry, atomic models, periodic trends & chemical bonding',
      icon: Icons.science_rounded,
      color: const Color(0xFFEF4444),
      questionsCount: 10,
      durationMinutes: 12,
    ),
  ];

  _CbtCourse? _activeCourse;
  bool _isExamActive = false;
  bool _isResultActive = false;

  int _currentQuestionIndex = 0;
  final Map<int, int> _selectedAnswers = {}; // questionIndex -> optionIndex
  int _secondsRemaining = 0;
  Timer? _examTimer;

  // Preloaded mock questions for GST 111 (as prototype)
  final List<_CbtQuestion> _gst111Questions = [
    _CbtQuestion(
      question: 'Neither the lecturer nor the students _____ present at the auditorium.',
      options: ['was', 'were', 'is', 'are being'],
      correctIndex: 1,
      explanation: 'In the rule of proximity for "neither... nor", the verb agrees with the closer subject ("students", which is plural), hence "were".',
    ),
    _CbtQuestion(
      question: 'Identify the figure of speech in: "The university library whispered secrets of past scholars."',
      options: ['Metaphor', 'Simile', 'Personification', 'Synecdoche'],
      correctIndex: 2,
      explanation: 'Assigning human qualities ("whispered secrets") to an inanimate object (the library) is Personification.',
    ),
    _CbtQuestion(
      question: 'Which of the following is a complex sentence?',
      options: [
        'Afe Babalola University was founded in 2009.',
        'The students prepared, and the examination commenced promptly.',
        'Because the bell rang, the candidate submitted her script.',
        'Study hard, pray hard.',
      ],
      correctIndex: 2,
      explanation: 'A complex sentence contains an independent clause and at least one dependent subordinate clause introduced by a subordinating conjunction ("Because").',
    ),
    _CbtQuestion(
      question: 'Choose the word nearest in meaning to EPHEMERAL in the context: "Campus popularity is ephemeral."',
      options: ['Lasting', 'Fleeting', 'Monumental', 'Glorious'],
      correctIndex: 1,
      explanation: '"Ephemeral" means lasting for a very short time; fleeting or transient.',
    ),
    _CbtQuestion(
      question: 'One of the following prefixes indicates negation:',
      options: ['Pro-', 'Dis-', 'Ante-', 'Super-'],
      correctIndex: 1,
      explanation: 'The prefix "Dis-" means not or opposite of (e.g. disrespect, disconnect).',
    ),
  ];

  void _startExam(_CbtCourse course) {
    HapticFeedback.mediumImpact();
    setState(() {
      _activeCourse = course;
      _isExamActive = true;
      _isResultActive = false;
      _currentQuestionIndex = 0;
      _selectedAnswers.clear();
      _secondsRemaining = course.durationMinutes * 60;
    });

    _examTimer?.cancel();
    _examTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _finishExam();
      }
    });
  }

  void _finishExam() {
    _examTimer?.cancel();
    HapticFeedback.heavyImpact();
    setState(() {
      _isExamActive = false;
      _isResultActive = true;
    });
  }

  int get _score {
    int count = 0;
    for (int i = 0; i < _gst111Questions.length; i++) {
      if (_selectedAnswers[i] == _gst111Questions[i].correctIndex) {
        count++;
      }
    }
    return count;
  }

  String _formatTimer(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _examTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _isExamActive
              ? '${_activeCourse?.code} Mock Exam'
              : (_isResultActive ? 'Exam Results & Review' : 'CBT Practice & Past Questions'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_isExamActive)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_rounded, size: 14, color: Colors.redAccent),
                    const SizedBox(width: 4),
                    Text(
                      _formatTimer(_secondsRemaining),
                      style: GoogleFonts.robotoMono(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: _isExamActive
          ? _buildActiveExamView(isDark)
          : (_isResultActive ? _buildResultsView(isDark) : _buildCourseSelectionView(isDark)),
    );
  }

  // ── 1. Course Selection View ──────────────────────────────────────────────

  Widget _buildCourseSelectionView(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Hero Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'OFFICIAL ABUAD CBT PORTAL',
                  style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'University-Wide Past Questions & Mock Tests',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Prepare for TDC CBT exams with authentic questions, real timing, and answer explanations.',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Select a Course to Practice',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        ..._courses.map((course) => _buildCourseCard(course, isDark)),
      ],
    );
  }

  Widget _buildCourseCard(_CbtCourse course, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _startExam(course),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: course.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(course.icon, color: course.color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            course.code,
                            style: GoogleFonts.robotoMono(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: course.color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '· ${course.durationMinutes} mins',
                            style: GoogleFonts.inter(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        course.title,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        course.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 2. Active Exam View ───────────────────────────────────────────────────

  Widget _buildActiveExamView(bool isDark) {
    final q = _gst111Questions[_currentQuestionIndex];
    final selectedOption = _selectedAnswers[_currentQuestionIndex];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Question Progress Navigator
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_gst111Questions.length, (index) {
                final isCurrent = index == _currentQuestionIndex;
                final isAnswered = _selectedAnswers.containsKey(index);
                return GestureDetector(
                  onTap: () => setState(() => _currentQuestionIndex = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? const Color(0xFF8B5CF6)
                          : (isAnswered ? const Color(0xFF10B981) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.robotoMono(
                          fontWeight: FontWeight.bold,
                          color: (isCurrent || isAnswered) ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),

          // Question Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QUESTION ${_currentQuestionIndex + 1} OF ${_gst111Questions.length}',
                  style: GoogleFonts.robotoMono(fontSize: 11, color: const Color(0xFF8B5CF6), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  q.question,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 17),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Options List
          Expanded(
            child: ListView.separated(
              itemCount: q.options.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, optIdx) {
                final isSelected = selectedOption == optIdx;
                final letter = ['A', 'B', 'C', 'D'][optIdx];
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedAnswers[_currentQuestionIndex] = optIdx);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.18)
                          : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF8B5CF6) : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? const Color(0xFF8B5CF6) : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                          ),
                          child: Center(
                            child: Text(
                              letter,
                              style: GoogleFonts.robotoMono(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            q.options[optIdx],
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Navigation Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentQuestionIndex > 0)
                OutlinedButton(
                  onPressed: () => setState(() => _currentQuestionIndex--),
                  child: const Text('Previous'),
                )
              else
                const SizedBox.shrink(),
              if (_currentQuestionIndex < _gst111Questions.length - 1)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white),
                  onPressed: () => setState(() => _currentQuestionIndex++),
                  child: const Text('Next'),
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                  onPressed: _finishExam,
                  child: const Text('Submit Test'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 3. Results & Explanations Review View ──────────────────────────────────

  Widget _buildResultsView(bool isDark) {
    final score = _score;
    final total = _gst111Questions.length;
    final percent = (score / total) * 100;
    final passed = percent >= 50;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Score Header Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: passed
                  ? [const Color(0xFF10B981), const Color(0xFF047857)]
                  : [const Color(0xFFEF4444), const Color(0xFFB91C1C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Icon(passed ? Icons.verified_rounded : Icons.warning_rounded, color: Colors.white, size: 48),
              const SizedBox(height: 12),
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900),
              ),
              Text(
                passed ? 'Exam Passed! Excellent Work' : 'Needs Practice Before Exam Day',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'You answered $score out of $total questions correctly.',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Detailed Answers & Explanations',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),

        ..._gst111Questions.asMap().entries.map((entry) {
          final idx = entry.key;
          final question = entry.value;
          final userAns = _selectedAnswers[idx];
          final isCorrect = userAns == question.correctIndex;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCorrect ? const Color(0xFF10B981) : Colors.redAccent.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: isCorrect ? const Color(0xFF10B981) : Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Question ${idx + 1}',
                      style: GoogleFonts.robotoMono(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(question.question, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  'Correct Answer: ${question.options[question.correctIndex]}',
                  style: GoogleFonts.inter(color: const Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '💡 ${question.explanation}',
                    style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B5CF6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () => setState(() => _isResultActive = false),
          child: const Text('Back to Course Hub'),
        ),
      ],
    );
  }
}

class _CbtCourse {
  final String code;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int questionsCount;
  final int durationMinutes;

  _CbtCourse({
    required this.code,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.questionsCount,
    required this.durationMinutes,
  });
}

class _CbtQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  _CbtQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}
