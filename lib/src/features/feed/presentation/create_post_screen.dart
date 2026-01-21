import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart'; // Requires dependency
import 'package:uuid/uuid.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../data/post_repository.dart';
import '../../user/data/user_repository.dart';
import '../domain/post.dart';
import '../../auth/data/auth_repository.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final String? initialChannelId;
  const CreatePostScreen({super.key, this.initialChannelId});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _picker = ImagePicker();
  File? _selectedImage;
  bool _isPosting = false;
  String _channelId = 'general';

  @override
  void initState() {
    super.initState();
    if (widget.initialChannelId != null) {
      _channelId = widget.initialChannelId!;
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String> _uploadImage(File image) async {
    // In a real app, use Firebase Storage
    // For now, if we can't upload, we might return a dummy URL or fail
    // Implementing actual storage upload:
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('post_images')
          .child(DateTime.now().toIso8601String() + '.jpg');
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Storage Upload Error: $e");
      // Fallback or rethrow
      return '';
    }
  }

  Future<void> _submitPost() async {
    if (_contentController.text.trim().isEmpty && _selectedImage == null)
      return;

    setState(() => _isPosting = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final user = authRepo.currentUser;
      if (user == null) throw Exception("Not logged in");

      // Fetch full user details for denormalized data
      final userRepo = ref.read(userRepositoryProvider);
      final appUser = await userRepo.getUserById(user.uid);

      String mediaUrl = '';
      if (_selectedImage != null) {
        mediaUrl = await _uploadImage(_selectedImage!);
      }

      final post = Post(
        id: const Uuid().v4(),
        authorId: user.uid,
        authorName: appUser?.displayName ?? 'Anonymous',
        authorHandle: appUser?.handle ?? '@anon',
        authorAvatarUrl: appUser?.avatarUrl,
        content: _contentController.text.trim(),
        mediaUrl: mediaUrl,
        mediaType: mediaUrl.isNotEmpty ? MediaType.image : MediaType.none,
        timestamp: DateTime.now(),
        channelId: _channelId,
        isVerified: appUser?.isVerified ?? false,
      );

      await ref.read(postRepositoryProvider).addPost(post);

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          "New Post",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ElevatedButton(
              onPressed: _isPosting ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: _isPosting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("Post"),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isPosting) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar placeholder
                    const CircleAvatar(
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: _contentController,
                            autofocus: true,
                            maxLines: null,
                            decoration: const InputDecoration(
                              hintText: "What's happening?",
                              border: InputBorder.none,
                              hintStyle: TextStyle(fontSize: 18),
                            ),
                            style: const TextStyle(fontSize: 18),
                          ),
                          if (_selectedImage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.file(
                                      _selectedImage!,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _selectedImage = null),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
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
              ],
            ),
          ),
          // Tool Bar
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image_outlined, color: Colors.blue),
                  onPressed: _pickImage,
                ),
                IconButton(
                  icon: const Icon(Icons.gif_box_outlined, color: Colors.blue),
                  onPressed: () {}, // Todo
                ),
                IconButton(
                  icon: const Icon(Icons.poll_outlined, color: Colors.blue),
                  onPressed: () {}, // Todo
                ),
                const Spacer(),
                Text(
                  "$_channelId channel",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
