import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/academic_repository.dart';

class CgpaSimulatorScreen extends ConsumerStatefulWidget {
  const CgpaSimulatorScreen({super.key});

  @override
  ConsumerState<CgpaSimulatorScreen> createState() => _CgpaSimulatorScreenState();
}

class _CgpaSimulatorScreenState extends ConsumerState<CgpaSimulatorScreen> {
  // Target honors
  final List<_HonorTier> _honorTiers = [
    _HonorTier(title: 'First Class', minCgpa: 4.50, maxCgpa: 5.00, icon: Icons.emoji_events_rounded, color: const Color(0xFFF59E0B)),
    _HonorTier(title: 'Second Class Upper (2:1)', minCgpa: 3.50, maxCgpa: 4.49, icon: Icons.military_tech_rounded, color: const Color(0xFF8B5CF6)),
    _HonorTier(title: 'Second Class Lower (2:2)', minCgpa: 2.40, maxCgpa: 3.49, icon: Icons.workspace_premium_rounded, color: const Color(0xFF3B82F6)),
    _HonorTier(title: 'Third Class', minCgpa: 1.50, maxCgpa: 2.39, icon: Icons.school_rounded, color: const Color(0xFF64748B)),
  ];

  late _HonorTier _selectedTarget;

  // Student standing inputs
  final TextEditingController _currentCgpaController = TextEditingController(text: '4.82');
  final TextEditingController _completedUnitsController = TextEditingController(text: '42');

  // Semester Courses Simulation
  final List<_SimulatedCourse> _simCourses = [
    _SimulatedCourse(code: 'CSC 201', units: 3, grade: 'A'),
    _SimulatedCourse(code: 'CSC 203', units: 3, grade: 'A'),
    _SimulatedCourse(code: 'MTH 201', units: 3, grade: 'A'),
    _SimulatedCourse(code: 'GST 211', units: 2, grade: 'A'),
    _SimulatedCourse(code: 'PHY 201', units: 3, grade: 'B'),
    _SimulatedCourse(code: 'CSC 205', units: 2, grade: 'A'),
  ];

  bool _isLoadedFromPortal = false;
  String _portalStudentName = '';

  @override
  void initState() {
    super.initState();
    _selectedTarget = _honorTiers.first; // First class target by default
    _loadPortalBaseline();
  }

