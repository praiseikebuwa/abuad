import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/chat_repository.dart';
import '../domain/chat_channel.dart';
import '../../../core/utils/url_validator.dart';
import 'group_settings_screen.dart';

class GroupInfoScreen extends ConsumerStatefulWidget {
  final String channelId;

  const GroupInfoScreen({super.key, required this.channelId});

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  bool _isMuted = false;
  String _notificationSetting = 'On / Custom';

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
    final actionButtonBg = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return FutureBuilder<ChatChannel?>(
      future: repo.getChannel(widget.channelId),
      builder: (context, snapshot) {
        final channel = snapshot.data;
        final displayName = channel?.displayName ?? 'MTH 205 — Mathematics';
        final memberCount = channel?.memberIds.isNotEmpty == true ? channel!.memberIds.length : 128;
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
              'Group Info',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
            centerTitle: true,
            actions: [
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, color: textPrimary, size: 26),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (val) {
                  if (val == 'settings') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupSettingsScreen(channelId: widget.channelId),
                      ),
                    );
                  } else if (val == 'share') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Group invite link copied')),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings_outlined, size: 20),
                        SizedBox(width: 10),
                        Text('Group Settings'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share_outlined, size: 20),
                        SizedBox(width: 10),
                        Text('Share Group Link'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.report_problem_outlined, size: 20, color: Colors.red),
                        SizedBox(width: 10),
                        Text('Report Group', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // Top Avatar Cluster & Title Section
                _buildProfileHeader(
                  displayName: displayName,
                  memberCount: memberCount,
                  avatars: avatars,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),

                const SizedBox(height: 20),

                // 4 Round Quick Action Buttons
                _buildActionButtonsRow(actionButtonBg, textPrimary),

                const SizedBox(height: 20),

                // Description Card
                _buildDescriptionCard(
                  cardColor: cardColor,
                  cardBorderColor: cardBorderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),

                const SizedBox(height: 16),

                // Media, Docs & Links Card
                _buildMediaDocsLinksCard(
                  cardColor: cardColor,
                  cardBorderColor: cardBorderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),

                const SizedBox(height: 16),

                // Settings & Options Card
                _buildOptionsCard(
                  cardColor: cardColor,
                  cardBorderColor: cardBorderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),

                const SizedBox(height: 16),

                // Members Card
                _buildMembersCard(
                  memberCount: memberCount,
                  channel: channel,
                  cardColor: cardColor,
                  cardBorderColor: cardBorderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),

                const SizedBox(height: 16),

                // Destructive Actions Card
                _buildDestructiveActionsCard(isDark),

                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader({
    required String displayName,
    required int memberCount,
    required List<String> avatars,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Column(
      children: [
        // Avatar Cluster with subject book badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(43),
                child: _buildAvatarCollage(avatars),
              ),
            ),
            // Subject / Book Badge
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: isDark ? const Color(0xFF0F172A) : Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('📖', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          displayName,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$memberCount Members • Created by Liam (Class Rep)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarCollage(List<String> avatars) {
    if (avatars.length >= 3) {
      return Stack(
        children: [
          Positioned(
            left: 4,
            top: 4,
            child: CircleAvatar(
              radius: 19,
              backgroundImage: CachedNetworkImageProvider(avatars[0]),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: CircleAvatar(
              radius: 19,
              backgroundImage: CachedNetworkImageProvider(avatars[1]),
            ),
          ),
          Positioned(
            left: 23,
            bottom: 4,
            child: CircleAvatar(
              radius: 19,
              backgroundImage: CachedNetworkImageProvider(avatars[2]),
            ),
          ),
        ],
      );
    }
    return const Center(
      child: Icon(Icons.groups_rounded, size: 48, color: Color(0xFF3B82F6)),
    );
  }

  Widget _buildActionButtonsRow(Color buttonBg, Color textPrimary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: Icons.phone_rounded,
          label: 'Call',
          bg: buttonBg,
          textPrimary: textPrimary,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Starting group voice call...')),
            );
          },
        ),
        _buildActionButton(
          icon: Icons.videocam_rounded,
          label: 'Video',
          bg: buttonBg,
          textPrimary: textPrimary,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Starting group video call...')),
            );
          },
        ),
        _buildActionButton(
          icon: _isMuted ? Icons.notifications_off_rounded : Icons.notifications_rounded,
          label: 'Mute',
          bg: buttonBg,
          textPrimary: textPrimary,
          isActive: _isMuted,
          onTap: () {
            setState(() => _isMuted = !_isMuted);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_isMuted ? 'Group notifications muted' : 'Group unmuted')),
            );
          },
        ),
        _buildActionButton(
          icon: Icons.search_rounded,
          label: 'Search',
          bg: buttonBg,
          textPrimary: textPrimary,
          onTap: () {
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color bg,
    required Color textPrimary,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF3B82F6) : bg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                icon,
                color: isActive ? Colors.white : textPrimary,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard({
    required Color cardColor,
    required Color cardBorderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Official study group for MTH 205 (Mathematical Methods I). Share assignment updates, lecture notes, and study session details here. Keep it constructive! 📚 📐',
            style: TextStyle(
              fontSize: 14,
              color: textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('📌', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Pinned announcement by Liam',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaDocsLinksCard({
    required Color cardColor,
    required Color cardBorderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Media, Docs & Links',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening all shared media gallery...')),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        'View All (42)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              children: [
                _buildMediaThumbnail(
                  title: 'MTH205_Lec4...',
                  icon: Icons.picture_as_pdf_rounded,
                  iconColor: const Color(0xFFEF4444),
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _buildMediaThumbnail(
                  title: 'handwritten\ncalculations photo',
                  icon: Icons.image_rounded,
                  iconColor: const Color(0xFF10B981),
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _buildMediaThumbnail(
                  title: 'zoom.us/j/...',
                  icon: Icons.link_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _buildMediaThumbnail(
                  title: 'syllabus.pdf',
                  icon: Icons.description_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaThumbnail({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 74,
          height: 64,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              width: 0.5,
            ),
          ),
          child: Center(
            child: Icon(icon, size: 30, color: iconColor),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 80,
          child: Text(
            title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsCard({
    required Color cardColor,
    required Color cardBorderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: 0.5),
      ),
      child: Column(
        children: [
          _buildOptionTile(
            title: 'Group Settings',
            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupSettingsScreen(channelId: widget.channelId),
                ),
              );
            },
            textPrimary: textPrimary,
          ),
          _buildInnerDivider(isDark),
          _buildOptionTile(
            title: 'Starred Messages',
            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No starred messages in this group yet')),
              );
            },
            textPrimary: textPrimary,
          ),
          _buildInnerDivider(isDark),
          _buildOptionTile(
            title: 'Notifications',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _notificationSetting,
                  style: TextStyle(fontSize: 14, color: textSecondary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
              ],
            ),
            onTap: _showNotificationOptions,
            textPrimary: textPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required String title,
    required Widget trailing,
    required VoidCallback onTap,
    required Color textPrimary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildMembersCard({
    required int memberCount,
    required ChatChannel? channel,
    required Color cardColor,
    required Color cardBorderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Members ($memberCount)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              Row(
                children: [
                  _buildHeaderPillButton(
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Add Member',
                    isDark: isDark,
                    onTap: () => context.push('/chat/user-search'),
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderPillButton(
                    icon: Icons.search_rounded,
                    label: 'Search',
                    isDark: isDark,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 2-Column Grid or List of Members matching Screenshot 1
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column 1
              Expanded(
                child: Column(
                  children: [
                    _buildMemberRowItem(
                      name: 'Liam (Class Rep)',
                      role: 'Admin',
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    _buildMemberRowItem(
                      name: 'David Okafor',
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Column 2
              Expanded(
                child: Column(
                  children: [
                    _buildMemberRowItem(
                      name: 'Priya Sharma',
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    _buildMemberRowItem(
                      name: 'Sarah Johnson',
                      isOnline: true,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPillButton({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isDark ? Colors.white70 : const Color(0xFF475569)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberRowItem({
    required String name,
    String? role,
    bool isOnline = false,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF6366F1),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            if (isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              if (role != null) ...[
                const SizedBox(height: 1),
                Text(
                  role,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDestructiveActionsCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C1517) : const Color(0xFFFEE2E2).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFFEF4444).withValues(alpha: 0.2) : const Color(0xFFFECACA),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _confirmExitGroup,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Exit Group',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ),
          ),
          _buildInnerDivider(isDark),
          InkWell(
            onTap: _confirmReportGroup,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Report Group',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInnerDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      endIndent: 16,
      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
    );
  }

  void _showNotificationOptions() {
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
              const Text('Notification Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('All Messages (Default)'),
                trailing: _notificationSetting == 'On / Custom' ? const Icon(Icons.check, color: Color(0xFF3B82F6)) : null,
                onTap: () {
                  setState(() => _notificationSetting = 'On / Custom');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Only Mentions'),
                trailing: _notificationSetting == 'Mentions Only' ? const Icon(Icons.check, color: Color(0xFF3B82F6)) : null,
                onTap: () {
                  setState(() => _notificationSetting = 'Mentions Only');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Mute Always'),
                trailing: _notificationSetting == 'Muted' ? const Icon(Icons.check, color: Color(0xFF3B82F6)) : null,
                onTap: () {
                  setState(() {
                    _notificationSetting = 'Muted';
                    _isMuted = true;
                  });
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

  void _confirmExitGroup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Group?'),
        content: const Text('You will no longer receive messages or updates from this group.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await ref.read(chatRepositoryProvider).leaveGroup(widget.channelId);
              if (mounted) {
                nav.pop();
                if (context.mounted) context.pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  void _confirmReportGroup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Group'),
        content: const Text('Are you sure you want to report this group for violating community guidelines?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report submitted. Thank you for keeping our community safe.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }
}
