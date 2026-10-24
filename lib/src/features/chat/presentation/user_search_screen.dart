import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/utils/url_validator.dart';
import '../../../core/widgets/verification_badge.dart';
import '../../auth/data/auth_repository.dart';
import '../data/chat_repository.dart';

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _isLoading = true;
  String _searchQuery = '';
  List<AppUser> _users = [];
  String? _loadingUserId;

  @override
  void initState() {
    super.initState();
    _loadUsers('');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = value.trim();
        });
        _loadUsers(_searchQuery);
      }
    });
  }

  Future<void> _loadUsers(String query) async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(userRepositoryProvider);
      List<AppUser> result;
      if (query.isEmpty) {
        // Try getting people you may know or search default
        final suggestions = await repo.getPeopleYouMayKnow();
        if (suggestions.isNotEmpty) {
          result = suggestions.map((s) => s.user).toList();
        } else {
          result = await repo.searchUsers('');
        }
      } else {
        result = await repo.searchUsers(query);
      }

      if (mounted) {
        setState(() {
          _users = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading users in search screen: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleUserTap(AppUser user) async {
    if (_loadingUserId != null) return;
    setState(() => _loadingUserId = user.uid);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final currentUser = authRepo.currentUser ?? ref.read(currentUserProvider).value;

      final channelId = await ref.read(chatRepositoryProvider).createOrGetChannel(
            user.uid,
            otherUserName: user.displayName,
            otherUserAvatar: user.avatarUrl,
            currentUserName: currentUser?.displayName,
            currentUserAvatar: currentUser?.avatarUrl,
          );

      if (mounted) {
        context.push('/chat/$channelId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chat: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingUserId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = ref.watch(chatRepositoryProvider).currentUserId;

    // Filter out current user from the list
    final filteredUsers = _users.where((u) => u.uid != currentUserId).toList();

    final cardBg = isDark ? Colors.black : const Color(0xFFF1F5F9);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'New Message',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: textPrimary,
          ),
        ),
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: TextStyle(fontSize: 15, color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search students by name, handle, department...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white38 : Colors.grey[500],
                  ),
                  prefixIcon: Icon(
                    CupertinoIcons.search,
                    size: 20,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(CupertinoIcons.clear_circled_solid, size: 18),
                          color: isDark ? Colors.white54 : Colors.grey[500],
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // Quick AI DM Option
          if (_searchQuery.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: InkWell(
                onTap: () {
                  final aiUser = AppUser(
                    uid: 'abuad_ai',
                    displayName: 'ABUAD AI',
                    email: 'ai@abuad.edu.ng',
                    handle: 'abuad_ai',
                    avatarUrl:
                        'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=400&q=80',
                    bio: 'Official Campus & Academic Assistant',
                    isVerified: true,
                    verificationType: 'official',
                  );
                  _handleUserTap(aiUser);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF312E81), const Color(0xFF1E1B4B)]
                          : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.sparkles,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'ABUAD AI Assistant',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const VerificationBadge(type: 'official', size: 15),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Instant answers, study help & campus info',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        CupertinoIcons.chat_bubble_2_fill,
                        color: const Color(0xFF6366F1),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Header label
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text(
              _searchQuery.isEmpty ? 'SUGGESTED STUDENTS' : 'SEARCH RESULTS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: textSecondary,
              ),
            ),
          ),

          // User List / Loading / Empty
          Expanded(
            child: _isLoading
                ? _buildShimmerLoading(isDark)
                : filteredUsers.isEmpty
                    ? _buildEmptyState(isDark)
                    : RefreshIndicator(
                        onRefresh: () => _loadUsers(_searchQuery),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          itemCount: filteredUsers.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            indent: 72,
                            color: isDark ? Colors.black : const Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            final isItemLoading = _loadingUserId == user.uid;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                    backgroundImage: user.avatarUrl != null &&
                                            user.avatarUrl!.isNotEmpty &&
                                            UrlValidator.isValidUrl(user.avatarUrl)
                                        ? CachedNetworkImageProvider(user.avatarUrl!)
                                        : null,
                                    child: (user.avatarUrl == null ||
                                            user.avatarUrl!.isEmpty ||
                                            !UrlValidator.isValidUrl(user.avatarUrl))
                                        ? Text(
                                            user.displayName.isNotEmpty
                                                ? user.displayName[0].toUpperCase()
                                                : (user.handle.isNotEmpty
                                                    ? user.handle[0].toUpperCase()
                                                    : 'U'),
                                            style: const TextStyle(
                                              color: Color(0xFF6366F1),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          )
                                        : null,
                                  ),
                                  if (user.status == 'online')
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: theme.scaffoldBackgroundColor,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      user.displayName.isNotEmpty
                                          ? user.displayName
                                          : user.handle,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (user.isVerified) ...[
                                    const SizedBox(width: 4),
                                    VerificationBadge(
                                      type: user.verificationType,
                                      size: 15,
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                user.department != null && user.department!.isNotEmpty
                                    ? '${user.department!} • @${user.handle}'
                                    : (user.handle.isNotEmpty ? '@${user.handle}' : user.email),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: isItemLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.paperplane_fill,
                                        size: 16,
                                        color: Color(0xFF6366F1),
                                      ),
                                    ),
                              onTap: () => _handleUserTap(user),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.black : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _searchQuery.isEmpty ? CupertinoIcons.person_2 : CupertinoIcons.search,
                size: 48,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No students found'
                  : 'No results for "$_searchQuery"',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isEmpty
                  ? 'Try searching by student name, matric number, or username'
                  : 'Check for typos or try searching with another keyword',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    final baseColor = isDark ? Colors.black : const Color(0xFFE2E8F0);
    final highlightColor = isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        itemCount: 8,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const CircleAvatar(radius: 24, backgroundColor: Colors.white),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 140,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 90,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
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
    );
  }
}
