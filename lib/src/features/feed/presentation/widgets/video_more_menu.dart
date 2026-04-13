import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/post.dart';
import '../../data/post_repository.dart';
import '../../domain/report.dart';
import '../../../user/data/user_repository.dart';
import 'report_bottom_sheet.dart';

class VideoMoreMenu extends ConsumerWidget {
  final Post post;

  const VideoMoreMenu({super.key, required this.post});

  static Future<void> show(BuildContext context, Post post) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => VideoMoreMenu(post: post),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(postRepositoryProvider);
    final userRepo = ref.watch(userRepositoryProvider);
    final currentUserId = repo.currentUserId;
    final isOwnPost = post.authorId == currentUserId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16181C) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.only(top: 12, bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            if (!isOwnPost) ...[
              _buildMenuItem(
                icon: Icons.person_add_outlined,
                title: 'Follow @${post.authorHandle}',
                onTap: () {
                  userRepo.followUser(post.authorId);
                  Navigator.pop(context);
                },
              ),
              _buildMenuItem(
                icon: Icons.list_alt_outlined,
                title: 'Add/remove from Lists',
                onTap: () {
                  // Mock implementation
                  Navigator.pop(context);
                },
              ),
              _buildMenuItem(
                icon: Icons.volume_off_outlined,
                title: 'Mute @${post.authorHandle}',
                onTap: () {
                  userRepo.muteUser(post.authorId);
                  Navigator.pop(context);
                },
              ),
              _buildMenuItem(
                icon: Icons.block_flipped,
                title: 'Block @${post.authorHandle}',
                onTap: () {
                  userRepo.blockUser(post.authorId);
                  Navigator.pop(context);
                },
              ),
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: Colors.white10,
              ),
              _buildMenuItem(
                icon: Icons.flag_outlined,
                title: 'Report post',
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ReportBottomSheet(
                      targetId: post.id,
                      type: ReportType.post,
                    ),
                  );
                },
              ),
              _buildMenuItem(
                icon: Icons.campaign_outlined,
                title: 'Request Community Note',
                onTap: () {
                  // Mock implementation
                  Navigator.pop(context);
                },
              ),
            ] else ...[
              _buildMenuItem(
                icon: Icons.delete_outline,
                title: 'Delete Post',
                destructive: true,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Post'),
                      content: const Text('This action cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await repo.deletePost(post.id);
                    if (context.mounted) {
                      Navigator.pop(context);
                      Navigator.pop(context); // Go back from video player
                    }
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: destructive ? Colors.red : Colors.white70,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: destructive ? Colors.red : Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
