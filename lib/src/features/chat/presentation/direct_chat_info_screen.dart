import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/chat_repository.dart';
import '../domain/chat_channel.dart';
import '../../user/data/user_repository.dart';
import '../../../core/utils/url_validator.dart';

class DirectChatInfoScreen extends ConsumerStatefulWidget {
  final String channelId;
  final String? otherUserId;

  const DirectChatInfoScreen({
    super.key,
    required this.channelId,
    this.otherUserId,
  });

  @override
  ConsumerState<DirectChatInfoScreen> createState() => _DirectChatInfoScreenState();
}

class _DirectChatInfoScreenState extends ConsumerState<DirectChatInfoScreen> {
  bool _isMuted = false;
  String _notificationSetting = 'On / Custom';
  String _disappearingMessages = 'Off';
  String _chatTheme = 'Indigo';

  final List<String> _themeOptions = ['Indigo', 'Teal', 'Blue', 'Purple', 'Rose', 'Emerald'];

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
        final currentUserId = repo.currentUserId;
        
        // Find other user ID
        final targetUserId = widget.otherUserId ??
            (channel?.memberIds.firstWhere(
                  (id) => id != currentUserId,
                  orElse: () => '',
                ) ??
                '');

        final otherUserAsync = targetUserId.isNotEmpty ? ref.watch(userProvider(targetUserId)) : null;
        final otherUser = otherUserAsync?.value;

        final displayName = otherUser?.displayName ??
            (channel?.displayName != null && channel?.displayName != 'Direct Message'
                ? channel!.displayName!
                : (channel?.memberNames[targetUserId] ?? 'Aria Park'));

        final handle = otherUser?.handle.isNotEmpty == true
            ? otherUser!.handle.replaceAll('@', '')
            : 'aria_park';

        final subtitle = otherUser?.department != null && otherUser!.department!.isNotEmpty
            ? '@$handle • ${otherUser.department}'
            : '@$handle • 3rd Year Biology Major';

