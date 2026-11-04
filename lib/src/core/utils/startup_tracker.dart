import 'package:flutter/foundation.dart';

/// Lightweight startup performance tracker to measure and log
/// critical milestones from app launch to first frame and home screen.
class StartupTracker {
  StartupTracker._();
  static final StartupTracker instance = StartupTracker._();

  final Stopwatch _stopwatch = Stopwatch();
  final Map<String, int> _milestones = {};

  void start() {
    _stopwatch.start();
    _milestones['app_start'] = 0;
    debugPrint('⏱️ [StartupTracker] App startup clock started');
  }

  void mark(String milestone) {
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
    }
    final elapsedMs = _stopwatch.elapsedMilliseconds;
    _milestones[milestone] = elapsedMs;
    debugPrint('⏱️ [StartupTracker] Milestone [$milestone]: ${elapsedMs}ms');
  }

  int? getMilestone(String milestone) => _milestones[milestone];

  Map<String, int> getAllMilestones() => Map.unmodifiable(_milestones);

  void printSummary() {
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('🚀 ABUAD APP STARTUP PERFORMANCE REPORT');
    debugPrint('═══════════════════════════════════════════════════');
    _milestones.forEach((name, timeMs) {
      debugPrint('  • $name: ${timeMs}ms');
    });
    debugPrint('  Total Startup Time to Usable UI: ${_stopwatch.elapsedMilliseconds}ms');
    debugPrint('═══════════════════════════════════════════════════');
  }
}
