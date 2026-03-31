import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../user/data/user_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/firebase_storage_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late TextEditingController _handleController;
  late TextEditingController _collegeController;
  late TextEditingController _departmentController;
  late TextEditingController _phoneController;
  late TextEditingController _websiteController;
  late TextEditingController _facebookController;
  late TextEditingController _twitterController;
  late TextEditingController _instagramController;
  late TextEditingController _linkedinController;
  late TextEditingController _tiktokController;
  late TextEditingController _youtubeController;
  late TextEditingController _snapchatController;
  late TextEditingController _githubController;
  late TextEditingController _twitchController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).value;
    _displayNameController = TextEditingController(
      text: user?.displayName ?? '',
    );
    _bioController = TextEditingController(text: user?.bio ?? '');
    _handleController = TextEditingController(text: user?.handle ?? '');
    _collegeController = TextEditingController(text: user?.college ?? '');
    _departmentController = TextEditingController(text: user?.department ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _websiteController = TextEditingController(text: user?.websiteUrl ?? '');
    _facebookController = TextEditingController(text: user?.facebookUrl ?? '');
    _twitterController = TextEditingController(text: user?.twitterUrl ?? '');
    _instagramController = TextEditingController(
      text: user?.instagramUrl ?? '',
    );
    _linkedinController = TextEditingController(text: user?.linkedinUrl ?? '');
    _tiktokController = TextEditingController(text: user?.tiktokUrl ?? '');
    _youtubeController = TextEditingController(text: user?.youtubeUrl ?? '');
    _snapchatController = TextEditingController(text: user?.snapchatUrl ?? '');
    _githubController = TextEditingController(text: user?.githubUrl ?? '');
    _twitchController = TextEditingController(text: user?.twitchUrl ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _handleController.dispose();
    _collegeController.dispose();
    _departmentController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _facebookController.dispose();
    _twitterController.dispose();
    _instagramController.dispose();
    _linkedinController.dispose();
    _tiktokController.dispose();
    _youtubeController.dispose();
    _snapchatController.dispose();
    _githubController.dispose();
    _twitchController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage(bool isAvatar) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final picker = ImagePicker();
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: isAvatar ? 512 : 1024,
        maxHeight: isAvatar ? 512 : 1024,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        setState(() => _isLoading = true);
        try {
          final storage = FirebaseStorageService();
          final url = await storage.uploadImage(
            pickedFile,
            path: 'profile_images/${user.uid}/',
          );

          if (url.isNotEmpty && mounted) {
            await ref.read(userRepositoryProvider).updateUser(user.uid, {
              isAvatar ? 'avatar_url' : 'banner_url': url,
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isAvatar ? 'Avatar updated!' : 'Banner updated!'),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('User not found');

      await ref.read(userRepositoryProvider).updateUser(user.uid, {
        'display_name': _displayNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'handle': _handleController.text.trim(),
        'college': _collegeController.text.trim(),
        'department': _departmentController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'website_url': _websiteController.text.trim(),
        'facebook_url': _facebookController.text.trim(),
        'twitter_url': _twitterController.text.trim(),
        'instagram_url': _instagramController.text.trim(),
        'linkedin_url': _linkedinController.text.trim(),
        'tiktok_url': _tiktokController.text.trim(),
        'youtube_url': _youtubeController.text.trim(),
        'snapchat_url': _snapchatController.text.trim(),
        'github_url': _githubController.text.trim(),
        'twitch_url': _twitchController.text.trim(),
      });

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? AppColors.inkTealGradient
                : AppColors.goldGradient,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveChanges,
            child: Text(
              'Save',
              style: TextStyle(
                color: Colors.white.withValues(alpha: _isLoading ? 0.5 : 1.0),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // Banner & Avatar Section
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Banner
                    GestureDetector(
                      onTap: () => _pickAndUploadImage(false),
                      child: Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.grey[200],
                          image: user?.bannerUrl != null
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(
                                    user!.bannerUrl!,
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Avatar
                    Positioned(
                      bottom: -50,
                      left: 16,
                      child: GestureDetector(
                        onTap: () => _pickAndUploadImage(true),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black : Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: 45,
                                backgroundColor: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                                backgroundImage: user?.avatarUrl != null
                                    ? CachedNetworkImageProvider(
                                        user!.avatarUrl!,
                                      )
                                    : null,
                                child: (user?.avatarUrl == null)
                                    ? Text(
                                        user?.displayName.isNotEmpty == true
                                            ? user!.displayName[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            if (user != null)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.black
                                          : Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 60),

                // Form Fields
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildInputField(
                          controller: _displayNameController,
                          label: 'Display Name',
                          hint: 'Enter your full name',
                          icon: Icons.person_outline,
                          validator: (v) => v?.trim().isEmpty ?? true
                              ? 'Name is required'
                              : null,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildInputField(
                                controller: _handleController,
                                label: 'Handle',
                                hint: 'Unique username',
                                icon: Icons.alternate_email,
                                prefixText: '@',
                                validator: (v) {
                                  if (v?.trim().isEmpty ?? true) {
                                    return 'Handle is required';
                                  }
                                  if (!RegExp(
                                    r'^[a-zA-Z0-9_]+$',
                                  ).hasMatch(v!)) {
                                    return 'Letters, numbers, underscores only';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: IconButton(
                                onPressed: () async {
                                  final displayName = _displayNameController
                                      .text
                                      .trim();
                                  if (displayName.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Enter Display Name first',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  setState(() => _isLoading = true);
                                  try {
                                    final repo = ref.read(
                                      userRepositoryProvider,
                                    );
                                    final newHandle = await repo.generateHandle(
                                      displayName,
                                    );
                                    setState(() {
                                      _handleController.text = newHandle;
                                    });
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error generating handle: $e',
                                        ),
                                      ),
                                    );
                                  } finally {
                                    setState(() => _isLoading = false);
                                  }
                                },
                                icon: const Icon(Icons.auto_awesome),
                                tooltip: 'Auto-generate handle',
                                style: IconButton.styleFrom(
                                  backgroundColor: isDark
                                      ? Colors.white10
                                      : Colors.grey[200],
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        _buildInputField(
                          controller: _bioController,
                          label: 'Bio',
                          hint: 'Tell others about yourself',
                          icon: Icons.description_outlined,
                          maxLines: 3,
                          maxLength: 160,
                        ),
                        const Divider(height: 32),
                        const Text(
                          'Campus Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          controller: _collegeController,
                          label: 'College',
                          hint: 'e.g., Engineering, Law',
                          icon: Icons.school_outlined,
                        ),
                        _buildInputField(
                          controller: _departmentController,
                          label: 'Department',
                          hint: 'e.g., Computer Science',
                          icon: Icons.apartment_outlined,
                        ),
                        _buildInputField(
                          controller: _phoneController,
                          label: 'Phone Number',
                          hint: 'e.g., +234...',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const Divider(height: 32),
                        const Text(
                          'Social Links',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          controller: _websiteController,
                          label: 'Website',
                          hint: 'https://example.com',
                          icon: FontAwesomeIcons.globe,
                          keyboardType: TextInputType.url,
                        ),
                        _buildInputField(
                          controller: _facebookController,
                          label: 'Facebook',
                          hint: 'https://facebook.com/username',
                          icon: FontAwesomeIcons.facebook,
                          iconColor: const Color(0xFF1877F2),
                          keyboardType: TextInputType.url,
                        ),
                        _buildInputField(
                          controller: _twitterController,
                          label: 'Twitter / X',
                          hint: 'https://x.com/username',
                          icon: FontAwesomeIcons.xTwitter,
                          iconColor: Colors.black,
                          keyboardType: TextInputType.url,
                        ),
                        _buildInputField(
                          controller: _instagramController,
                          label: 'Instagram',
                          hint: 'https://instagram.com/username',
                          icon: FontAwesomeIcons.instagram,
                          iconColor: const Color(0xFFE4405F),
                          keyboardType: TextInputType.url,
                        ),
                        _buildInputField(
                          controller: _linkedinController,
                          label: 'LinkedIn',
                          hint: 'https://linkedin.com/in/username',
                          icon: FontAwesomeIcons.linkedin,
                          iconColor: const Color(0xFF0077B5),
                          keyboardType: TextInputType.url,
                        ),
                        _buildInputField(
                          controller: _tiktokController,
                          label: 'TikTok',
                          hint: 'https://tiktok.com/@username',
                          icon: FontAwesomeIcons.tiktok,
                          iconColor: Colors.black,
                          keyboardType: TextInputType.url,
                        ),
                        _buildInputField(
                          controller: _youtubeController,
                          label: 'YouTube',
                          hint: 'https://youtube.com/@channel',
                          icon: FontAwesomeIcons.youtube,
                          iconColor: const Color(0xFFFF0000),
                          keyboardType: TextInputType.url,
                        ),
                        _buildInputField(
                          controller: _snapchatController,
                          label: 'Snapchat',
                          hint: 'https://snapchat.com/add/username',
                          icon: FontAwesomeIcons.snapchat,
                          iconColor: const Color(0xFFFFFC00),
                          keyboardType: TextInputType.url,
                        ),
                        _buildInputField(
                          controller: _githubController,
                          label: 'GitHub',
                          hint: 'https://github.com/username',
                          icon: FontAwesomeIcons.github,
                          iconColor: const Color(0xFF181717),
                          keyboardType: TextInputType.url,
                        ),
                        _buildInputField(
                          controller: _twitchController,
                          label: 'Twitch',
                          hint: 'https://twitch.tv/username',
                          icon: FontAwesomeIcons.twitch,
                          iconColor: const Color(0xFF9146FF),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required dynamic icon,
    Color? iconColor,
    int? maxLines = 1,
    int? maxLength,
    String? prefixText,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        validator: validator,
        keyboardType: keyboardType,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12.0),
            child: (icon is IconData && icon is! FaIconData)
                ? Icon(
                    icon,
                    color: iconColor ?? AppColors.secondaryTeal,
                    size: 20,
                  )
                : FaIcon(
                    icon as dynamic,
                    color: iconColor ?? AppColors.secondaryTeal,
                    size: 20,
                  ),
          ),
          prefixText: prefixText,
          counterText: '',
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? Colors.white12 : Colors.grey[300]!,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey[200]!,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppColors.secondaryTeal,
              width: 2,
            ),
          ),
          labelStyle: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
