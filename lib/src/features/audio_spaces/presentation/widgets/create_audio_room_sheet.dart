import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../controllers/audio_room_controller.dart';
import '../live_audio_room_screen.dart';
import '../../../chat/data/chat_repository.dart';
import '../../../chat/domain/chat_channel.dart';
import '../../../user/data/user_repository.dart';

class CreateAudioRoomSheet extends ConsumerStatefulWidget {
  const CreateAudioRoomSheet({super.key});

  @override
  ConsumerState<CreateAudioRoomSheet> createState() => _CreateAudioRoomSheetState();
}

class _CreateAudioRoomSheetState extends ConsumerState<CreateAudioRoomSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _customTagController = TextEditingController();

  String _category = 'ACADEMIC';
  String _visibility = 'PUBLIC';
  String _speakersPermission = 'HOST_APPROVED';
  bool _isRecording = false;
  bool _isChatEnabled = true;
  bool _isScheduled = false;
  DateTime? _scheduledDateTime;
  bool _isSubmitting = false;

  // Tagged campus groups & users
  final List<ChatChannel> _selectedGroups = [];
  final List<AppUser> _selectedUsers = [];

  // Hashtags
  final Set<String> _selectedTags = {'#CampusGist'};
  final List<String> _presetTags = [
    '#ExamPrep',
    '#Tutorial',
    '#CampusGist',
    '#SUG',
    '#Coding',
    '#LifeAtABUAD',
    '#Sports',
    '#Music',
    '#LawTownHall',
    '#Freshers',
  ];

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
    _customTagController.dispose();
    super.dispose();
  }

  Future<void> _pickScheduledDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF7C4DFF),
              surface: Color(0xFF1E1E2E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF7C4DFF),
              surface: Color(0xFF1E1E2E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (time == null || !mounted) return;

    setState(() {
      _scheduledDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _showGroupPickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _GroupPickerSheet(
          initiallySelected: _selectedGroups,
          onGroupsSelected: (groups) {
            setState(() {
              _selectedGroups.clear();
              _selectedGroups.addAll(groups);
            });
          },
        );
      },
    );
  }

  void _showUserPickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _UserPickerSheet(
          initiallySelected: _selectedUsers,
          onUsersSelected: (users) {
            setState(() {
              _selectedUsers.clear();
              _selectedUsers.addAll(users);
            });
          },
        );
      },
    );
  }

  void _addCustomTag() {
    final text = _customTagController.text.trim();
    if (text.isEmpty) return;
    final tag = text.startsWith('#') ? text : '#$text';
    setState(() {
      _selectedTags.add(tag);
      _customTagController.clear();
    });
  }

  Future<void> _handleStart() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room title')),
      );
      return;
    }

    if (_isScheduled && _scheduledDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time for your space')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final room = await ref.read(activeAudioRoomNotifierProvider.notifier).startRoom(
            title: title,
            description: _descController.text.trim(),
            category: _category,
            visibility: _visibility,
            speakersPermission: _speakersPermission,
            isRecording: _isRecording,
            isChatEnabled: _isChatEnabled,
            scheduledAt: _isScheduled ? _scheduledDateTime : null,
            taggedGroupIds: _selectedGroups.map((g) => g.id).toList(),
            taggedUserIds: _selectedUsers.map((u) => u.uid).toList(),
            tags: _selectedTags.toList(),
          );

      if (mounted) {
        Navigator.of(context).pop();

        if (_isScheduled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Live Space scheduled for ${DateFormat('MMM d, h:mm a').format(_scheduledDateTime!)}! Invites sent 📢',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E1E2E),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
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
      height: MediaQuery.of(context).size.height * 0.90,
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
      child: Column(
        children: [
          // Drag Handle
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
          const SizedBox(height: 14),

          // Header Bar
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create Live Space',
                    style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Campus Audio Rooms with Live Activities',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Scrollable Configuration Form
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Space Timing Mode (Live Now vs Schedule)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222232),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isScheduled = false),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isScheduled ? const Color(0xFF7C4DFF) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.fiber_manual_record_rounded,
                                    size: 14,
                                    color: !_isScheduled ? Colors.redAccent : Colors.white54,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Go Live Now',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: !_isScheduled ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() => _isScheduled = true);
                              if (_scheduledDateTime == null) {
                                _pickScheduledDateTime();
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isScheduled ? const Color(0xFF7C4DFF) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 14,
                                    color: _isScheduled ? Colors.white : Colors.white54,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Schedule for Later',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: _isScheduled ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Scheduled DateTime Picker Tile
                  if (_isScheduled) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickScheduledDateTime,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF222232),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_filled_rounded, color: Color(0xFF7C4DFF), size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Scheduled Date & Time',
                                    style: TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                  Text(
                                    _scheduledDateTime != null
                                        ? DateFormat('EEEE, MMM d · h:mm a').format(_scheduledDateTime!)
                                        : 'Tap to pick date & time',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Room Title Input
                  const Text(
                    'What do you want to talk about?',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'e.g. MTH 102 - Integration Exam Prep 🔥',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFF222232),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextField(
                    controller: _descController,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Add an optional agenda or speakers list...',
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
                  const SizedBox(height: 18),

                  // Tag Campus Groups 🏛️
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.groups_3_rounded, color: Color(0xFF38BDF8), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Tag Campus Groups (${_selectedGroups.length})',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          backgroundColor: const Color(0xFF38BDF8).withOpacity(0.12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _showGroupPickerSheet,
                        icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF38BDF8)),
                        label: const Text(
                          'Add Group',
                          style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Members of tagged groups get Live Activity & lock screen alerts to join',
                    style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedGroups.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _selectedGroups.map((group) {
                        return Chip(
                          backgroundColor: const Color(0xFF222232),
                          side: const BorderSide(color: Color(0xFF38BDF8), width: 0.8),
                          avatar: const Icon(Icons.groups_rounded, size: 16, color: Color(0xFF38BDF8)),
                          label: Text(
                            group.displayName ?? 'Campus Group',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
                          onDeleted: () {
                            setState(() => _selectedGroups.remove(group));
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),

                  // Tag People / Friends / Co-hosts 👥
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFFF43F5E), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Tag People (${_selectedUsers.length})',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          backgroundColor: const Color(0xFFF43F5E).withOpacity(0.12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _showUserPickerSheet,
                        icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFFF43F5E)),
                        label: const Text(
                          'Tag Person',
                          style: TextStyle(color: Color(0xFFF43F5E), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Tagged friends receive Dynamic Island & Live Activities notifications to drop in',
                    style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedUsers.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _selectedUsers.map((user) {
                        return Chip(
                          backgroundColor: const Color(0xFF222232),
                          side: const BorderSide(color: Color(0xFFF43F5E), width: 0.8),
                          avatar: CircleAvatar(
                            radius: 10,
                            backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                            child: user.avatarUrl == null
                                ? Text(user.displayName.isNotEmpty ? user.displayName[0] : 'U', style: const TextStyle(fontSize: 9))
                                : null,
                          ),
                          label: Text(
                            '@${user.handle}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
                          onDeleted: () {
                            setState(() => _selectedUsers.remove(user));
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),

                  // Category Selection
                  const Text(
                    'Select Category',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
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
                          fontSize: 12.5,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _category = c['id']!);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Hashtags / Topic Tags 🏷️
                  const Text(
                    'Topics & Hashtags',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _presetTags.map((tag) {
                      final isSelected = _selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(tag),
                        selected: isSelected,
                        selectedColor: const Color(0xFF7C4DFF).withOpacity(0.3),
                        checkmarkColor: const Color(0xFF7C4DFF),
                        backgroundColor: const Color(0xFF222232),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF7C4DFF) : Colors.transparent,
                        ),
                        labelStyle: TextStyle(
                          color: isSelected ? const Color(0xFF7C4DFF) : Colors.white70,
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.remove(tag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customTagController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Add custom hashtag (e.g. #FreshersDebate)',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF222232),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _addCustomTag(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF7C4DFF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                        onPressed: _addCustomTag,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Speaker Permission Selector
                  const Text(
                    'Who can speak?',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 18),

                  // Toggles (Recording & Chat)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222232),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Enable In-Space Chat', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                          subtitle: Text('Allow text messages while listening', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                          value: _isChatEnabled,
                          activeColor: const Color(0xFF7C4DFF),
                          onChanged: (val) => setState(() => _isChatEnabled = val),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const Divider(color: Colors.white10, height: 1),
                        SwitchListTile(
                          title: const Text('Record this Session', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                          subtitle: Text('Save audio replay for students who missed it', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                          value: _isRecording,
                          activeColor: const Color(0xFF7C4DFF),
                          onChanged: (val) => setState(() => _isRecording = val),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Action Button (Go Live Now or Schedule Space)
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
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isScheduled ? Icons.calendar_month_rounded : Icons.mic_rounded,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isScheduled ? 'Schedule Live Space' : 'Go Live Now',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campus Group Picker Bottom Sheet
class _GroupPickerSheet extends ConsumerStatefulWidget {
  final List<ChatChannel> initiallySelected;
  final ValueChanged<List<ChatChannel>> onGroupsSelected;

  const _GroupPickerSheet({
    required this.initiallySelected,
    required this.onGroupsSelected,
  });

  @override
  ConsumerState<_GroupPickerSheet> createState() => _GroupPickerSheetState();
}

class _GroupPickerSheetState extends ConsumerState<_GroupPickerSheet> {
  final List<ChatChannel> _selected = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initiallySelected);
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(chatChannelsProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF161622),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tag Campus Groups',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  widget.onGroupsSelected(_selected);
                  Navigator.of(context).pop();
                },
                child: const Text('Done', style: TextStyle(color: Color(0xFF7C4DFF), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (val) => setState(() => _search = val.trim().toLowerCase()),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search groups (e.g. Law, 200L, SUG)...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
              filled: true,
              fillColor: const Color(0xFF222232),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: channelsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.redAccent))),
              data: (channels) {
                final groups = channels.where((c) {
                  if (!c.isGroup) return false;
                  if (_search.isEmpty) return true;
                  return (c.displayName ?? '').toLowerCase().contains(_search);
                }).toList();

                if (groups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.groups_outlined, size: 48, color: Colors.white24),
                        const SizedBox(height: 8),
                        Text(
                          _search.isEmpty ? 'No campus groups joined yet' : 'No matching groups found',
                          style: TextStyle(color: Colors.white.withOpacity(0.5)),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (ctx, i) {
                    final group = groups[i];
                    final isChecked = _selected.any((g) => g.id == group.id);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF222232),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: CheckboxListTile(
                        value: isChecked,
                        activeColor: const Color(0xFF7C4DFF),
                        secondary: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C4DFF).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.groups_rounded, color: Color(0xFF7C4DFF), size: 20),
                        ),
                        title: Text(
                          group.displayName ?? 'Campus Group',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${group.memberIds.length} members · Live Activity invite',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                        ),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selected.add(group);
                            } else {
                              _selected.removeWhere((g) => g.id == group.id);
                            }
                          });
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// People / Student Tag Picker Bottom Sheet
class _UserPickerSheet extends ConsumerStatefulWidget {
  final List<AppUser> initiallySelected;
  final ValueChanged<List<AppUser>> onUsersSelected;

  const _UserPickerSheet({
    required this.initiallySelected,
    required this.onUsersSelected,
  });

  @override
  ConsumerState<_UserPickerSheet> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends ConsumerState<_UserPickerSheet> {
  final List<AppUser> _selected = [];
  final TextEditingController _searchController = TextEditingController();
  List<AppUser> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initiallySelected);
    _performSearch('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final results = await userRepo.searchUsers(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF161622),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tag Students / Speakers',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  widget.onUsersSelected(_selected);
                  Navigator.of(context).pop();
                },
                child: const Text('Done', style: TextStyle(color: Color(0xFF7C4DFF), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: _performSearch,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search by name or @handle...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
              filled: true,
              fillColor: const Color(0xFF222232),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(
                        child: Text(
                          'No students found',
                          style: TextStyle(color: Colors.white.withOpacity(0.5)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (ctx, i) {
                          final user = _searchResults[i];
                          final isChecked = _selected.any((u) => u.uid == user.uid);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF222232),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: CheckboxListTile(
                              value: isChecked,
                              activeColor: const Color(0xFFF43F5E),
                              secondary: CircleAvatar(
                                radius: 18,
                                backgroundImage: user.avatarUrl != null ? CachedNetworkImageProvider(user.avatarUrl!) : null,
                                child: user.avatarUrl == null
                                    ? Text(user.displayName.isNotEmpty ? user.displayName[0] : 'U')
                                    : null,
                              ),
                              title: Text(
                                user.displayName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Text(
                                '@${user.handle}${user.department != null ? ' · ${user.department}' : ''}',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selected.add(user);
                                  } else {
                                    _selected.removeWhere((u) => u.uid == user.uid);
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
