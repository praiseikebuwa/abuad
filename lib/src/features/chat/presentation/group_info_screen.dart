import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/chat_repository.dart';
import '../domain/chat_channel.dart';
import '../../../core/widgets/verification_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/firebase_storage_service.dart';
import 'package:image_picker/image_picker.dart';

class GroupInfoScreen extends ConsumerStatefulWidget {
  final String channelId;

  const GroupInfoScreen({super.key, required this.channelId});

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateGroupName(ChatChannel channel) async {
    _nameController.text = channel.displayName ?? '';
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Group Name'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(hintText: 'Enter group name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _nameController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null &&
        newName.isNotEmpty &&
        newName != channel.displayName) {
      await ref
          .read(chatRepositoryProvider)
          .updateChannelInfo(channel.id, name: newName);
      if (mounted) setState(() {});
    }
  }

  Future<void> _updateGroupAvatar(ChatChannel channel) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null && mounted) {
      try {
        final storage = FirebaseStorageService();
        final url = await storage.uploadImage(
          pickedFile,
          path: 'groups/${channel.id}/',
        );

        if (url.isNotEmpty) {
          await ref
              .read(chatRepositoryProvider)
              .updateChannelInfo(channel.id, avatarUrl: url);
          if (mounted) setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error updating avatar: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(chatRepositoryProvider);
    final theme = Theme.of(context);
    final channelId = widget.channelId;

    return FutureBuilder(
      future: repo.getChannel(channelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final channel = snapshot.data;
        if (channel == null) {
          return const Scaffold(body: Center(child: Text('Group not found')));
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Group Info')),
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Group Avatar
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.secondaryTeal.withValues(
                          alpha: 0.1,
                        ),
                        backgroundImage: channel.displayAvatarUrl != null
                            ? CachedNetworkImageProvider(
                                channel.displayAvatarUrl!,
                              )
                            : null,
                        child: channel.displayAvatarUrl == null
                            ? const Icon(
                                Icons.groups,
                                size: 50,
                                color: AppColors.secondaryTeal,
                              )
                            : null,
                      ),
                      if (channel.adminIds.contains(repo.currentUserId) ||
                          !channel.restrictInfoUpdates)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _updateGroupAvatar(channel),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.secondaryTeal,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      channel.displayName ?? 'Untitled Group',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (channel.adminIds.contains(repo.currentUserId) ||
                        !channel.restrictInfoUpdates)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _updateGroupName(channel),
                      ),
                  ],
                ),
                Text(
                  '${channel.memberIds.length} Members',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),

                // Member List Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'MEMBERS',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.grey,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                // Members List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: channel.memberIds.length,
                  itemBuilder: (context, index) {
                    final memberId = channel.memberIds[index];
                    final memberName =
                        channel.memberNames[memberId] ?? 'Student';
                    final memberAvatar = channel.memberAvatars[memberId];
                    final isOwner = memberId == channel.createdBy;
                    final isAdmin = channel.adminIds.contains(memberId);
                    final currentUserIsAdmin = channel.adminIds.contains(
                      repo.currentUserId,
                    );
                    final isCurrentUser = memberId == repo.currentUserId;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: memberAvatar != null
                            ? CachedNetworkImageProvider(memberAvatar)
                            : null,
                        child: memberAvatar == null
                            ? Text(
                                memberName.isNotEmpty
                                    ? memberName[0].toUpperCase()
                                    : '?',
                              )
                            : null,
                      ),
                      title: Row(
                        children: [
                          Text(memberName),
                          if (isOwner) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryTeal.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Owner',
                                style: TextStyle(
                                  color: AppColors.secondaryTeal,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ] else if (isAdmin) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Admin',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(isCurrentUser ? 'You' : 'Member'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (channel.verificationTypes[memberId] != null &&
                              channel.verificationTypes[memberId] != 'none')
                            VerificationBadge(
                              type: channel.verificationTypes[memberId]!,
                              size: 16,
                            ),
                          if (currentUserIsAdmin && !isCurrentUser && !isOwner)
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) async {
                                if (value == 'toggle_admin') {
                                  await repo.toggleAdminStatus(
                                    channelId,
                                    memberId,
                                  );
                                } else if (value == 'remove') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Remove Member'),
                                      content: Text(
                                        'Are you sure you want to remove $memberName?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text(
                                            'Remove',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await repo.removeMember(
                                      channelId,
                                      memberId,
                                    );
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'toggle_admin',
                                  child: Text(
                                    isAdmin
                                        ? 'Dismiss as Admin'
                                        : 'Make Group Admin',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text(
                                    'Remove from Group',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Group Settings (Admin Only)
                if (channel.adminIds.contains(repo.currentUserId)) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'GROUP SETTINGS',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.grey,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Restrict Info Updates'),
                    subtitle: const Text('Only admins can change group info'),
                    value: channel.restrictInfoUpdates,
                    onChanged: (val) {
                      repo.updateGroupSettings(
                        channelId,
                        restrictInfoUpdates: val,
                      );
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Restrict Messaging'),
                    subtitle: const Text('Only admins can send messages'),
                    value: channel.restrictMessaging,
                    onChanged: (val) {
                      repo.updateGroupSettings(
                        channelId,
                        restrictMessaging: val,
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                const Divider(),

                // Actions
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.red),
                  title: const Text(
                    'Leave Group',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Leave Group'),
                        content: const Text(
                          'Are you sure you want to leave this group?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Leave',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await repo.leaveGroup(channelId);
                      if (context.mounted) {
                        Navigator.of(context).pop(); // Close GroupInfo
                        Navigator.of(context).pop(); // Close ChatScreen
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
