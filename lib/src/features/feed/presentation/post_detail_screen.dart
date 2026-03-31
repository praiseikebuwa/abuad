import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../data/post_repository.dart';
import '../domain/post.dart' as domain;
import 'widgets/poll_widget.dart';
import 'widgets/animated_like_button.dart';
import 'widgets/video_post_widget.dart';
import 'package:flutter/gestures.dart';
import '../../user/data/user_repository.dart';
import '../../../core/widgets/verification_badge.dart';
import 'package:image_picker/image_picker.dart';
import 'package:giphy_get/giphy_get.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import '../../../core/services/image_upload_service.dart';
import '../domain/report.dart';
import 'widgets/report_bottom_sheet.dart';
import '../../../core/theme/app_colors.dart';
// import '../../chat/presentation/widgets/attachment_preview.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final domain.Post? post;
  final String? postId;

  const PostDetailScreen({super.key, this.post, this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isPosting = false;

  // Attachment State
  XFile? _selectedImage;
  String? _selectedGifUrl;
  Map<String, dynamic>? _pollData;
  double? _latitude;
  double? _longitude;
  String? _address;

  // Reply State
  String? _replyToCommentId;
  String? _replyToUserName;

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
        _selectedGifUrl = null;
        _pollData = null;
        _latitude = null;
        _longitude = null;
        _address = null;
      });
    }
  }

  Future<void> _pickGif() async {
    final gif = await GiphyGet.getGif(
      context: context,
      apiKey:
          '3wP5y8Jm9vH1jY6Y3mX9vH1jY6Y3mX9v', // Using the key from chat_screen
      tabColor: Theme.of(context).primaryColor,
    );

    if (gif != null && gif.images?.original?.url != null) {
      setState(() {
        _selectedGifUrl = gif.images!.original!.url;
        _selectedImage = null;
        _pollData = null;
        _latitude = null;
        _longitude = null;
        _address = null;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied'),
          ),
        );
      }
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _address = "My Current Location";
        _selectedImage = null;
        _selectedGifUrl = null;
        _pollData = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
      }
    }
  }

  void _onReply(String commentId, String userName) {
    setState(() {
      _replyToCommentId = commentId;
      _replyToUserName = userName;
    });
    _commentController.text = ''; // Clear if they were typing something else
    FocusScope.of(context).requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToUserName = null;
    });
  }

  int _getVerificationWeight(String? type) {
    switch (type) {
      case 'gold':
        return 0;
      case 'blue':
        return 1;
      default:
        return 2;
    }
  }

  void _clearAttachments() {
    setState(() {
      _selectedImage = null;
      _selectedGifUrl = null;
      _pollData = null;
      _latitude = null;
      _longitude = null;
      _address = null;
    });
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty &&
        _selectedImage == null &&
        _selectedGifUrl == null &&
        _pollData == null &&
        _latitude == null) {
      return;
    }

    setState(() => _isPosting = true);

    try {
      final repo = ref.read(postRepositoryProvider);
      final postId = widget.post?.id ?? widget.postId!;

      String? imageUrl = _selectedGifUrl;
      String? mediaType = _selectedGifUrl != null ? 'gif' : null;

      if (_selectedImage != null) {
        final imageService = ref.read(imageUploadServiceProvider);
        final uploadResult = await imageService.uploadImage(
          _selectedImage!,
          path: 'comments/$postId',
        );
        imageUrl = uploadResult.url;
        mediaType = 'image';
      }

      await repo.addComment(
        postId,
        content,
        parentId: _replyToCommentId,
        imageUrl: imageUrl,
        mediaType: mediaType,
        pollData: _pollData,
        latitude: _latitude,
        longitude: _longitude,
      );

      _commentController.clear();
      _clearAttachments();
      _cancelReply();

      // Scroll to bottom (optional)
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error posting comment: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  void _showPollDialog() {
    final questionController = TextEditingController();
    final option1Controller = TextEditingController();
    final option2Controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create a Poll'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: questionController,
              decoration: const InputDecoration(hintText: 'Ask a question...'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: option1Controller,
              decoration: const InputDecoration(hintText: 'Option 1'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: option2Controller,
              decoration: const InputDecoration(hintText: 'Option 2'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (questionController.text.isNotEmpty &&
                  option1Controller.text.isNotEmpty &&
                  option2Controller.text.isNotEmpty) {
                setState(() {
                  _pollData = {
                    'question': questionController.text.trim(),
                    'options': [
                      option1Controller.text.trim(),
                      option2Controller.text.trim(),
                    ],
                    'votes': {
                      option1Controller.text.trim(): 0,
                      option2Controller.text.trim(): 0,
                    },
                    'voters': [],
                    'end_time': DateTime.now()
                        .add(const Duration(days: 1))
                        .toIso8601String(),
                  };
                  _selectedImage = null;
                  _selectedGifUrl = null;
                  _latitude = null;
                  _longitude = null;
                  _address = null;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add Poll'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: Colors.grey[600], size: 22),
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      splashRadius: 20,
    );
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(postRepositoryProvider);
      final postId = widget.post?.id ?? widget.postId!;
      await repo.deleteComment(postId, commentId);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Comment deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showCommentMenu(BuildContext context, String commentId, bool isOwn) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwn)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Comment',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteComment(commentId);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.report_outlined),
                title: const Text('Report Comment'),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ReportBottomSheet(
                      targetId: commentId,
                      type: ReportType.comment,
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showPostMenu(
    BuildContext context,
    domain.Post post,
    PostRepository repo,
  ) {
    final currentUserId = repo.currentUserId;
    final isOwnPost = post.authorId == currentUserId;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwnPost)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Post',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Post'),
                      content: const Text(
                        'Are you sure you want to delete this post? This action cannot be undone.',
                      ),
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

                  if (confirmed == true && mounted) {
                    try {
                      await repo.deletePost(post.id);
                      if (mounted) {
                        Navigator.pop(context); // Go back to feed
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Post deleted')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  }
                },
              ),
            Consumer(
              builder: (context, ref, child) {
                final isSavedAsync = ref.watch(isPostSavedProvider(post.id));
                final isSaved = isSavedAsync.value ?? false;
                return ListTile(
                  leading: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: isSaved ? AppColors.secondaryTeal : null,
                  ),
                  title: Text(isSaved ? 'Unsave Post' : 'Save Post'),
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(userRepositoryProvider).togglePostSave(post.id);
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('Report Post'),
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
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showRepostBottomSheet(domain.Post originalPost) {
    final commentController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    ref
                        .read(postRepositoryProvider)
                        .repost(originalPost, commentController.text);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text("Repost"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: commentController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: "Add a comment...",
                      border: InputBorder.none,
                    ),
                    maxLines: 4,
                    minLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (originalPost.mediaUrl.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: originalPost.mediaUrl,
                        height: 60,
                        width: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          originalPost.authorName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          originalPost.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[800],
                          ),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(postRepositoryProvider);
    final postId = widget.post?.id ?? widget.postId;

    if (postId == null || postId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("Error: No Post ID provided")),
      );
    }

    final commentsStream = repo.watchComments(postId);
    final isLikedStream = repo.isPostLiked(postId);
    final currentUserId = repo.currentUserId;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              Share.share(
                'Check out this post on ABUAD Nest: https://abuadapp.web.app/post/$postId',
                subject: 'Check out this post on ABUAD',
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<domain.Post?>(
        stream: repo.watchPost(postId),
        builder: (context, snapshot) {
          final post = snapshot.data ?? widget.post;

          if (post == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final isPureRepost =
              post.repostData != null && post.content.trim().isEmpty;

          // Data to Display (Swap if Pure Repost)
          final displayAuthorName = isPureRepost
              ? (post.repostData!['author_name'] ?? 'Unknown')
              : post.authorName;
          final displayAuthorHandle = isPureRepost
              ? (post.repostData!['author_handle'] ?? '')
              : post.authorHandle;
          final displayAvatarUrl = isPureRepost
              ? post.repostData!['author_avatar_url']
              : post.authorAvatarUrl;
          final displayContent = isPureRepost
              ? (post.repostData!['content'] ?? '')
              : post.content;
          final displayMediaUrl = isPureRepost
              ? (post.repostData!['media_url'] ?? '')
              : post.mediaUrl;
          final displayMediaTypeStr = isPureRepost
              ? (post.repostData!['media_type'] as String?)
              : null;
          final displayTimestamp = isPureRepost
              ? (DateTime.tryParse(post.repostData!['timestamp'] ?? '') ??
                    post.timestamp)
              : post.timestamp;
          final displayIsVerified = isPureRepost
              ? (post.repostData!['is_verified'] == true)
              : post.isVerified;
          final displayVerificationType = isPureRepost
              ? (post.repostData!['verification_type'] ?? 'none')
              : post.verificationType;
          final displayIsAnonymous = isPureRepost
              ? (post.repostData!['is_anonymous'] == true)
              : post.isAnonymous;

          // Media Type Enum Conversion
          domain.MediaType displayMediaType = post.mediaType;
          if (isPureRepost && displayMediaTypeStr != null) {
            displayMediaType = domain.MediaType.values.firstWhere(
              (e) => e.name == displayMediaTypeStr,
              orElse: () => domain.MediaType.none,
            );
          } else if (isPureRepost && displayMediaUrl.isNotEmpty) {
            if (displayMediaUrl.endsWith('.mp4')) {
              displayMediaType = domain.MediaType.video;
            } else if (displayMediaUrl.contains('giphy') ||
                displayMediaUrl.endsWith('.gif')) {
              displayMediaType = domain.MediaType.gif;
            } else {
              displayMediaType = domain.MediaType.image;
            }
          }

          // Determine author ID to watch
          final authorIdToWatch = isPureRepost
              ? post.repostData!['author_id']
              : post.authorId;
          final shouldWatch = !displayIsAnonymous && authorIdToWatch != null;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    children: [
                      // Main Post Content
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isPureRepost)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.repeat,
                                      size: 16,
                                      color: isDark
                                          ? Colors.grey[500]
                                          : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${post.authorName} reposted',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey[500]
                                            : Colors.grey[600],
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Header: Avatar, Names, More
                            StreamBuilder<AppUser?>(
                              stream: shouldWatch
                                  ? ref
                                        .read(userRepositoryProvider)
                                        .watchUser(authorIdToWatch)
                                  : const Stream.empty(),
                              builder: (context, userSnapshot) {
                                final user = userSnapshot.data;
                                final effectiveAuthorName =
                                    user?.displayName ?? displayAuthorName;
                                final effectiveAuthorHandle =
                                    user?.handle ?? displayAuthorHandle;
                                final effectiveAvatarUrl =
                                    user?.avatarUrl ?? displayAvatarUrl;
                                final effectiveIsVerified =
                                    user?.isVerified ?? displayIsVerified;
                                final effectiveVerificationType =
                                    user?.verificationType ??
                                    displayVerificationType;

                                return Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.grey[200],
                                      backgroundImage:
                                          (effectiveAvatarUrl != null &&
                                              !displayIsAnonymous)
                                          ? CachedNetworkImageProvider(
                                              effectiveAvatarUrl,
                                            )
                                          : null,
                                      child: displayIsAnonymous
                                          ? const Icon(Icons.person_outline)
                                          : (effectiveAvatarUrl == null
                                                ? Text(
                                                    effectiveAuthorName
                                                            .isNotEmpty
                                                        ? effectiveAuthorName[0]
                                                              .toUpperCase()
                                                        : '?',
                                                    style: TextStyle(
                                                      color: theme.primaryColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 20,
                                                    ),
                                                  )
                                                : null),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                displayIsAnonymous
                                                    ? 'Anonymous Student'
                                                    : effectiveAuthorName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              if (effectiveIsVerified &&
                                                  !displayIsAnonymous) ...[
                                                const SizedBox(width: 4),
                                                VerificationBadge(
                                                  type:
                                                      effectiveVerificationType,
                                                  size: 18,
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (!displayIsAnonymous)
                                            Text(
                                              '@$effectiveAuthorHandle',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.more_horiz),
                                      onPressed: () {
                                        _showPostMenu(context, post, repo);
                                      },
                                      color: Colors.grey,
                                    ),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 16),

                            // Post Text
                            _buildHighlightedContent(
                              context,
                              displayContent,
                              theme,
                              ref,
                            ),

                            // Repost (Quote) Rendering
                            if (!isPureRepost && post.repostData != null) ...[
                              const SizedBox(height: 12),
                              _buildQuotedPost(
                                context,
                                post.repostData!,
                                isDark,
                              ),
                            ],

                            // Post Media
                            if (displayMediaUrl.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child:
                                    displayMediaType == domain.MediaType.video
                                    ? VideoPostWidget(videoUrl: displayMediaUrl)
                                    : CachedNetworkImage(
                                        imageUrl: displayMediaUrl,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                              height: 300,
                                              color: Colors.grey[100],
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            ),
                                        errorWidget: (_, __, ___) =>
                                            const SizedBox(),
                                      ),
                              ),
                            ],

                            // Poll
                            if (post.pollData != null) ...[
                              const SizedBox(height: 16),
                              PollWidget(post: post, repo: repo),
                            ],

                            const SizedBox(height: 16),

                            // Timestamp and Platform
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat(
                                    'h:mm a · MMM d, yyyy',
                                  ).format(displayTimestamp),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            const Divider(),

                            // Stats Row
                            if (post.repostCount > 0 ||
                                post.likesCount > 0) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Row(
                                  children: [
                                    if (post.repostCount > 0) ...[
                                      _StatText(
                                        count: post.repostCount,
                                        label: 'Reposts',
                                      ),
                                      const SizedBox(width: 20),
                                    ],
                                    if (post.likesCount > 0)
                                      _StatText(
                                        count: post.likesCount,
                                        label: 'Likes',
                                      ),
                                  ],
                                ),
                              ),
                              const Divider(),
                            ],

                            // Action Bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  onPressed: () {
                                    // Focus logic handled by placing focus node or just tapping the bottom field
                                    // For now, we can rely on the user tapping the bottom field
                                  },
                                  color: Colors.grey[600],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.repeat),
                                  onPressed: () => _showRepostBottomSheet(post),
                                  color: Colors.grey[600],
                                ),
                                StreamBuilder<bool>(
                                  stream: isLikedStream,
                                  builder: (context, snapshot) {
                                    final isLiked = snapshot.data ?? false;
                                    return AnimatedLikeButton(
                                      isLiked: isLiked,
                                      count:
                                          0, // We hide count in the button for this view
                                      showCount: false,
                                      iconSize: 24,
                                      onTap: () => repo.toggleLike(post.id),
                                    );
                                  },
                                ),
                                Consumer(
                                  builder: (context, ref, child) {
                                    final isSavedAsync = ref.watch(
                                      isPostSavedProvider(post.id),
                                    );
                                    final isSaved = isSavedAsync.value ?? false;

                                    return IconButton(
                                      icon: Icon(
                                        isSaved
                                            ? Icons.bookmark
                                            : Icons.bookmark_border,
                                        color: isSaved
                                            ? AppColors.secondaryTeal
                                            : Colors.grey[600],
                                      ),
                                      onPressed: () {
                                        ref
                                            .read(userRepositoryProvider)
                                            .togglePostSave(post.id);
                                      },
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.share_outlined),
                                  onPressed: () {
                                    Share.share(
                                      '${post.authorName} (@${post.authorHandle}): ${post.content}\n\nSent from ABUAD Nest',
                                    );
                                  },
                                  color: Colors.grey[600],
                                ),
                              ],
                            ),
                            const Divider(),
                          ],
                        ),
                      ),

                      // Comments List
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: commentsStream,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          }

                          final rawComments = snapshot.data ?? [];

                          // Sort: Gold > Blue > None, then Timestamp (Asc)
                          final comments =
                              List<Map<String, dynamic>>.from(rawComments)
                                ..sort((a, b) {
                                  final weightA = _getVerificationWeight(
                                    a['authorVerificationType'],
                                  );
                                  final weightB = _getVerificationWeight(
                                    b['authorVerificationType'],
                                  );
                                  if (weightA != weightB) {
                                    return weightA.compareTo(weightB);
                                  }
                                  return (a['timestamp'] ?? 0).compareTo(
                                    b['timestamp'] ?? 0,
                                  );
                                });

                          if (comments.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Center(
                                child: Text(
                                  'No comments yet. Be the first to reply!',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: comments.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final comment = comments[index];
                              return _CommentItem(
                                comment: comment,
                                currentUserId: currentUserId,
                                postId: postId,
                                onReply: _onReply,
                                onMenu: _showCommentMenu,
                              );
                            },
                          );
                        },
                      ),
                      // Add some bottom padding so content isn't hidden by input
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),

              // Sticky Comment Input
              SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? Colors.grey[900]! : Colors.grey[200]!,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reply Indicator
                      if (_replyToCommentId != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          color: theme.primaryColor.withOpacity(0.05),
                          child: Row(
                            children: [
                              Text(
                                "Replying to ",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                "@$_replyToUserName",
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _cancelReply,
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Visibility Indicator
                      if (_replyToCommentId == null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.public,
                                size: 14,
                                color: theme.primaryColor.withOpacity(0.8),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Everyone can reply",
                                style: TextStyle(
                                  color: theme.primaryColor.withOpacity(0.8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Attachment Previews
                      if (_selectedImage != null ||
                          _selectedGifUrl != null ||
                          _latitude != null ||
                          _pollData != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Stack(
                            children: [
                              if (_selectedImage != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(_selectedImage!.path),
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              if (_selectedGifUrl != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: _selectedGifUrl!,
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              if (_latitude != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(_address ?? "Location attached"),
                                    ],
                                  ),
                                ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: _clearAttachments,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: theme.primaryColor.withOpacity(
                                  0.1,
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: theme.primaryColor,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                decoration: const InputDecoration(
                                  hintText: 'Post your reply',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                maxLines: null,
                                textCapitalization:
                                    TextCapitalization.sentences,
                              ),
                            ),
                            IconButton(
                              onPressed: _isPosting ? null : _postComment,
                              icon: _isPosting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(Icons.send, color: theme.primaryColor),
                            ),
                          ],
                        ),
                      ),

                      // Action Icons Row
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 44,
                          right: 16,
                          bottom: 8,
                        ),
                        child: Row(
                          children: [
                            _buildActionIcon(
                              Icons.image_outlined,
                              () => _pickImage(ImageSource.gallery),
                            ),
                            _buildActionIcon(
                              Icons.camera_alt_outlined,
                              () => _pickImage(ImageSource.camera),
                            ),
                            _buildActionIcon(Icons.gif_box_outlined, _pickGif),
                            _buildActionIcon(
                              Icons.poll_outlined,
                              _showPollDialog,
                            ),
                            _buildActionIcon(
                              Icons.location_on_outlined,
                              _getCurrentLocation,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHighlightedContent(
    BuildContext context,
    String text,
    ThemeData theme,
    WidgetRef ref,
  ) {
    final words = text.split(' ');
    final List<TextSpan> spans = [];

    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      final isLast = i == words.length - 1;

      if (word.startsWith('#')) {
        final tag = word.substring(1);
        spans.add(
          TextSpan(
            text: word,
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                context.push('/hashtag/$tag');
              },
          ),
        );
      } else if (word.startsWith('@')) {
        final handle = word.substring(1);
        spans.add(
          TextSpan(
            text: word,
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                final user = await ref
                    .read(userRepositoryProvider)
                    .getUserByHandle(handle);
                if (context.mounted) {
                  if (user != null) {
                    context.push('/user/${user.uid}');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User not found')),
                    );
                  }
                }
              },
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: word,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color ?? Colors.black,
              fontSize: 18,
            ),
          ),
        );
      }

      if (!isLast) {
        spans.add(const TextSpan(text: ' ', style: TextStyle(fontSize: 18)));
      }
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 18, height: 1.4),
        children: spans,
      ),
    );
  }

  Widget _buildQuotedPost(
    BuildContext context,
    Map<String, dynamic> data,
    bool isDark,
  ) {
    final mediaUrl = data['media_url'] as String?;
    final timestampStr = data['timestamp'] as String?;
    final timestamp = timestampStr != null
        ? DateTime.tryParse(timestampStr) ?? DateTime.now()
        : DateTime.now();

    return GestureDetector(
      onTap: () {
        // Create a basic post from map for the detail screen
        final originalPost = domain.Post.fromMap(data);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(post: originalPost),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  data['author_name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '@${data['author_handle'] ?? ''}',
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  timeago.format(timestamp, locale: 'en_short'),
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              data['content'] ?? '',
              style: const TextStyle(fontSize: 14, height: 1.3),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (mediaUrl != null && mediaUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: mediaUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatText extends StatelessWidget {
  final int count;
  final String label;

  const _StatText({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$count',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 15)),
      ],
    );
  }
}

class _CommentItem extends ConsumerStatefulWidget {
  final Map<String, dynamic> comment;
  final String? currentUserId;
  final String postId;
  final Function(String, String) onReply;
  final Function(BuildContext, String, bool) onMenu;

  const _CommentItem({
    required this.comment,
    required this.currentUserId,
    required this.postId,
    required this.onReply,
    required this.onMenu,
  });

  @override
  ConsumerState<_CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends ConsumerState<_CommentItem> {
  bool _showReplies = false;

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      comment['timestamp'] ?? 0,
    );
    final isOwnComment = comment['userId'] == widget.currentUserId;
    final userId = comment['userId'] as String?;
    final replyCount = comment['replyCount'] as int? ?? 0;

    return StreamBuilder<AppUser?>(
      stream: userId != null
          ? ref.read(userRepositoryProvider).watchUser(userId)
          : const Stream.empty(),
      builder: (context, userSnapshot) {
        final user = userSnapshot.data;
        final effectiveName =
            user?.displayName ?? comment['userName'] ?? 'Student';
        final effectiveAvatar = user?.avatarUrl ?? comment['userAvatar'];
        final verificationType =
            user?.verificationType ??
            comment['authorVerificationType'] ??
            'none';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onLongPress: () =>
                  widget.onMenu(context, comment['id'], isOwnComment),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (userId != null) context.push('/user/$userId');
                      },
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.primaryColor.withOpacity(0.1),
                        backgroundImage: effectiveAvatar != null
                            ? CachedNetworkImageProvider(effectiveAvatar)
                            : null,
                        child: effectiveAvatar == null
                            ? Text(
                                effectiveName.isNotEmpty
                                    ? effectiveName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (userId != null) {
                                    context.push('/user/$userId');
                                  }
                                },
                                child: Text(
                                  effectiveName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              VerificationBadge(
                                type: verificationType,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                timeago.format(timestamp, locale: 'en_short'),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            comment['content'] ?? '',
                            style: const TextStyle(fontSize: 14, height: 1.3),
                          ),

                          // Comment Media
                          if (comment['imageUrl'] != null &&
                              comment['imageUrl'] != '') ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: comment['imageUrl'],
                                maxHeightDiskCache: 400,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                placeholder: (context, url) => Container(
                                  height: 200,
                                  color: isDark
                                      ? Colors.grey[900]
                                      : Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
                                    const SizedBox(),
                              ),
                            ),
                          ],

                          const SizedBox(height: 8),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => widget.onReply(
                                  comment['id'],
                                  effectiveName,
                                ),
                                child: Text(
                                  "Reply",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (replyCount > 0) ...[
                                const SizedBox(width: 16),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _showReplies = !_showReplies;
                                    });
                                  },
                                  child: Text(
                                    _showReplies
                                        ? "Hide replies"
                                        : "Show $replyCount replies",
                                    style: TextStyle(
                                      color: theme.primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showReplies)
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: _ReplyList(
                  postId: widget.postId,
                  commentId: comment['id'],
                  currentUserId: widget.currentUserId,
                  onMenu: widget.onMenu,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ReplyList extends ConsumerWidget {
  final String postId;
  final String commentId;
  final String? currentUserId;
  final Function(BuildContext, String, bool) onMenu;

  const _ReplyList({
    required this.postId,
    required this.commentId,
    required this.currentUserId,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ref.read(postRepositoryProvider).watchReplies(postId, commentId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final replies = snapshot.data!;
        if (replies.isEmpty) return const SizedBox.shrink();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: replies.length,
          itemBuilder: (context, index) {
            return _ReplyItem(
              reply: replies[index],
              currentUserId: currentUserId,
              onMenu: onMenu,
            );
          },
        );
      },
    );
  }
}

class _ReplyItem extends ConsumerWidget {
  final Map<String, dynamic> reply;
  final String? currentUserId;
  final Function(BuildContext, String, bool) onMenu;

  const _ReplyItem({
    required this.reply,
    required this.currentUserId,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      reply['timestamp'] ?? 0,
    );
    final isOwnReply = reply['userId'] == currentUserId;
    final userId = reply['userId'] as String?;

    return StreamBuilder<AppUser?>(
      stream: userId != null
          ? ref.read(userRepositoryProvider).watchUser(userId)
          : const Stream.empty(),
      builder: (context, userSnapshot) {
        final user = userSnapshot.data;
        final effectiveName =
            user?.displayName ?? reply['userName'] ?? 'Student';
        final effectiveAvatar = user?.avatarUrl ?? reply['userAvatar'];
        final verificationType =
            user?.verificationType ?? reply['authorVerificationType'] ?? 'none';

        return InkWell(
          onLongPress: () => onMenu(context, reply['id'], isOwnReply),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    if (userId != null) context.push('/user/$userId');
                  },
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                    backgroundImage: effectiveAvatar != null
                        ? CachedNetworkImageProvider(effectiveAvatar)
                        : null,
                    child: effectiveAvatar == null
                        ? Text(
                            effectiveName.isNotEmpty
                                ? effectiveName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            effectiveName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          VerificationBadge(type: verificationType, size: 12),
                          const SizedBox(width: 6),
                          Text(
                            timeago.format(timestamp, locale: 'en_short'),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reply['content'] ?? '',
                        style: const TextStyle(fontSize: 13, height: 1.3),
                      ),
                      // Media in replies too?
                      if (reply['imageUrl'] != null &&
                          reply['imageUrl'] != '') ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: reply['imageUrl'],
                            maxHeightDiskCache: 400,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
