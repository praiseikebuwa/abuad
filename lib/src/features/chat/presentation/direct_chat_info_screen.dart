import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';
import '../data/chat_repository.dart';
import '../domain/chat_channel.dart';
import '../domain/chat_message.dart';
import '../../user/data/user_repository.dart';
import '../../../core/utils/url_validator.dart';
import '../../feed/presentation/widgets/document_viewer_screen.dart';

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
  bool _isUserBlocked = false;

  final List<String> _themeOptions = ['Indigo', 'Teal', 'Blue', 'Purple', 'Rose', 'Emerald'];
  Future<ChatChannel?>? _channelFuture;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _channelFuture = ref.read(chatRepositoryProvider).getChannel(widget.channelId);
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final muted = prefs.getBool('chat_muted_${widget.channelId}') ?? false;
      final notif = prefs.getString('chat_notifications_${widget.channelId}') ?? (muted ? 'Muted' : 'On / Custom');
      final disappearing = prefs.getString('chat_disappearing_${widget.channelId}') ?? 'Off';
      final theme = prefs.getString('chat_theme_${widget.channelId}') ?? 'Indigo';

      if (mounted) {
        setState(() {
          _isMuted = muted;
          _notificationSetting = notif;
          _disappearingMessages = disappearing;
          _chatTheme = theme;
        });
      }

      if (widget.otherUserId != null && widget.otherUserId!.isNotEmpty) {
        final blocked = prefs.getBool('blocked_user_${widget.otherUserId}') ?? false;
        if (mounted) {
          setState(() {
            _isUserBlocked = blocked;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading chat info settings: $e');
    }
  }

  Future<void> _saveNotificationSetting(String setting, bool isMuted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_notifications_${widget.channelId}', setting);
    await prefs.setBool('chat_muted_${widget.channelId}', isMuted);
    setState(() {
      _notificationSetting = setting;
      _isMuted = isMuted;
    });
  }

  Future<void> _saveDisappearingSetting(String opt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_disappearing_${widget.channelId}', opt);
    setState(() {
      _disappearingMessages = opt;
    });
  }

  Future<void> _saveThemeSetting(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_theme_${widget.channelId}', themeName);
    setState(() {
      _chatTheme = themeName;
    });
  }

  Future<void> _toggleBlockUser(String targetUserId, String displayName) async {
    final repo = ref.read(chatRepositoryProvider);
    if (_isUserBlocked) {
      await repo.unblockUser(targetUserId);
      setState(() => _isUserBlocked = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$displayName has been unblocked.')),
        );
      }
    } else {
      await repo.blockUser(targetUserId);
      setState(() => _isUserBlocked = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$displayName has been blocked.')),
        );
      }
    }
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
        final currentUserId = repo.currentUserId;

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
                : (channel?.memberNames[targetUserId] ?? 'User'));

        final handle = otherUser?.handle.isNotEmpty == true
            ? otherUser!.handle.replaceAll('@', '')
            : 'user';

        final subtitle = otherUser?.department != null && otherUser!.department!.isNotEmpty
            ? '@$handle • ${otherUser.department}'
            : '@$handle';

        final avatarUrl = otherUser?.avatarUrl ?? channel?.memberAvatars[targetUserId] ?? channel?.displayAvatarUrl;
        final isOnline = otherUser?.status == 'online';

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
                    _toggleBlockUser(targetUserId, displayName);
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
                        Icon(
                          _isUserBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                          size: 20,
                          color: _isUserBlocked ? Colors.blue : Colors.red,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isUserBlocked ? 'Unblock $displayName' : 'Block $displayName',
                          style: TextStyle(color: _isUserBlocked ? Colors.blue : Colors.red),
                        ),
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

                // Quick Action Buttons
                _buildActionButtonsRow(
                  buttonBg: actionButtonBg,
                  textPrimary: textPrimary,
                  displayName: displayName,
                  targetUserId: targetUserId,
                ),

                const SizedBox(height: 20),

                // Real Interactive Shared Media Card
                _buildRealSharedMediaCard(
                  repo: repo,
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
                  targetUserId: targetUserId,
                  cardColor: cardColor,
                  cardBorderColor: cardBorderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),

                const SizedBox(height: 16),

                // Real Groups in Common Card
                _buildRealGroupsInCommonCard(
                  targetUserId: targetUserId,
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
                  targetUserId: targetUserId,
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
          icon: _isMuted ? Icons.notifications_off_rounded : Icons.notifications_rounded,
          label: _isMuted ? 'Muted' : 'Mute',
          bg: buttonBg,
          textPrimary: textPrimary,
          isActive: _isMuted,
          onTap: () {
            final nextMuted = !_isMuted;
            _saveNotificationSetting(nextMuted ? 'Muted' : 'On / Custom', nextMuted);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(nextMuted ? 'Chat muted' : 'Chat unmuted')),
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

  Widget _buildRealSharedMediaCard({
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
              (m.audioUrl != null && m.audioUrl!.isNotEmpty) ||
              content.startsWith('http') ||
              content.contains('www.') ||
              content.contains('.pdf') ||
              content.contains('.docx');
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
                      'Shared Media',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    if (mediaItems.isNotEmpty)
                      GestureDetector(
                        onTap: () => _openSharedMediaGallery(mediaItems, isDark, textPrimary),
                        child: Row(
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
                      final isDoc = item.type == 'document' ||
                          item.content.contains('.pdf') ||
                          item.content.contains('.docx') ||
                          item.content.contains('.txt');
                      final isLink = item.content.startsWith('http') || item.content.contains('www.');
                      final url = item.imageUrl ?? item.audioUrl ?? (isLink ? item.content : '');

                      IconData icon = Icons.image_rounded;
                      Color iconColor = const Color(0xFF10B981);
                      String title = item.content.isNotEmpty ? item.content : 'Image';

                      if (isDoc) {
                        icon = item.content.contains('.pdf')
                            ? Icons.picture_as_pdf_rounded
                            : Icons.description_rounded;
                        iconColor = item.content.contains('.pdf')
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF2563EB);
                        title = item.content.replaceFirst('📄 Document:', '').trim();
                      } else if (isLink) {
                        icon = Icons.link_rounded;
                        iconColor = const Color(0xFF3B82F6);
                      }

                      return GestureDetector(
                        onTap: () => _handleSharedMediaItemClick(item, url, isDoc, isLink, title),
                        child: _buildMediaThumbnail(
                          title: title,
                          icon: icon,
                          iconColor: iconColor,
                          imageUrl: (item.type == 'image' || item.imageUrl != null) ? url : null,
                          isDark: isDark,
                        ),
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

  void _handleSharedMediaItemClick(ChatMessage item, String url, bool isDoc, bool isLink, String title) {
    if (isDoc) {
      final docUrl = url.isNotEmpty ? url : item.content;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentViewerScreen(
            documentUrl: docUrl,
            title: title.isNotEmpty ? title : 'Document',
          ),
        ),
      );
    } else if (isLink) {
      final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
      canLaunchUrl(uri).then((can) {
        if (can) launchUrl(uri, mode: LaunchMode.externalApplication);
      });
    } else if (url.isNotEmpty) {
      // Full screen image preview dialog
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              PhotoView(
                imageProvider: NetworkImage(url),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _openSharedMediaGallery(List<ChatMessage> mediaItems, bool isDark, Color textPrimary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Text('Shared Media Gallery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textPrimary)),
                  const SizedBox(height: 12),
                  TabBar(
                    labelColor: const Color(0xFF3B82F6),
                    unselectedLabelColor: isDark ? Colors.white60 : Colors.grey[600],
                    indicatorColor: const Color(0xFF3B82F6),
                    tabs: const [
                      Tab(text: 'Media'),
                      Tab(text: 'Documents'),
                      Tab(text: 'Links'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Media Tab
                        _buildGalleryGrid(
                          items: mediaItems.where((m) => m.type == 'image' || m.imageUrl != null || m.type == 'video').toList(),
                          isDark: isDark,
                        ),
                        // Docs Tab
                        _buildGalleryDocsList(
                          items: mediaItems.where((m) => m.type == 'document' || m.content.contains('.pdf') || m.content.contains('.docx')).toList(),
                          isDark: isDark,
                          textPrimary: textPrimary,
                        ),
                        // Links Tab
                        _buildGalleryLinksList(
                          items: mediaItems.where((m) => m.content.startsWith('http') || m.content.contains('www.')).toList(),
                          isDark: isDark,
                          textPrimary: textPrimary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGalleryGrid({required List<ChatMessage> items, required bool isDark}) {
    if (items.isEmpty) {
      return const Center(child: Text('No media items shared yet'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final url = item.imageUrl ?? item.audioUrl ?? '';
        return GestureDetector(
          onTap: () => _handleSharedMediaItemClick(item, url, false, false, 'Media'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: url.isNotEmpty
                ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
                : Container(color: isDark ? Colors.white10 : Colors.grey[200], child: const Icon(Icons.image_rounded)),
          ),
        );
      },
    );
  }

  Widget _buildGalleryDocsList({required List<ChatMessage> items, required bool isDark, required Color textPrimary}) {
    if (items.isEmpty) {
      return const Center(child: Text('No documents shared yet'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final docUrl = item.imageUrl ?? item.audioUrl ?? item.content;
        final title = item.content.replaceFirst('📄 Document:', '').trim();
        final isPdf = title.contains('.pdf');

        return ListTile(
          leading: Icon(
            isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
            color: isPdf ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
            size: 32,
          ),
          title: Text(title.isNotEmpty ? title : 'Document', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
          subtitle: Text(item.timestamp.toString().split('.')[0], style: const TextStyle(fontSize: 12)),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DocumentViewerScreen(documentUrl: docUrl, title: title),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGalleryLinksList({required List<ChatMessage> items, required bool isDark, required Color textPrimary}) {
    if (items.isEmpty) {
      return const Center(child: Text('No links shared yet'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final url = item.content;
        return ListTile(
          leading: const Icon(Icons.link_rounded, color: Color(0xFF3B82F6), size: 30),
          title: Text(url, style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () {
            final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
            canLaunchUrl(uri).then((can) {
              if (can) launchUrl(uri, mode: LaunchMode.externalApplication);
            });
          },
        );
      },
    );
  }

  Widget _buildMediaThumbnail({
    required String title,
    required IconData icon,
    required Color iconColor,
    String? imageUrl,
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl != null && imageUrl.isNotEmpty && UrlValidator.isValidUrl(imageUrl)
                ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
                : Center(child: Icon(icon, size: 30, color: iconColor)),
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
    required String targetUserId,
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

          // Block / Unblock Option
          _buildSettingsTile(
            leadingIcon: _isUserBlocked ? Icons.lock_open_rounded : Icons.error_rounded,
            iconColor: _isUserBlocked ? const Color(0xFF2563EB) : const Color(0xFFDC2626),
            title: _isUserBlocked ? 'Unblock $displayName' : 'Block $displayName',
            value: _isUserBlocked ? 'Blocked' : 'Active',
            isDestructive: !_isUserBlocked,
            onTap: () => _toggleBlockUser(targetUserId, displayName),
            textPrimary: _isUserBlocked ? const Color(0xFF2563EB) : const Color(0xFFDC2626),
            textSecondary: _isUserBlocked ? const Color(0xFF2563EB) : const Color(0xFFDC2626),
          ),
        ],
      ),
    );
  }

  Widget _buildRealGroupsInCommonCard({
    required String targetUserId,
    required Color cardColor,
    required Color cardBorderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    final channelsAsync = ref.watch(chatChannelsProvider);
    final allChannels = channelsAsync.value ?? [];
    final commonGroups = allChannels.where((c) => c.type == 'group' && c.memberIds.contains(targetUserId)).toList();

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
            'Groups in Common (${commonGroups.length})',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          if (commonGroups.isEmpty)
            Text(
              'No groups in common',
              style: TextStyle(fontSize: 13, color: textSecondary),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: commonGroups.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final group = commonGroups[index];
                return InkWell(
                  onTap: () => context.push('/chat/${group.id}'),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF059669),
                        child: Text(
                          group.displayName?.isNotEmpty == true ? group.displayName![0].toUpperCase() : 'G',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.displayName ?? 'Group',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${group.memberIds.length} Members',
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
              },
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
    required String targetUserId,
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
            onTap: () => _toggleBlockUser(targetUserId, displayName),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _isUserBlocked ? 'Unblock $displayName' : 'Block $displayName',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _isUserBlocked ? const Color(0xFF2563EB) : const Color(0xFFDC2626),
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
                  _saveNotificationSetting('On / Custom', false);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Mute Always'),
                trailing: _notificationSetting == 'Muted' ? const Icon(Icons.check, color: Color(0xFF3B82F6)) : null,
                onTap: () {
                  _saveNotificationSetting('Muted', true);
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
                    _saveDisappearingSetting(opt);
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
                    _saveThemeSetting(themeName);
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
        content: const Text('Messages will be removed from your chat history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              await ref.read(chatRepositoryProvider).clearChannelMessages(widget.channelId);
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Chat history cleared.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
