import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/services/api_client.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'q': 'How do I create a post?',
        'a': 'Tap the "+" icon in the center of the bottom navigation bar.',
      },
      {
        'q': 'Can I post anonymously?',
        'a':
            'Yes, toggle the "Post Anonymously" switch in the post creation screen.',
      },
      {
        'q': 'How do I find shuttle routes?',
        'a': 'Go to the Utilities tab and select "Shuttle Tracker".',
      },
      {
        'q': 'How do I calculate my GPA?',
        'a': 'Go to the Portal tab and select "GPA Calculator".',
      },
      {
        'q': 'Where can I find exam timetables?',
        'a': 'Timetables are available in the Portal tab under "Timetable".',
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Help Center')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqs.length,
        itemBuilder: (context, index) {
          final faq = faqs[index];
          return ExpansionTile(
            title: Text(
              faq['q']!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(faq['a']!),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SupportFormScreen extends ConsumerStatefulWidget {
  final String title;
  final String type;
  const SupportFormScreen({super.key, required this.title, required this.type});

  @override
  ConsumerState<SupportFormScreen> createState() => _SupportFormScreenState();
}

class _SupportFormScreenState extends ConsumerState<SupportFormScreen> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      await ApiClient.post('/reports', {
        'userId': user?.uid,
        'userEmail': user?.email,
        'type': widget.type,
        'message': _controller.text.trim(),
        'status': 'open',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Submitted successfully! Thank you for your feedback.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 10,
              decoration: InputDecoration(
                hintText:
                    'Describe your ${widget.type == 'bug' ? 'issue' : 'feedback'} here...',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
