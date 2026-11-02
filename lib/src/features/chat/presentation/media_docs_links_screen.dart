import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../data/chat_repository.dart';
import '../domain/chat_message.dart';

class MediaDocsLinksScreen extends ConsumerStatefulWidget {
  final String channelId;
  final String channelName;
  final int initialTabIndex;

  const MediaDocsLinksScreen({
    super.key,
    required this.channelId,
    required this.channelName,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<MediaDocsLinksScreen> createState() => _MediaDocsLinksScreenState();
}

class _MediaDocsLinksScreenState extends ConsumerState<MediaDocsLinksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryTeal = const Color(0xFF14B8A6);

    final repo = ref.watch(chatRepositoryProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Media, Docs & Links',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            Text(
              widget.channelName,
              style: TextStyle(
                color: textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: primaryTeal,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(3),
              tabs: const [
                Tab(text: 'Media'),
                Tab(text: 'Docs'),
                Tab(text: 'Links'),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<ChatMessage>>(
        stream: repo.watchMessages(widget.channelId),
        builder: (context, snapshot) {
          final allMessages = snapshot.data ?? repo.getCachedMessages(widget.channelId);

          // Extract Media
          final mediaList = allMessages.where((m) {
            final isImg = m.type == 'image' || (m.imageUrl != null && m.imageUrl!.isNotEmpty);
            final isVid = m.type == 'video';
            final isSnap = m.isSnap;
            return isImg || isVid || isSnap;
          }).toList();

          // Extract Docs
          final docsList = allMessages.where((m) {
            final content = m.content.toLowerCase();
            return m.type == 'document' ||
                m.type == 'file' ||
                content.contains('.pdf') ||
                content.contains('.docx') ||
                content.contains('.xlsx') ||
                content.contains('.pptx') ||
                content.contains('📄 document:');
          }).toList();

          // Extract Links
          final linksList = allMessages.where((m) {
            final content = m.content;
            return content.contains('http://') ||
                content.contains('https://') ||
                content.contains('www.');
          }).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildMediaTab(mediaList, isDark, textPrimary, textSecondary),
              _buildDocsTab(docsList, isDark, cardColor, textPrimary, textSecondary),
              _buildLinksTab(linksList, isDark, cardColor, textPrimary, textSecondary),
            ],
          );
        },
      ),
    );
  }

  // ── 1. MEDIA TAB ──────────────────────────────────────────────────────────

  Widget _buildMediaTab(
    List<ChatMessage> mediaList,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (mediaList.isEmpty) {
      return _buildEmptyState(
        icon: Icons.photo_library_outlined,
        title: 'No media shared',
        subtitle: 'Photos, videos and snaps shared in this chat will appear here.',
        textPrimary: textPrimary,
        textSecondary: textSecondary,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: mediaList.length,
      itemBuilder: (context, index) {
        final item = mediaList[index];
        final url = item.imageUrl ?? (item.content.startsWith('http') ? item.content : null);
        final isVideo = item.type == 'video' || item.content.contains('Video');

        return InkWell(
          onTap: () {
            if (url != null) {
              _openFullScreenMediaViewer(context, url, isVideo: isVideo);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (url != null)
                  CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (_, _, _) => Container(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                    ),
                  )
                else
                  Container(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    child: const Icon(Icons.photo_rounded, color: Colors.teal),
                  ),

                if (isVideo)
                  Container(
                    alignment: Alignment.bottomRight,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 22),
                  ),

                if (item.isSnap)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 12),
                          SizedBox(width: 2),
                          Text('Snap', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 2. DOCS TAB ───────────────────────────────────────────────────────────

  Widget _buildDocsTab(
    List<ChatMessage> docsList,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (docsList.isEmpty) {
      return _buildEmptyState(
        icon: Icons.description_outlined,
        title: 'No documents shared',
        subtitle: 'PDFs, assignments, and study materials shared will appear here.',
        textPrimary: textPrimary,
        textSecondary: textSecondary,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: docsList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final doc = docsList[index];
        final cleanTitle = doc.content.replaceFirst('📄 Document:', '').trim();
        final isPdf = cleanTitle.toLowerCase().contains('.pdf');
        final formattedDate = DateFormat('MMM d, yyyy · h:mm a').format(doc.timestamp);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              width: 0.6,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPdf
                      ? Colors.red.withValues(alpha: 0.12)
                      : Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPdf ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
                  color: isPdf ? Colors.redAccent : Colors.blueAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cleanTitle.isNotEmpty ? cleanTitle : 'Document',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined, size: 20),
                color: textSecondary,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Share.share(cleanTitle, subject: 'Shared Document from $widget.channelName');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 3. LINKS TAB ──────────────────────────────────────────────────────────

  Widget _buildLinksTab(
    List<ChatMessage> linksList,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (linksList.isEmpty) {
      return _buildEmptyState(
        icon: Icons.link_rounded,
        title: 'No links shared',
        subtitle: 'Web links and resources sent in this chat will be cataloged here.',
        textPrimary: textPrimary,
        textSecondary: textSecondary,
      );
    }

    final urlRegex = RegExp(r'(https?:\/\/[^\s]+|www\.[^\s]+)');

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: linksList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final msg = linksList[index];
        final match = urlRegex.firstMatch(msg.content);
        final rawUrl = match?.group(0) ?? msg.content;
        final validUrl = rawUrl.startsWith('http') ? rawUrl : 'https://$rawUrl';
        final uri = Uri.tryParse(validUrl);
        final host = uri?.host.isNotEmpty == true ? uri!.host : 'Website link';
        final formattedDate = DateFormat('MMM d, yyyy').format(msg.timestamp);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              width: 0.6,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.language_rounded, color: Color(0xFF3B82F6), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          host,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          formattedDate,
                          style: TextStyle(fontSize: 11.5, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    color: textSecondary,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: validUrl));
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link copied to clipboard! 📋'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  if (await canLaunchUrl(Uri.parse(validUrl))) {
                    await launchUrl(Uri.parse(validUrl), mode: LaunchMode.externalApplication);
                  }
                },
                child: Text(
                  validUrl,
                  style: const TextStyle(
                    color: Color(0xFF3B82F6),
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreenMediaViewer(BuildContext context, String imageUrl, {bool isVideo = false}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              onPressed: () {
                Share.share(imageUrl);
              },
            ),
          ],
        ),
        body: Center(
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.8,
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (_, _) => const CircularProgressIndicator(color: Colors.white),
              errorWidget: (_, _, _) => const Icon(Icons.broken_image_rounded, color: Colors.white, size: 50),
            ),
          ),
        ),
      ),
    );
  }
}

