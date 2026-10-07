import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/url_validator.dart';
import '../../auth/data/auth_repository.dart';
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
  late TextEditingController _whatsappController;
  late TextEditingController _tiktokController;
  late TextEditingController _youtubeController;
  late TextEditingController _snapchatController;
  late TextEditingController _githubController;
  late TextEditingController _twitchController;
  bool _isPopulated = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _bioController = TextEditingController();
    _handleController = TextEditingController();
    _collegeController = TextEditingController();
    _departmentController = TextEditingController();
    _phoneController = TextEditingController();
    _websiteController = TextEditingController();
    _facebookController = TextEditingController();
    _twitterController = TextEditingController();
    _instagramController = TextEditingController();
    _whatsappController = TextEditingController();
    _tiktokController = TextEditingController();
    _youtubeController = TextEditingController();
    _snapchatController = TextEditingController();
    _githubController = TextEditingController();
    _twitchController = TextEditingController();

    final authRepo = ref.read(authRepositoryProvider);
    final initialUser = authRepo.currentUser ?? ref.read(currentUserProvider).value;
    if (initialUser != null) {
      _populateControllers(initialUser);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final currentUid = authRepo.currentUser?.uid ?? authRepo.currentUserId;
      if (currentUid != null) {
        final freshUser = await ref.read(userRepositoryProvider).getUserById(currentUid);
        if (freshUser != null && mounted) {
          setState(() {
            _populateControllers(freshUser, force: true);
          });
        }
      }
    });
  }

  void _populateControllers(AppUser user, {bool force = false}) {
    if (_isPopulated && !force) return;
    _isPopulated = true;
    _displayNameController.text = user.displayName;
    _bioController.text = user.bio ?? '';
    _handleController.text = user.handle;
    _collegeController.text = user.college ?? '';
    _departmentController.text = user.department ?? '';
    _phoneController.text = user.phoneNumber ?? '';
    _websiteController.text = user.websiteUrl ?? '';
    _facebookController.text = user.facebookUrl ?? '';
    _twitterController.text = user.twitterUrl ?? '';
    _instagramController.text = user.instagramUrl ?? '';
    _whatsappController.text = user.whatsappUrl ?? '';
    _tiktokController.text = user.tiktokUrl ?? '';
    _youtubeController.text = user.youtubeUrl ?? '';
    _snapchatController.text = user.snapchatUrl ?? '';
    _githubController.text = user.githubUrl ?? '';
    _twitchController.text = user.twitchUrl ?? '';
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
    _whatsappController.dispose();
    _tiktokController.dispose();
    _youtubeController.dispose();
    _snapchatController.dispose();
    _githubController.dispose();
    _twitchController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage(bool isAvatar) async {
    final authRepo = ref.read(authRepositoryProvider);
    final userUid = authRepo.currentUser?.uid ?? authRepo.currentUserId ?? ref.read(currentUserProvider).value?.uid;
    if (userUid == null) return;

    final picker = ImagePicker();
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        top: false,
        child: Wrap(
          children: [
            Material(
              color: Colors.transparent,
              child: ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
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
          final storage = CloudStorageService();
          final url = await storage.uploadImage(
            pickedFile,
            path: 'profile_images/$userUid/',
          );

          if (url.isNotEmpty && mounted) {
            final snakeKey = isAvatar ? 'avatar_url' : 'banner_url';
            final camelKey = isAvatar ? 'avatarUrl' : 'bannerUrl';
            await ref.read(userRepositoryProvider).updateUser(userUid, {
              snakeKey: url,
              camelKey: url,
            });
            ref.invalidate(userProvider(userUid));
            await ref.read(authRepositoryProvider).init();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isAvatar ? 'Avatar updated!' : 'Banner updated!'),
                ),
              );
            }
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
      final authRepo = ref.read(authRepositoryProvider);
      final userUid = authRepo.currentUser?.uid ?? authRepo.currentUserId ?? ref.read(currentUserProvider).value?.uid;
      if (userUid == null) throw Exception('User session invalid. Please sign in again.');

      await ref.read(userRepositoryProvider).updateUser(userUid, {
        'display_name': _displayNameController.text.trim(),
        'fullName': _displayNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'handle': _handleController.text.trim(),
        'username': _handleController.text.trim(),
        'college': _collegeController.text.trim(),
        'department': _departmentController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'website_url': _websiteController.text.trim(),
        'websiteUrl': _websiteController.text.trim(),
        'facebook_url': _facebookController.text.trim(),
        'facebookUrl': _facebookController.text.trim(),
        'twitter_url': _twitterController.text.trim(),
        'twitterUrl': _twitterController.text.trim(),
        'instagram_url': _instagramController.text.trim(),
        'instagramUrl': _instagramController.text.trim(),
        'whatsapp_url': _whatsappController.text.trim(),
        'whatsappUrl': _whatsappController.text.trim(),
        'tiktok_url': _tiktokController.text.trim(),
        'tiktokUrl': _tiktokController.text.trim(),
        'youtube_url': _youtubeController.text.trim(),
        'youtubeUrl': _youtubeController.text.trim(),
        'snapchat_url': _snapchatController.text.trim(),
        'snapchatUrl': _snapchatController.text.trim(),
        'github_url': _githubController.text.trim(),
        'githubUrl': _githubController.text.trim(),
        'twitch_url': _twitchController.text.trim(),
        'twitchUrl': _twitchController.text.trim(),
      });

      ref.invalidate(userProvider(userUid));
      ref.invalidate(currentUserProvider);
      await authRepo.init();

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
    final authRepo = ref.watch(authRepositoryProvider);
    final currentUid = authRepo.currentUser?.uid ?? authRepo.currentUserId;
    final userAsync = currentUid != null ? ref.watch(userProvider(currentUid)) : null;
    final user = userAsync?.value ?? authRepo.currentUser ?? ref.watch(currentUserProvider).value;
    if (user != null && !_isPopulated) {
      _populateControllers(user);
    }

    final bannerUrl = user?.bannerUrl;
    final avatarUrl = user?.avatarUrl;

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
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      // Banner
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 160,
                        child: GestureDetector(
                          onTap: () => _pickAndUploadImage(false),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[900] : Colors.grey[200],
                              image: (bannerUrl != null &&
                                      UrlValidator.isValidUrl(bannerUrl))
                                  ? DecorationImage(
                                      image: CachedNetworkImageProvider(
                                        UrlValidator.formatImageUrl(bannerUrl),
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
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
                      ),
                      // Avatar
                      Positioned(
                        top: 110,
                        left: 16,
                        width: 105,
                        height: 105,
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
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFE2E8F0),
                                  backgroundImage: (avatarUrl != null &&
                                          UrlValidator.isValidUrl(avatarUrl))
                                      ? CachedNetworkImageProvider(
                                          UrlValidator.formatImageUrl(avatarUrl),
                                        )
                                      : null,
                                  child: (avatarUrl == null ||
                                          !UrlValidator.isValidUrl(avatarUrl))
                                      ? Text(
                                          user?.displayName.isNotEmpty == true
                                              ? user!.displayName[0].toUpperCase()
                                              : (user?.handle.isNotEmpty == true
                                                  ? user!.handle[0].toUpperCase()
                                                  : 'P'),
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : AppColors.primaryInk,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
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
                ),
                const SizedBox(height: 16),

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

                                  final messenger = ScaffoldMessenger.of(context);
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
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error generating handle: $e',
                                          ),
                                        ),
                                      );
                                    }
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
                          controller: _whatsappController,
                          label: 'WhatsApp',
                          hint: 'https://wa.me/234...',
                          icon: FontAwesomeIcons.whatsapp,
                          iconColor: const Color(0xFF25D366),
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
