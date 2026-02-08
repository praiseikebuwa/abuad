import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import '../../../core/theme/app_colors.dart';
import '../data/chat_repository.dart';
import '../domain/chat_message.dart';
import '../../../core/services/image_upload_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String channelId;
  const ChatScreen({super.key, required this.channelId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatRepositoryProvider).markMessagesAsRead(widget.channelId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    // Clear typing status when leaving
    ref.read(chatRepositoryProvider).setTypingStatus(widget.channelId, false);
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty && !_isTyping) {
      setState(() => _isTyping = true);
      ref.read(chatRepositoryProvider).setTypingStatus(widget.channelId, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        setState(() => _isTyping = false);
        ref
            .read(chatRepositoryProvider)
            .setTypingStatus(widget.channelId, false);
      }
    });
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    ref.read(chatRepositoryProvider).sendMessage(widget.channelId, content);

    _messageController.clear();
    _isTyping = false;
    _typingTimer?.cancel();
  }

  Future<void> _sendImage() async {
    try {
      final imageService = ref.read(imageUploadServiceProvider);
      final imageFile = await imageService.pickImage();

      if (imageFile == null) return;

      // Show loading
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Uploading image...')));

      final result = await imageService.uploadImage(imageFile);

      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            widget.channelId,
            '📷 Photo',
            type: 'image',
            imageUrl: result.url,
            imageWidth: result.width,
            imageHeight: result.height,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
    }
  }

  void _viewImage(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: PhotoView(
            imageProvider: CachedNetworkImageProvider(imageUrl),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(chatRepositoryProvider);
    final messagesStream = repo.watchMessages(widget.channelId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder(
      future: repo.getChannel(widget.channelId),
      builder: (context, channelSnapshot) {
        final channel = channelSnapshot.data;
        final otherUserId = channel?.memberIds.firstWhere(
          (id) => id != repo.currentUserId,
          orElse: () => 'Unknown',
        );
        final otherUserName = channel?.memberNames[otherUserId] ?? 'Chat';
        final otherUserAvatar = channel?.memberAvatars[otherUserId];
        final isOtherTyping = channel?.typingUsers[otherUserId] ?? false;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.inkTealGradient,
              ),
            ),
            title: Row(
              children: [
                if (otherUserAvatar != null && otherUserAvatar.isNotEmpty)
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: CachedNetworkImageProvider(
                      otherUserAvatar,
                    ),
                  )
                else
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white.withOpacity(0.15),
                    child: Text(
                      otherUserName.isNotEmpty
                          ? otherUserName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    otherUserName,
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: messagesStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data!;
                    if (messages.isEmpty) {
                      return const Center(child: Text('Say hello! 👋'));
                    }

                    return ListView.builder(
                      reverse: true,
                      controller: _scrollController,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == repo.currentUserId;
                        final isRead = message.readBy.length > 1;

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: isMe
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (!isMe) ...[
                                      const SizedBox(width: 4),
                                    ],
                                    Flexible(
                                      child:
                                          message.type == 'image' &&
                                              message.imageUrl != null
                                          ? GestureDetector(
                                              onTap: () =>
                                                  _viewImage(message.imageUrl!),
                                              child: ClipRRectangle(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: CachedNetworkImage(
                                                  imageUrl: message.imageUrl!,
                                                  width: 200,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      Container(
                                                        width: 200,
                                                        height: 150,
                                                        color: Colors.grey[200],
                                                        child: const Center(
                                                          child:
                                                              CircularProgressIndicator(),
                                                        ),
                                                      ),
                                                ),
                                              ),
                                            )
                                          : GestureDetector(
                                              onTap: () {
                                                // Show timestamp on tap
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 10,
                                                    ),
                                                decoration: BoxDecoration(
                                                  gradient: isMe
                                                      ? AppColors.inkTealGradient
                                                      : null,
                                                  color: isMe
                                                      ? null
                                                      : (isDark
                                                            ? AppColors.surfaceDarkElevated
                                                            : AppColors.surfaceLightAlt),
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  border: Border.all(
                                                    color: isMe
                                                        ? Colors.transparent
                                                        : (isDark
                                                              ? Colors.white12
                                                              : const Color(0xFFE8E1D7)),
                                                  ),
                                                ),
                                                child: Text(
                                                  message.content,
                                                  style: TextStyle(
                                                    color: isMe
                                                        ? Colors.white
                                                        : (isDark
                                                              ? Colors.white
                                                              : Colors.black87),
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                                if (isMe) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Icon(
                                        isRead ? Icons.done_all : Icons.done,
                                        size: 16,
                                        color: isRead
                                            ? AppColors.secondaryTeal
                                            : Colors.grey,
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Typing indicator
              if (isOtherTyping)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      const SizedBox(width: 8),
                      Text(
                        'typing...',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

              // Input Area
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.secondaryTeal,
                        ),
                        onPressed: _sendImage,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: _onTextChanged,
                          decoration: InputDecoration(
                            hintText: 'Chat...',
                            filled: true,
                            fillColor: isDark
                                ? AppColors.surfaceDarkElevated
                                : AppColors.surfaceLightAlt,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: AppColors.secondaryTeal,
                        ),
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Helper widget for rounded rectangle image
class ClipRRectangle extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const ClipRRectangle({
    super.key,
    required this.child,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(borderRadius: borderRadius, child: child);
  }
}
