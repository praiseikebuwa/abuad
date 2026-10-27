import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/api_client.dart';
import '../../resources/data/resource_repository.dart';

class CbtPracticeScreen extends ConsumerStatefulWidget {
  final String? initialCourseCode;
  final String? initialResourceId;

  const CbtPracticeScreen({
    super.key,
    this.initialCourseCode,
    this.initialResourceId,
  });

  @override
  ConsumerState<CbtPracticeScreen> createState() => _CbtPracticeScreenState();
}

class _CbtPracticeScreenState extends ConsumerState<CbtPracticeScreen> {
  // Course curriculum list (dynamically enriched from backend academic resources)
  List<_CbtCourse> _courses = [
    _CbtCourse(
      code: 'GST 111',
      title: 'Use of English',
      description: 'Concord, Lexis, Reading Comprehension & Figures of Speech',
      icon: Icons.menu_book_rounded,
      color: const Color(0xFF8B5CF6),
      level: '100',
    ),
    _CbtCourse(
      code: 'GST 112',
      title: 'Logic, Philosophy & Human Existence',
      description: 'Deductive vs Inductive reasoning, Fallacies & Epistemology',
      icon: Icons.psychology_rounded,
      color: const Color(0xFF3B82F6),
      level: '100',
    ),
    _CbtCourse(
      code: 'GST 211',
      title: 'Peace & Conflict Studies',
      description: 'Conflict dynamics, mediation, peace treaties & security',
      icon: Icons.handshake_rounded,
      color: const Color(0xFF10B981),
      level: '200',
    ),
    _CbtCourse(
      code: 'MTH 101',
      title: 'Elementary Mathematics I',
      description: 'Trigonometry, complex numbers, quadratic systems & calculus',
      icon: Icons.functions_rounded,
      color: const Color(0xFFF59E0B),
      level: '100',
    ),
    _CbtCourse(
      code: 'CHM 101',
      title: 'General Chemistry I',
      description: 'Stoichiometry, atomic models, periodic trends & chemical bonding',
      icon: Icons.science_rounded,
      color: const Color(0xFFEF4444),
      level: '100',
    ),
    _CbtCourse(
      code: 'PHY 101',
      title: 'General Physics I',
      description: 'Mechanics, kinematics, heat, and sound thermodynamics',
      icon: Icons.bolt_rounded,
      color: const Color(0xFF06B6D4),
      level: '100',
    ),
    _CbtCourse(
      code: 'CSC 201',
      title: 'Computer Programming I',
      description: 'Algorithms, structured programming, control flow & syntax',
      icon: Icons.code_rounded,
      color: const Color(0xFF6366F1),
      level: '200',
    ),
    _CbtCourse(
      code: 'LAW 101',
      title: 'Legal Method I',
      description: 'Judicial precedent, statutory interpretation & classification',
      icon: Icons.gavel_rounded,
      color: const Color(0xFFD97706),
      level: '100',
    ),
  ];

  _CbtCourse? _activeCourse;
  bool _isLoadingCourses = false;
  bool _isGeneratingExam = false;
  String _generationStatusText = '';

  bool _isExamActive = false;
  bool _isResultActive = false;

  int _selectedQuestionCount = 10;
  String _filterLevel = 'All';
  String _searchQuery = '';

  List<_CbtQuestion> _activeQuestions = [];
  int _currentQuestionIndex = 0;
  final Map<int, int> _selectedAnswers = {}; // questionIndex -> optionIndex
  final Set<int> _flaggedQuestions = {};
  int _secondsRemaining = 0;
  Timer? _examTimer;
  String _reviewFilter = 'all'; // all, wrong, correct

  @override
  void initState() {
    super.initState();
    _loadDynamicCourses();
  }

