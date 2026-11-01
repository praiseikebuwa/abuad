import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/notification_service.dart';
import '../../audio_spaces/domain/audio_room.dart';
import '../../audio_spaces/presentation/controllers/audio_room_controller.dart';
import '../../audio_spaces/presentation/live_audio_room_screen.dart';
import '../data/study_lounge_repository.dart';
import '../services/study_ai_service.dart';

class StudyLoungesScreen extends ConsumerStatefulWidget {
  const StudyLoungesScreen({super.key});

  @override
  ConsumerState<StudyLoungesScreen> createState() => _StudyLoungesScreenState();
}

class _StudyLoungesScreenState extends ConsumerState<StudyLoungesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // AI Assistant state
  final TextEditingController _aiCourseController = TextEditingController();
  final TextEditingController _aiTopicController = TextEditingController();
  bool _isAiLoading = false;
  String _aiMode = 'EXPLAIN'; // EXPLAIN, QUIZ, AUDIO
  StudyExplanation? _explanationResult;
  List<StudyQuizQuestion>? _quizQuestions;
  Map<String, int> _selectedQuizAnswers = {};
  AudioLectureSession? _audioLectureResult;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _aiCourseController.dispose();
    _aiTopicController.dispose();
    super.dispose();
  }

  Future<void> _joinLounge(AudioRoom room) async {
    HapticFeedback.lightImpact();
    try {
      ref.read(activeAudioRoomNotifierProvider.notifier).joinRoom(room.id);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LiveAudioRoomScreen(roomId: room.id),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join study lounge: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showCreateLoungeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateStudyLoungeSheet(
        onCreated: (newRoom) {
          ref.invalidate(liveStudyLoungesProvider);
          ref.invalidate(scheduledStudySessionsProvider);
          if (newRoom.status == 'LIVE') {
            _joinLounge(newRoom);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Study session scheduled successfully!'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _runAiStudyAssistant() async {
    final topic = _aiTopicController.text.trim();
    final course = _aiCourseController.text.trim().isEmpty
        ? 'General Study'
        : _aiCourseController.text.trim();

    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a study topic or question.')),
      );
      return;
    }

    setState(() {
      _isAiLoading = true;
      _aiError = null;
    });
    FocusScope.of(context).unfocus();

    try {
      final aiService = ref.read(studyAiServiceProvider);

      if (_aiMode == 'EXPLAIN') {
        final res = await aiService.explainTopic(
          courseCode: course,
          topic: topic,
        );
        if (mounted) {
          setState(() {
            _explanationResult = res;
            _quizQuestions = null;
            _audioLectureResult = null;
          });
        }
      } else if (_aiMode == 'QUIZ') {
        final res = await aiService.generateQuiz(
          courseCode: course,
          topic: topic,
          count: 4,
        );
        if (mounted) {
          setState(() {
            _quizQuestions = res;
            _selectedQuizAnswers.clear();
            _explanationResult = null;
            _audioLectureResult = null;
          });
        }
      } else if (_aiMode == 'AUDIO') {
        final res = await aiService.generateAudioLecture(
          courseCode: course,
          topic: topic,
          durationMinutes: 3,
        );
        if (mounted) {
          setState(() {
            _audioLectureResult = res;
            _explanationResult = null;
            _quizQuestions = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _aiError = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isAiLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const navyBg = Color(0xFF0A1128);
    const goldAccent = Color(0xFFD4AF37);

    return Scaffold(
      backgroundColor: navyBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.school_rounded, color: goldAccent, size: 24),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Study Lounges',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Collaborative Audio & ABUAD AI Hub',
                  style: TextStyle(
                    color: Color(0xFFF3C64F),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: goldAccent,
          indicatorWeight: 3,
          labelColor: goldAccent,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.mic_external_on_rounded, size: 18), text: 'Live Lounges'),
            Tab(icon: Icon(Icons.event_note_rounded, size: 18), text: 'Scheduled'),
            Tab(icon: Icon(Icons.auto_awesome_rounded, size: 18), text: 'ABUAD AI'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: goldAccent),
            tooltip: 'Start Study Room',
            onPressed: _showCreateLoungeSheet,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLiveLoungesTab(),
          _buildScheduledSessionsTab(),
          _buildAiStudyAssistantTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: goldAccent,
        foregroundColor: const Color(0xFF0A1128),
        icon: const Icon(Icons.record_voice_over_rounded, size: 20),
        label: const Text('Start Study Room', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showCreateLoungeSheet,
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 1: LIVE STUDY LOUNGES
  // ----------------------------------------------------
  Widget _buildLiveLoungesTab() {
    final liveLoungesAsync = ref.watch(liveStudyLoungesProvider);

    return RefreshIndicator(
      color: const Color(0xFFD4AF37),
      backgroundColor: const Color(0xFF1E293B),
      onRefresh: () async {
        ref.invalidate(liveStudyLoungesProvider);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // Search Bar
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1B263B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by course (e.g. GST 111, MTH 201)...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFD4AF37), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          liveLoungesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
            ),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load lounges:\n$err',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
                      onPressed: () => ref.invalidate(liveStudyLoungesProvider),
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0A1128)),
                      label: const Text('Try Again', style: TextStyle(color: Color(0xFF0A1128), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            data: (rooms) {
              final filtered = rooms.where((r) {
                if (_searchQuery.isEmpty) return true;
                final title = r.title.toLowerCase();
                final desc = (r.description ?? '').toLowerCase();
                final tags = r.tags.join(' ').toLowerCase();
                return title.contains(_searchQuery) || desc.contains(_searchQuery) || tags.contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B263B),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.headset_mic_rounded, color: Color(0xFFD4AF37), size: 40),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty ? 'No Active Study Lounges' : 'No Lounges Found for "$_searchQuery"',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Start a room for your course, revision group, or study with ABUAD AI!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: const Color(0xFF0A1128),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Start an Audio Study Lounge', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _showCreateLoungeSheet,
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: filtered.map((room) => _buildStudyLoungeCard(room)).toList(),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildStudyLoungeCard(AudioRoom room) {
    const goldAccent = Color(0xFFD4AF37);
    final speakersCount = room.speakers.length;
    final totalCount = room.totalParticipants;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: goldAccent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _joinLounge(room),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Category + LIVE badge + Listener count
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: goldAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: goldAccent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        room.tags.isNotEmpty ? room.tags.first : room.category,
                        style: const TextStyle(
                          color: goldAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 8),
                          SizedBox(width: 4),
                          Text('LIVE', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.headphones_rounded, color: Colors.white70, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            '$speakersCount speaking • $totalCount listening',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  room.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),

                if (room.description != null && room.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    room.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 10),

                // Bottom row: Host avatar & Join Button
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: goldAccent.withValues(alpha: 0.2),
                      backgroundImage: room.host.avatarUrl != null && room.host.avatarUrl!.isNotEmpty
                          ? NetworkImage(room.host.avatarUrl!)
                          : null,
                      child: room.host.avatarUrl == null || room.host.avatarUrl!.isEmpty
                          ? Text(
                              room.host.fullName.isNotEmpty ? room.host.fullName[0].toUpperCase() : 'H',
                              style: const TextStyle(color: goldAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hosted by ${room.host.fullName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: goldAccent,
                        foregroundColor: const Color(0xFF0A1128),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      icon: const Icon(Icons.volume_up_rounded, size: 16),
                      label: const Text('Join', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () => _joinLounge(room),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 2: SCHEDULED SESSIONS
  // ----------------------------------------------------
  Widget _buildScheduledSessionsTab() {
    final scheduledAsync = ref.watch(scheduledStudySessionsProvider);

    return RefreshIndicator(
      color: const Color(0xFFD4AF37),
      backgroundColor: const Color(0xFF1E293B),
      onRefresh: () async {
        ref.invalidate(scheduledStudySessionsProvider);
      },
      child: scheduledAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
              const SizedBox(height: 10),
              Text('Failed to load scheduled sessions: $err', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => ref.invalidate(scheduledStudySessionsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B263B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Icon(Icons.event_available_rounded, color: Color(0xFFD4AF37), size: 44),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Upcoming Sessions',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Schedule an exam marathon, group reading, or tutorial session with fellow ABUAD students!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
                      icon: const Icon(Icons.add_rounded, color: Color(0xFF0A1128)),
                      label: const Text('Schedule a Session', style: TextStyle(color: Color(0xFF0A1128), fontWeight: FontWeight.bold)),
                      onPressed: _showCreateLoungeSheet,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final dateStr = session.scheduledAt != null
                  ? DateFormat('EEE, MMM d • h:mm a').format(session.scheduledAt!.toLocal())
                  : 'Time to be announced';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B263B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time_filled_rounded, color: Color(0xFFD4AF37), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          dateStr,
                          style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            session.tags.isNotEmpty ? session.tags.first : session.category,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      session.title,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    if (session.description != null && session.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        session.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text('Host: ${session.host.fullName}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        const Spacer(),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD4AF37),
                            side: const BorderSide(color: Color(0xFFD4AF37)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.notifications_active_rounded, size: 14),
                          label: const Text('Remind Me', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            NotificationService().showLocalNotification(
                              title: 'Study Reminder Set',
                              body: 'You will receive a notification before "${session.title}" begins.',
                              type: 'study',
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Reminder registered successfully!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 3: ABUAD AI STUDY ASSISTANT & AUDIO LECTURE
  // ----------------------------------------------------
  Widget _buildAiStudyAssistantTab() {
    const goldAccent = Color(0xFFD4AF37);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B263B), Color(0xFF0D1B2A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: goldAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: goldAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.psychology_rounded, color: goldAccent, size: 30),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ABUAD AI Study Companion',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Powered by Google Gemini. Tailored for Afe Babalola University curricula, continuous assessment, and exams.',
                        style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Course Code and Topic Inputs
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _aiCourseController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Course Code',
                    labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                    hintText: 'e.g., GST 111, MTH 201',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF1B263B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _aiTopicController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Topic or Concept',
                    labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                    hintText: 'e.g., Matrix Diagonalization, Law of Tort',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF1B263B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Mode Selector (Explain, Practice Quiz, Audio Tutor)
          Row(
            children: [
              _buildModeSelectorItem('EXPLAIN', 'Revision Guide', Icons.menu_book_rounded),
              const SizedBox(width: 8),
              _buildModeSelectorItem('QUIZ', 'Practice Quiz', Icons.quiz_rounded),
              const SizedBox(width: 8),
              _buildModeSelectorItem('AUDIO', 'Audio Tutor', Icons.headphones_rounded),
            ],
          ),
          const SizedBox(height: 14),

          // Generate Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: goldAccent,
                foregroundColor: const Color(0xFF0A1128),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _isAiLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A1128)),
                    )
                  : const Icon(Icons.bolt_rounded),
              label: Text(
                _isAiLoading ? 'Synthesizing with ABUAD AI...' : 'Generate Learning Material',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: _isAiLoading ? null : _runAiStudyAssistant,
            ),
          ),
          const SizedBox(height: 20),

          // Error banner
          if (_aiError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_aiError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                ],
              ),
            ),

          // Results Section
          if (_explanationResult != null) _buildExplanationView(_explanationResult!),
          if (_quizQuestions != null) _buildQuizView(_quizQuestions!),
          if (_audioLectureResult != null) _buildAudioLectureView(_audioLectureResult!),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildModeSelectorItem(String modeKey, String label, IconData icon) {
    final isSelected = _aiMode == modeKey;
    const goldAccent = Color(0xFFD4AF37);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _aiMode = modeKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? goldAccent.withValues(alpha: 0.2) : const Color(0xFF1B263B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? goldAccent : Colors.white12,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? goldAccent : Colors.white60, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? goldAccent : Colors.white70,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExplanationView(StudyExplanation explanation) {
    const goldAccent = Color(0xFFD4AF37);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: goldAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(explanation.courseCode, style: const TextStyle(color: goldAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white54, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: '${explanation.courseCode} - ${explanation.topic}\n\n${explanation.detailedNotes}'));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notes copied to clipboard!')));
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(explanation.topic, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(explanation.summary, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
          const Divider(color: Colors.white12, height: 24),
          const Text('Detailed Revision Notes', style: TextStyle(color: goldAccent, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(explanation.detailedNotes, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5)),
          if (explanation.keyTakeaways.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Key Takeaways', style: TextStyle(color: goldAccent, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...explanation.keyTakeaways.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: goldAccent, fontSize: 14)),
                    Expanded(child: Text(item, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                  ],
                ),
              ),
            ),
          ],
          if (explanation.examTips.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: Colors.amber, size: 16),
                      SizedBox(width: 6),
                      Text('High-Yield Exam Tips', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...explanation.examTips.map(
                    (tip) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('• $tip', style: TextStyle(color: Colors.amber.shade200, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuizView(List<StudyQuizQuestion> questions) {
    const goldAccent = Color(0xFFD4AF37);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Practice Questions', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('${_selectedQuizAnswers.length}/${questions.length} Answered', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 10),
        ...questions.asMap().entries.map((entry) {
          final index = entry.key;
          final q = entry.value;
          final selected = _selectedQuizAnswers[q.id];

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B263B),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Question ${index + 1}', style: const TextStyle(color: goldAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(q.question, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                ...q.options.asMap().entries.map((optEntry) {
                  final optIdx = optEntry.key;
                  final optText = optEntry.value;
                  final isChosen = selected == optIdx;
                  final isAnswered = selected != null;
                  final isCorrect = optIdx == q.correctIndex;

                  Color optBg = Colors.white.withValues(alpha: 0.05);
                  Color optBorder = Colors.white10;
                  if (isAnswered) {
                    if (isCorrect) {
                      optBg = Colors.green.withValues(alpha: 0.2);
                      optBorder = Colors.green;
                    } else if (isChosen) {
                      optBg = Colors.redAccent.withValues(alpha: 0.2);
                      optBorder = Colors.redAccent;
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: optBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: optBorder),
                    ),
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: isChosen ? goldAccent : Colors.white12,
                        child: Text(
                          String.fromCharCode(65 + optIdx),
                          style: TextStyle(
                            color: isChosen ? const Color(0xFF0A1128) : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(optText, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      onTap: isAnswered
                          ? null
                          : () {
                              setState(() {
                                _selectedQuizAnswers[q.id] = optIdx;
                              });
                            },
                    ),
                  );
                }),
                if (selected != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (selected == q.correctIndex ? Colors.green : Colors.amber).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Explanation: ${q.explanation}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAudioLectureView(AudioLectureSession lecture) {
    const goldAccent = Color(0xFFD4AF37);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: goldAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: goldAccent.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.record_voice_over_rounded, color: goldAccent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lecture.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('Approx. ${lecture.estimatedDurationSeconds ~/ 60} mins spoken breakdown', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Spoken Tutor Script:', style: TextStyle(color: goldAccent, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              lecture.spokenScript,
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
            ),
          ),
          if (lecture.bulletPoints.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Audio Takeaways:', style: TextStyle(color: goldAccent, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...lecture.bulletPoints.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('🎧 $p', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ),
          ],
          const SizedBox(height: 18),
          // Start Live Space around this topic
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: goldAccent,
                foregroundColor: const Color(0xFF0A1128),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.podcasts_rounded),
              label: const Text('Host Live Space for this Topic', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                _createStudyRoomFromTopic(lecture.courseCode, lecture.title);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createStudyRoomFromTopic(String course, String topic) async {
    try {
      final newRoom = await ref.read(studyLoungeRepositoryProvider).createStudyLounge(
        title: '$course: $topic',
        description: 'Interactive audio study session generated by ABUAD AI.',
        courseCode: course,
      );
      ref.invalidate(liveStudyLoungesProvider);
      _joinLounge(newRoom);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch room: $e')),
      );
    }
  }
}

class _CreateStudyLoungeSheet extends StatefulWidget {
  final ValueChanged<AudioRoom> onCreated;

  const _CreateStudyLoungeSheet({required this.onCreated});

  @override
  State<_CreateStudyLoungeSheet> createState() => _CreateStudyLoungeSheetState();
}

class _CreateStudyLoungeSheetState extends State<_CreateStudyLoungeSheet> {
  final _titleController = TextEditingController();
  final _courseController = TextEditingController();
  final _facultyController = TextEditingController();
  final _descController = TextEditingController();
  bool _isScheduled = false;
  DateTime _scheduledDate = DateTime.now().add(const Duration(hours: 2));
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _courseController.dispose();
    _facultyController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    final title = _titleController.text.trim();
    final course = _courseController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a study room topic.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final repo = container.read(studyLoungeRepositoryProvider);

      final room = await repo.createStudyLounge(
        title: title,
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        courseCode: course.isEmpty ? 'GENERAL' : course,
        faculty: _facultyController.text.trim().isEmpty ? null : _facultyController.text.trim(),
        scheduledAt: _isScheduled ? _scheduledDate : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated(room);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create study room: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const goldAccent = Color(0xFFD4AF37);

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF141D33),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.record_voice_over_rounded, color: goldAccent, size: 22),
                SizedBox(width: 8),
                Text(
                  'Start Study Lounge',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Session Topic',
                labelStyle: const TextStyle(color: Colors.white60),
                hintText: 'e.g. CHE 202 Organic Mechanisms Practice',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _courseController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Course Code',
                      labelStyle: const TextStyle(color: Colors.white60),
                      hintText: 'e.g. CHE 202',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _facultyController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Faculty / College',
                      labelStyle: const TextStyle(color: Colors.white60),
                      hintText: 'e.g. Engineering',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Notes / Pinned Agenda',
                labelStyle: const TextStyle(color: Colors.white60),
                hintText: 'What questions or chapters will you cover?',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: goldAccent,
              title: const Text('Schedule for Later', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(
                _isScheduled
                    ? DateFormat('EEE, MMM d • h:mm a').format(_scheduledDate)
                    : 'Start immediately after creating',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              value: _isScheduled,
              onChanged: (val) async {
                if (val) {
                  final now = DateTime.now();
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 30)),
                  );
                  if (pickedDate != null && context.mounted) {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
                    );
                    if (pickedTime != null) {
                      setState(() {
                        _scheduledDate = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                        _isScheduled = true;
                      });
                      return;
                    }
                  }
                }
                setState(() => _isScheduled = val);
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: goldAccent,
                  foregroundColor: const Color(0xFF0A1128),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isLoading ? null : () => _submit(context),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Color(0xFF0A1128), strokeWidth: 2),
                      )
                    : Text(
                        _isScheduled ? 'Schedule Study Session' : 'Start Live Study Room',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
