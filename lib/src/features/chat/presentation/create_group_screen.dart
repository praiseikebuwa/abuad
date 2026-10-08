import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../user/data/user_repository.dart';
import '../data/chat_repository.dart';
import '../../../core/utils/url_validator.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  
  String _searchQuery = '';
  final List<AppUser> _selectedUsers = [];
  bool _isCreating = false;
  String? _groupAvatarPath;
  Uint8List? _groupAvatarBytes;
  bool _isPrivate = true;
  bool _memberApprovals = true;
  int _activeTab = 0; // 0: Frequently Contacted, 1: All Contacts

  final _picker = ImagePicker();

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickGroupPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _groupAvatarPath = picked.path;
        _groupAvatarBytes = bytes;
      });
    }
  }

  void _toggleUser(AppUser user) {
    setState(() {
      final index = _selectedUsers.indexWhere((u) => u.uid == user.uid);
      if (index >= 0) {
        _selectedUsers.removeAt(index);
      } else {
        _selectedUsers.add(user);
      }
    });
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    if (_selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final channelId = await ref.read(chatRepositoryProvider).createGroupChannel(
            name: name,
            memberIds: _selectedUsers.map((u) => u.uid).toList(),
            avatarUrl: _groupAvatarPath,
          );

      if (mounted) {
        context.pushReplacement('/chat/$channelId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating group: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(chatRepositoryProvider).currentUserId;
    final usersStream = Stream.fromFuture(
      ref.watch(userRepositoryProvider).searchUsers(_searchQuery),
    );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF2F2F7);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);
    final isFormValid = _nameController.text.trim().isNotEmpty && _selectedUsers.isNotEmpty;

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
          'New Group',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            child: SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: (_isCreating || !isFormValid) ? null : _createGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF818CF8),
                  disabledBackgroundColor: const Color(0xFF818CF8).withValues(alpha: 0.5),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Create',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Group Photo Avatar
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickGroupPhoto,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            shape: BoxShape.circle,
                          ),
                          child: _groupAvatarBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(42),
                                  child: Image.memory(
                                    _groupAvatarBytes!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 36,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                )
                              : (_groupAvatarPath != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(42),
                                      child: kIsWeb
                                          ? Image.network(
                                              _groupAvatarPath!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => const Icon(
                                                Icons.camera_alt_rounded,
                                                size: 36,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            )
                                          : Image.file(
                                              File(_groupAvatarPath!),
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => const Icon(
                                                Icons.camera_alt_rounded,
                                                size: 36,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 36,
                                      color: Color(0xFF94A3B8),
                                    )),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.add, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add group photo',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. Group Name Field
            Text(
              'Group Name',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorderColor, width: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(fontSize: 15, color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Enter group name...',
                        hintStyle: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const Text('😄', style: TextStyle(fontSize: 20)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Description Field
            Text(
              'Description',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorderColor, width: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _descController,
                maxLines: 3,
                style: TextStyle(fontSize: 14, color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'What is this group for? (optional)...',
                  hintStyle: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.grey[400]),
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 18),

            // 4. Public vs Private Selector
            Row(
              children: [
                // Public Option
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isPrivate = false),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: !_isPrivate
                            ? const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.2 : 0.08)
                            : cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: !_isPrivate ? const Color(0xFF4F46E5) : cardBorderColor,
                          width: !_isPrivate ? 1.5 : 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Public',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Anyone can search and join.',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Private Option
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isPrivate = true),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _isPrivate
                            ? const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.2 : 0.08)
                            : cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isPrivate ? const Color(0xFF4F46E5) : cardBorderColor,
                          width: _isPrivate ? 1.5 : 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Private',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Only invited students can join and see messages.',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 5. Member Approvals Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cardBorderColor, width: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Member Approvals',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Admins must approve requests to join.',
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _memberApprovals,
                    activeThumbColor: const Color(0xFF4F46E5),
                    activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.4 : 0.6),
                    onChanged: (val) => setState(() => _memberApprovals = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 6. Select Members Card
            Container(
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
                    'Select Members',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Pill Search Bar
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(21),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: isDark ? Colors.white38 : Colors.grey[500],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() => _searchQuery = val.trim()),
                            style: TextStyle(fontSize: 14, color: textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Search students, friends, contacts...',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white38 : Colors.grey[500],
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Selected Member Chips Strip
                  if (_selectedUsers.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _selectedUsers.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final user = _selectedUsers[index];
                          return Container(
                            padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFF6366F1),
                                  backgroundImage: user.avatarUrl != null &&
                                          user.avatarUrl!.isNotEmpty &&
                                          UrlValidator.isValidUrl(user.avatarUrl)
                                      ? CachedNetworkImageProvider(user.avatarUrl!)
                                      : null,
                                  child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                                      ? Text(
                                          user.displayName.isNotEmpty
                                              ? user.displayName[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  user.displayName.split(' ').first,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _toggleUser(user),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: isDark ? Colors.white60 : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 7. Contact List Card (Frequently Contacted / All Contacts)
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorderColor, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tab Headers
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _activeTab = 0),
                          child: Text(
                            'Frequently Contacted',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: _activeTab == 0 ? FontWeight.w700 : FontWeight.w500,
                              color: _activeTab == 0 ? textPrimary : textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: () => setState(() => _activeTab = 1),
                          child: Text(
                            'All Contacts',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: _activeTab == 1 ? FontWeight.w700 : FontWeight.w500,
                              color: _activeTab == 1 ? textPrimary : textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Contacts List
                  StreamBuilder<List<AppUser>>(
                    stream: usersStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      var users = (snapshot.data ?? [])
                          .where((u) => u.uid != currentUserId)
                          .toList();

                      if (users.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32.0),
                          child: Center(
                            child: Text(
                              _searchQuery.isNotEmpty ? 'No users matching "$_searchQuery"' : 'No contacts found',
                              style: TextStyle(fontSize: 14, color: textSecondary),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: users.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          thickness: 0.5,
                          indent: 68,
                          endIndent: 16,
                          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        ),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final isSelected = _selectedUsers.any((u) => u.uid == user.uid);

                          final colors = [
                            const Color(0xFF3B82F6),
                            const Color(0xFFF59E0B),
                            const Color(0xFFEC4899),
                            const Color(0xFF10B981),
                            const Color(0xFF8B5CF6),
                          ];
                          final avatarBg = colors[index % colors.length];

                          return InkWell(
                            onTap: () => _toggleUser(user),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  // User Avatar
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: avatarBg,
                                    backgroundImage: user.avatarUrl != null &&
                                            user.avatarUrl!.isNotEmpty &&
                                            UrlValidator.isValidUrl(user.avatarUrl)
                                        ? CachedNetworkImageProvider(user.avatarUrl!)
                                        : null,
                                    child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                                        ? Text(
                                            user.displayName.isNotEmpty
                                              ? user.displayName[0].toUpperCase()
                                              : '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 14),

                                  // Name and Major
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.displayName,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          user.department ?? 'Major - 2nd Year CS',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Circular Checkbox
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF4F46E5)
                                            : (isDark ? Colors.white30 : const Color(0xFFCBD5E1)),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Center(
                                            child: Icon(
                                              Icons.check_rounded,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
