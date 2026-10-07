import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../user/data/user_repository.dart';
import '../../../core/widgets/verification_badge.dart';
import '../data/chat_repository.dart';

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersStream = Stream.fromFuture(
      ref.watch(userRepositoryProvider).searchUsers(_searchQuery),
    );
    final currentUserId = ref.watch(chatRepositoryProvider).currentUserId;

    return Scaffold(
      appBar: AppBar(title: const Text('New Message')),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search students...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim();
                });
              },
            ),
          ),

          // User List
          Expanded(
            child: StreamBuilder<List<AppUser>>(
              stream: usersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final users = snapshot.data ?? [];

                // Filter out current user
                final filteredUsers = users
                    .where((user) => user.uid != currentUserId)
                    .toList();

                if (filteredUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No users found'
                              : 'No results',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return ListTile(
                      leading:
                          user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                          ? CircleAvatar(
                              backgroundImage: CachedNetworkImageProvider(
                                user.avatarUrl!,
                              ),
                              backgroundColor: Colors.grey[200],
                            )
                          : CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.1),
                              child: Text(
                                user.displayName.isNotEmpty
                                    ? user.displayName[0].toUpperCase()
                                    : user.email[0].toUpperCase(),
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                      title: Row(
                        children: [
                          Text(
                            user.displayName.isNotEmpty
                                ? user.displayName
                                : 'Student',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (user.isVerified) ...[
                            const SizedBox(width: 4),
                            VerificationBadge(
                              type: user.verificationType,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        user.handle.isNotEmpty ? user.handle : user.email,
                      ),
                      onTap: () async {
                        // Create or get channel with this user
                        try {
                          final currentUser = ref
                              .read(currentUserProvider)
                              .value;
                          if (currentUser == null) {
                            throw Exception('Profile not found');
                          }

                          final channelId = await ref
                              .read(chatRepositoryProvider)
                              .createOrGetChannel(
                                user.uid,
                                otherUserName: user.displayName,
                                otherUserAvatar: user.avatarUrl,
                                currentUserName: currentUser.displayName,
                                currentUserAvatar: currentUser.avatarUrl,
                              );

                          if (context.mounted) {
                            // Navigate to chat screen (use push to maintain back stack)
                            context.push('/chat/$channelId');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
