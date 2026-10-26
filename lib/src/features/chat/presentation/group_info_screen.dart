import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/chat_repository.dart';
import '../domain/chat_channel.dart';
import '../domain/chat_message.dart';
import '../../user/data/user_repository.dart';
import '../../../core/services/image_upload_service.dart';
import '../../../core/utils/url_validator.dart';
import '../../../core/theme/app_colors.dart';
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
  Future<ChatChannel?>? _channelFuture;
  bool _isSearchingMembers = false;
  String _memberSearchQuery = '';

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
    final cardColor = isDark ? Colors.black : Colors.white;
    final cardBorderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);
    final actionButtonBg = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final cached = repo.getCachedChannel(widget.channelId);
    _channelFuture ??= repo.getChannel(widget.channelId);

    return FutureBuilder<ChatChannel?>(
      future: _channelFuture,
      initialData: cached,
      builder: (context, snapshot) {
        final channel = snapshot.data ?? cached;
        if (channel == null && snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: backgroundColor,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (channel == null) {
          return Scaffold(
            backgroundColor: backgroundColor,
            appBar: AppBar(backgroundColor: backgroundColor, elevation: 0),
            body: Center(
              child: Text('Group not found', style: TextStyle(color: textPrimary, fontSize: 16)),
            ),
          );
        }

        final displayName = channel.displayName?.isNotEmpty == true ? channel.displayName! : 'Group';
        final memberCount = channel.memberIds.length;
        final createdByName = channel.createdBy != null
            ? (channel.memberNames[channel.createdBy] ?? 'Admin')
            : 'Admin';

        final avatars = channel.memberAvatars.values
            .where((a) => a != null && a.isNotEmpty && UrlValidator.isValidUrl(a))
            .cast<String>()
            .toList();

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
                    _shareGroupLink(displayName);
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
                  createdByName: createdByName,
                  avatars: avatars,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),

                const SizedBox(height: 20),

                // 4 Round Quick Action Buttons
                _buildActionButtonsRow(actionButtonBg, textPrimary, displayName),

                const SizedBox(height: 20),

                // Description Card
                _buildDescriptionCard(
                  displayName: displayName,
                  createdByName: createdByName,
                  cardColor: cardColor,
                  cardBorderColor: cardBorderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),

                const SizedBox(height: 16),

                // Media, Docs & Links Card (Live Messages)
                _buildRealMediaDocsLinksCard(
                  repo: repo,
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

                // Real Dynamic Members Card
                _buildRealMembersCard(
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
    required String createdByName,
    required List<String> avatars,
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
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(43),
                child: _buildAvatarCollage(avatars, displayName),
              ),
            ),
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
          '$memberCount Members • Created by $createdByName',
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

  Widget _buildAvatarCollage(List<String> avatars, String displayName) {
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
    return Center(
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'G',
        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
      ),
    );
  }

  Widget _buildActionButtonsRow(Color buttonBg, Color textPrimary, String displayName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
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
        _buildActionButton(
          icon: Icons.share_rounded,
          label: 'Share Link',
          bg: buttonBg,
          textPrimary: textPrimary,
          onTap: () => _shareGroupLink(displayName),
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
    required String displayName,
    required String createdByName,
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
            'Official group for $displayName. Share updates, discussions, resources, and announcements here.',
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
                  'Created by $createdByName',
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

  Widget _buildRealMediaDocsLinksCard({
    required ChatRepository repo,
    required Color cardColor,
    required Color cardBorderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return StreamBuilder<List<ChatMessage>>(
      stream: repo.watchMessages(widget.channelId),
      builder: (context, snapshot) {
        final messages = snapshot.data ?? [];
        final mediaItems = messages.where((m) {
          final type = m.type;
          final content = m.content.toLowerCase();
          return type == 'document' ||
              type == 'image' ||
              type == 'video' ||
              (m.imageUrl != null && m.imageUrl!.isNotEmpty) ||
              content.startsWith('http') ||
              content.contains('www.') ||
              content.contains('.pdf');
        }).toList();

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
                    if (mediaItems.isNotEmpty)
                      Row(
                        children: [
                          Text(
                            'View All (${mediaItems.length})',
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
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (mediaItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'No shared media or documents yet',
                    style: TextStyle(fontSize: 13, color: textSecondary),
                  ),
                )
              else
                SizedBox(
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: mediaItems.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = mediaItems[index];
                      final isPdf = item.type == 'document' || item.content.contains('.pdf');
                      final isLink = item.content.startsWith('http') || item.content.contains('www.');

                      IconData icon = Icons.image_rounded;
                      Color iconColor = const Color(0xFF10B981);
                      String title = item.content.isNotEmpty ? item.content : 'Image';

                      if (isPdf) {
                        icon = Icons.picture_as_pdf_rounded;
                        iconColor = const Color(0xFFEF4444);
                        title = item.content.replaceFirst('📄 Document:', '').trim();
                      } else if (isLink) {
                        icon = Icons.link_rounded;
                        iconColor = const Color(0xFF3B82F6);
                      }

                      return _buildMediaThumbnail(
                        title: title,
                        icon: icon,
                        iconColor: iconColor,
                        isDark: isDark,
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
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
            title: 'Group Wallpaper / Background',
            trailing: const Icon(Icons.wallpaper_rounded, color: Color(0xFF94A3B8)),
            onTap: () => _showWallpaperPicker(context, isDark),
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

  Widget _buildRealMembersCard({
    required ChatChannel channel,
    required Color cardColor,
    required Color cardBorderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    final memberIds = channel.memberIds;
    final filteredIds = memberIds.where((uid) {
      if (_memberSearchQuery.isEmpty) return true;
      final name = (channel.memberNames[uid] ?? '').toLowerCase();
      return name.contains(_memberSearchQuery.toLowerCase());
    }).toList();

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
                'Members (${filteredIds.length})',
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
                    onTap: () => _showAddMemberSheet(context, channel),
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderPillButton(
                    icon: _isSearchingMembers ? Icons.close_rounded : Icons.search_rounded,
                    label: _isSearchingMembers ? 'Close' : 'Search',
                    isDark: isDark,
                    onTap: () {
                      setState(() {
                        _isSearchingMembers = !_isSearchingMembers;
                        if (!_isSearchingMembers) _memberSearchQuery = '';
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          if (_isSearchingMembers) ...[
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search members by name...',
                hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 18),
                filled: true,
                fillColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _memberSearchQuery = val),
            ),
          ],
          const SizedBox(height: 16),

          // Real Member List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredIds.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 0.5,
              indent: 52,
              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
            ),
            itemBuilder: (context, index) {
              final uid = filteredIds[index];
              final name = channel.memberNames[uid] ?? 'Member';
              final avatar = channel.memberAvatars[uid];
              final isAdmin = channel.adminIds.contains(uid);
              final isOwner = uid == channel.createdBy;

              String? roleBadge;
              if (isOwner) {
                roleBadge = 'Owner';
              } else if (isAdmin) {
                roleBadge = 'Admin';
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF6366F1),
                      backgroundImage: avatar != null && avatar.isNotEmpty && UrlValidator.isValidUrl(avatar)
                          ? CachedNetworkImageProvider(avatar)
                          : null,
                      child: avatar == null || avatar.isEmpty
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            )
                          : null,
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
                          if (roleBadge != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              roleBadge,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
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

  Future<void> _shareGroupLink(String displayName) async {
    final link = 'https://abuadapp.com.ng/join/group/${widget.channelId}';
    await SharePlus.instance.share(
      ShareParams(
        text: 'Join our ABUAD campus group "$displayName" on ABUAD Life:\n$link',
        subject: 'Join $displayName on ABUAD Life',
      ),
    );
  }

  Future<void> _showWallpaperPicker(BuildContext context, bool isDark) async {
    final repo = ref.read(chatRepositoryProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.black : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Group Wallpaper & Background',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Set a custom background image for all members of this group.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: AppColors.secondaryTeal),
                  ),
                  title: const Text('Choose Photo from Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Upload a custom group photo or campus banner', style: TextStyle(fontSize: 12)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      final imageService = ref.read(imageUploadServiceProvider);
                      final file = await imageService.pickImage();
                      if (file != null) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Setting group wallpaper...')),
                        );
                        final uploadResult = await imageService.uploadImage(file, path: 'chat_wallpapers/${widget.channelId}/');
                        await repo.updateGroupWallpaper(widget.channelId, uploadResult.url);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Group wallpaper updated successfully!')),
                          );
                        }
                      }
                    } catch (e) {
                      debugPrint('Error uploading group wallpaper: $e');
                    }
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.palette_rounded, color: Colors.purple),
                  ),
                  title: const Text('ABUAD Emerald Campus Preset', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Official ABUAD green and gold mesh style', style: TextStyle(fontSize: 12)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await repo.updateGroupWallpaper(widget.channelId, 'preset_emerald');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ABUAD Emerald wallpaper applied!')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.restart_alt_rounded, color: Colors.red),
                  ),
                  title: const Text('Reset to Default Wallpaper', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('chat_wallpaper_${widget.channelId}');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Wallpaper reset to default.')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddMemberSheet(BuildContext context, ChatChannel channel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _AddMemberModal(
          channel: channel,
          onMembersAdded: () {
            setState(() {
              _channelFuture = ref.read(chatRepositoryProvider).getChannel(widget.channelId);
            });
          },
        );
      },
    );
  }
}

class _AddMemberModal extends ConsumerStatefulWidget {
  final ChatChannel channel;
  final VoidCallback onMembersAdded;

  const _AddMemberModal({required this.channel, required this.onMembersAdded});

  @override
  ConsumerState<_AddMemberModal> createState() => _AddMemberModalState();
}

class _AddMemberModalState extends ConsumerState<_AddMemberModal> {
  final _searchController = TextEditingController();
  final Set<String> _selectedUids = {};
  List<AppUser> _searchResults = [];
  bool _isLoading = false;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _loadInitialUsers();
  }

  Future<void> _loadInitialUsers() async {
    setState(() => _isLoading = true);
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final users = await userRepo.searchUsers('');
      final existingIds = widget.channel.memberIds.toSet();
      if (mounted) {
        setState(() {
          _searchResults = users.where((u) => !existingIds.contains(u.uid)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final users = await userRepo.searchUsers(query);
      final existingIds = widget.channel.memberIds.toSet();
      if (mounted) {
        setState(() {
          _searchResults = users.where((u) => !existingIds.contains(u.uid)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.white60 : Colors.black54;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Members',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  if (_selectedUids.isNotEmpty)
                    TextButton(
                      onPressed: _isAdding ? null : () async {
                        final nav = Navigator.of(context);
                        final selected = _selectedUids.toList();
                        setState(() => _isAdding = true);
                        try {
                          final success = await ref
                              .read(chatRepositoryProvider)
                              .addMembersToGroup(widget.channel.id, selected);
                          if (!mounted) return;
                          setState(() => _isAdding = false);
                          if (success) {
                            widget.onMembersAdded();
                            nav.pop();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added ${selected.length} member(s) to group'),
                                  backgroundColor: AppColors.secondaryTeal,
                                ),
                              );
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to add members. Please try again.'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) setState(() => _isAdding = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error adding members: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.secondaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: _isAdding
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('Add (${_selectedUids.length})'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search students by name or matric...',
                  hintStyle: TextStyle(color: textSecondary),
                  prefixIcon: Icon(Icons.search_rounded, color: textSecondary),
                  filled: true,
                  fillColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: _onSearch,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                      ? Center(
                          child: Text(
                            'No eligible students found to add',
                            style: TextStyle(color: textSecondary),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                          itemBuilder: (context, index) {
                            final user = _searchResults[index];
                            final isChecked = _selectedUids.contains(user.uid);
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                                    ? CachedNetworkImageProvider(user.avatarUrl!)
                                    : null,
                                backgroundColor: AppColors.secondaryTeal.withValues(alpha: 0.2),
                                child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                                    ? Text(
                                        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                              title: Text(
                                user.displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                user.department ?? '@${user.handle}',
                                style: TextStyle(color: textSecondary, fontSize: 12),
                              ),
                              trailing: Checkbox(
                                value: isChecked,
                                activeColor: AppColors.secondaryTeal,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedUids.add(user.uid);
                                    } else {
                                      _selectedUids.remove(user.uid);
                                    }
                                  });
                                },
                              ),
                              onTap: () {
                                setState(() {
                                  if (isChecked) {
                                    _selectedUids.remove(user.uid);
                                  } else {
                                    _selectedUids.add(user.uid);
                                  }
                                });
                              },
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}