  Future<void> _loadPortalBaseline() async {
    try {
      final repo = ref.read(academicRepositoryProvider);
      final profile = await repo.getStudentIdProfile();
      final cumulativeGpa = await repo.getCumulativeGpa();

      final portalCgpaStr = profile['cgpa'];
      final portalGpaStr = profile['gpa'];
      final name = profile['fullName'] ?? '';

      double baselineCgpa = 4.82;
      if (portalCgpaStr != null && double.tryParse(portalCgpaStr) != null) {
        baselineCgpa = double.parse(portalCgpaStr);
      } else if (portalGpaStr != null && double.tryParse(portalGpaStr) != null) {
        baselineCgpa = double.parse(portalGpaStr);
      } else if (cumulativeGpa > 0) {
        baselineCgpa = cumulativeGpa;
      }

      final levelStr = profile['level'] ?? '200 Level';
      int units = 42;
      if (levelStr.contains('100')) units = 20;
      if (levelStr.contains('200')) units = 42;
      if (levelStr.contains('300')) units = 74;
      if (levelStr.contains('400')) units = 108;
      if (levelStr.contains('500')) units = 142;

      if (mounted) {
        setState(() {
          _currentCgpaController.text = baselineCgpa.toStringAsFixed(2);
          _completedUnitsController.text = units.toString();
          _isLoadedFromPortal = true;
          _portalStudentName = name;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _currentCgpaController.dispose();
    _completedUnitsController.dispose();
    super.dispose();
  }

  double _gradePoint(String grade) {
    switch (grade) {
      case 'A':
        return 5.0;
      case 'B':
        return 4.0;
      case 'C':
        return 3.0;
      case 'D':
        return 2.0;
      case 'E':
        return 1.0;
      case 'F':
      default:
        return 0.0;
    }
  }

  // Calculate Semester GPA
  double get _simulatedSemesterGpa {
    int totalUnits = 0;
    double totalPoints = 0;
    for (final c in _simCourses) {
      totalUnits += c.units;
      totalPoints += c.units * _gradePoint(c.grade);
    }
    if (totalUnits == 0) return 0.0;
    return totalPoints / totalUnits;
  }

  int get _simulatedSemesterUnits {
    return _simCourses.fold<int>(0, (sum, c) => sum + c.units);
  }

  // Calculate Projected Cumulative GPA
  double get _projectedCgpa {
    final currentCgpa = double.tryParse(_currentCgpaController.text.trim()) ?? 0.0;
    final completedUnits = int.tryParse(_completedUnitsController.text.trim()) ?? 0;

    final currentTotalPoints = currentCgpa * completedUnits;
    final semUnits = _simulatedSemesterUnits;
    final semPoints = _simulatedSemesterGpa * semUnits;

    final newTotalUnits = completedUnits + semUnits;
    if (newTotalUnits == 0) return currentCgpa;

    return (currentTotalPoints + semPoints) / newTotalUnits;
  }

  // Algorithmic computation: Minimum semester GPA needed to reach target
  double get _minGpaRequiredToHitTarget {
    final target = _selectedTarget.minCgpa;
    final currentCgpa = double.tryParse(_currentCgpaController.text.trim()) ?? 0.0;
    final completedUnits = int.tryParse(_completedUnitsController.text.trim()) ?? 0;
    final semUnits = _simulatedSemesterUnits;
    if (semUnits == 0) return 0.0;

    final targetTotalPoints = target * (completedUnits + semUnits);
    final currentPoints = currentCgpa * completedUnits;
    final neededSemPoints = targetTotalPoints - currentPoints;
    final neededGpa = neededSemPoints / semUnits;

    return neededGpa.clamp(0.0, 5.0);
  }

  // Algorithmic computation: Safety margin index (0% to 100%)
  int get _degreeSafetyIndex {
    final projected = _projectedCgpa;
    final target = _selectedTarget.minCgpa;
    if (projected >= target) {
      final surplus = (projected - target);
      return (85 + (surplus * 30)).clamp(85, 99).toInt();
    } else {
      final deficit = (target - projected);
      return (80 - (deficit * 40)).clamp(25, 79).toInt();
    }
  }

  void _addCourse() {
    HapticFeedback.lightImpact();
    setState(() {
      _simCourses.add(
        _SimulatedCourse(code: 'CSC ${_simCourses.length + 201}', units: 2, grade: 'A'),
      );
    });
  }

  void _removeCourse(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _simCourses.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projected = _projectedCgpa;
    final hitsTarget = projected >= _selectedTarget.minCgpa;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'CGPA Target Simulator',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Target Graduating Honors Selector
          Text(
            'Target Graduating Honor',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _honorTiers.map((tier) {
                final isSelected = _selectedTarget == tier;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedTarget = tier);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? tier.color.withValues(alpha: 0.2)
                          : (isDark ? Colors.black : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? tier.color : (isDark ? Colors.white10 : const Color(0xFFCBD5E1)),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(tier.icon, color: tier.color, size: 18),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tier.title,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              '${tier.minCgpa.toStringAsFixed(2)} - ${tier.maxCgpa.toStringAsFixed(2)}',
                              style: GoogleFonts.robotoMono(fontSize: 10, color: tier.color, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // Current Standing Inputs
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
                      'Your Current Academic Standing',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    if (_isLoadedFromPortal)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            Text(
                              'Portal Baseline',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current CGPA', style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _currentCgpaController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: GoogleFonts.robotoMono(fontWeight: FontWeight.bold, fontSize: 18),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Completed Units', style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _completedUnitsController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.robotoMono(fontWeight: FontWeight.bold, fontSize: 18),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // AI Predictive Degree Algorithm Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF090D16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.psychology_rounded, color: Color(0xFFA78BFA), size: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Degree Forecast Algorithm',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: const Color(0xFFA78BFA),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Gemini Heuristic Engine',
                        style: GoogleFonts.robotoMono(fontSize: 9.5, color: const Color(0xFFA78BFA)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Minimum Target GPA',
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.white60),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _minGpaRequiredToHitTarget.toStringAsFixed(2),
                              style: GoogleFonts.robotoMono(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _minGpaRequiredToHitTarget <= 5.0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                              ),
                            ),
                            Text(
                              _minGpaRequiredToHitTarget <= 5.0 ? 'Achievable this semester' : 'Requires multi-semester plan',
                              style: GoogleFonts.inter(fontSize: 9.5, color: Colors.white38),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Degree Safety Index',
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.white60),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_degreeSafetyIndex%',
                              style: GoogleFonts.robotoMono(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _degreeSafetyIndex >= 85 ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                              ),
                            ),
                            Text(
                              _degreeSafetyIndex >= 85 ? 'High First Class buffer' : 'Moderate margin zone',
                              style: GoogleFonts.inter(fontSize: 9.5, color: Colors.white38),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  hitsTarget
                      ? '💡 Algorithmic Insight: Your current simulation yields ${projected.toStringAsFixed(2)} CGPA, safely hitting ${_selectedTarget.title}. Keep at least 4 courses with "A" grades to protect this standing against unexpected exam variances.'
                      : '⚠️ Algorithmic Insight: To guarantee ${_selectedTarget.title} (${_selectedTarget.minCgpa.toStringAsFixed(2)}+), the algorithm computes that your semester GPA must reach ${_minGpaRequiredToHitTarget.toStringAsFixed(2)}. Convert more "B" grades into "A"s below.',
                  style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Projected Result Hero Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hitsTarget
                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                    : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (hitsTarget ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.35),
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
                    Text(
                      'SIMULATION OUTCOME',
                      style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Icon(
                      hitsTarget ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      projected.toStringAsFixed(2),
                      style: GoogleFonts.robotoMono(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hitsTarget ? 'Target Achieved! 🎉' : 'Needs Grade Adjustment',
                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                          ),
                          Text(
                            hitsTarget
                                ? 'Your simulated grades will hit your ${_selectedTarget.title} target.'
                                : 'Adjust more courses to "A" to reach ${_selectedTarget.minCgpa.toStringAsFixed(2)}.',
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Simulated Semester GPA: ${_simulatedSemesterGpa.toStringAsFixed(2)}',
                      style: GoogleFonts.robotoMono(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      '$_simulatedSemesterUnits Credit Units',
                      style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Course Grade Simulator Table
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Registered Semester Courses',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('Add Course'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF8B5CF6)),
                onPressed: _addCourse,
              ),
            ],
          ),
          const SizedBox(height: 8),

          ..._simCourses.asMap().entries.map((entry) {
            final i = entry.key;
            final course = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      course.code,
                      style: GoogleFonts.robotoMono(fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6), fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${course.units} Units',
                    style: GoogleFonts.inter(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12),
                  ),
                  const Spacer(),

                  // Grade selector chips
                  Row(
                    children: ['A', 'B', 'C', 'D', 'E', 'F'].map((g) {
                      final isSelected = course.grade == g;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => course.grade = g);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (g == 'A'
                                    ? const Color(0xFF10B981)
                                    : (g == 'B' ? const Color(0xFF3B82F6) : const Color(0xFF64748B)))
                                : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            g,
                            style: GoogleFonts.robotoMono(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white38),
                    onPressed: () => _removeCourse(i),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _HonorTier {
  final String title;
  final double minCgpa;
  final double maxCgpa;
  final IconData icon;
  final Color color;

  _HonorTier({
    required this.title,
    required this.minCgpa,
    required this.maxCgpa,
    required this.icon,
    required this.color,
  });
}

class _SimulatedCourse {
  String code;
  int units;
  String grade;

  _SimulatedCourse({required this.code, required this.units, required this.grade});
}
