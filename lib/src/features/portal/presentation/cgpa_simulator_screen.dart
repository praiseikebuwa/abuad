import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class CgpaSimulatorScreen extends StatefulWidget {
  const CgpaSimulatorScreen({super.key});

  @override
  State<CgpaSimulatorScreen> createState() => _CgpaSimulatorScreenState();
}

class _CgpaSimulatorScreenState extends State<CgpaSimulatorScreen> {
  // Target honors
  final List<_HonorTier> _honorTiers = [
    _HonorTier(title: 'First Class', minCgpa: 4.50, maxCgpa: 5.00, icon: Icons.emoji_events_rounded, color: const Color(0xFFF59E0B)),
    _HonorTier(title: 'Second Class Upper (2:1)', minCgpa: 3.50, maxCgpa: 4.49, icon: Icons.military_tech_rounded, color: const Color(0xFF8B5CF6)),
    _HonorTier(title: 'Second Class Lower (2:2)', minCgpa: 2.40, maxCgpa: 3.49, icon: Icons.workspace_premium_rounded, color: const Color(0xFF3B82F6)),
    _HonorTier(title: 'Third Class', minCgpa: 1.50, maxCgpa: 2.39, icon: Icons.school_rounded, color: const Color(0xFF64748B)),
  ];

  late _HonorTier _selectedTarget;

  // Student standing inputs
  final TextEditingController _currentCgpaController = TextEditingController(text: '4.15');
  final TextEditingController _completedUnitsController = TextEditingController(text: '72');

  // Semester Courses Simulation
  final List<_SimulatedCourse> _simCourses = [
    _SimulatedCourse(code: 'GST 211', units: 2, grade: 'A'),
    _SimulatedCourse(code: 'ENG 201', units: 3, grade: 'A'),
    _SimulatedCourse(code: 'MTH 201', units: 3, grade: 'B'),
    _SimulatedCourse(code: 'EEE 203', units: 3, grade: 'A'),
    _SimulatedCourse(code: 'MEE 205', units: 2, grade: 'B'),
    _SimulatedCourse(code: 'CVE 201', units: 3, grade: 'A'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedTarget = _honorTiers.first; // First class target by default
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

  void _addCourse() {
    HapticFeedback.lightImpact();
    setState(() {
      _simCourses.add(
        _SimulatedCourse(code: 'CRS ${_simCourses.length + 1}', units: 2, grade: 'A'),
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
                Text(
                  'Your Current Academic Standing',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
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
