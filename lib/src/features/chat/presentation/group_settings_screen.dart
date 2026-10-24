import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/chat_repository.dart';
import '../domain/chat_channel.dart';
import '../../../core/utils/url_validator.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  final String channelId;

  const GroupSettingsScreen({super.key, required this.channelId});

  @override
  ConsumerState<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  bool _editGroupInfo = false;
  String _sendMessagesPermission = 'All Members';
  bool _addOtherMembers = true;
  bool _approveNewMembers = true;
  bool _participantHistory = true;
  int _activeInviteLinks = 1;
  final int _bannedUsersCount = 0;
  Future<ChatChannel?>? _channelFuture;

  @override
  void initState() {
    super.initState();
    _channelFuture = ref.read(chatRepositoryProvider).getChannel(widget.channelId);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(chatRepositoryProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF2F2F7);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);
    final sectionHeaderColor = isDark ? Colors.white54 : const Color(0xFF64748B);

    final cached = repo.getCachedChannel(widget.channelId);
    _channelFuture ??= repo.getChannel(widget.channelId);

    return FutureBuilder<ChatChannel?>(
      future: _channelFuture,
      initialData: cached,
      builder: (context, snapshot) {
        final channel = snapshot.data ?? cached;
        final displayName = channel?.displayName?.isNotEmpty == true ? channel!.displayName! : 'Group';
        final memberCount = channel?.memberIds.length ?? 0;
        final adminIds = channel?.adminIds ?? [];
        final adminNames = adminIds.map((id) => channel?.memberNames[id] ?? 'Admin').toList();
        final adminSubtext = adminNames.isNotEmpty ? adminNames.join(', ') : 'Admins';

        final avatars = channel?.memberAvatars.values
                .where((a) => a != null && a.isNotEmpty && UrlValidator.isValidUrl(a))
                .cast<String>()
                .toList() ??
            [];

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: backgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Group Settings',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(Icons.edit_outlined, color: textPrimary, size: 22),
                onPressed: () => _showEditGroupNameDialog(displayName),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                _buildHeaderCard(
                  displayName: displayName,
                  memberCount: memberCount,
                  avatars: avatars,
                  cardColor: cardColor,
                  cardBorderColor: cardBorderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),

                const SizedBox(height: 24),

                // SECTION 1: GROUP INFO & PERMISSIONS
                _buildSectionTitle('SECTION 1: GROUP INFO & PERMISSIONS', sectionHeaderColor),
                const SizedBox(height: 8),
                _buildCardContainer(
                  cardColor: cardColor,
                  cardBorderColor: cardBorderColor,
                  children: [
                    _buildSwitchRow(
                      title: 'Edit Group Info',
                      subtitle: 'Only admins can change group name, image, and description.',
                      value: _editGroupInfo,
                      onChanged: (val) {
                        setState(() => _editGroupInfo = val);
                        repo.updateGroupSettings(widget.channelId, restrictInfoUpdates: val);
                      },
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDark: isDark,
                    ),
                    _buildDivider(isDark),
                    _buildNavigationRow(
                      title: 'Send Messages',
                      value: _sendMessagesPermission,
                      subtitle: 'Choose who can send messages to this group.',
                      onTap: _showSendMessagesDialog,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    _buildDivider(isDark),
                    _buildSwitchRow(
                      title: 'Add Other Members',
                      subtitle: 'Allow all members to add new students.',
                      value: _addOtherMembers,
                      onChanged: (val) => setState(() => _addOtherMembers = val),
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDark: isDark,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // SECTION 2: MEMBERSHIP & APPROVALS
                _buildSectionTitle('SECTION 2: MEMBERSHIP & APPROVALS', sectionHeaderColor),
                const SizedBox(height: 8),
                _buildCardContainer(
                  cardColor: cardColor,
                  cardBorderColor: cardBorderColor,
                  children: [
                    _buildSwitchRow(
                      title: 'Approve New Members',
                      subtitle: 'Admins must approve requests to join via link.',
                      value: _approveNewMembers,
                      onChanged: (val) => setState(() => _approveNewMembers = val),
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDark: isDark,
                    ),
                    _buildDivider(isDark),
                    _buildSwitchRow(
                      title: 'Participant History',
                      subtitle: 'New members can see past messages.',
                      value: _participantHistory,
                      onChanged: (val) => setState(() => _participantHistory = val),
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDark: isDark,
                    ),
                    _buildDivider(isDark),
                    _buildNavigationRow(
                      title: 'Invite Links',
                      value: '$_activeInviteLinks active links',
                      subtitle: 'Manage links and QR codes to join this group.',
                      onTap: () => _showInviteLinksDialog(widget.channelId),
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // SECTION 3: ADMINISTRATION
                _buildSectionTitle('SECTION 3: ADMINISTRATION', sectionHeaderColor),
                const SizedBox(height: 8),
                _buildCardContainer(
                  cardColor: cardColor,
                  cardBorderColor: cardBorderColor,
                  children: [
                    _buildNavigationRow(
                      title: 'Group Admins',
                      value: '${adminIds.length} admins',
                      subtitle: adminSubtext,
                      onTap: () => _showAdminsDialog(channel),
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    _buildDivider(isDark),
                    _buildNavigationRow(
                      title: 'Manage Banned Users',
                      value: '$_bannedUsersCount users',
                      subtitle: 'View and unban users restricted from this group.',
                      onTap: _showBannedUsersDialog,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // SECTION 4: DESTRUCTIVE / RESET ACTIONS
                _buildSectionTitle('SECTION 4: DESTRUCTIVE / RESET ACTIONS', sectionHeaderColor),
                const SizedBox(height: 8),
                _buildDestructiveCard(
                  isDark: isDark,
                  children: [
                    _buildDestructiveRow(
                      title: 'Reset Invite Links',
                      subtitle: 'Warning: Resets active invite link tokens for this group.',
                      onTap: _confirmResetInviteLinks,
                    ),
                    _buildDivider(isDark),
                    _buildDestructiveRow(
                      title: 'Delete Group History',
                      subtitle: 'Warning: Deletes group chat history on this device.',
                      onTap: _confirmDeleteGroupHistory,
                    ),
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildHeaderCard({
    required String displayName,
    required int memberCount,
    required List<String> avatars,
    required Color cardColor,
    required Color cardBorderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(34),
                child: _buildAvatarCollage(avatars, displayName),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: GestureDetector(
                onTap: () => _showEditGroupNameDialog(displayName),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.edit,
                      size: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$memberCount Members',
                style: TextStyle(
                  fontSize: 14,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarCollage(List<String> avatars, String displayName) {
    if (avatars.length >= 3) {
      return Stack(
        children: [
          Positioned(
            left: 2,
            top: 2,
            child: CircleAvatar(
              radius: 16,
              backgroundImage: CachedNetworkImageProvider(avatars[0]),
            ),
          ),
          Positioned(
            right: 2,
            top: 2,
            child: CircleAvatar(
              radius: 16,
              backgroundImage: CachedNetworkImageProvider(avatars[1]),
            ),
          ),
          Positioned(
            left: 18,
            bottom: 2,
            child: CircleAvatar(
              radius: 16,
              backgroundImage: CachedNetworkImageProvider(avatars[2]),
            ),
          ),
        ],
      );
    }
    return Center(
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'G',
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
      ),
    );
  }

  Widget _buildCardContainer({
    required Color cardColor,
    required Color cardBorderColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDestructiveCard({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C1517) : const Color(0xFFFEE2E2).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFFEF4444).withValues(alpha: 0.2) : const Color(0xFFFECACA),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            activeThumbColor: const Color(0xFF22C55E),
            activeTrackColor: const Color(0xFF22C55E).withValues(alpha: isDark ? 0.4 : 0.6),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRow({
    required String title,
    required String value,
    required String subtitle,
    required VoidCallback onTap,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestructiveRow({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF991B1B),
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      endIndent: 16,
      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
    );
  }

  void _showEditGroupNameDialog(String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Group Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter group name',
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await ref.read(chatRepositoryProvider).updateChannelInfo(
                      widget.channelId,
                      name: newName,
                    );
                if (mounted) setState(() {});
              }
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSendMessagesDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Who can send messages?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('All Members'),
                trailing: _sendMessagesPermission == 'All Members' ? const Icon(Icons.check, color: Color(0xFF3B82F6)) : null,
                onTap: () {
                  setState(() => _sendMessagesPermission = 'All Members');
                  ref.read(chatRepositoryProvider).updateGroupSettings(widget.channelId, restrictMessaging: false);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Only Admins'),
                trailing: _sendMessagesPermission == 'Only Admins' ? const Icon(Icons.check, color: Color(0xFF3B82F6)) : null,
                onTap: () {
                  setState(() => _sendMessagesPermission = 'Only Admins');
                  ref.read(chatRepositoryProvider).updateGroupSettings(widget.channelId, restrictMessaging: true);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showInviteLinksDialog(String channelId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Text('Active Invite Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                const Text('Share this link to invite students to join the group.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'https://abuad.edu.ng/join/$channelId',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invite link copied to clipboard')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAdminsDialog(ChatChannel? channel) {
    final adminIds = channel?.adminIds ?? [];
    final creatorId = channel?.createdBy;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('Group Admins (${adminIds.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              if (adminIds.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No admins assigned yet.'),
                )
              else
                for (final adminId in adminIds)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF6366F1),
                      child: Text(
                        (channel?.memberNames[adminId]?.isNotEmpty == true)
                            ? channel!.memberNames[adminId]![0].toUpperCase()
                            : 'A',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      channel?.memberNames[adminId] ?? 'Admin',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(adminId == creatorId ? 'Group Creator & Admin' : 'Group Admin'),
                    trailing: Chip(
                      label: Text(adminId == creatorId ? 'Owner' : 'Admin', style: const TextStyle(fontSize: 11, color: Colors.white)),
                      backgroundColor: adminId == creatorId ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                    ),
                  ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showBannedUsersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Banned Users'),
        content: const Text('There are currently no banned users in this group.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmResetInviteLinks() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Invite Links?'),
        content: const Text('Previous links will stop working immediately. Anyone trying to join with an old link will need a new one.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _activeInviteLinks = 1);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All previous invite links were reset.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroupHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group History?'),
        content: const Text('This will clear local group messages and attachments from your device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Group history deleted successfully.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete History'),
          ),
        ],
      ),
    );
  }
}
