import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controllers/audio_room_controller.dart';
import 'widgets/create_audio_room_sheet.dart';
import 'widgets/floating_audio_space_bar.dart';
import 'widgets/live_space_feed_card.dart';

class LiveSpacesHubScreen extends ConsumerWidget {
  const LiveSpacesHubScreen({super.key});

  void _openCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateAudioRoomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(audioRoomsProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    final categories = [
      {'id': 'ALL', 'label': 'All Spaces', 'icon': '🎙️'},
      {'id': 'ACADEMIC', 'label': 'Academic & Tutorials', 'icon': '🎓'},
      {'id': 'SOCIAL', 'label': 'Social & Gist', 'icon': '🔥'},
      {'id': 'DEBATE', 'label': 'SUG & Debates', 'icon': '⚖️'},
      {'id': 'COMMUNITY', 'label': 'Communities', 'icon': '👥'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.podcasts_rounded, color: Color(0xFF7C4DFF), size: 26),
            SizedBox(width: 10),
            Text(
              'Live Audio Spaces',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Go Live', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: () => _openCreateSheet(context),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const FloatingAudioSpaceBar(),
      body: RefreshIndicator(
        color: const Color(0xFF7C4DFF),
        backgroundColor: const Color(0xFF1E1E2C),
        onRefresh: () async {
          ref.invalidate(audioRoomsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // Category Chips Selector
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = selectedCategory == cat['id'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: Text(cat['icon']!),
                        label: Text(cat['label']!),
                        selected: isSelected,
                        selectedColor: const Color(0xFF7C4DFF),
                        backgroundColor: const Color(0xFF1C1C2C),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF7C4DFF) : Colors.white12,
                        ),
                        onSelected: (_) {
                          ref.read(selectedCategoryProvider.notifier).state = cat['id']!;
                        },
                      ),
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Room List Content
            roomsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF7C4DFF)),
                ),
              ),
              error: (err, stack) => SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(
                          'Could not load spaces: $err',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(audioRoomsProvider),
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              data: (rooms) {
                if (rooms.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C4DFF).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.podcasts_rounded,
                                size: 48,
                                color: Color(0xFF7C4DFF),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Live Spaces Active',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to start a conversation, tutorial, or faculty town hall!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C4DFF),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                              icon: const Icon(Icons.mic_rounded),
                              label: const Text('Start First Space', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () => _openCreateSheet(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final liveRooms = rooms.where((r) => r.isLive).toList();
                final scheduledRooms = rooms.where((r) => r.isScheduled).toList();

                return SliverList(
                  delegate: SliverChildListDelegate([
                    if (liveRooms.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 12),
                            SizedBox(width: 6),
                            Text(
                              'Live Now',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...liveRooms.map((room) => LiveSpaceFeedCard(room: room)),
                      const SizedBox(height: 16),
                    ],

                    if (scheduledRooms.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, color: Colors.amber, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Upcoming Sessions',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...scheduledRooms.map((room) => LiveSpaceFeedCard(room: room)),
                    ],
                    const SizedBox(height: 60),
                  ]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
