import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/report.dart';
import '../../data/report_repository.dart';

class ReportBottomSheet extends ConsumerStatefulWidget {
  final String targetId;
  final ReportType type;

  const ReportBottomSheet({
    super.key,
    required this.targetId,
    required this.type,
  });

  @override
  ConsumerState<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends ConsumerState<ReportBottomSheet> {
  ReportReason? _selectedReason;
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;

  final Map<ReportReason, String> _reasonLabels = {
    ReportReason.spam: 'Spam',
    ReportReason.harassment: 'Harassment',
    ReportReason.inappropriateContent: 'Inappropriate Content',
    ReportReason.hateSpeech: 'Hate Speech',
    ReportReason.misinformation: 'Misinformation',
    ReportReason.other: 'Other',
  };

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repo = ref.read(reportRepositoryProvider);

      switch (widget.type) {
        case ReportType.post:
          await repo.reportPost(
            postId: widget.targetId,
            reason: _selectedReason!,
            details: _detailsController.text.isNotEmpty
                ? _detailsController.text
                : null,
          );
          break;
        case ReportType.comment:
          await repo.reportComment(
            commentId: widget.targetId,
            reason: _selectedReason!,
            details: _detailsController.text.isNotEmpty
                ? _detailsController.text
                : null,
          );
          break;
        case ReportType.story:
          await repo.reportStory(
            storyId: widget.targetId,
            reason: _selectedReason!,
            details: _detailsController.text.isNotEmpty
                ? _detailsController.text
                : null,
          );
          break;
        case ReportType.user:
          await repo.reportUser(
            userId: widget.targetId,
            reason: _selectedReason!,
            details: _detailsController.text.isNotEmpty
                ? _detailsController.text
                : null,
          );
          break;
        case ReportType.message:
          await repo.reportMessage(
            messageId: widget.targetId,
            reason: _selectedReason!,
            details: _detailsController.text.isNotEmpty
                ? _detailsController.text
                : null,
          );
          break;
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for reporting. Our team will review it.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting report: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Report Content',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Why are you reporting this?',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          ...ReportReason.values.map((reason) {
            return RadioListTile<ReportReason>(
              title: Text(
                _reasonLabels[reason]!,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
              ),
              value: reason,
              groupValue: _selectedReason,
              onChanged: (value) {
                setState(() {
                  _selectedReason = value;
                });
              },
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFF8B5CF6),
            );
          }),
          const SizedBox(height: 12),
          TextField(
            controller: _detailsController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Additional details (optional)',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF2C2C2E)
                  : const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _selectedReason != null && !_isSubmitting
                  ? _submitReport
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit Report',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
      )
    );
  }
}