        final avatarUrl = otherUser?.avatarUrl ?? channel?.memberAvatars[targetUserId] ?? channel?.displayAvatarUrl;
        final isOnline = otherUser?.status == 'online' || true;

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
              'Chat Settings',
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
                  if (val == 'profile' && targetUserId.isNotEmpty) {
                    context.push('/profile/$targetUserId');
                  } else if (val == 'clear') {
                    _confirmClearChat();
                  } else if (val == 'block') {
                    _confirmBlockUser(displayName);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 20),
                        SizedBox(width: 10),
                        Text('View Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 20),
                        SizedBox(width: 10),
                        Text('Clear Chat'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        const Icon(Icons.block_rounded, size: 20, color: Colors.red),
                        const SizedBox(width: 10),
                        Text('Block $displayName', style: const TextStyle(color: Colors.red)),
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
                // Profile Avatar & Name Header
                _buildProfileHeader(
                  displayName: displayName,
                  subtitle: subtitle,
                  avatarUrl: avatarUrl,
                  isOnline: isOnline,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),

                const SizedBox(height: 20),

                // 4 Round Quick Action Buttons
                _buildActionButtonsRow(
                  buttonBg: actionButtonBg,
                  textPrimary: textPrimary,
                  displayName: displayName,
                  targetUserId: targetUserId,
                ),

                const SizedBox(height: 20),

                // Shared Media Card
                _buildSharedMediaCard(
                  cardColor: cardColor,
                  cardBorderColor: cardBorderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),

                const SizedBox(height: 16),

                // Chat Settings & Preferences Card
                _buildSettingsCard(
                  displayName: displayName,
                  cardColor: cardColor,
                  cardBorderColor: cardBorderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),

                const SizedBox(height: 16),

                // Groups in Common Card
                _buildGroupsInCommonCard(
                  cardColor: cardColor,
                  cardBorderColor: cardBorderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),

                const SizedBox(height: 16),

                // Search & Encryption Security Card
                _buildSecurityCard(
                  cardColor: cardColor,
                  cardBorderColor: cardBorderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),

                const SizedBox(height: 16),

                // Destructive Actions Card
                _buildDestructiveActionsCard(
                  displayName: displayName,
                  isDark: isDark,
                ),

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
    required String subtitle,
    required String? avatarUrl,
    required bool isOnline,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(43),
                child: avatarUrl != null && avatarUrl.isNotEmpty && UrlValidator.isValidUrl(avatarUrl)
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Center(
                          child: Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ),
              ),
            ),
            // Online Green Indicator Dot
            if (isOnline)
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      width: 2.5,
                    ),
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
          subtitle,
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

  Widget _buildActionButtonsRow({
    required Color buttonBg,
    required Color textPrimary,
    required String displayName,
    required String targetUserId,
  }) {
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
              SnackBar(content: Text('Calling $displayName...')),
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
              SnackBar(content: Text('Starting video call with $displayName...')),
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
              SnackBar(content: Text(_isMuted ? 'Chat muted' : 'Chat unmuted')),
            );
          },
        ),
        _buildActionButton(
          icon: Icons.person_rounded,
          label: 'Profile',
          bg: buttonBg,
          textPrimary: textPrimary,
          onTap: () {
            if (targetUserId.isNotEmpty) {
              context.push('/profile/$targetUserId');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening user profile...')),
              );
            }
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

  Widget _buildSharedMediaCard({
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
                  'Shared Media',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening shared media gallery...')),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        'View All (28)',
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
                  title: 'biology_lab.pdf',
                  icon: Icons.picture_as_pdf_rounded,
                  iconColor: const Color(0xFFEF4444),
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _buildMediaThumbnail(
                  title: 'Art gallery photo',
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

  Widget _buildSettingsCard({
    required String displayName,
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
          // Notifications
          _buildSettingsTile(
            leadingIcon: Icons.notifications_rounded,
            iconColor: const Color(0xFF6366F1),
            title: 'Notifications',
            value: _notificationSetting,
            onTap: _showNotificationOptions,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          _buildDivider(isDark),

          // Disappearing Messages
          _buildSettingsTile(
            leadingIcon: Icons.timer_outlined,
            iconColor: const Color(0xFF06B6D4),
            title: 'Disappearing Messages',
            value: _disappearingMessages,
            onTap: _showDisappearingMessagesOptions,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          _buildDivider(isDark),

          // Chat Theme
          _buildSettingsTile(
            leadingIcon: Icons.palette_rounded,
            iconColor: const Color(0xFF8B5CF6),
            title: 'Chat Theme',
            value: _chatTheme,
            onTap: _showThemePicker,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          _buildDivider(isDark),

          // Block Option
          _buildSettingsTile(
            leadingIcon: Icons.error_rounded,
            iconColor: const Color(0xFFDC2626),
            title: 'Block $displayName',
            value: 'warn/danger',
            isDestructive: true,
            onTap: () => _confirmBlockUser(displayName),
            textPrimary: const Color(0xFFDC2626),
            textSecondary: const Color(0xFFDC2626),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsInCommonCard({
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
          Text(
            'Groups in Common (3)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _buildGroupInCommonItem(
            name: 'MTH 205 — Mathematics',
            membersCount: '128 Members',
            color: const Color(0xFF059669),
            icon: Icons.calculate_rounded,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _buildGroupInCommonItem(
            name: 'Biology Study Group',
            membersCount: '14 Members',
            color: const Color(0xFF2563EB),
            icon: Icons.biotech_rounded,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildGroupInCommonItem({
    required String name,
    required String membersCount,
    required Color color,
    required IconData icon,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  membersCount,
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard({
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
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 20, color: textSecondary),
                  const SizedBox(width: 12),
                  Text(
                    'Search in Chat',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildDivider(isDark),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 20, color: textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Encryption & Security',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF22C55E)),
                    const SizedBox(width: 4),
                    Text(
                      'Verified',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestructiveActionsCard({
    required String displayName,
    required bool isDark,
  }) {
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
            onTap: _confirmClearChat,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Clear Chat History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ),
          ),
          _buildDivider(isDark),
          InkWell(
            onTap: () => _confirmBlockUser(displayName),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Block $displayName',
                  style: const TextStyle(
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

  Widget _buildSettingsTile({
    required IconData leadingIcon,
    required Color iconColor,
    required String title,
    required String value,
    required VoidCallback onTap,
    required Color textPrimary,
    required Color textSecondary,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(leadingIcon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDestructive ? const Color(0xFFDC2626) : textPrimary,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDestructive ? const Color(0xFFDC2626) : textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDestructive ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
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
              const Text('Notification Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('All Messages'),
                trailing: _notificationSetting == 'On / Custom' ? const Icon(Icons.check, color: Color(0xFF3B82F6)) : null,
                onTap: () {
                  setState(() => _notificationSetting = 'On / Custom');
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

  void _showDisappearingMessagesOptions() {
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
              const Text('Disappearing Messages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 12),
              for (final opt in ['Off', '24 Hours', '7 Days', '90 Days'])
                ListTile(
                  title: Text(opt),
                  trailing: _disappearingMessages == opt ? const Icon(Icons.check, color: Color(0xFF3B82F6)) : null,
                  onTap: () {
                    setState(() => _disappearingMessages = opt);
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

  void _showThemePicker() {
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
              const Text('Chat Theme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 12),
              for (final themeName in _themeOptions)
                ListTile(
                  title: Text(themeName),
                  trailing: _chatTheme == themeName ? const Icon(Icons.check, color: Color(0xFF3B82F6)) : null,
                  onTap: () {
                    setState(() => _chatTheme = themeName);
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

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History?'),
        content: const Text('Messages will be removed from your device. Other participants will still be able to see them.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat history cleared.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _confirmBlockUser(String displayName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Block $displayName?'),
        content: Text('Blocked contacts will no longer be able to call you or send you messages.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$displayName has been blocked.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }
}
