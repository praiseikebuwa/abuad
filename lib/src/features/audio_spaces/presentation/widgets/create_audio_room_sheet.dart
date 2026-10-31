import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/audio_room_controller.dart';
import '../live_audio_room_screen.dart';

class CreateAudioRoomSheet extends ConsumerStatefulWidget {
  const CreateAudioRoomSheet({super.key});

  @override
  ConsumerState<CreateAudioRoomSheet> createState() => _CreateAudioRoomSheetState();
}

class _CreateAudioRoomSheetState extends ConsumerState<CreateAudioRoomSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String _category = 'ACADEMIC';
  String _visibility = 'PUBLIC';
  String _speakersPermission = 'HOST_APPROVED';
  bool _isRecording = false;
  bool _isChatEnabled = true;
  bool _isSubmitting = false;

  final List<Map<String, String>> _categories = [
    {'id': 'ACADEMIC', 'label': 'Academic', 'icon': '🎓'},
    {'id': 'SOCIAL', 'label': 'Social', 'icon': '🔥'},
    {'id': 'DEBATE', 'label': 'Debate / SUG', 'icon': '⚖️'},
    {'id': 'COMMUNITY', 'label': 'Community', 'icon': '👥'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleStart() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room title')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(activeAudioRoomNotifierProvider.notifier).startRoom(
            title: title,
            description: _descController.text.trim(),
            category: _category,
            visibility: _visibility,
            speakersPermission: _speakersPermission,
            isRecording: _isRecording,
            isChatEnabled: _isChatEnabled,
          );

      if (mounted) {
        Navigator.of(context).pop();
        final room = ref.read(activeAudioRoomNotifierProvider).room;
        if (room != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LiveAudioRoomScreen(roomId: room.id),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start space: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 12,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF161622),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C4DFF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.podcasts_rounded, color: Color(0xFF7C4DFF), size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Start a Live Space',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Room Title Input
            const Text(
              'What do you want to talk about?',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'e.g. MTH 102 - Integration Exam Prep 🔥',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 15),
                filled: true,
                fillColor: const Color(0xFF222232),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Add an optional description or agenda...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF222232),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Category Selection
            const Text(
              'Select Category',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((c) {
                final isSelected = _category == c['id'];
                return ChoiceChip(
                  avatar: Text(c['icon']!),
                  label: Text(c['label']!),
                  selected: isSelected,
                  selectedColor: const Color(0xFF7C4DFF),
                  backgroundColor: const Color(0xFF222232),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _category = c['id']!);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Speaker Permission Selector
            const Text(
              'Who can speak?',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _speakersPermission = 'HOST_APPROVED'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(
                        color: _speakersPermission == 'HOST_APPROVED'
                            ? const Color(0xFF7C4DFF).withOpacity(0.25)
                            : const Color(0xFF222232),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _speakersPermission == 'HOST_APPROVED'
                              ? const Color(0xFF7C4DFF)
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.approval_rounded,
                            color: _speakersPermission == 'HOST_APPROVED'
                                ? const Color(0xFF7C4DFF)
                                : Colors.white60,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Host Approved',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Listeners raise hand',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _speakersPermission = 'EVERYONE'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(
                        color: _speakersPermission == 'EVERYONE'
                            ? const Color(0xFF7C4DFF).withOpacity(0.25)
                            : const Color(0xFF222232),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _speakersPermission == 'EVERYONE'
                              ? const Color(0xFF7C4DFF)
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.groups_rounded,
                            color: _speakersPermission == 'EVERYONE'
                                ? const Color(0xFF7C4DFF)
                                : Colors.white60,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Open Mic',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Anyone can speak',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Toggles (Recording & Chat)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF222232),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Enable In-Space Chat', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text('Allow text messages while listening', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                    value: _isChatEnabled,
                    activeColor: const Color(0xFF7C4DFF),
                    onChanged: (val) => setState(() => _isChatEnabled = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  SwitchListTile(
                    title: const Text('Record this Session', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text('Save audio replay for students who missed it', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                    value: _isRecording,
                    activeColor: const Color(0xFF7C4DFF),
                    onChanged: (val) => setState(() => _isRecording = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Start Live Space Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  elevation: 8,
                ),
                onPressed: _isSubmitting ? null : _handleStart,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mic_rounded, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Go Live Now',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