  Future<void> _loadDynamicCourses() async {
    setState(() => _isLoadingCourses = true);
    try {
      final repo = ref.read(resourceRepositoryProvider);
      final rawCourses = await repo.fetchCourses();
      if (rawCourses.isNotEmpty && mounted) {
        final existingCodes = _courses.map((c) => c.code.toUpperCase()).toSet();
        final List<_CbtCourse> fetched = [];

        for (final item in rawCourses) {
          final code = (item['code'] ?? '').toString().toUpperCase().trim();
          if (code.isNotEmpty && !existingCodes.contains(code)) {
            fetched.add(
              _CbtCourse(
                code: code,
                title: item['title'] ?? code,
                description: 'ABUAD Course Material & Assessment Questions',
                icon: Icons.school_rounded,
                color: const Color(0xFF4F46E5),
                level: (item['level'] ?? '100').toString(),
              ),
            );
          }
        }

        if (fetched.isNotEmpty) {
          setState(() {
            _courses = [..._courses, ...fetched];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading dynamic courses: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCourses = false);

      // If opened with pre-selected course from a resource card
      if (widget.initialCourseCode != null) {
        final match = _courses.firstWhere(
          (c) => c.code.toUpperCase() == widget.initialCourseCode!.toUpperCase(),
          orElse: () => _CbtCourse(
            code: widget.initialCourseCode!.toUpperCase(),
            title: widget.initialCourseCode!.toUpperCase(),
            description: 'Course study material',
            icon: Icons.school_rounded,
            color: const Color(0xFF4F46E5),
            level: '100',
          ),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _promptExamConfig(match, resourceId: widget.initialResourceId);
        });
      }
    }
  }

  void _promptExamConfig(_CbtCourse course, {String? resourceId}) {
    int selectedCount = 10;
    final topicController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: course.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(course.icon, color: course.color, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.code,
                              style: GoogleFonts.robotoMono(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: course.color,
                              ),
                            ),
                            Text(
                              course.title,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Select Number of Questions',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [10, 20, 40, 60].map((count) {
                      final isSel = selectedCount == count;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () => setModalState(() => selectedCount = count),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? const Color(0xFF4F46E5)
                                    : (isDark ? Colors.black26 : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSel ? const Color(0xFF4F46E5) : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '$count',
                                    style: GoogleFonts.robotoMono(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                  Text(
                                    'Questions',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isSel ? Colors.white70 : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Focus Topic (Optional)',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: topicController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Concord, Thermodynamics, Calculus (or Leave blank for full course)',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      filled: true,
                      fillColor: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _generateAndStartExam(
                          course,
                          count: selectedCount,
                          topic: topicController.text.trim(),
                          resourceId: resourceId,
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Generate $selectedCount Questions with Dual AI',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _generateAndStartExam(
    _CbtCourse course, {
    required int count,
    String? topic,
    String? resourceId,
  }) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _activeCourse = course;
      _selectedQuestionCount = count;
      _isGeneratingExam = true;
      _generationStatusText = 'Gemini & Cloudflare AI synthesizing ${course.code} questions...';
    });

    try {
      final response = await ApiClient.post('/ai/cbt-generate', {
        'courseCode': course.code,
        'courseTitle': course.title,
        'questionCount': count,
        if (topic != null && topic.isNotEmpty) 'topic': topic,
        if (resourceId != null && resourceId.isNotEmpty) 'resourceId': resourceId,
      });

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['success'] == true && resData['data'] != null) {
          final qList = resData['data']['questions'] as List? ?? [];
          final List<_CbtQuestion> parsed = [];

          for (final raw in qList) {
            final opts = (raw['options'] as List?)?.map((e) => e.toString()).toList() ?? [];
            if (opts.length >= 2) {
              parsed.add(
                _CbtQuestion(
                  question: raw['question'] ?? 'Question',
                  options: opts,
                  correctIndex: int.tryParse(raw['correctIndex']?.toString() ?? '0') ?? 0,
                  explanation: raw['explanation'] ?? '',
                ),
              );
            }
          }

          if (parsed.isNotEmpty) {
            setState(() {
              _activeQuestions = parsed;
              _isGeneratingExam = false;
              _isExamActive = true;
              _isResultActive = false;
              _currentQuestionIndex = 0;
              _selectedAnswers.clear();
              _flaggedQuestions.clear();
              // 1 minute per question allocation
              _secondsRemaining = parsed.length * 60;
            });

            _startTimer();
            return;
          }
        }
      }

      throw Exception('Failed to generate verified questions');
    } catch (err) {
      debugPrint('Error generating questions: $err');
      if (mounted) {
        setState(() => _isGeneratingExam = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI Generation issue: $err. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _startTimer() {
    _examTimer?.cancel();
    _examTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
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

  void _confirmSubmitExam() {
    final unanswered = _activeQuestions.length - _selectedAnswers.length;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Submit CBT Examination?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Text(
            unanswered > 0
                ? 'You have $unanswered unanswered question${unanswered > 1 ? 's' : ''}. Are you sure you want to submit now?'
                : 'You have answered all ${_activeQuestions.length} questions. Submit for instant AI grading?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Continue Test'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _finishExam();
              },
              child: const Text('Submit Now'),
            ),
          ],
        );
      },
    );
  }

  int get _score {
    int count = 0;
    for (int i = 0; i < _activeQuestions.length; i++) {
      if (_selectedAnswers[i] == _activeQuestions[i].correctIndex) {
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
              ? '${_activeCourse?.code} CBT Exam'
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
                  color: _secondsRemaining < 300
                      ? Colors.redAccent.withValues(alpha: 0.2)
                      : const Color(0xFF4F46E5).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _secondsRemaining < 300 ? Colors.redAccent : const Color(0xFF4F46E5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_rounded,
                      size: 14,
                      color: _secondsRemaining < 300 ? Colors.redAccent : const Color(0xFF4F46E5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTimer(_secondsRemaining),
                      style: GoogleFonts.robotoMono(
                        color: _secondsRemaining < 300 ? Colors.redAccent : const Color(0xFF4F46E5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: _isGeneratingExam
          ? _buildGeneratingView(isDark)
          : (_isExamActive
              ? _buildActiveExamView(isDark)
              : (_isResultActive ? _buildResultsView(isDark) : _buildCourseSelectionView(isDark))),
    );
  }

  // ── 0. AI Question Synthesis View ──────────────────────────────────────────

  Widget _buildGeneratingView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 28),
            Text(
              'Dual AI Examination Engine',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _generationStatusText,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gemini 3 Flash & Cloudflare Llama-3.3 70B generating $_selectedQuestionCount verified curriculum questions...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }

  // ── 1. Course Selection View ──────────────────────────────────────────────

  Widget _buildCourseSelectionView(bool isDark) {
    final filtered = _courses.where((c) {
      final matchesLevel = _filterLevel == 'All' || c.level == _filterLevel;
      final matchesSearch = _searchQuery.isEmpty ||
          c.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.title.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesLevel && matchesSearch;
    }).toList();

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
                  'DUAL AI CBT ENGINE • GEMINI & CLOUDFLARE',
                  style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'University-Wide CBT Mock Tests',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Practice authentic tests from 10 up to 60 questions with real timing, verified answers, and instant AI explanations.',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Search Bar
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: 'Search courses by code or name...',
              hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Level Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', '100', '200', '300', '400', '500'].map((lvl) {
              final isSel = _filterLevel == lvl;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(lvl == 'All' ? 'All Levels' : '${lvl}L'),
                  selected: isSel,
                  onSelected: (val) => setState(() => _filterLevel = lvl),
                  selectedColor: const Color(0xFF4F46E5),
                  labelStyle: TextStyle(
                    color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12.5,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select a Course to Start',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (_isLoadingCourses)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: 12),

        if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No courses found matching your search.',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ),
          )
        else
          ...filtered.map((course) => _buildCourseCard(course, isDark)),
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
          onTap: () => _promptExamConfig(course),
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
                            '· ${course.level}L',
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
    if (_activeQuestions.isEmpty) {
      return const Center(child: Text('No questions available'));
    }

    final q = _activeQuestions[_currentQuestionIndex];
    final selectedOption = _selectedAnswers[_currentQuestionIndex];
    final isFlagged = _flaggedQuestions.contains(_currentQuestionIndex);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Question Progress Navigator (Horizontal Jump Palette)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_activeQuestions.length, (index) {
                final isCurrent = index == _currentQuestionIndex;
                final isAnswered = _selectedAnswers.containsKey(index);
                final flagged = _flaggedQuestions.contains(index);

                Color bgColor;
                if (isCurrent) {
                  bgColor = const Color(0xFF4F46E5);
                } else if (flagged) {
                  bgColor = const Color(0xFFF59E0B);
                } else if (isAnswered) {
                  bgColor = const Color(0xFF10B981);
                } else {
                  bgColor = isDark ? Colors.black26 : const Color(0xFFE2E8F0);
                }

                return GestureDetector(
                  onTap: () => setState(() => _currentQuestionIndex = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.robotoMono(
                          fontWeight: FontWeight.bold,
                          color: (isCurrent || isAnswered || flagged) ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'QUESTION ${_currentQuestionIndex + 1} OF ${_activeQuestions.length}',
                      style: GoogleFonts.robotoMono(
                        fontSize: 11.5,
                        color: const Color(0xFF4F46E5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isFlagged) {
                            _flaggedQuestions.remove(_currentQuestionIndex);
                          } else {
                            _flaggedQuestions.add(_currentQuestionIndex);
                          }
                        });
                      },
                      child: Row(
                        children: [
                          Icon(
                            isFlagged ? Icons.flag_rounded : Icons.outlined_flag_rounded,
                            size: 16,
                            color: isFlagged ? const Color(0xFFF59E0B) : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isFlagged ? 'Flagged' : 'Flag for review',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isFlagged ? const Color(0xFFF59E0B) : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  q.question,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

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
                          ? const Color(0xFF4F46E5).withValues(alpha: 0.16)
                          : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF4F46E5) : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
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
                            color: isSelected ? const Color(0xFF4F46E5) : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
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
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Navigation Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentQuestionIndex > 0)
                OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Previous'),
                  onPressed: () => setState(() => _currentQuestionIndex--),
                )
              else
                const SizedBox.shrink(),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _confirmSubmitExam,
                    child: const Text('Submit'),
                  ),
                  const SizedBox(width: 10),
                  if (_currentQuestionIndex < _activeQuestions.length - 1)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('Next'),
                      onPressed: () => setState(() => _currentQuestionIndex++),
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _confirmSubmitExam,
                      child: const Text('Finish Test'),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 3. Results & Review View ──────────────────────────────────────────────

  Widget _buildResultsView(bool isDark) {
    final score = _score;
    final total = _activeQuestions.length;
    final percent = total > 0 ? (score / total) * 100 : 0.0;
    final passed = percent >= 50;

    String grade = 'F';
    if (percent >= 70) {
      grade = 'A';
    } else if (percent >= 60) {
      grade = 'B';
    } else if (percent >= 50) {
      grade = 'C';
    } else if (percent >= 45) {
      grade = 'D';
    }

    final filteredList = _activeQuestions.asMap().entries.where((entry) {
      final userAns = _selectedAnswers[entry.key];
      final isCorrect = userAns == entry.value.correctIndex;
      if (_reviewFilter == 'wrong') return !isCorrect;
      if (_reviewFilter == 'correct') return isCorrect;
      return true;
    }).toList();

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
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${percent.toStringAsFixed(0)}%',
                    style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Grade: $grade',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                passed ? 'Exam Passed! Excellent Work' : 'Keep Practicing to Boost Your Score',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'You answered $score out of $total questions correctly in ${_activeCourse?.code}.',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Review Filter Tabs
        Row(
          children: [
            _buildReviewFilterChip('all', 'All ($total)', isDark),
            const SizedBox(width: 8),
            _buildReviewFilterChip('wrong', 'Incorrect (${total - score})', isDark),
            const SizedBox(width: 8),
            _buildReviewFilterChip('correct', 'Correct ($score)', isDark),
          ],
        ),
        const SizedBox(height: 16),

        Text(
          'Answers & Verified AI Explanations',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),

        ...filteredList.map((entry) {
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: isCorrect ? const Color(0xFF10B981) : Colors.redAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Question ${idx + 1}',
                          style: GoogleFonts.robotoMono(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    if (userAns != null)
                      Text(
                        'Your Answer: Option ${['A', 'B', 'C', 'D'][userAns]}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isCorrect ? const Color(0xFF10B981) : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      const Text(
                        'Unanswered',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  question.question,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'Correct Answer: Option ${['A', 'B', 'C', 'D'][question.correctIndex]} — ${question.options[question.correctIndex]}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (question.explanation.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '💡 ${question.explanation}',
                      style: GoogleFonts.inter(fontSize: 12.5, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),

        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => setState(() => _isResultActive = false),
                child: const Text('Back to Courses'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  if (_activeCourse != null) {
                    _generateAndStartExam(_activeCourse!, count: _selectedQuestionCount);
                  }
                },
                child: const Text('Retake Test'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewFilterChip(String key, String label, bool isDark) {
    final isSel = _reviewFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      onSelected: (val) => setState(() => _reviewFilter = key),
      selectedColor: const Color(0xFF4F46E5),
      labelStyle: TextStyle(
        color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }
}

class _CbtCourse {
  final String code;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String level;

  _CbtCourse({
    required this.code,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.level,
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
