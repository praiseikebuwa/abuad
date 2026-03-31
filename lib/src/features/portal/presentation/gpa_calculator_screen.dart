import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/academic_repository.dart';

class GPACalculatorScreen extends ConsumerStatefulWidget {
  const GPACalculatorScreen({super.key});

  @override
  ConsumerState<GPACalculatorScreen> createState() =>
      _GPACalculatorScreenState();
}

class _GPACalculatorScreenState extends ConsumerState<GPACalculatorScreen> {
  final List<Map<String, dynamic>> _courses = [
    {'name': '', 'units': 3, 'grade': 'A'},
  ];
  final _semesterController = TextEditingController(
    text: '2023/2024 First Semester',
  );
  double _gpa = 0.0;
  bool _isSaving = false;

  void _addCourse() {
    setState(() {
      _courses.add({'name': '', 'units': 3, 'grade': 'A'});
    });
  }

  void _removeCourse(int index) {
    setState(() {
      _courses.removeAt(index);
    });
  }

  void _calculateGPA() {
    if (_courses.isEmpty) return;

    final gradePoints = {
      'A': 5.0,
      'B': 4.0,
      'C': 3.0,
      'D': 2.0,
      'E': 1.0,
      'F': 0.0,
    };
    double totalPoints = 0;
    int totalUnits = 0;

    for (var course in _courses) {
      final units = course['units'] as int;
      final grade = course['grade'] as String;
      totalPoints += (gradePoints[grade] ?? 0) * units;
      totalUnits += units;
    }

    setState(() {
      _gpa = totalUnits > 0 ? totalPoints / totalUnits : 0.0;
    });
  }

  Future<void> _saveResult() async {
    if (_gpa == 0) _calculateGPA();
    if (_gpa == 0) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(academicRepositoryProvider)
          .saveGPAResult(
            semester: _semesterController.text,
            gpa: _gpa,
            courses: _courses,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Result saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving result: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GPA Calculator'),
        actions: [
          if (_gpa > 0)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              onPressed: _isSaving ? null : _saveResult,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _semesterController,
              decoration: const InputDecoration(
                labelText: 'Semester',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
            ),
          ),
          if (_gpa > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: theme.primaryColor.withOpacity(0.1),
              child: Column(
                children: [
                  const Text('Calculated GPA', style: TextStyle(fontSize: 14)),
                  Text(
                    _gpa.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _courses.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.primaryColor.withOpacity(0.1),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(flex: 2, child: Text('Course Units:')),
                        DropdownButton<int>(
                          value: _courses[index]['units'],
                          items: [1, 2, 3, 4, 5, 6].map((units) {
                            return DropdownMenuItem(
                              value: units,
                              child: Text('$units U'),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => _courses[index]['units'] = value!),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Grade:')),
                        DropdownButton<String>(
                          value: _courses[index]['grade'],
                          items: ['A', 'B', 'C', 'D', 'E', 'F'].map((grade) {
                            return DropdownMenuItem(
                              value: grade,
                              child: Text(grade),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => _courses[index]['grade'] = value!),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _removeCourse(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _addCourse,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'calc',
            onPressed: _calculateGPA,
            label: const Text('Calculate'),
            icon: const Icon(Icons.calculate),
          ),
        ],
      ),
    );
  }
}
